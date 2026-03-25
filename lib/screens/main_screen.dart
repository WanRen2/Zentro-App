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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final pm = ProfileManager();
    final profile = await pm.loadProfile();
    if (profile != null) {
      _backend.setAuthToken(profile.token);
    }
    await _chatManager.loadChats();
    await _chatManager.loadFriends();
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
          chatKey: chat.chatKeyBase64,
        );
      } catch (_) {}

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

  Future<void> _createChatWithFriend(Map<String, dynamic> friend) async {
    try {
      final chat = await _chatManager.createChatWithFriend(
        friend['name'] ?? 'Unknown',
        friend['fingerprint'] ?? '',
        friend['public_key'] ?? '',
      );

      try {
        await _backend.uploadChatKey(
          chat.id,
          _profile?.fingerprint ?? '',
          chat.chatKeyBase64,
        );
      } catch (_) {}

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            chatKey: chat.chatKey,
            chatName: chat.name,
          ),
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

  Future<void> _deleteChat(String chatId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Chat',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: const Text(
          'Delete this chat? This cannot be undone.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
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

    if (confirm == true) {
      await _chatManager.deleteChat(chatId);
      setState(() {});
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Remove Friend',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: const Text(
          'Remove this friend? This cannot be undone.',
          style: TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatManager.removeFriend(friendId);
      setState(() {});
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _ChatsTab(
            chatManager: _chatManager,
            profile: _profile,
            onRefresh: _loadData,
            onCreateChat: _createChat,
            onDeleteChat: _deleteChat,
            onScan: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQrScreen()),
            ),
          ),
          _FriendsTab(
            chatManager: _chatManager,
            profile: _profile,
            onRemoveFriend: _removeFriend,
            onMessage: _createChatWithFriend,
            onScan: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQrScreen()),
            ),
          ),
          ProfileScreen(profile: _profile, onRefresh: _loadData),
        ],
      ),
      floatingActionButton: _currentIndex != 2
          ? FloatingActionButton(
              onPressed: _currentIndex == 0
                  ? _createChat
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                    ),
              backgroundColor: const Color(0xFF00FF9C),
              child: Icon(
                _currentIndex == 0 ? Icons.add : Icons.qr_code_scanner,
                color: const Color(0xFF0A0A0A),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF9C).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.chat_bubble_outline,
                  Icons.chat_bubble,
                  'Chats',
                ),
                const SizedBox(width: 48),
                _buildNavItem(1, Icons.people_outline, Icons.people, 'Friends'),
                const SizedBox(width: 48),
                _buildNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? const Color(0xFF00FF9C)
                  : const Color(0xFF888888),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00FF9C)
                    : const Color(0xFF888888),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
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
  final Function(String) onDeleteChat;
  final VoidCallback onScan;

  const _ChatsTab({
    required this.chatManager,
    required this.profile,
    required this.onRefresh,
    required this.onCreateChat,
    required this.onDeleteChat,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZENTRO',
                      style: TextStyle(
                        color: Color(0xFF00FF9C),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    if (profile?.name != null)
                      Text(
                        profile!.name,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Color(0xFF00FF9C),
                  ),
                  onPressed: onScan,
                ),
              ],
            ),
          ),
          Expanded(
            child: chatManager.chats.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: chatManager.chats.length,
                    itemBuilder: (context, index) {
                      final chat = chatManager.chats[index];
                      return Dismissible(
                        key: Key(chat.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          onDeleteChat(chat.id);
                          return false;
                        },
                        child: _ChatTile(
                          chat: chat,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chat.id,
                                chatKey: chat.chatKey,
                                chatName: chat.name,
                              ),
                            ),
                          ).then((_) => onRefresh()),
                          onInvite: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InviteScreen(chat: chat, profile: profile!),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Color(0xFF00FF9C),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No chats yet',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  const _ChatTile({
    required this.chat,
    required this.onTap,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFF00FF9C,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF00FF9C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.lock,
                            size: 12,
                            color: Color(0xFF00FF9C),
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
                  icon: const Icon(
                    Icons.qr_code,
                    color: Color(0xFF888888),
                    size: 20,
                  ),
                  onPressed: onInvite,
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF888888)),
              ],
            ),
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
  final ChatManager chatManager;
  final ProfileModel? profile;
  final Function(String) onRemoveFriend;
  final Function(Map<String, dynamic>) onMessage;
  final VoidCallback onScan;

  const _FriendsTab({
    required this.chatManager,
    required this.profile,
    required this.onRemoveFriend,
    required this.onMessage,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FRIENDS',
                  style: TextStyle(
                    color: Color(0xFF00FF9C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: Color(0xFF00FF9C)),
                  onPressed: onScan,
                ),
              ],
            ),
          ),
          Expanded(
            child: chatManager.friends.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: chatManager.friends.length,
                    itemBuilder: (context, index) {
                      final friend = chatManager.friends[index];
                      return Dismissible(
                        key: Key(friend['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          onRemoveFriend(friend['id']);
                          return false;
                        },
                        child: _FriendTile(
                          friend: friend,
                          onTap: () => onMessage(friend),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
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
          const SizedBox(height: 24),
          const Text(
            'No friends yet',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan a QR code to add friends',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00FF9C)),
            label: const Text(
              'Scan QR Code',
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
}

class _FriendTile extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onTap;

  const _FriendTile({required this.friend, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFF00FF9C,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    (friend['name'] ?? '?')[0].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00FF9C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              friend['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.lock,
                            size: 12,
                            color: Color(0xFF00FF9C),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FP: ${(friend['fingerprint'] ?? '').substring(0, 8)}...',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF888888)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
