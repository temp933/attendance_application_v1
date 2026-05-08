// session_guard_mixin.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

mixin SessionGuardMixin<T extends StatefulWidget> on State<T> {
  Timer? _sessionTimer;

  /// Call this in initState() of any dashboard
  void startSessionGuard({Duration interval = const Duration(seconds: 30)}) {
    _sessionTimer = Timer.periodic(interval, (_) => _checkSession());
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    final valid = await AuthService.validateSession();
    if (!valid && mounted) {
      _sessionTimer?.cancel();
      // Clear local prefs silently — server already cleared session
      await AuthService.clearSession(notifyServer: false);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      // Show snack after navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Your session was ended by an administrator.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      });
    }
  }
}
