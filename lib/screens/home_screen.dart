import 'package:flutter/material.dart';
import '../managers/profile_manager.dart';
import '../managers/chat_manager.dart';
import '../api/backend_client.dart';
import '../models/profile_model.dart';
import '../models/chat_model.dart';
import 'chat_screen.dart';
import 'invite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatManager _chatManager = ChatManager();
  final BackendClient _backend = BackendClient();
  bool _isLoading = true;
  String? _profileName;
  String? _fingerprint;
  ProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    await _chatManager.loadChats();
    setState(() {
      _profile = profile;
      _profileName = profile?.name;
      _fingerprint = profile?.fingerprint;
      _isLoading = false;
    });
  }

  Future<void> _createChat() async {
    final name = await _showCreateChatDialog();
    if (name == null || name.isEmpty) return;

    try {
      final chat = await _chatManager.createChat(name);

      // Upload chat key to backend (silently fail if backend unavailable)
      try {
        await _backend.uploadChatKey(
          chat.id,
          _fingerprint ?? '',
          chat.chatKeyBase64,
        );
      } catch (e) {
        // Backend not available - continue anyway
      }

      setState(() {});

      if (!mounted) return;

      // Show invite screen with QR code for sharing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InviteScreen(chat: chat, profile: _profile!),
        ),
      ).then((_) => setState(() {}));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create chat: $e'),
          backgroundColor: const Color(0xFFFF4444),
        ),
      );
    }
  }

  Future<String?> _showCreateChatDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'New Chat',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE0E0E0)),
          decoration: const InputDecoration(
            hintText: 'Chat name',
            hintStyle: TextStyle(color: Color(0xFF888888)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF9C),
              foregroundColor: const Color(0xFF0A0A0A),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ZENTRO',
              style: TextStyle(
                color: Color(0xFF00FF9C),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (_profileName != null)
              Text(
                _profileName!,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF9C)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF9C)),
            )
          : _chatManager.chats.isEmpty
          ? _buildEmptyState()
          : _buildChatList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChat,
        backgroundColor: const Color(0xFF00FF9C),
        child: const Icon(Icons.add, color: Color(0xFF0A0A0A)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Color(0xFF2A2A2A),
          ),
          const SizedBox(height: 24),
          const Text(
            'No chats yet',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new chat to get started',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _createChat,
            icon: const Icon(Icons.add, color: Color(0xFF00FF9C)),
            label: const Text(
              'Create Chat',
              style: TextStyle(color: Color(0xFF00FF9C)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00FF9C)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _chatManager.chats.length,
      itemBuilder: (context, index) {
        final chat = _chatManager.chats[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Text(
          chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Color(0xFF00FF9C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        chat.name,
        style: const TextStyle(
          color: Color(0xFFE0E0E0),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Created ${_formatDate(chat.createdAt)}',
        style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Color(0xFF00FF9C), size: 20),
            onPressed: () {
              if (_profile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InviteScreen(chat: chat, profile: _profile!),
                  ),
                );
              }
            },
            tooltip: 'Share invite',
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF888888)),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chat.id,
              chatKey: chat.chatKey,
              chatName: chat.name,
            ),
          ),
        ).then((_) => setState(() {}));
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
