import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'change_password_screen.dart';
import '../App Admin/app_admin_dashboard_screen.dart';
import 'forgot_password_screen.dart';
import '../providers/api_config.dart';
import 'user_dashboard_screen.dart';
import '../services/permissions_service.dart';
import '../services/background_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TargetPlatform;

// ─── API base ────────────────────────────────────────────────────────────────
final String _baseUrl = ApiConfig.baseUrl;

// ─── Palette ─────────────────────────────────────────────────────────────────
const _primary = Color(0xFF4F46E5);
const _primaryLight = Color(0xFF818CF8);
const _surface = Color(0xFFF8F8FF);
const _textPrimary = Color(0xFF1E1B4B);
const _textSecondary = Color(0xFF6B7280);
const _errorRed = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF10B981);

// ─── App Admin username constant ─────────────────────────────────────────────
const _appAdminUsername = 'App_Admin';

// ─────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;

  bool _bioAvailable = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    _tabController.animateTo(index);
    setState(() => _activeTab = index);
  }

  void _navigateToDashboard({
    required int loginId,
    required int empId,
    required int roleId,
    required String userType,
    required String tenantId,
    List<Map<String, dynamic>>? permissions,
  }) {
    ApiConfig.tenantId = tenantId;
    Widget screen;

    // ── Strictly check userType first, fall back to roleId only as tiebreaker ──
    if (userType == 'app_admin') {
      screen = AppAdminDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
      );
    } else {
      // HR, Employee, TL, Manager → permission-filtered dashboard
      screen = UserDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
        userType: userType,
        permissions: permissions,
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final hPad = isDesktop ? size.width * 0.22 : 20.0;

    return Scaffold(
      backgroundColor: _surface,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Color(0xFFF8F8FF), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
              child: Column(
                children: [
                  _Header(isDesktop: isDesktop),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: Colors.indigo.shade50),
                    ),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: _textSecondary,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Sign In'),
                              Tab(text: 'Register Organisation'),
                            ],
                          ),
                        ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _activeTab == 0
                              ? KeyedSubtree(
                                  key: const ValueKey('signin'),
                                  child: _SignInTab(
                                    isDesktop: isDesktop,
                                    bioAvailable: _bioAvailable,
                                    bioEnabled: _bioEnabled,
                                    onBioDisabled: () =>
                                        setState(() => _bioEnabled = false),
                                    onNavigate: _navigateToDashboard,
                                  ),
                                )
                              : KeyedSubtree(
                                  key: const ValueKey('signup'),
                                  child: _SignUpTab(
                                    isDesktop: isDesktop,
                                    onSuccess: (_) => _switchTab(0),
                                  ),
                                ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _activeTab == 0
                              ? _TabLink(
                                  prefix: "Don't have an account? ",
                                  label: 'Register Organisation',
                                  onTap: () => _switchTab(1),
                                )
                              : _TabLink(
                                  prefix: 'Already registered? ',
                                  label: 'Sign In',
                                  onTap: () => _switchTab(0),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN TAB
// ─────────────────────────────────────────────────────────────────────────────
class _SignInTab extends StatefulWidget {
  final bool isDesktop, bioAvailable, bioEnabled;
  final VoidCallback onBioDisabled;
  final void Function({
    required int loginId,
    required int empId,
    required int roleId,
    required String userType,
    required String tenantId,
    List<Map<String, dynamic>>? permissions,
  })
  onNavigate;

  const _SignInTab({
    required this.isDesktop,
    required this.bioAvailable,
    required this.bioEnabled,
    required this.onBioDisabled,
    required this.onNavigate,
  });
  @override
  State<_SignInTab> createState() => _SignInTabState();
}

class _SignInTabState extends State<_SignInTab> {
  int _loginMode = 0; // 0 = Password, 1 = OTP

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _hidePass = true;
  bool _loading = false;
  bool _otpSent = false;
  int _resendCd = 0;
  String? _error;

  // ── App Admin OTP flow state ──────────────────────────────────────────────
  bool _isAppAdminFlow = false;
  String _appAdminSessionId = '';
  String _appAdminEmailHint = '';
  final _appAdminOtpCtrl = TextEditingController();

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _appAdminOtpCtrl.dispose();
    super.dispose();
  }

  // ── Detect App Admin username ─────────────────────────────────────────────
  bool get _isAppAdminUsername =>
      _usernameCtrl.text.trim() == _appAdminUsername;

  // ── Regular password login ────────────────────────────────────────────────
  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    // Intercept App Admin
    if (_isAppAdminUsername) {
      await _initiateAppAdminLogin();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _handleLoginResponse(data);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── App Admin: Step 1 — validate credentials & request OTP ───────────────
  Future<void> _initiateAppAdminLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/app-admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _isAppAdminFlow = true;
          _appAdminSessionId = body['session_id'] as String;
          _appAdminEmailHint = body['email_hint'] as String? ?? '***';
        });
        debugPrint('🔑 sessionId stored: $_appAdminSessionId');
        _startResendCd();
      } else {
        setState(
          () => _error =
              body['message'] as String? ??
              'Invalid credentials. Please try again.',
        );
      }
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── App Admin: Step 2 — verify OTP ───────────────────────────────────────
  Future<void> _verifyAppAdminOtp() async {
    final otp = _appAdminOtpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/app-admin/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _appAdminSessionId, 'otp': otp}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        if (!mounted) return;
        FocusScope.of(context).unfocus();

        final appAdminToken = body['token'] as String? ?? '';

        // ✅ Set token in ApiConfig memory BEFORE navigating
        ApiConfig.setToken(appAdminToken);

        debugPrint(
          '🔐 ApiConfig token set: ${appAdminToken.isEmpty ? "❌ EMPTY" : appAdminToken.substring(0, 20)}...',
        );

        await AuthService.saveSession(
          loginId: (body['adminId'] as num?)?.toInt().toString() ?? '0',
          empId: '0',
          role: '6',
          userType: body['userType'] as String? ?? 'app_admin',
          username: body['username'] as String? ?? 'App_Admin',
          sessionToken: appAdminToken,
          tenantId: 'global',
        );

        widget.onNavigate(
          loginId:
              (body['adminId'] as num?)?.toInt() ??
              0, // ← 'adminId' not 'loginId'
          empId: 0,
          roleId: 6,
          userType: body['userType'] as String? ?? 'app_admin',
          tenantId: 'global',
        );
      } else {
        setState(
          () =>
              _error = body['message'] as String? ?? 'OTP verification failed.',
        );
      }
    } catch (_) {
      setState(() => _error = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── App Admin: Resend OTP ─────────────────────────────────────────────────
  Future<void> _resendAppAdminOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/app-admin/resend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'session_id': _appAdminSessionId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        setState(() {
          _appAdminSessionId = body['session_id'] as String;
          _appAdminEmailHint =
              body['email_hint'] as String? ?? _appAdminEmailHint;
        });
        _appAdminOtpCtrl.clear();
        _startResendCd();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New OTP sent.'),
              backgroundColor: _green,
            ),
          );
        }
      } else {
        setState(() => _error = body['message'] as String? ?? 'Resend failed.');
      }
    } catch (_) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Cancel App Admin flow ─────────────────────────────────────────────────
  void _cancelAppAdminFlow() {
    setState(() {
      _isAppAdminFlow = false;
      _appAdminSessionId = '';
      _appAdminEmailHint = '';
      _appAdminOtpCtrl.clear();
      _error = null;
    });
  }

  // ── Regular OTP login ─────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter your username first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.sendLoginOtp(username: username);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendCd();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to send OTP. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthService.verifyLoginOtp(
        username: _usernameCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _handleLoginResponse(data);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLoginResponse(Map<String, dynamic> data) async {
    final int loginId = int.parse(data['loginId'].toString());
    final int empId = int.parse((data['empId'] ?? 0).toString());
    final int roleId = int.parse(data['roleId'].toString());
    final String tenantId =
        (data['tenantId'] ?? data['tenant_id'])?.toString() ?? '';
    final String token = data['sessionToken']?.toString() ?? '';
    final String userType = data['userType']?.toString() ?? 'employee';
    final String username = data['username']?.toString() ?? '';

    ApiConfig.setToken(token);
    ApiConfig.tenantId = tenantId;
    ApiConfig.employeeId = empId.toString();

    await ApiConfig.saveSession(
      loginId: loginId.toString(),
      empId: empId.toString(),
      role: roleId.toString(),
      userType: userType,
      username: username,
      sessionToken: token,
      tenantId: tenantId,
    );

    // ── Start background tracking — mobile only, non-app_admin ───────────
    if (!kIsWeb &&
        userType != 'app_admin' &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final int? sessionId =
          int.tryParse(data['sessionId']?.toString() ?? '') ??
          int.tryParse(data['session_id']?.toString() ?? '');
      await initBackgroundService();
      await startBackgroundTracking(empId, sessionId: sessionId);
      debugPrint(
        '[Login] Background tracking started emp=$empId session=$sessionId',
      );
    }

    if (data['firstLogin'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChangePasswordScreen(
            loginId: loginId,
            empId: empId,
            roleId: roleId,
            username: username,
            tenantId: tenantId,
          ),
        ),
        (r) => false,
      );
      return;
    }

    // ── Fetch permissions for non-admin roles ──────────────────────────
    List<Map<String, dynamic>>? permissions;
    if (userType != 'org_admin') {
      permissions = await PermissionsService.getMyPermissions();
    }

    widget.onNavigate(
      loginId: loginId,
      empId: empId,
      roleId: roleId,
      userType: userType,
      tenantId: tenantId,
      permissions: permissions, // ← ADD this parameter
    );
  }

  void _startResendCd() {
    _resendCd = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCd--);
      return _resendCd > 0;
    });
  }

  void _switchMode(int mode) {
    setState(() {
      _loginMode = mode;
      _error = null;
      _otpSent = false;
      _otpCtrl.clear();
      _isAppAdminFlow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── App Admin OTP verification screen ─────────────────────────────────
    if (_isAppAdminFlow) {
      return _buildAppAdminOtpScreen();
    }

    // ── Normal sign-in screen ─────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _ModeBtn(
                    label: 'Password',
                    active: _loginMode == 0,
                    onTap: () => _switchMode(0),
                  ),
                  _ModeBtn(
                    label: 'OTP',
                    active: _loginMode == 1,
                    onTap: () => _switchMode(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _AppField(
              ctrl: _usernameCtrl,
              label: 'Username / Email / Employee ID',
              icon: Icons.person_outline_rounded,
              onChanged: (_) => setState(() => _error = null),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            if (_loginMode == 0) ...[
              _AppPasswordField(
                ctrl: _passwordCtrl,
                label: 'Password',
                hide: _hidePass,
                onToggle: () => setState(() => _hidePass = !_hidePass),
                onSubmit: _loginWithPassword,
                onChanged: (_) => setState(() => _error = null),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _primary,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],

            if (_loginMode == 1) ...[
              if (!_otpSent) ...[
                _AppPrimaryBtn(
                  label: 'Send OTP to Email',
                  loading: _loading,
                  onTap: _sendOtp,
                  icon: Icons.send_rounded,
                  outlined: true,
                ),
              ] else ...[
                _OtpCard(
                  label: 'Login OTP',
                  email: '(check your registered email)',
                  ctrl: _otpCtrl,
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _resendCd > 0
                          ? 'Resend in ${_resendCd}s'
                          : "Didn't receive? ",
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (_resendCd == 0)
                      GestureDetector(
                        onTap: _loading ? null : _sendOtp,
                        child: const Text(
                          'Resend',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              _AppErrorBanner(message: _error!),
            ],
            const SizedBox(height: 14),

            if (_loginMode == 0)
              _AppPrimaryBtn(
                label: 'Sign In',
                loading: _loading,
                onTap: _loginWithPassword,
              ),
            if (_loginMode == 1 && _otpSent)
              _AppPrimaryBtn(
                label: 'Verify & Sign In',
                loading: _loading,
                onTap: _verifyOtp,
                icon: Icons.verified_rounded,
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── App Admin OTP verification panel ─────────────────────────────────────
  Widget _buildAppAdminOtpScreen() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E7FF)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primary, _primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Admin Verification',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'OTP sent to $_appAdminEmailHint',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Enter the 6-digit OTP sent to your\nregistered email address.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),

          _OtpCard(
            label: 'App Admin OTP',
            email: _appAdminEmailHint,
            ctrl: _appAdminOtpCtrl,
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 12),

          // Resend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _resendCd > 0 ? 'Resend in ${_resendCd}s' : "Didn't receive? ",
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
              if (_resendCd == 0)
                GestureDetector(
                  onTap: _loading ? null : _resendAppAdminOtp,
                  child: const Text(
                    'Resend',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            _AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),

          _AppPrimaryBtn(
            label: 'Verify & Sign In',
            loading: _loading,
            onTap: _verifyAppAdminOtp,
            icon: Icons.verified_rounded,
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: _loading ? null : _cancelAppAdminFlow,
            child: const Text(
              '← Back to Sign In',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _textSecondary,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP TAB  (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────
class _SignUpTab extends StatefulWidget {
  final bool isDesktop;
  final void Function(String username) onSuccess;
  const _SignUpTab({required this.isDesktop, required this.onSuccess});
  @override
  State<_SignUpTab> createState() => _SignUpTabState();
}

class _SignUpTabState extends State<_SignUpTab> {
  int _step = 0;

  final _orgFormKey = GlobalKey<FormState>();
  final _orgNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactNumCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _hrEmailCtrl = TextEditingController();
  final _expectedEmpCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  final _adminOtpCtrl = TextEditingController();
  final _hrOtpCtrl = TextEditingController();
  String _sessionId = '';
  int _resendCd = 0;

  final _adminCredFormKey = GlobalKey<FormState>();
  final _adminUsernameCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();
  final _adminConfirmCtrl = TextEditingController();
  bool _adminHidePass = true;
  bool _adminHideConfirm = true;

  final _hrCredFormKey = GlobalKey<FormState>();
  final _hrUsernameCtrl = TextEditingController();
  final _hrPassCtrl = TextEditingController();
  final _hrConfirmCtrl = TextEditingController();
  bool _hrHidePass = true;
  bool _hrHideConfirm = true;

  final _adminProfileFormKey = GlobalKey<FormState>();
  final _hrProfileFormKey = GlobalKey<FormState>();

  final _adminFirstCtrl = TextEditingController();
  final _adminMidCtrl = TextEditingController();
  final _adminLastCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _adminDobCtrl = TextEditingController();
  String? _adminGender;
  final _adminDojCtrl = TextEditingController();
  String _adminEmpType = 'Permanent';
  String _adminWorkType = 'Full Time';
  String _hrWorkType = 'Full Time';
  final _adminAddressCtrl = TextEditingController();
  final _adminCommAddressCtrl = TextEditingController();
  final _adminFatherCtrl = TextEditingController();
  final _adminEmergencyContactCtrl = TextEditingController();
  final _adminEmergencyRelCtrl = TextEditingController();
  final _adminAadharCtrl = TextEditingController();
  final _adminPanCtrl = TextEditingController();
  final _adminPfCtrl = TextEditingController();
  final _adminEsicCtrl = TextEditingController();
  final _adminYearsExpCtrl = TextEditingController();

  final _hrFirstCtrl = TextEditingController();
  final _hrMidCtrl = TextEditingController();
  final _hrLastCtrl = TextEditingController();
  final _hrPhoneCtrl = TextEditingController();
  final _hrDobCtrl = TextEditingController();
  String? _hrGender;
  final _hrDojCtrl = TextEditingController();
  String _hrEmpType = 'Permanent';
  final _hrAddressCtrl = TextEditingController();
  final _hrCommAddressCtrl = TextEditingController();
  final _hrFatherCtrl = TextEditingController();
  final _hrEmergencyContactCtrl = TextEditingController();
  final _hrEmergencyRelCtrl = TextEditingController();
  final _hrAadharCtrl = TextEditingController();
  final _hrPanCtrl = TextEditingController();
  final _hrPfCtrl = TextEditingController();
  final _hrEsicCtrl = TextEditingController();
  final _hrYearsExpCtrl = TextEditingController();
  Map<String, dynamic>? _selectedPlan;
  List<Map<String, dynamic>> _plans = [];
  bool _plansLoading = false;
  int _profileSection = 0;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _orgNameCtrl,
      _contactPersonCtrl,
      _contactNumCtrl,
      _adminEmailCtrl,
      _hrEmailCtrl,
      _expectedEmpCtrl,
      _addressCtrl,
      _domainCtrl,
      _gstCtrl,
      _adminOtpCtrl,
      _hrOtpCtrl,
      _adminUsernameCtrl,
      _adminPassCtrl,
      _adminConfirmCtrl,
      _hrUsernameCtrl,
      _hrPassCtrl,
      _hrConfirmCtrl,
      _adminFirstCtrl,
      _adminMidCtrl,
      _adminLastCtrl,
      _adminPhoneCtrl,
      _adminDobCtrl,
      _adminDojCtrl,
      _adminAddressCtrl,
      _adminCommAddressCtrl,
      _adminFatherCtrl,
      _adminEmergencyContactCtrl,
      _adminEmergencyRelCtrl,
      _adminAadharCtrl,
      _adminPanCtrl,
      _adminPfCtrl,
      _adminEsicCtrl,
      _adminYearsExpCtrl,
      _hrFirstCtrl,
      _hrMidCtrl,
      _hrLastCtrl,
      _hrPhoneCtrl,
      _hrDobCtrl,
      _hrDojCtrl,
      _hrAddressCtrl,
      _hrCommAddressCtrl,
      _hrFatherCtrl,
      _hrEmergencyContactCtrl,
      _hrEmergencyRelCtrl,
      _hrAadharCtrl,
      _hrPanCtrl,
      _hrPfCtrl,
      _hrEsicCtrl,
      _hrYearsExpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())
        ? null
        : 'Invalid email';
  }

  String? _phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())
        ? null
        : 'Enter a valid 10-digit mobile number';
  }

  String? _gst(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(
          r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
        ).hasMatch(v.trim())
        ? null
        : 'Invalid GST (e.g. 29ABCDE1234F1Z5)';
  }

  String? _domain(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return RegExp(
          r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}$',
        ).hasMatch(v.trim())
        ? null
        : 'Enter a valid domain (e.g. company.com)';
  }

  String? _optPhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())
        ? null
        : 'Enter a valid 10-digit mobile number';
  }

  String? _aadhar(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^\d{12}$').hasMatch(v.trim())
        ? null
        : 'Aadhar must be 12 digits';
  }

  String? _pan(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(v.trim())
        ? null
        : 'Invalid PAN (e.g. ABCDE1234F)';
  }

  String? _username(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (v.trim().length < 4) return 'Minimum 4 characters';
    if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(v.trim()))
      return 'Only letters, numbers, _ and . allowed';
    return null;
  }

  String? _password(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v))
      return 'Must include an uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must include a number';
    return null;
  }

  Future<void> _fetchPlans() async {
    if (_plans.isNotEmpty) return; // already loaded
    setState(() => _plansLoading = true);
    try {
      final res = await http.get(Uri.parse('$_baseUrl/plans/list'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          setState(() {
            _plans = List<Map<String, dynamic>>.from(body['plans'] as List);
          });
        }
      }
    } catch (_) {
      // silently fail — user can retry by tapping again
    } finally {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    TextEditingController ctrl, {
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final initial = DateTime.tryParse(ctrl.text) ?? DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _sendOtp() async {
    if (!_orgFormKey.currentState!.validate()) return;

    // Validate plan selection
    if (_selectedPlan == null) {
      setState(() => _error = 'Please select a plan before continuing.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'org_name': _orgNameCtrl.text.trim(),
          'admin_email': _adminEmailCtrl.text.trim(),
          'hr_email': _hrEmailCtrl.text.trim(),
          'plan_id': _selectedPlan!['plan_id'], // ← ADD
          'plan_code': _selectedPlan!['plan_code'], // ← ADD
        }),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _sessionId = body['session_id'];
        setState(() {
          _step = 1;
          _startResendCd();
        });
      } else {
        setState(() => _error = body['message'] ?? 'Failed to send OTP.');
      }
    } catch (_) {
      setState(() => _error = 'Network error. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final a = _adminOtpCtrl.text.trim(), h = _hrOtpCtrl.text.trim();
    if (a.length != 6 || h.length != 6) {
      setState(() => _error = 'Enter valid 6-digit OTPs for both emails.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'admin_otp': a,
          'hr_otp': h,
        }),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (_adminFirstCtrl.text.isEmpty) {
          final parts = _contactPersonCtrl.text.trim().split(' ');
          if (parts.isNotEmpty) _adminFirstCtrl.text = parts.first;
          if (parts.length > 1)
            _adminLastCtrl.text = parts.sublist(1).join(' ');
        }
        if (_adminPhoneCtrl.text.isEmpty) {
          _adminPhoneCtrl.text = _contactNumCtrl.text.trim();
        }
        setState(() => _step = 2);
      } else {
        setState(() => _error = body['message'] ?? 'OTP verification failed.');
      }
    } catch (_) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _complete() async {
    final adminCredValid = _adminCredFormKey.currentState?.validate() ?? false;
    final hrCredValid = _hrCredFormKey.currentState?.validate() ?? false;
    final adminProfileValid =
        _adminProfileFormKey.currentState?.validate() ?? false;
    final hrProfileValid = _hrProfileFormKey.currentState?.validate() ?? false;

    if (!adminCredValid ||
        !hrCredValid ||
        !adminProfileValid ||
        !hrProfileValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fix all validation errors in both Admin and HR sections.',
          ),
          backgroundColor: _errorRed,
        ),
      );
      return;
    }

    if (_adminGender == null) {
      setState(() => _error = 'Please select Admin gender.');
      return;
    }
    if (_hrGender == null) {
      setState(() => _error = 'Please select HR gender.');
      return;
    }
    if (_adminPassCtrl.text != _adminConfirmCtrl.text) {
      setState(() => _error = 'Admin passwords do not match.');
      return;
    }
    if (_hrPassCtrl.text != _hrConfirmCtrl.text) {
      setState(() => _error = 'HR passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'org_name': _orgNameCtrl.text.trim(),
          'contact_person': _contactPersonCtrl.text.trim(),
          'contact_number': _contactNumCtrl.text.trim(),
          'admin_email': _adminEmailCtrl.text.trim(),
          'hr_email': _hrEmailCtrl.text.trim(),
          'expected_employees': int.tryParse(_expectedEmpCtrl.text.trim()) ?? 0,
          'company_address': _addressCtrl.text.trim(),
          'domain_name': _domainCtrl.text.trim(),
          'gst_number': _gstCtrl.text.trim(),
          'plan_id': _selectedPlan?['plan_id'] ?? 'plan-free-trial',
          'admin_login': {
            'username': _adminUsernameCtrl.text.trim(),
            'password': _adminPassCtrl.text,
          },
          'hr_login': {
            'username': _hrUsernameCtrl.text.trim(),
            'password': _hrPassCtrl.text,
          },
          'admin_profile': {
            'first_name': _adminFirstCtrl.text.trim(),
            'mid_name': _adminMidCtrl.text.trim(),
            'last_name': _adminLastCtrl.text.trim(),
            'phone_number': _adminPhoneCtrl.text.trim(),
            'date_of_birth': _adminDobCtrl.text.trim(),
            'gender': _adminGender,
            'date_of_joining': _adminDojCtrl.text.trim(),
            'employment_type': _adminEmpType,
            'work_type': _adminWorkType,
            'permanent_address': _adminAddressCtrl.text.trim(),
            'communication_address': _adminCommAddressCtrl.text.trim(),
            'father_name': _adminFatherCtrl.text.trim(),
            'emergency_contact': _adminEmergencyContactCtrl.text.trim(),
            'emergency_contact_relation': _adminEmergencyRelCtrl.text.trim(),
            'aadhar_number': _adminAadharCtrl.text.trim(),
            'pan_number': _adminPanCtrl.text.trim().toUpperCase(),
            'pf_number': _adminPfCtrl.text.trim(),
            'esic_number': _adminEsicCtrl.text.trim(),
            'years_experience':
                int.tryParse(_adminYearsExpCtrl.text.trim()) ?? 0,
          },
          'hr_profile': {
            'first_name': _hrFirstCtrl.text.trim(),
            'mid_name': _hrMidCtrl.text.trim(),
            'last_name': _hrLastCtrl.text.trim(),
            'phone_number': _hrPhoneCtrl.text.trim(),
            'date_of_birth': _hrDobCtrl.text.trim(),
            'gender': _hrGender,
            'date_of_joining': _hrDojCtrl.text.trim(),
            'employment_type': _hrEmpType,
            'work_type': _hrWorkType,
            'permanent_address': _hrAddressCtrl.text.trim(),
            'communication_address': _hrCommAddressCtrl.text.trim(),
            'father_name': _hrFatherCtrl.text.trim(),
            'emergency_contact': _hrEmergencyContactCtrl.text.trim(),
            'emergency_contact_relation': _hrEmergencyRelCtrl.text.trim(),
            'aadhar_number': _hrAadharCtrl.text.trim(),
            'pan_number': _hrPanCtrl.text.trim().toUpperCase(),
            'pf_number': _hrPfCtrl.text.trim(),
            'esic_number': _hrEsicCtrl.text.trim(),
            'years_experience': int.tryParse(_hrYearsExpCtrl.text.trim()) ?? 0,
          },
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Organisation registered! Please sign in.'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onSuccess(
          body['admin_username'] ?? _adminUsernameCtrl.text.trim(),
        );
      } else {
        setState(() => _error = body['message'] ?? 'Registration failed.');
      }
    } catch (_) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendCd() {
    _resendCd = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCd--);
      return _resendCd > 0;
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': _sessionId,
          'org_name': _orgNameCtrl.text.trim(),
          'admin_email': _adminEmailCtrl.text.trim(),
          'hr_email': _hrEmailCtrl.text.trim(),
        }),
      );
      if (res.statusCode == 200) {
        _adminOtpCtrl.clear();
        _hrOtpCtrl.clear();
        _startResendCd();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New OTPs sent.'),
              backgroundColor: _green,
            ),
          );
      } else {
        final body = jsonDecode(res.body);
        setState(() => _error = body['message'] ?? 'Resend failed.');
      }
    } catch (_) {
      setState(() => _error = 'Network error.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: _step == 0
        ? _buildOrgForm()
        : _step == 1
        ? _buildOtpStep()
        : _buildProfileStep(),
  );

  Widget _buildOrgForm() => Padding(
    key: const ValueKey('s0'),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Form(
      key: _orgFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(
            step: '1 of 3',
            title: 'Organisation Details',
            subtitle: 'Fill in your company information',
          ),
          const SizedBox(height: 16),
          _AppField(
            ctrl: _orgNameCtrl,
            label: 'Organisation Name *',
            icon: Icons.business_rounded,
            validator: _req,
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _contactPersonCtrl,
            label: 'Contact Person Name *',
            icon: Icons.person_outline_rounded,
            validator: _req,
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _contactNumCtrl,
            label: 'Contact Number *',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: _phone,
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _adminEmailCtrl,
            label: 'Admin Email ID *',
            icon: Icons.admin_panel_settings_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
                return 'Invalid email';
              if (v.trim().toLowerCase() ==
                  _hrEmailCtrl.text.trim().toLowerCase())
                return 'Must be different from HR email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _hrEmailCtrl,
            label: 'HR Email ID *',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
                return 'Invalid email';
              if (v.trim().toLowerCase() ==
                  _adminEmailCtrl.text.trim().toLowerCase())
                return 'Must be different from Admin email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _expectedEmpCtrl,
            label: 'Expected Employee Count *',
            icon: Icons.groups_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return (int.tryParse(v.trim()) ?? 0) >= 1
                  ? null
                  : 'Enter a valid number';
            },
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _addressCtrl,
            label: 'Company Address *',
            icon: Icons.location_on_outlined,
            maxLines: 2,
            validator: _req,
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _domainCtrl,
            label: 'Domain Name *',
            icon: Icons.language_rounded,
            hint: 'yourcompany.com',
            validator: _domain,
          ),
          const SizedBox(height: 12),
          _AppField(
            ctrl: _gstCtrl,
            label: 'GST Number (optional)',
            icon: Icons.receipt_long_outlined,
            hint: '29ABCDE1234F1Z5',
            inputFormatters: [
              _UpperCase(),
              LengthLimitingTextInputFormatter(15),
            ],
            validator: _gst,
          ),

          const SizedBox(height: 12),
          FormField<String>(
            validator: (_) => _selectedPlan == null
                ? 'Please select a plan to continue'
                : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanPickerField(
                  selectedPlan: _selectedPlan,
                  loading: _plansLoading,
                  hasError: field.hasError,
                  onTap: () async {
                    await _fetchPlans();
                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _PlanBottomSheet(
                        plans: _plans,
                        loading: _plansLoading,
                        selectedPlanId: _selectedPlan?['plan_id'] as String?,
                        onSelect: (plan) {
                          setState(() => _selectedPlan = plan);
                          field.didChange(plan['plan_id'] as String);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 13,
                          color: _errorRed,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          field.errorText!,
                          style: const TextStyle(
                            color: _errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AppErrorBanner(message: _error!),
          ],
          const SizedBox(height: 20),
          _AppPrimaryBtn(
            label: 'Send OTP to Emails',
            loading: _loading,
            onTap: _sendOtp,
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Widget _buildOtpStep() => Padding(
    key: const ValueKey('s1'),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          step: '2 of 3',
          title: 'Verify Email IDs',
          subtitle: 'Enter OTPs sent to your admin and HR emails',
        ),
        const SizedBox(height: 16),
        _OtpCard(
          label: 'Admin OTP',
          email: _adminEmailCtrl.text.trim(),
          ctrl: _adminOtpCtrl,
          icon: Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: 12),
        _OtpCard(
          label: 'HR OTP',
          email: _hrEmailCtrl.text.trim(),
          ctrl: _hrOtpCtrl,
          icon: Icons.email_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _resendCd > 0 ? 'Resend in ${_resendCd}s' : "Didn't receive?",
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            if (_resendCd == 0) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _loading ? null : _resendOtp,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _AppErrorBanner(message: _error!),
        ],
        const SizedBox(height: 16),
        _AppPrimaryBtn(
          label: 'Verify & Continue',
          loading: _loading,
          onTap: _verifyOtp,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() {
            _step = 0;
            _error = null;
          }),
          child: const Text(
            '← Back',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _buildProfileStep() => Padding(
    key: const ValueKey('s2'),
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          step: '3 of 3',
          title: 'Admin & HR Setup',
          subtitle: 'Set profiles and login credentials for Admin and HR',
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _ProfileSectionBtn(
                label: '👤 Admin',
                active: _profileSection == 0,
                onTap: () => setState(() => _profileSection = 0),
              ),
              _ProfileSectionBtn(
                label: '👤 HR',
                active: _profileSection == 1,
                onTap: () => setState(() => _profileSection = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IndexedStack(
          index: _profileSection,
          children: [
            _buildPersonSection(
              key: const ValueKey('admin'),
              role: 'Admin',
              roleColor: const Color(0xFF4F46E5),
              roleIcon: Icons.admin_panel_settings_rounded,
              prefillEmail: _adminEmailCtrl.text,
              credFormKey: _adminCredFormKey,
              usernameCtrl: _adminUsernameCtrl,
              passCtrl: _adminPassCtrl,
              confirmCtrl: _adminConfirmCtrl,
              hidePass: _adminHidePass,
              hideConfirm: _adminHideConfirm,
              onTogglePass: () =>
                  setState(() => _adminHidePass = !_adminHidePass),
              onToggleConfirm: () =>
                  setState(() => _adminHideConfirm = !_adminHideConfirm),
              profileFormKey: _adminProfileFormKey,
              firstCtrl: _adminFirstCtrl,
              midCtrl: _adminMidCtrl,
              lastCtrl: _adminLastCtrl,
              phoneCtrl: _adminPhoneCtrl,
              dobCtrl: _adminDobCtrl,
              gender: _adminGender,
              onGenderChanged: (v) => setState(() => _adminGender = v),
              dojCtrl: _adminDojCtrl,
              empType: _adminEmpType,
              onEmpTypeChanged: (v) => setState(() => _adminEmpType = v!),
              workType: _adminWorkType,
              onWorkTypeChanged: (v) => setState(() => _adminWorkType = v!),
              addressCtrl: _adminAddressCtrl,
              commAddressCtrl: _adminCommAddressCtrl,
              fatherCtrl: _adminFatherCtrl,
              emergencyContactCtrl: _adminEmergencyContactCtrl,
              emergencyRelCtrl: _adminEmergencyRelCtrl,
              aadharCtrl: _adminAadharCtrl,
              panCtrl: _adminPanCtrl,
              pfCtrl: _adminPfCtrl,
              esicCtrl: _adminEsicCtrl,
              yearsExpCtrl: _adminYearsExpCtrl,
            ),
            _buildPersonSection(
              key: const ValueKey('hr'),
              role: 'HR',
              roleColor: const Color(0xFF059669),
              roleIcon: Icons.people_alt_rounded,
              prefillEmail: _hrEmailCtrl.text,
              credFormKey: _hrCredFormKey,
              usernameCtrl: _hrUsernameCtrl,
              passCtrl: _hrPassCtrl,
              confirmCtrl: _hrConfirmCtrl,
              hidePass: _hrHidePass,
              hideConfirm: _hrHideConfirm,
              onTogglePass: () => setState(() => _hrHidePass = !_hrHidePass),
              onToggleConfirm: () =>
                  setState(() => _hrHideConfirm = !_hrHideConfirm),
              profileFormKey: _hrProfileFormKey,
              firstCtrl: _hrFirstCtrl,
              midCtrl: _hrMidCtrl,
              lastCtrl: _hrLastCtrl,
              phoneCtrl: _hrPhoneCtrl,
              dobCtrl: _hrDobCtrl,
              gender: _hrGender,
              onGenderChanged: (v) => setState(() => _hrGender = v),
              dojCtrl: _hrDojCtrl,
              empType: _hrEmpType,
              onEmpTypeChanged: (v) => setState(() => _hrEmpType = v!),
              workType: _hrWorkType,
              onWorkTypeChanged: (v) => setState(() => _hrWorkType = v!),
              addressCtrl: _hrAddressCtrl,
              commAddressCtrl: _hrCommAddressCtrl,
              fatherCtrl: _hrFatherCtrl,
              emergencyContactCtrl: _hrEmergencyContactCtrl,
              emergencyRelCtrl: _hrEmergencyRelCtrl,
              aadharCtrl: _hrAadharCtrl,
              panCtrl: _hrPanCtrl,
              pfCtrl: _hrPfCtrl,
              esicCtrl: _hrEsicCtrl,
              yearsExpCtrl: _hrYearsExpCtrl,
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _AppErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        if (_profileSection == 0)
          _AppPrimaryBtn(
            label: 'Next: HR Setup →',
            loading: false,
            onTap: () => setState(() => _profileSection = 1),
            outlined: true,
            icon: Icons.arrow_forward_rounded,
          )
        else
          _AppPrimaryBtn(
            label: 'Complete Registration',
            loading: _loading,
            onTap: _complete,
            icon: Icons.check_circle_outline_rounded,
          ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                  if (_profileSection == 1) {
                    _profileSection = 0;
                  } else {
                    _step = 1;
                    _error = null;
                  }
                }),
          child: Text(
            _profileSection == 1 ? '← Admin Setup' : '← Back',
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _buildPersonSection({
    required Key key,
    required String role,
    required Color roleColor,
    required IconData roleIcon,
    required String prefillEmail,
    required GlobalKey<FormState> credFormKey,
    required TextEditingController usernameCtrl,
    required TextEditingController passCtrl,
    required TextEditingController confirmCtrl,
    required bool hidePass,
    required bool hideConfirm,
    required VoidCallback onTogglePass,
    required VoidCallback onToggleConfirm,
    required GlobalKey<FormState> profileFormKey,
    required TextEditingController firstCtrl,
    required TextEditingController midCtrl,
    required TextEditingController lastCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController dobCtrl,
    required String? gender,
    required ValueChanged<String?> onGenderChanged,
    required TextEditingController dojCtrl,
    required String empType,
    required ValueChanged<String?> onEmpTypeChanged,
    required String workType,
    required ValueChanged<String?> onWorkTypeChanged,
    required TextEditingController addressCtrl,
    required TextEditingController commAddressCtrl,
    required TextEditingController fatherCtrl,
    required TextEditingController emergencyContactCtrl,
    required TextEditingController emergencyRelCtrl,
    required TextEditingController aadharCtrl,
    required TextEditingController panCtrl,
    required TextEditingController pfCtrl,
    required TextEditingController esicCtrl,
    required TextEditingController yearsExpCtrl,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: roleColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(roleIcon, color: roleColor, size: 20),
              const SizedBox(width: 10),
              Text(
                '$role Setup',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: roleColor,
                ),
              ),
              const Spacer(),
              Text(
                prefillEmail,
                style: TextStyle(
                  fontSize: 11,
                  color: roleColor.withOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionDivider(label: '$role Login Credentials'),
        const SizedBox(height: 12),
        Form(
          key: credFormKey,
          child: Column(
            children: [
              _AppField(
                ctrl: usernameCtrl,
                label: '$role Username *',
                icon: Icons.badge_outlined,
                validator: _username,
              ),
              const SizedBox(height: 12),
              _AppPasswordField(
                ctrl: passCtrl,
                label: '$role Password *',
                hide: hidePass,
                onToggle: onTogglePass,
                validator: _password,
              ),
              const SizedBox(height: 12),
              _AppPasswordField(
                ctrl: confirmCtrl,
                label: 'Confirm $role Password *',
                hide: hideConfirm,
                onToggle: onToggleConfirm,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != passCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '• Min 8 characters  • 1 uppercase  • 1 number',
                  style: TextStyle(fontSize: 11, color: _textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionDivider(label: 'Personal Information'),
        const SizedBox(height: 12),
        Form(
          key: profileFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AppField(
                      ctrl: firstCtrl,
                      label: 'First Name *',
                      icon: Icons.person_outline_rounded,
                      validator: _req,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AppField(
                      ctrl: midCtrl,
                      label: 'Middle Name',
                      icon: Icons.person_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: lastCtrl,
                label: 'Last Name *',
                icon: Icons.person_outline_rounded,
                validator: _req,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: phoneCtrl,
                label: 'Phone Number *',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _phone,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _pickDate(
                  context,
                  dobCtrl,
                  lastDate: DateTime.now().subtract(
                    const Duration(days: 365 * 18),
                  ),
                ),
                child: AbsorbPointer(
                  child: _AppField(
                    ctrl: dobCtrl,
                    label: 'Date of Birth *',
                    icon: Icons.cake_outlined,
                    hint: 'YYYY-MM-DD',
                    validator: _req,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: _appFieldDecor(
                  label: 'Gender *',
                  icon: Icons.wc_rounded,
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: onGenderChanged,
                validator: (v) => v == null ? 'Please select gender' : null,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: fatherCtrl,
                label: "Father's Name",
                icon: Icons.family_restroom_outlined,
              ),
              const SizedBox(height: 16),
              _SectionDivider(label: 'Employment Details'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _pickDate(context, dojCtrl),
                child: AbsorbPointer(
                  child: _AppField(
                    ctrl: dojCtrl,
                    label: 'Date of Joining *',
                    icon: Icons.work_outline_rounded,
                    hint: 'YYYY-MM-DD',
                    validator: _req,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: empType,
                decoration: _appFieldDecor(
                  label: 'Employment Type *',
                  icon: Icons.badge_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Permanent',
                    child: Text('Permanent'),
                  ),
                  DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                  DropdownMenuItem(value: 'Intern', child: Text('Intern')),
                ],
                onChanged: onEmpTypeChanged,
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: workType,
                decoration: _appFieldDecor(
                  label: 'Work Type *',
                  icon: Icons.location_city_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Full Time',
                    child: Text('Full Time'),
                  ),
                  DropdownMenuItem(
                    value: 'Part Time',
                    child: Text('Part Time'),
                  ),
                ],
                onChanged: onWorkTypeChanged,
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: yearsExpCtrl,
                label: 'Years of Experience',
                icon: Icons.timeline_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
              ),
              const SizedBox(height: 16),
              _SectionDivider(label: 'Address'),
              const SizedBox(height: 12),
              _AppField(
                ctrl: addressCtrl,
                label: 'Permanent Address *',
                icon: Icons.home_outlined,
                maxLines: 2,
                validator: _req,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: commAddressCtrl,
                label: 'Communication Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                hint: 'Leave blank if same as permanent',
              ),
              const SizedBox(height: 16),
              _SectionDivider(label: 'Emergency Contact'),
              const SizedBox(height: 12),
              _AppField(
                ctrl: emergencyContactCtrl,
                label: 'Emergency Contact Number',
                icon: Icons.emergency_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _optPhone,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: emergencyRelCtrl,
                label: 'Relationship',
                icon: Icons.people_outline_rounded,
                hint: 'e.g. Spouse, Parent, Sibling',
              ),
              const SizedBox(height: 16),
              _SectionDivider(label: 'Government & Payroll IDs'),
              const SizedBox(height: 12),
              _AppField(
                ctrl: aadharCtrl,
                label: 'Aadhar Number',
                icon: Icons.fingerprint_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                validator: _aadhar,
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: panCtrl,
                label: 'PAN Number',
                icon: Icons.credit_card_outlined,
                inputFormatters: [
                  _UpperCase(),
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: _pan,
                hint: 'ABCDE1234F',
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: pfCtrl,
                label: 'PF Number',
                icon: Icons.account_balance_outlined,
                hint: 'Optional',
              ),
              const SizedBox(height: 12),
              _AppField(
                ctrl: esicCtrl,
                label: 'ESIC Number',
                icon: Icons.health_and_safety_outlined,
                hint: 'Optional',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile section toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSectionBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ProfileSectionBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _textSecondary,
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Section divider with label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _primary,
            letterSpacing: 0.3,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: Colors.indigo.shade50, thickness: 1)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isDesktop;
  const _Header({required this.isDesktop});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: isDesktop ? 80 : 64,
        height: isDesktop ? 80 : 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primary, _primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.business_center_rounded,
          color: Colors.white,
          size: isDesktop ? 42 : 34,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'Employee Management',
        style: TextStyle(
          fontSize: isDesktop ? 28 : 22,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Manage your workforce with ease',
        style: TextStyle(fontSize: isDesktop ? 14 : 13, color: _textSecondary),
      ),
    ],
  );
}

class _StepHeader extends StatelessWidget {
  final String step, title, subtitle;
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Step $step',
          style: const TextStyle(
            color: _primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: _textSecondary),
      ),
    ],
  );
}

class _OtpCard extends StatelessWidget {
  final String label, email;
  final TextEditingController ctrl;
  final IconData icon;
  const _OtpCard({
    required this.label,
    required this.email,
    required this.ctrl,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5FF),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E7FF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: _primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label  ·  $email',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 14,
            color: _textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w400,
              letterSpacing: 10,
              color: Colors.grey.shade300,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E7FF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

InputDecoration _appFieldDecor({
  required String label,
  required IconData icon,
  String? hint,
  Widget? suffix,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(color: _textSecondary, fontSize: 14),
  prefixIcon: Icon(icon, color: _primary, size: 20),
  suffixIcon: suffix,
  filled: true,
  fillColor: const Color(0xFFF5F5FF),
  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _primary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _errorRed),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _errorRed, width: 1.5),
  ),
);

class _AppField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? inputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  const _AppField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    textInputAction: inputAction ?? TextInputAction.next,
    maxLines: maxLines,
    inputFormatters: inputFormatters,
    validator: validator,
    onChanged: onChanged,
    decoration: _appFieldDecor(label: label, icon: icon, hint: hint),
  );
}

class _AppPasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool hide;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final VoidCallback? onSubmit;
  const _AppPasswordField({
    required this.ctrl,
    required this.label,
    required this.hide,
    required this.onToggle,
    this.validator,
    this.onChanged,
    this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    obscureText: hide,
    textInputAction: onSubmit != null
        ? TextInputAction.done
        : TextInputAction.next,
    onFieldSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
    validator: validator,
    onChanged: onChanged,
    decoration: _appFieldDecor(
      label: label,
      icon: Icons.lock_outline_rounded,
      suffix: IconButton(
        icon: Icon(
          hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _textSecondary,
          size: 20,
        ),
        onPressed: onToggle,
      ),
    ),
  );
}

class _AppPrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final IconData? icon;
  final bool outlined;
  const _AppPrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
    this.icon,
    this.outlined = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: outlined
        ? OutlinedButton(
            onPressed: loading ? null : onTap,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: _btnContent(),
          )
        : ElevatedButton(
            onPressed: loading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primary.withOpacity(0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: _btnContent(),
          ),
  );

  Widget _btnContent() => loading
      ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        );
}

class _TabLink extends StatelessWidget {
  final String prefix, label;
  final VoidCallback onTap;
  const _TabLink({
    required this.prefix,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(prefix, style: const TextStyle(color: _textSecondary, fontSize: 13)),
      GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _AppOrDivider extends StatelessWidget {
  const _AppOrDivider();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: Colors.grey.shade200)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'or',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      ),
      Expanded(child: Divider(color: Colors.grey.shade200)),
    ],
  );
}

class _AppErrorBanner extends StatelessWidget {
  final String message;
  const _AppErrorBanner({required this.message});
  bool get _isLockout =>
      message.contains('locked') || message.contains('another device');
  @override
  Widget build(BuildContext context) {
    final color = _isLockout ? _amber : _errorRed;
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

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase(), selection: n.selection);
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan picker field (tappable, shows selected plan name)
// ─────────────────────────────────────────────────────────────────────────────
class _PlanPickerField extends StatelessWidget {
  final Map<String, dynamic>? selectedPlan;
  final bool loading;
  final bool hasError; // ← ADD
  final VoidCallback onTap;

  const _PlanPickerField({
    required this.selectedPlan,
    required this.loading,
    required this.onTap,
    this.hasError = false, // ← ADD
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedPlan != null;

    // Border color: error = red, selected = primary, default = grey
    final borderColor = hasError
        ? _errorRed
        : hasSelection
        ? _primary.withOpacity(0.5)
        : Colors.grey.shade200;
    final borderWidth = (hasError || hasSelection) ? 1.5 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasError
              ? _errorRed.withOpacity(0.03)
              : const Color(0xFFF5F5FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: hasError ? _errorRed : _primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSelection
                              ? selectedPlan!['plan_name'] as String
                              : 'Select a Plan *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasSelection
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasError
                                ? _errorRed
                                : hasSelection
                                ? _textPrimary
                                : _textSecondary,
                          ),
                        ),
                        if (hasSelection) ...[
                          const SizedBox(height: 2),
                          Text(
                            '₹${selectedPlan!['price_monthly']}/month · '
                            '${selectedPlan!['total_modules']} modules',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasError ? _errorRed : _textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan bottom sheet — DTH/recharge-style cards
// ─────────────────────────────────────────────────────────────────────────────
class _PlanBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> plans;
  final bool loading;
  final String? selectedPlanId;
  final void Function(Map<String, dynamic>) onSelect;

  const _PlanBottomSheet({
    required this.plans,
    required this.loading,
    required this.selectedPlanId,
    required this.onSelect,
  });

  @override
  State<_PlanBottomSheet> createState() => _PlanBottomSheetState();
}

class _PlanBottomSheetState extends State<_PlanBottomSheet> {
  String _billing = 'monthly'; // 'monthly' | 'yearly'
  String? _expandedPlanId;

  // Plan-tier accent colours (matches plan_code order from API)
  static const _tierColors = [
    Color(0xFF6B7280), // Free Trial — neutral grey
    Color(0xFF0EA5E9), // Starter — sky blue
    Color(0xFF8B5CF6), // Growth — violet
    Color(0xFFF59E0B), // Enterprise — amber/gold
  ];

  Color _colorFor(int index) =>
      _tierColors[index.clamp(0, _tierColors.length - 1)];

  String _formatPrice(dynamic price) {
    final d = double.tryParse(price.toString()) ?? 0;
    if (d == 0) return 'Free';
    // Format Indian style: 2999 → ₹2,999
    final parts = d.toStringAsFixed(0).split('');
    if (parts.length > 3) {
      parts.insert(parts.length - 3, ',');
    }
    return '₹${parts.join()}';
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;

    return Container(
      height: sh * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Handle ──────────────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Plan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Select the best fit for your organisation',
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Billing toggle ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _BillingTab(
                    label: 'Monthly',
                    active: _billing == 'monthly',
                    onTap: () => setState(() => _billing = 'monthly'),
                  ),
                  _BillingTab(
                    label: 'Yearly  🏷️ Save ~17%',
                    active: _billing == 'yearly',
                    onTap: () => setState(() => _billing = 'yearly'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Divider(height: 1),

          // ── Plan cards ───────────────────────────────────────────────
          Expanded(
            child: widget.loading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : widget.plans.isEmpty
                ? const Center(
                    child: Text(
                      'No plans available.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: widget.plans.length,
                    itemBuilder: (_, i) {
                      final plan = widget.plans[i];
                      final planId = plan['plan_id'] as String;
                      final isSelected = planId == widget.selectedPlanId;
                      final isExpanded = planId == _expandedPlanId;
                      final color = _colorFor(i);
                      final price = _billing == 'monthly'
                          ? plan['price_monthly']
                          : plan['price_yearly'];
                      final modules =
                          (plan['modules'] as List?)?.cast<String>() ?? [];
                      final totalMods =
                          (plan['total_modules'] as num?)?.toInt() ?? 0;
                      final maxUsers =
                          (plan['max_users'] as num?)?.toInt() ?? 0;
                      final isFree = double.tryParse(price.toString()) == 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _expandedPlanId = isExpanded ? null : planId,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.05)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(
                                    isSelected ? 0.12 : 0.04,
                                  ),
                                  blurRadius: isSelected ? 16 : 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // ── Card header ──────────────────
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Left: colour dot + name
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _planIcon(
                                            plan['plan_code'] as String,
                                          ),
                                          color: color,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  plan['plan_name'] as String,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: _textPrimary,
                                                  ),
                                                ),
                                                if (plan['plan_code'] ==
                                                    'GROWTH') ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _amber.withOpacity(
                                                        0.15,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      '⭐ Popular',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: _amber,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // User limit chip
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.people_outline,
                                                  size: 12,
                                                  color: _textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  maxUsers == -1
                                                      ? 'Unlimited users'
                                                      : 'Up to $maxUsers users',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.grid_view_rounded,
                                                  size: 12,
                                                  color: _textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '$totalMods modules',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: _textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Right: price
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            isFree
                                                ? 'Free'
                                                : _formatPrice(price),
                                            style: TextStyle(
                                              fontSize: isFree ? 18 : 20,
                                              fontWeight: FontWeight.w900,
                                              color: color,
                                            ),
                                          ),
                                          if (!isFree)
                                            Text(
                                              _billing == 'monthly'
                                                  ? '/month'
                                                  : '/year',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: _textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Module chips row ──────────────
                                if (modules.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      0,
                                    ),
                                    child: SizedBox(
                                      height: 26,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: isExpanded
                                            ? modules.length
                                            : modules.take(5).length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(width: 6),
                                        itemBuilder: (_, mi) {
                                          final mod = modules[mi];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              mod,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: color,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                // ── Expanded: full module grid ────
                                if (isExpanded && modules.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: modules.map((mod) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: color.withOpacity(0.2),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_rounded,
                                                size: 10,
                                                color: color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                mod,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],

                                // ── Bottom bar: expand + select ───
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      // View details toggle
                                      TextButton.icon(
                                        onPressed: () => setState(
                                          () => _expandedPlanId = isExpanded
                                              ? null
                                              : planId,
                                        ),
                                        icon: Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons
                                                    .keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: color,
                                        ),
                                        label: Text(
                                          isExpanded
                                              ? 'Hide details'
                                              : 'View details',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Select button
                                      SizedBox(
                                        height: 36,
                                        child: isSelected
                                            ? OutlinedButton.icon(
                                                onPressed: () =>
                                                    widget.onSelect(plan),
                                                icon: Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 15,
                                                  color: color,
                                                ),
                                                label: Text(
                                                  'Selected',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: color,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: color,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton(
                                                onPressed: () =>
                                                    widget.onSelect(plan),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: color,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Select',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _planIcon(String code) {
    switch (code) {
      case 'FREE_TRIAL':
        return Icons.free_breakfast_rounded;
      case 'STARTER':
        return Icons.rocket_launch_rounded;
      case 'GROWTH':
        return Icons.trending_up_rounded;
      case 'ENTERPRISE':
        return Icons.diamond_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Billing toggle tab (used inside _PlanBottomSheet)
// ─────────────────────────────────────────────────────────────────────────────
class _BillingTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BillingTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _textSecondary,
          ),
        ),
      ),
    ),
  );
}
