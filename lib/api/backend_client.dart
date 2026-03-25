import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class BackendClient {
  final String baseUrl;
  final http.Client _client;

  BackendClient({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? AppConfig.backendUrl,
      _client = client ?? http.Client();

  Future<void> uploadMessage(
    String chatId,
    String messageId,
    Map payload,
  ) async {
    final url = '$baseUrl/message/upload';
    final body = {
      'chat_id': chatId,
      'message_id': messageId,
      'payload': payload,
    };
    final resp = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('uploadMessage failed: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<List<String>> listMessages(String chatId) async {
    final url = '$baseUrl/message/list?chat_id=$chatId';
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('listMessages failed: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final msgs = (data['messages'] as List).cast<Map<String, dynamic>>();
    return msgs.map((m) => m['id'] as String).toList();
  }

  Future<Map<String, dynamic>> getMessage(
    String chatId,
    String messageId,
  ) async {
    final url = '$baseUrl/message/get?chat_id=$chatId&message_id=$messageId';
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('getMessage failed: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> uploadChatKey(
    String chatId,
    String fingerprint,
    String encryptedKey,
  ) async {
    final url = '$baseUrl/chat/key/upload';
    final body = {
      'chat_id': chatId,
      'fingerprint': fingerprint,
      'encrypted_key': encryptedKey,
    };
    final resp = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('uploadChatKey failed: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<String> getChatKey(String chatId, String fingerprint) async {
    final url =
        '$baseUrl/chat/key/get?chat_id=$chatId&fingerprint=$fingerprint';
    final resp = await _client.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('getChatKey failed: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['encrypted_key'] as String;
  }
}
