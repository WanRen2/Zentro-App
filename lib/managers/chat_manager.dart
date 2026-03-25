import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';

class ChatManager {
  static const _chatsKey = 'zentro_chats';
  static const _friendsKey = 'zentro_friends';
  static const _pendingInvitesKey = 'zentro_pending_invites';
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  final List<ChatModel> _chats = [];
  final List<Map<String, dynamic>> _friends = [];
  final List<Map<String, dynamic>> _pendingInvites = [];

  List<ChatModel> get chats => List.unmodifiable(_chats);
  List<Map<String, dynamic>> get friends => List.unmodifiable(_friends);
  List<Map<String, dynamic>> get pendingInvites =>
      List.unmodifiable(_pendingInvites);

  Future<void> loadChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_chatsKey);
    if (jsonStr == null) {
      _chats.clear();
      return;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _chats.clear();
      for (final item in jsonList) {
        _chats.add(ChatModel.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      _chats.clear();
    }
  }

  Future<void> loadFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_friendsKey);
    if (jsonStr == null) {
      _friends.clear();
      return;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _friends.clear();
      for (final item in jsonList) {
        _friends.add(item as Map<String, dynamic>);
      }
    } catch (e) {
      _friends.clear();
    }
  }

  Future<void> loadPendingInvites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pendingInvitesKey);
    if (jsonStr == null) {
      _pendingInvites.clear();
      return;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _pendingInvites.clear();
      for (final item in jsonList) {
        _pendingInvites.add(item as Map<String, dynamic>);
      }
    } catch (e) {
      _pendingInvites.clear();
    }
  }

  Future<void> addPendingInvite(Map<String, dynamic> invite) async {
    final existing = _pendingInvites.any(
      (i) => i['chat_id'] == invite['chat_id'],
    );
    if (!existing) {
      _pendingInvites.insert(0, {
        ...invite,
        'received_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      await _savePendingInvites();
    }
  }

  Future<void> removePendingInvite(String chatId) async {
    _pendingInvites.removeWhere((i) => i['chat_id'] == chatId);
    await _savePendingInvites();
  }

  Future<void> _savePendingInvites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInvitesKey, jsonEncode(_pendingInvites));
  }

  Future<ChatModel> createChat(String name) async {
    final chatKey = _generateChatKey();
    final chat = ChatModel(
      id: _generateUuid(),
      name: name,
      createdAt: DateTime.now(),
      chatKey: chatKey,
    );
    _chats.insert(0, chat);
    await _saveChats();
    return chat;
  }

  Future<ChatModel> createChatWithFriend(
    String friendName,
    String friendFingerprint,
    String friendPublicKey,
  ) async {
    final chatKey = _generateChatKey();
    final chat = ChatModel(
      id: _generateUuid(),
      name: friendName,
      createdAt: DateTime.now(),
      chatKey: chatKey,
    );
    _chats.insert(0, chat);
    await _saveChats();
    return chat;
  }

  Future<ChatModel> joinChat(
    String chatId,
    String chatName,
    String senderName,
    String chatKeyBase64,
  ) async {
    final chatKey = base64Decode(chatKeyBase64);
    final chat = ChatModel(
      id: chatId,
      name: chatName,
      createdAt: DateTime.now(),
      chatKey: chatKey,
    );
    _chats.insert(0, chat);
    await _saveChats();
    return chat;
  }

  bool isChatExists(String chatId) {
    return _chats.any((c) => c.id == chatId);
  }

  Future<void> addFriend(
    String name,
    String fingerprint,
    String publicKey,
    String inviteCode,
  ) async {
    final friend = {
      'id': _generateUuid(),
      'name': name,
      'fingerprint': fingerprint,
      'public_key': publicKey,
      'invite_code': inviteCode,
      'added_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    _friends.add(friend);
    await _saveFriends();
  }

  Future<bool> isFriendExists(String fingerprint) async {
    return _friends.any((f) => f['fingerprint'] == fingerprint);
  }

  List<int> _generateChatKey() {
    final rng = Random.secure();
    return List<int>.generate(32, (_) => rng.nextInt(256));
  }

  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> _saveChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _chats.map((c) => c.toJson()).toList();
    await prefs.setString(_chatsKey, jsonEncode(jsonList));
  }

  Future<void> _saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_friendsKey, jsonEncode(_friends));
  }

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    await _saveChats();
  }

  Future<void> deleteChats(List<String> chatIds) async {
    _chats.removeWhere((c) => chatIds.contains(c.id));
    await _saveChats();
  }

  Future<void> removeFriend(String friendId) async {
    _friends.removeWhere((f) => f['id'] == friendId);
    await _saveFriends();
  }

  Future<void> removeFriends(List<String> friendIds) async {
    _friends.removeWhere((f) => friendIds.contains(f['id']));
    await _saveFriends();
  }
}
