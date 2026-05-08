import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'change_password_screen.dart';

import 'emp_dashboard_screen.dart';
import 'admin_dashboard.dart';
import 'hr_dashboard_screen.dart';
import '../App Admin/app_admin_dashboard_screen.dart';
import '../services/biometric_service.dart';
import 'team_lead_dashboard.dart';
import 'manager_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;
  String? _errorMsg;
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  @override
  void initState() {
    super.initState();
    _checkBio();
  }

  Future<void> _checkBio() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isBioEnabled();
    if (mounted) {
      setState(() {
        _bioAvailable = available;
        _bioEnabled = enabled;
      });
    }
  }

  Future<void> _loginWithBio() async {
    final loginId = await BiometricService.getBioLoginId();
    if (loginId == null) return;

    final verified = await BiometricService.authenticate();
    if (!verified || !mounted) return;

    setState(() => _isLoading = true);
    try {
      // Re-validate session or navigate directly using stored loginId
      final session = await AuthService.getSession();
      if (session != null) {
        _navigateToDashboard(
          loginId: int.parse(session['loginId']!),
          empId: int.parse(session['empId']!),
          roleId: int.parse(session['role']!),
        );
      } else {
        _snackError('Session expired. Please login with password.');
        await BiometricService.disableBio();
        setState(() => _bioEnabled = false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── LOGIN ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = await AuthService.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 100));

      // ── First login → force password change, NO session saved ────────────
      if (data['firstLogin'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(
              loginId: data['loginId'] as int,
              empId: data['empId'] as int,
              roleId: data['roleId'] as int,
              username: data['username'] as String,
            ),
          ),
          (route) => false,
        );
        return;
      }

      // ── Normal login → session already saved in AuthService.login ─────────
      _navigateToDashboard(
        loginId: data['loginId'] as int,
        empId: data['empId'] as int,
        roleId: data['roleId'] as int,
      );
    } on AuthException catch (e) {
      setState(() => _errorMsg = e.message);
    } catch (_) {
      setState(() => _errorMsg = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── ROLE-BASED NAVIGATION ──────────────────────────────────────────────────
  //
  // ✅ Each case maps to a real dashboard screen.
  // Pass loginId / empId / roleId as your dashboard constructors require.
  //
  void _navigateToDashboard({
    required int loginId,
    required int empId,
    required int roleId,
  }) {
    Widget screen;

    switch (roleId) {
      case 1:
        screen = AdminDashboardScreen(
          loginId: loginId,
          employeeId: empId.toString(),
          roleId: roleId.toString(),
        );
        break;

      case 2:
        screen = HRDashboardScreen(
          loginId: loginId,
          employeeId: empId.toString(),
          roleId: roleId.toString(),
        );
        break;

      case 3:
        screen = TLDashboardScreen(
          loginId: loginId,
          employeeId: empId.toString(),
          role: roleId.toString(),
        );
        break;

      case 6:
        screen = AppAdminDashboardScreen(
          loginId: loginId,
          employeeId: empId.toString(),
          roleId: roleId.toString(),
        );
        break;

      case 8:
        screen = ManagerDashboardScreen(
          loginId: loginId,
          employeeId: empId.toString(),
          roleId: roleId.toString(),
        );
        break;

      default:
        screen = DashboardScreen(
          loginId: loginId,
          empId: empId,
          role: roleId.toString(),
        );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final hPad = isDesktop ? size.width * 0.2 : 24.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 40),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadowColor: Colors.indigo.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo / title ────────────────────────────────────
                      Icon(
                        Icons.fingerprint,
                        size: isDesktop ? 120 : 90,
                        color: Colors.indigo,
                      ),
                      SizedBox(height: isDesktop ? 24 : 16),
                      Text(
                        'Employee Management System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 36 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 16 : 8),
                      Text(
                        'Login to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 40 : 32),

                      // ── Username ────────────────────────────────────────
                      TextFormField(
                        controller: _usernameCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Username / Email',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Username or email is required';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_errorMsg != null) {
                            setState(() => _errorMsg = null);
                          }
                        },
                      ),
                      SizedBox(height: isDesktop ? 24 : 16),

                      // ── Password ────────────────────────────────────────
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_errorMsg != null) {
                            setState(() => _errorMsg = null);
                          }
                        },
                      ),

                      // ── Inline error banner ─────────────────────────────
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _errorMsg!),
                      ],

                      SizedBox(height: isDesktop ? 32 : 24),

                      // ── LOGIN button ────────────────────────────────────
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.indigo.withOpacity(
                              0.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      // ── Biometric login button ──────────────────────────
                      if (_bioAvailable && _bioEnabled) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithBio,
                          icon: const Icon(
                            Icons.fingerprint_rounded,
                            size: 22,
                            color: Colors.indigo,
                          ),
                          label: const Text(
                            'Login with Biometrics',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.indigo,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.indigo.withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline error banner
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);

  bool get _isLockout =>
      message.contains('locked') || message.contains('another device');

  @override
  Widget build(BuildContext context) {
    final color = _isLockout ? _amber : _red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _isLockout
                ? Icons.lock_clock_outlined
                : Icons.error_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
