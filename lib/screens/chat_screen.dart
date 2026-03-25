import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _pendingMessageIds = {};
  bool _isLoading = true;
  String _myFingerprint = '';
  String _myName = '';
  Timer? _pollingTimer;
  bool _showEmojiPicker = false;
  bool _showStickers = false;
  int _selectedStickerPack = 0;
  String _chatWallpaper = 'default';
  final List<Map<String, dynamic>> _pendingImages = [];

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
      _myName = profile?.name ?? 'User';
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
    _scrollController.dispose();
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
          _messages.removeWhere((m) => _pendingMessageIds.contains(m['id']));
          _messages.sort(
            (a, b) => ((a['ts'] ?? 0) as int).compareTo((b['ts'] ?? 0) as int),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;

    _controller.clear();

    if (_pendingImages.isNotEmpty) {
      await _sendImageMessage();
      return;
    }

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
        'from_name': _myName,
        'nonce': enc['nonce'],
        'ciphertext': enc['ciphertext'],
        'mac': enc['mac'],
        'ts': ts,
        'reactions': <String>[],
      };
      final messageId = const Uuid().v4();

      setState(() {
        _messages.add({
          'id': messageId,
          ...payload,
          'text': text,
          'decryptFailed': false,
          'pending': true,
        });
        _pendingMessageIds.add(messageId);
      });
      _scrollToBottom();

      await _backend.uploadMessage(widget.chatId, messageId, payload);

      setState(() {
        _pendingMessageIds.remove(messageId);
        final idx = _messages.indexWhere((m) => m['id'] == messageId);
        if (idx >= 0) _messages[idx]['pending'] = false;
      });
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

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
        limit: 10 - _pendingImages.length,
      );

      if (images.isEmpty) return;

      final newImages = <Map<String, dynamic>>[];
      for (final img in images.take(10 - _pendingImages.length)) {
        final bytes = await img.readAsBytes();
        newImages.add({'file': img, 'bytes': bytes});
      }

      setState(() {
        _pendingImages.addAll(newImages);
      });

      if (_pendingImages.isNotEmpty && !_showEmojiPicker) {
        _showPendingImagesPreview();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  void _showPendingImagesPreview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_pendingImages.length} images selected',
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 16,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _pendingImages.clear());
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Color(0xFFFF4444)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: MemoryImage(
                              _pendingImages[index]['bytes'] as Uint8List? ??
                                  Uint8List(0),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _pendingImages.removeAt(index));
                            if (_pendingImages.isEmpty) Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sendImageMessage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF9C),
                  foregroundColor: const Color(0xFF0A0A0A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageMessage() async {
    if (_pendingImages.isEmpty) return;

    final imagesToSend = List<Map<String, dynamic>>.from(_pendingImages);
    setState(() => _pendingImages.clear());

    for (final imageData in imagesToSend) {
      try {
        final bytes = imageData['bytes'] as Uint8List;
        final base64Image = base64Encode(bytes);
        final messageId = const Uuid().v4();

        setState(() {
          _messages.add({
            'id': messageId,
            'type': 'image',
            'from': _myFingerprint,
            'from_name': _myName,
            'image_data': base64Image,
            'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'pending': true,
            'reactions': <String>[],
          });
          _pendingMessageIds.add(messageId);
        });
        _scrollToBottom();

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
          'from_name': _myName,
          'media_id': messageId,
          'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'reactions': <String>[],
        };
        await _backend.uploadMessage(widget.chatId, messageId, payload);

        setState(() {
          _pendingMessageIds.remove(messageId);
          final idx = _messages.indexWhere((m) => m['id'] == messageId);
          if (idx >= 0) _messages[idx]['pending'] = false;
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
  }

  Future<void> _sendSticker(StickerData sticker) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = {
        'v': 1,
        'type': 'sticker',
        'from': _myFingerprint,
        'from_name': _myName,
        'sticker': sticker.emoji,
        'sticker_id': sticker.id,
        'ts': ts,
        'reactions': <String>[],
      };
      final messageId = const Uuid().v4();

      setState(() {
        _messages.add({
          'id': messageId,
          ...payload,
          'text': sticker.emoji,
          'pending': true,
        });
        _pendingMessageIds.add(messageId);
      });
      _scrollToBottom();

      await _backend.uploadMessage(widget.chatId, messageId, payload);

      setState(() {
        _pendingMessageIds.remove(messageId);
        final idx = _messages.indexWhere((m) => m['id'] == messageId);
        if (idx >= 0) _messages[idx]['pending'] = false;
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

  Future<void> _addReaction(String messageId, String emoji) async {
    final idx = _messages.indexWhere((m) => m['id'] == messageId);
    if (idx < 0) return;

    final reactions = List<String>.from(_messages[idx]['reactions'] ?? []);
    if (reactions.contains(emoji)) {
      reactions.remove(emoji);
    } else {
      reactions.add(emoji);
    }

    setState(() {
      _messages[idx]['reactions'] = reactions;
    });

    try {
      final m = await _backend.getMessage(widget.chatId, messageId);
      m['reactions'] = reactions;
      await _backend.uploadMessage(widget.chatId, messageId, m);
    } catch (e) {}
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete message',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: const Text(
          'This message will be deleted for everyone.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _messages.removeWhere((m) => m['id'] == messageId);
    });

    try {
      final payload = {
        'v': 1,
        'type': 'deleted',
        'deleted': true,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      await _backend.uploadMessage(widget.chatId, messageId, payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  void _showMessageOptions(String messageId, String fromFingerprint) {
    final isMyMessage = fromFingerprint == _myFingerprint;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReactionPicker(messageId),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFFF4444)),
              title: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF4444)),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId);
              },
            ),
            if (!isMyMessage)
              ListTile(
                leading: const Icon(Icons.block, color: Color(0xFFFFAA00)),
                title: const Text(
                  'Block user',
                  style: TextStyle(color: Color(0xFFFFAA00)),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF00FF9C)),
              title: const Text(
                'Copy',
                style: TextStyle(color: Color(0xFF00FF9C)),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionPicker(String messageId) {
    const quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: quickReactions.map((emoji) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            _addReaction(messageId, emoji);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        );
      }).toList(),
    );
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
              if (_showEmojiPicker) _buildEmojiPicker(),
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isMe = msg['from'] == _myFingerprint;
        final msgType = msg['type'] as String? ?? 'text';
        final isDeleted = msg['deleted'] == true;

        if (isDeleted) {
          return _buildDeletedMessage(isMe);
        }

        if (msgType == 'sticker') {
          return _buildStickerMessage(msg, isMe);
        } else if (msgType == 'image') {
          return _buildImageMessage(msg, isMe);
        }

        final decryptFailed = msg['decryptFailed'] == true;
        if (isMe && decryptFailed) {
          return const SizedBox.shrink();
        }

        return _buildTextMessage(msg, isMe);
      },
    );
  }

  Widget _buildDeletedMessage(bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'This message was deleted',
          style: TextStyle(
            color: const Color(0xFF888888).withValues(alpha: 0.6),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(Map<String, dynamic> msg, bool isMe) {
    final text = msg['text'] as String? ?? '[Encrypted]';
    final name = msg['from_name'] as String? ?? 'User';
    final reactions = List<String>.from(msg['reactions'] ?? []);
    final pending = msg['pending'] == true;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg['id'], msg['from']),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF00FF9C),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF00FF9C),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? const Color(0xFF00FF9C)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              color: isMe
                                  ? const Color(0xFF0A0A0A)
                                  : const Color(0xFFE0E0E0),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(msg['ts'] ?? 0),
                                style: TextStyle(
                                  color: isMe
                                      ? const Color(
                                          0xFF0A0A0A,
                                        ).withValues(alpha: 0.6)
                                      : const Color(0xFF888888),
                                  fontSize: 10,
                                ),
                              ),
                              if (pending) ...[
                                const SizedBox(width: 4),
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1,
                                    color: Color(0xFF0A0A0A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) const SizedBox(width: 40),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions
                          .map(
                            (r) =>
                                Text(r, style: const TextStyle(fontSize: 14)),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStickerMessage(Map<String, dynamic> msg, bool isMe) {
    final name = msg['from_name'] as String? ?? 'User';
    final reactions = List<String>.from(msg['reactions'] ?? []);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg['id'], msg['from']),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF00FF9C),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe
                      ? const Color(0xFF00FF9C).withValues(alpha: 0.2)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMe
                        ? const Color(0xFF00FF9C)
                        : const Color(0xFF2A2A2A),
                  ),
                ),
                child: Text(
                  msg['sticker'] as String? ?? msg['text'] as String? ?? '🎉',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              if (isMe) const SizedBox(width: 40),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions
                          .map(
                            (r) =>
                                Text(r, style: const TextStyle(fontSize: 14)),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> msg, bool isMe) {
    final imageData = msg['image_data'] as String?;
    final name = msg['from_name'] as String? ?? 'User';
    final pending = msg['pending'] == true;
    final reactions = List<String>.from(msg['reactions'] ?? []);

    if (imageData == null) return const SizedBox.shrink();

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg['id'], msg['from']),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF00FF9C),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF00FF9C)
                          : const Color(0xFF2A2A2A),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 40),
            ],
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: reactions
                          .map(
                            (r) =>
                                Text(r, style: const TextStyle(fontSize: 14)),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 300,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          _controller.text += emoji.emoji;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        },
        config: Config(
          height: 300,
          checkPlatformCompatibility: true,
          emojiViewConfig: const EmojiViewConfig(
            backgroundColor: Color(0xFF1A1A1A),
            gridPadding: EdgeInsets.zero,
            horizontalSpacing: 0,
            verticalSpacing: 0,
          ),
          categoryViewConfig: const CategoryViewConfig(
            backgroundColor: Color(0xFF1A1A1A),
            indicatorColor: Color(0xFF00FF9C),
            iconColorSelected: Color(0xFF00FF9C),
            iconColor: Color(0xFF888888),
          ),
          bottomActionBarConfig: const BottomActionBarConfig(
            backgroundColor: Color(0xFF1A1A1A),
            buttonColor: Color(0xFF2A2A2A),
            buttonIconColor: Color(0xFF00FF9C),
          ),
          searchViewConfig: const SearchViewConfig(
            backgroundColor: Color(0xFF1A1A1A),
            buttonIconColor: Color(0xFF00FF9C),
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
                      child: Text(
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
          if (_pendingImages.isNotEmpty)
            Container(
              height: 60,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _pendingImages[index]['bytes'] as Uint8List? ??
                            Uint8List(0),
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      ),
                    ),
                  );
                },
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                  color: const Color(0xFF00FF9C),
                ),
                onPressed: () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                    _showStickers = false;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  _showStickers ? Icons.keyboard : Icons.sticky_note_2,
                  color: const Color(0xFF00FF9C),
                ),
                onPressed: () {
                  setState(() {
                    _showStickers = !_showStickers;
                    _showEmojiPicker = false;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.image, color: Color(0xFF00FF9C)),
                onPressed: _pickImages,
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
