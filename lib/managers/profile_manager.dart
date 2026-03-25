import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import '../models/profile_model.dart';

class ProfileManager {
  static const _profileKey = 'zentro_profile';
  static final ProfileManager _instance = ProfileManager._internal();
  factory ProfileManager() => _instance;
  ProfileManager._internal();

  SimpleKeyPair? _keyPair;
  ProfileModel? _profile;

  SimpleKeyPair? get keyPair => _keyPair;
  ProfileModel? get profile => _profile;
  bool get hasProfile => _profile != null;

  Future<ProfileModel?> loadProfile() async {
    if (_profile != null) return _profile;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_profileKey);
    if (jsonStr == null) return null;

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      _profile = ProfileModel.fromJson(json);

      // Load or generate keypair
      final privKeyStr = prefs.getString('zentro_privkey');
      if (privKeyStr != null) {
        final bytes = privKeyStr.split(',').map((s) => int.parse(s)).toList();
        final pubKeyStr = prefs.getString('zentro_pubkey');
        final pubBytes = pubKeyStr
            ?.split(',')
            .map((s) => int.parse(s))
            .toList();

        _keyPair = SimpleKeyPairData(
          bytes,
          publicKey: SimplePublicKey(pubBytes ?? [], type: KeyPairType.x25519),
          type: KeyPairType.x25519,
        );
      } else {
        // Regenerate if no private key stored
        await createProfile(_profile!.name);
      }

      return _profile;
    } catch (e) {
      return null;
    }
  }

  Future<ProfileModel> createProfile(String name) async {
    final keyPair = await X25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBytes = publicKey.bytes;
    final fingerprint = ProfileModel.computeFingerprint(publicKeyBytes);
    final token = ProfileModel.computeToken(publicKeyBytes);

    final profile = ProfileModel(
      name: name,
      publicKey: publicKeyBytes,
      fingerprint: fingerprint,
      token: token,
    );

    // Store everything
    final prefs = await SharedPreferences.getInstance();
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();
    await prefs.setString('zentro_privkey', privKeyBytes.join(','));
    await prefs.setString('zentro_pubkey', publicKeyBytes.join(','));
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

    _keyPair = keyPair;
    _profile = profile;
    return profile;
  }

  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove('zentro_privkey');
    await prefs.remove('zentro_pubkey');
    _profile = null;
    _keyPair = null;
  }
}
