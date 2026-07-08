import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// Optional app lock via Face ID / fingerprint / device biometrics.
/// Permission/enrollment is requested contextually — when the user flips
/// the toggle in settings, not at onboarding.
class BiometricService {
  final _auth = LocalAuthentication();

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<bool> canUse() async {
    if (!isSupported) return false;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    if (!isSupported) return true;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Gym Ledger',
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
