import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api/backend_client.dart';
import '../managers/profile_manager.dart';
import '../crypto/chat_crypto.dart';
import '../config.dart';
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
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String _myFingerprint = '';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    setState(() {
      _myFingerprint = profile?.fingerprint ?? '';
    });
    await _loadMessages();
    _startPolling();
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
        // Check if message already loaded
        final exists = _messages.any((m) => m['id'] == id);
        if (!exists) {
          try {
            final m = await _backend.getMessage(widget.chatId, id);
            newMessages.add({'id': id, ...m});
          } catch (e) {
            // Message might not exist yet
          }
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
        'from': _myFingerprint,
        'nonce': enc['nonce'],
        'ciphertext': enc['ciphertext'],
        'ts': ts,
      };
      final messageId = const Uuid().v4();
      await _backend.uploadMessage(widget.chatId, messageId, payload);

      setState(() {
        _messages.add({'id': messageId, ...payload, 'text': text});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE0E0E0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
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
        actions: [
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF9C)),
                  )
                : _messages.isEmpty
                ? _buildEmptyChat()
                : _buildMessageList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF2A2A2A)),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(color: Color(0xFF888888), fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message to start the conversation',
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
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Color(0xFFE0E0E0)),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Color(0xFF888888)),
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
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
            const SizedBox(width: 12),
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
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
