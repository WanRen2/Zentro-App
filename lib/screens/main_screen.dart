import 'dart:async';
import 'package:flutter/material.dart';
import '../managers/profile_manager.dart';
import '../managers/chat_manager.dart';
import '../api/backend_client.dart';
import '../models/profile_model.dart';
import '../models/chat_model.dart';
import 'chat_screen.dart';
import 'invite_screen.dart';
import 'scan_qr_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ChatManager _chatManager = ChatManager();
  final BackendClient _backend = BackendClient();
  ProfileModel? _profile;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    await _chatManager.loadChats();
    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  Future<void> _createChat() async {
    final name = await _showCreateChatDialog();
    if (name == null || name.isEmpty) return;

    try {
      final chat = await _chatManager.createChat(name);

      try {
        await _backend.uploadChatKey(
          chat.id,
          _profile?.fingerprint ?? '',
          chat.chatKeyBase64,
        );
      } catch (_) {}

      setState(() {});

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InviteScreen(chat: chat, profile: _profile!),
        ),
      ).then((_) => _loadData());
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'New Chat',
                style: TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Color(0xFFE0E0E0)),
                decoration: InputDecoration(
                  hintText: 'Chat name',
                  hintStyle: const TextStyle(color: Color(0xFF888888)),
                  filled: true,
                  fillColor: const Color(0xFF0A0A0A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF9C),
                    foregroundColor: const Color(0xFF0A0A0A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _ChatsTab(
            chatManager: _chatManager,
            profile: _profile,
            onRefresh: _loadData,
            onCreateChat: _createChat,
          ),
          _FriendsTab(profile: _profile),
          ProfileScreen(profile: _profile, onRefresh: _loadData),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.chat_bubble_outline, 'Chats'),
              _buildNavItem(1, Icons.people_outline, 'Friends'),
              _buildNavItem(2, Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FF9C).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF00FF9C)
                  : const Color(0xFF888888),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00FF9C),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatsTab extends StatelessWidget {
  final ChatManager chatManager;
  final ProfileModel? profile;
  final VoidCallback onRefresh;
  final VoidCallback onCreateChat;

  const _ChatsTab({
    required this.chatManager,
    required this.profile,
    required this.onRefresh,
    required this.onCreateChat,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chats',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${chatManager.chats.length} conversations',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF00FF9C),
              size: 28,
            ),
            onPressed: onCreateChat,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: chatManager.chats.isEmpty
          ? _buildEmptyState()
          : _buildChatList(context),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: const Color(0xFF888888).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'No conversations yet',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new chat to begin',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: chatManager.chats.length,
      itemBuilder: (context, index) {
        final chat = chatManager.chats[index];
        return _buildChatTile(context, chat);
      },
    );
  }

  Widget _buildChatTile(BuildContext context, ChatModel chat) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
          ).then((_) => onRefresh());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF00FF9C),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          chat.name,
                          style: const TextStyle(
                            color: Color(0xFFE0E0E0),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          Icons.lock,
                          size: 14,
                          color: const Color(0xFF00FF9C).withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(chat.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code, color: Color(0xFF888888)),
                onPressed: () {
                  if (profile != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InviteScreen(chat: chat, profile: profile!),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _FriendsTab extends StatelessWidget {
  final ProfileModel? profile;

  const _FriendsTab({this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Friends',
              style: TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Add and manage your contacts',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Color(0xFF00FF9C),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Add Friends',
                style: TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan a QR code to add friends and start encrypted conversations',
                style: TextStyle(color: Color(0xFF888888), fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 22),
                  label: const Text(
                    'Scan QR Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF9C),
                    foregroundColor: const Color(0xFF0A0A0A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
