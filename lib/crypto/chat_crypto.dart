import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class ChatCrypto {
  static final _rng = Random.secure();

  static List<int> generateChatKey([int length = 32]) {
    final bytes = List<int>.generate(length, (_) => _rng.nextInt(256));
    return bytes;
  }

  static Future<Map<String, dynamic>> encryptWithChatKey(
    List<int> key,
    Uint8List plaintext,
  ) async {
    final xchacha = Xchacha20.poly1305Aead();
    final nonce = List<int>.generate(24, (_) => _rng.nextInt(256));
    final secretBox = await xchacha.encrypt(
      plaintext,
      secretKey: SecretKey(Uint8List.fromList(key)),
      nonce: nonce,
    );
    return {
      'nonce': base64Encode(Uint8List.fromList(nonce)),
      'ciphertext': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  static Future<List<int>> decryptWithChatKey(
    List<int> key,
    String nonceB64,
    String ctB64,
    String macB64,
  ) async {
    final xchacha = Xchacha20.poly1305Aead();
    final nonce = base64Decode(nonceB64);
    final ct = base64Decode(ctB64);
    final mac = Mac(base64Decode(macB64));
    final secretBox = SecretBox(ct, nonce: nonce, mac: mac);
    final plaintext = await xchacha.decrypt(
      secretBox,
      secretKey: SecretKey(Uint8List.fromList(key)),
    );
    return plaintext;
  }
}
