import 'dart:convert';

class ChatModel {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<int> chatKey;

  ChatModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.chatKey,
  });

  String get chatKeyBase64 => base64Encode(chatKey);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'chatKey': chatKeyBase64,
  };

  static ChatModel fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      chatKey: base64Decode(json['chatKey'] as String),
    );
  }
}
