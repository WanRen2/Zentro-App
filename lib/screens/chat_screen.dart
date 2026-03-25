import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../api/backend_client.dart';
import '../managers/profile_manager.dart';
import '../crypto/chat_crypto.dart';
import '../config.dart';
import '../resources/stickers.dart';
import 'scan_qr_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final List<int> chatKey;
  final String chatName;

  const ChatScreen({
    required this.chatId,
    required this.chatKey,
    required this.chatName,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final BackendClient _backend = BackendClient();
  final ImagePicker _imagePicker = ImagePicker();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _myFingerprint = '';
  Timer? _pollingTimer;
  bool _showStickers = false;
  int _selectedStickerPack = 0;
  String _chatWallpaper = 'default';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    await _loadWallpaper();
    setState(() {
      _myFingerprint = profile?.fingerprint ?? '';
    });
    await _loadMessages();
    _startPolling();
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'wallpaper_${widget.chatId}';
    setState(() {
      _chatWallpaper = prefs.getString(key) ?? 'default';
    });
  }

  Future<void> _saveWallpaper(String wallpaperId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'wallpaper_${widget.chatId}';
    await prefs.setString(key, wallpaperId);
    setState(() {
      _chatWallpaper = wallpaperId;
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      Duration(seconds: AppConfig.pollingIntervalSeconds),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final ids = await _backend.listMessages(widget.chatId);
      final newMessages = <Map<String, dynamic>>[];

      for (final id in ids) {
        final exists = _messages.any((m) => m['id'] == id);
        if (!exists) {
          try {
            final m = await _backend.getMessage(widget.chatId, id);
            final msgType = m['type'] as String? ?? 'text';

            if (msgType == 'image') {
              final mediaId = m['media_id'] as String?;
              String? imageData;
              if (mediaId != null) {
                try {
                  imageData = await _backend.getMedia(
                    'media/${widget.chatId}/$mediaId.jpg',
                  );
                } catch (e) {
                  try {
                    imageData = await _backend.getMedia(
                      'media/${widget.chatId}/$mediaId',
                    );
                  } catch (_) {}
                }
              }
              newMessages.add({
                'id': id,
                ...m,
                'image_data': imageData,
                'text': null,
                'decryptFailed': false,
              });
            } else if (msgType == 'sticker') {
              newMessages.add({
                'id': id,
                ...m,
                'text': m['sticker'] as String?,
                'decryptFailed': false,
              });
            } else {
              String? decryptedText;
              bool decryptFailed = false;

              if (m.containsKey('ciphertext') &&
                  m.containsKey('nonce') &&
                  m.containsKey('mac') &&
                  (m['mac'] as String?)?.isNotEmpty == true) {
                try {
                  final dec = await ChatCrypto.decryptWithChatKey(
                    widget.chatKey,
                    m['nonce'] as String,
                    m['ciphertext'] as String,
                    m['mac'] as String,
                  );
                  decryptedText = utf8.decode(dec);
                } catch (e) {
                  decryptFailed = true;
                }
              } else {
                decryptFailed = true;
              }

              newMessages.add({
                'id': id,
                ...m,
                'text': decryptFailed ? '[Encrypted]' : decryptedText,
                'decryptFailed': decryptFailed,
              });
            }
          } catch (e) {}
        }
      }

      if (newMessages.isNotEmpty || _isLoading) {
        setState(() {
          _messages.addAll(newMessages);
          _messages.sort(
            (a, b) => ((a['ts'] ?? 0) as int).compareTo((b['ts'] ?? 0) as int),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final plaintext = utf8.encode(text);
      final enc = await ChatCrypto.encryptWithChatKey(
        widget.chatKey,
        Uint8List.fromList(plaintext),
      );
      final payload = {
        'v': 1,
        'type': 'text',
        'from': _myFingerprint,
        'nonce': enc['nonce'],
        'ciphertext': enc['ciphertext'],
        'mac': enc['mac'],
        'ts': ts,
      };
      final messageId = const Uuid().v4();
      await _backend.uploadMessage(widget.chatId, messageId, payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final messageId = const Uuid().v4();

      setState(() {
        _messages.add({
          'id': messageId,
          'type': 'image',
          'from': _myFingerprint,
          'image_data': base64Image,
          'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'pending': true,
        });
      });

      await _backend.uploadMedia(
        widget.chatId,
        messageId,
        'image',
        base64Image,
      );

      final payload = {
        'v': 1,
        'type': 'image',
        'from': _myFingerprint,
        'media_id': messageId,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      await _backend.uploadMessage(widget.chatId, messageId, payload);

      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index >= 0) {
          _messages[index]['pending'] = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send image: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  Future<void> _sendSticker(StickerData sticker) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = {
        'v': 1,
        'type': 'sticker',
        'from': _myFingerprint,
        'sticker': sticker.emoji,
        'sticker_id': sticker.id,
        'ts': ts,
      };
      final messageId = const Uuid().v4();
      await _backend.uploadMessage(widget.chatId, messageId, payload);

      setState(() {
        _messages.add({
          'id': messageId,
          ...payload,
          'text': sticker.emoji,
          'sticker_id': sticker.id,
        });
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send sticker: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WallpaperPicker(
        currentWallpaper: _chatWallpaper,
        onSelect: (id) {
          _saveWallpaper(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = WallpaperService.getById(_chatWallpaper);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: wallpaper.isGradient
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [wallpaper.primaryColor, wallpaper.secondaryColor],
                )
              : null,
          color: wallpaper.isGradient ? null : wallpaper.primaryColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FF9C),
                        ),
                      )
                    : _messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(),
              ),
              if (_showStickers) _buildStickerPanel(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFE0E0E0)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.lock, size: 12, color: Color(0xFF00FF9C)),
                    const SizedBox(width: 4),
                    Text(
                      'E2E Encrypted',
                      style: TextStyle(
                        color: const Color(0xFF00FF9C).withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.wallpaper, color: Color(0xFF00FF9C)),
            onPressed: _showWallpaperPicker,
            tooltip: 'Change wallpaper',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, color: Color(0xFF00FF9C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScanQrScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: const Color(0xFF00FF9C).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a message to start',
            style: TextStyle(color: Color(0xFF555555), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg['from'] == _myFingerprint;
        final msgType = msg['type'] as String? ?? 'text';

        if (msgType == 'sticker') {
          return _buildStickerMessage(msg, isMe);
        } else if (msgType == 'image') {
          return _buildImageMessage(msg, isMe);
        }

        final decryptFailed = msg['decryptFailed'] == true;
        if (isMe && decryptFailed) {
          return const SizedBox.shrink();
        }

        final text = msg['text'] as String? ?? '[Encrypted]';

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF00FF9C) : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isMe
                        ? const Color(0xFF0A0A0A)
                        : const Color(0xFFE0E0E0),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe) ...[
                      const Icon(
                        Icons.lock,
                        size: 10,
                        color: Color(0xFF00FF9C),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTime(msg['ts'] ?? 0),
                      style: TextStyle(
                        color: isMe
                            ? const Color(0xFF0A0A0A).withValues(alpha: 0.6)
                            : const Color(0xFF888888),
                        fontSize: 10,
                      ),
                    ),
                    if (msg['pending'] == true) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: isMe
                              ? const Color(0xFF0A0A0A).withValues(alpha: 0.6)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickerMessage(Map<String, dynamic> msg, bool isMe) {
    final stickerId =
        msg['sticker_id'] as String? ??
        msg['sticker'] as String? ??
        msg['text'] as String? ??
        '';
    final allStickers = StickerService.allStickers;
    final stickerData = allStickers
        .where((s) => s.id == stickerId || s.emoji == stickerId)
        .firstOrNull;
    final hasAnimation = stickerData?.hasAnimation ?? false;
    final lottieAsset = stickerData?.lottieAsset;
    final bgColor = stickerData?.backgroundColor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 80, minHeight: 80),
        decoration: BoxDecoration(
          color:
              bgColor?.withValues(alpha: 0.3) ??
              (isMe
                  ? const Color(0xFF00FF9C).withValues(alpha: 0.2)
                  : const Color(0xFF1A1A1A)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isMe ? const Color(0xFF00FF9C) : const Color(0xFF2A2A2A),
          ),
        ),
        child: hasAnimation && lottieAsset != null
            ? Lottie.asset(
                lottieAsset,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                repeat: true,
              )
            : Text(
                stickerId.isNotEmpty ? stickerId : '🎉',
                style: const TextStyle(fontSize: 48),
              ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> msg, bool isMe) {
    final imageData = msg['image_data'] as String?;
    final pending = msg['pending'] == true;

    if (imageData == null) return const SizedBox.shrink();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? const Color(0xFF00FF9C) : const Color(0xFF2A2A2A),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Image.memory(
                base64Decode(imageData),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
              if (pending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00FF9C),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 4,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatTime(msg['ts'] ?? 0),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerPanel() {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard, color: Color(0xFF888888)),
                  onPressed: () => setState(() => _showStickers = false),
                ),
                const Spacer(),
                const Text(
                  'Stickers',
                  style: TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: StickerService.packs.length,
              itemBuilder: (context, index) {
                final pack = StickerService.packs[index];
                final isSelected = _selectedStickerPack == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStickerPack = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00FF9C)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pack.icon,
                      style: TextStyle(fontSize: isSelected ? 18 : 16),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount:
                  StickerService.packs[_selectedStickerPack].stickers.length,
              itemBuilder: (context, index) {
                final sticker =
                    StickerService.packs[_selectedStickerPack].stickers[index];
                return GestureDetector(
                  onTap: () {
                    _sendSticker(sticker);
                    setState(() => _showStickers = false);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          sticker.backgroundColor?.withValues(alpha: 0.2) ??
                          const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: sticker.hasAnimation
                          ? Lottie.asset(
                              sticker.lottieAsset!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                              repeat: false,
                            )
                          : Text(
                              sticker.emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(color: Color(0xFF0A0A0A)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showStickers ? Icons.keyboard : Icons.emoji_emotions,
                  color: const Color(0xFF00FF9C),
                ),
                onPressed: () => setState(() => _showStickers = !_showStickers),
              ),
              IconButton(
                icon: const Icon(Icons.image, color: Color(0xFF00FF9C)),
                onPressed: _pickAndSendImage,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Color(0xFFE0E0E0)),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(color: Color(0xFF888888)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF00FF9C),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF0A0A0A)),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _WallpaperPicker extends StatelessWidget {
  final String currentWallpaper;
  final Function(String) onSelect;

  const _WallpaperPicker({
    required this.currentWallpaper,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Chat Wallpaper',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Choose a background for this chat',
              style: TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: WallpaperService.presets.length,
              itemBuilder: (context, index) {
                final wallpaper = WallpaperService.presets[index];
                final isSelected = currentWallpaper == wallpaper.id;
                return GestureDetector(
                  onTap: () => onSelect(wallpaper.id),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: wallpaper.isGradient
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                wallpaper.primaryColor,
                                wallpaper.secondaryColor,
                              ],
                            )
                          : null,
                      color: wallpaper.isGradient
                          ? null
                          : wallpaper.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF00FF9C)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.chat_bubble,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 32,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FF9C),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Color(0xFF0A0A0A),
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
