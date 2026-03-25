import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';

class ChatManager {
  static const _chatsKey = 'zentro_chats';
  static final ChatManager _instance = ChatManager._internal();
  factory ChatManager() => _instance;
  ChatManager._internal();

  final List<ChatModel> _chats = [];

  List<ChatModel> get chats => List.unmodifiable(_chats);

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

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    await _saveChats();
  }
}
