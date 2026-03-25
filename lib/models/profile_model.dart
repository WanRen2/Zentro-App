import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class ProfileModel {
  final String name;
  final List<int> publicKey;
  final String fingerprint;
  final String token;

  ProfileModel({
    required this.name,
    required this.publicKey,
    required this.fingerprint,
    required this.token,
  });

  String get publicKeyBase64 => base64Encode(publicKey);

  Map<String, dynamic> toJson() => {
    'name': name,
    'publicKey': base64Encode(publicKey),
    'fingerprint': fingerprint,
    'token': token,
  };

  static ProfileModel fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      name: json['name'] as String,
      publicKey: base64Decode(json['publicKey'] as String),
      fingerprint: json['fingerprint'] as String,
      token: json['token'] as String,
    );
  }

  static String computeFingerprint(List<int> publicKey) {
    final hash = crypto.sha256.convert(publicKey);
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String computeToken(List<int> publicKey) {
    return 'zentro:v1:${base64Encode(publicKey)}';
  }
}
