import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _kBioEnabled = 'bio_enabled';
  static const _kBioLoginId = 'bio_login_id';

  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> enableBio(int loginId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBioEnabled, true);
    await prefs.setInt(_kBioLoginId, loginId);
  }

  static Future<void> disableBio() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBioEnabled);
    await prefs.remove(_kBioLoginId);
  }

  static Future<bool> isBioEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBioEnabled) ?? false;
  }

  static Future<int?> getBioLoginId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBioLoginId);
  }
}
