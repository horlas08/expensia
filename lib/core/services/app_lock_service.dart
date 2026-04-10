import 'package:local_auth/local_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_preferences_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

class AppLockService {
  static const String _isLockEnabledKey = 'is_app_lock_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferencesService.getInstance();
    return prefs.getBoolean(_isLockEnabledKey) ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.setBoolean(_isLockEnabledKey, enabled);
  }

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return true; // If device doesn't support, we can't lock it effectively

      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access Expensia',
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    return await _auth.canCheckBiometrics;
  }
}
