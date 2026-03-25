import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

class CryptoService {
  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final _xchacha = Xchacha20.poly1305Aead();

  static Future<SimpleKeyPair> generateKeyPair() async {
    return _x25519.newKeyPair();
  }

  static Future<List<int>> extractPublicKey(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return pub.bytes;
  }

  static String publicKeyToBase64(List<int> pubKey) {
    return base64Encode(pubKey);
  }

  static List<int> publicKeyFromBase64(String b64) {
    return base64Decode(b64);
  }

  static String generateFingerprint(List<int> publicKey) {
    final hash = crypto.sha256.convert(publicKey);
    // Convert bytes to hex string
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String generateUserToken(List<int> publicKey) {
    return 'zentro:v1:${base64Encode(publicKey)}';
  }

  static List<int> parseUserToken(String token) {
    if (!token.startsWith('zentro:v1:')) {
      throw FormatException('Invalid token format');
    }
    return base64Decode(token.substring(10));
  }

  static Future<Uint8List> deriveSharedKey(
    SimpleKeyPair myPrivateKey,
    List<int> theirPublicKey,
  ) async {
    final theirPub = SimplePublicKey(theirPublicKey, type: KeyPairType.x25519);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myPrivateKey,
      remotePublicKey: theirPub,
    );
    final hkdfKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode('zentro-v1-kdf'),
      info: utf8.encode('chat-key-wrap'),
    );
    return Uint8List.fromList(await hkdfKey.extractBytes());
  }

  static Future<Uint8List> encryptSymmetric(
    Uint8List key,
    Uint8List plaintext,
  ) async {
    final nonce = _xchacha.newNonce();
    final secretBox = await _xchacha.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final result = Uint8List(
      nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    result.setAll(0, nonce);
    result.setAll(nonce.length, secretBox.cipherText);
    result.setAll(
      nonce.length + secretBox.cipherText.length,
      secretBox.mac.bytes,
    );
    return result;
  }

  static Future<Uint8List> decryptSymmetric(
    Uint8List key,
    Uint8List encrypted,
  ) async {
    final nonce = encrypted.sublist(0, 24);
    final macBytes = encrypted.sublist(encrypted.length - 16);
    final cipherText = encrypted.sublist(24, encrypted.length - 16);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes));
    final plain = await _xchacha.decrypt(secretBox, secretKey: SecretKey(key));
    return Uint8List.fromList(plain);
  }

  static Future<String> encryptChatKeyForUser(
    SimpleKeyPair myPrivateKey,
    List<int> theirPublicKey,
    Uint8List chatKey,
  ) async {
    final wrapKey = await deriveSharedKey(myPrivateKey, theirPublicKey);
    final encrypted = await encryptSymmetric(wrapKey, chatKey);
    return base64Encode(encrypted);
  }

  static Future<Uint8List> decryptChatKeyFromUser(
    SimpleKeyPair myPrivateKey,
    List<int> theirPublicKey,
    String encryptedKeyB64,
  ) async {
    final wrapKey = await deriveSharedKey(myPrivateKey, theirPublicKey);
    final encrypted = base64Decode(encryptedKeyB64);
    return decryptSymmetric(wrapKey, encrypted);
  }
}
