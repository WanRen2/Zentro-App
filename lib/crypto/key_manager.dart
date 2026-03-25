import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'crypto_service.dart';

class KeyManager {
  static const _privKeyPref = 'zentro_privkey';
  static const _pubKeyPref = 'zentro_pubkey';
  static const _fingerprintPref = 'zentro_fingerprint';
  static const _tokenPref = 'zentro_token';

  SimpleKeyPair? _keyPair;
  List<int>? _publicKey;
  String? _fingerprint;
  String? _token;

  SimpleKeyPair get keyPair => _keyPair!;
  List<int> get publicKey => _publicKey!;
  String get fingerprint => _fingerprint!;
  String get token => _token!;

  Future<bool> hasKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_privKeyPref);
  }

  Future<void> loadOrGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    // Always generate a fresh key pair for MVP stability
    _keyPair = await CryptoService.generateKeyPair();
    _publicKey = await CryptoService.extractPublicKey(_keyPair!);
    _fingerprint = CryptoService.generateFingerprint(_publicKey!);
    _token = CryptoService.generateUserToken(_publicKey!);

    // Persist the derived public data and token for future starts
    await prefs.setString(_pubKeyPref, _publicKey!.join(','));
    await prefs.setString(_fingerprintPref, _fingerprint!);
    await prefs.setString(_tokenPref, _token!);
  }
}
