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
  bool _isEditMode = false;
  final Set<String> _selectedChats = {};
  final Set<String> _selectedFriends = {};

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
    await _chatManager.loadChats();
    await _chatManager.loadFriends();
    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        _selectedChats.clear();
        _selectedFriends.clear();
      }
    });
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChats.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Delete Chats',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: Text(
          'Delete ${_selectedChats.length} chat(s)?',
          style: const TextStyle(color: Color(0xFF888888)),
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
      await _chatManager.deleteChats(_selectedChats.toList());
      setState(() {
        _selectedChats.clear();
        _isEditMode = false;
      });
    }
  }

  Future<void> _deleteSelectedFriends() async {
    if (_selectedFriends.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Remove Friends',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        content: Text(
          'Remove ${_selectedFriends.length} friend(s)?',
          style: const TextStyle(color: Color(0xFF888888)),
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
      await _chatManager.removeFriends(_selectedFriends.toList());
      setState(() {
        _selectedFriends.clear();
        _isEditMode = false;
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
            isEditMode: _isEditMode,
            selectedChats: _selectedChats,
            onToggleEdit: _toggleEditMode,
            onSelectChat: (id, selected) {
              setState(() {
                if (selected) {
                  _selectedChats.add(id);
                } else {
                  _selectedChats.remove(id);
                }
              });
            },
            onDeleteSelected: _deleteSelectedChats,
            onRefresh: _loadData,
            onCreateChat: _createChat,
            onScan: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanQrScreen()),
            ),
          ),
          _FriendsTab(
            chatManager: _chatManager,
            profile: _profile,
            isEditMode: _isEditMode,
            selectedFriends: _selectedFriends,
            onToggleEdit: _toggleEditMode,
            onSelectFriend: (id, selected) {
              setState(() {
                if (selected) {
                  _selectedFriends.add(id);
                } else {
                  _selectedFriends.remove(id);
                }
              });
            },
            onDeleteSelected: _deleteSelectedFriends,
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
          ? _isEditMode
                ? null
                : FloatingActionButton(
                    onPressed: _currentIndex == 0
                        ? _createChat
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanQrScreen(),
                            ),
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
  final bool isEditMode;
  final Set<String> selectedChats;
  final VoidCallback onToggleEdit;
  final Function(String, bool) onSelectChat;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCreateChat;
  final VoidCallback onScan;

  const _ChatsTab({
    required this.chatManager,
    required this.profile,
    required this.isEditMode,
    required this.selectedChats,
    required this.onToggleEdit,
    required this.onSelectChat,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCreateChat,
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF00FF9C),
                      ),
                      onPressed: onScan,
                    ),
                    IconButton(
                      icon: Icon(
                        isEditMode ? Icons.close : Icons.edit,
                        color: const Color(0xFF00FF9C),
                      ),
                      onPressed: onToggleEdit,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isEditMode && selectedChats.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFF4444).withValues(alpha: 0.2),
              child: Row(
                children: [
                  Text(
                    '${selectedChats.length} selected',
                    style: const TextStyle(color: Color(0xFFFF4444)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDeleteSelected,
                    icon: const Icon(Icons.delete, color: Color(0xFFFF4444)),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFFF4444)),
                    ),
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
                      return _ChatTile(
                        chat: chat,
                        isEditMode: isEditMode,
                        isSelected: selectedChats.contains(chat.id),
                        onTap: () {
                          if (isEditMode) {
                            onSelectChat(
                              chat.id,
                              !selectedChats.contains(chat.id),
                            );
                          } else {
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
                          }
                        },
                        onInvite: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                InviteScreen(chat: chat, profile: profile!),
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
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  const _ChatTile({
    required this.chat,
    required this.isEditMode,
    required this.isSelected,
    required this.onTap,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF00FF9C).withValues(alpha: 0.1)
            : const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF00FF9C) : const Color(0xFF2A2A2A),
        ),
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
                if (isEditMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: const Color(0xFF00FF9C),
                  ),
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
                if (!isEditMode) ...[
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
  final bool isEditMode;
  final Set<String> selectedFriends;
  final VoidCallback onToggleEdit;
  final Function(String, bool) onSelectFriend;
  final VoidCallback onDeleteSelected;
  final Function(Map<String, dynamic>) onMessage;
  final VoidCallback onScan;

  const _FriendsTab({
    required this.chatManager,
    required this.profile,
    required this.isEditMode,
    required this.selectedFriends,
    required this.onToggleEdit,
    required this.onSelectFriend,
    required this.onDeleteSelected,
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
                  icon: Icon(
                    isEditMode ? Icons.close : Icons.person_add,
                    color: const Color(0xFF00FF9C),
                  ),
                  onPressed: isEditMode ? onToggleEdit : onScan,
                ),
              ],
            ),
          ),
          if (isEditMode && selectedFriends.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFF4444).withValues(alpha: 0.2),
              child: Row(
                children: [
                  Text(
                    '${selectedFriends.length} selected',
                    style: const TextStyle(color: Color(0xFFFF4444)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onDeleteSelected,
                    icon: const Icon(Icons.delete, color: Color(0xFFFF4444)),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: Color(0xFFFF4444)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chatManager.friends.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: chatManager.friends.length,
                    itemBuilder: (context, index) {
                      final friend = chatManager.friends[index];
                      return _FriendTile(
                        friend: friend,
                        isEditMode: isEditMode,
                        isSelected: selectedFriends.contains(friend['id']),
                        onTap: () {
                          if (isEditMode) {
                            onSelectFriend(
                              friend['id'],
                              !selectedFriends.contains(friend['id']),
                            );
                          } else {
                            onMessage(friend);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
  final bool isEditMode;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendTile({
    required this.friend,
    required this.isEditMode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF00FF9C).withValues(alpha: 0.1)
            : const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF00FF9C) : const Color(0xFF2A2A2A),
        ),
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
                if (isEditMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: const Color(0xFF00FF9C),
                  ),
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
                if (!isEditMode)
                  const Icon(Icons.chevron_right, color: Color(0xFF888888)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
