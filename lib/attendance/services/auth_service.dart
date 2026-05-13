import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../providers/api_config.dart';

const String baseUrl = ApiConfig.baseUrl;
const String _authBase = '${ApiConfig.baseUrl}/auth'; // add this
const String _appAdminUsername = 'App_Admin';

class AuthService {
  // ── Prefs keys ────────────────────────────────────────────────────────────
  static const _kLoginId = 'loginId';
  static const _kEmpId = 'empId';
  static const _kRole = 'role';
  static const _kUserType = 'userType'; // NEW: org_admin | org_hr | employee
  static const _kUsername = 'username';
  static const _kToken = 'session_token';
  static const _kDeviceId = 'device_id';
  static const _kTenantId = 'tenantId';
  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE
  // ─────────────────────────────────────────────────────────────────────────
  static bool isAppAdminUsername(String username) {
    return username.trim().toLowerCase() == _appAdminUsername.toLowerCase();
  }

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    String deviceId = 'unknown';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        deviceId = (await info.androidInfo).id;
      } else if (Platform.isIOS) {
        deviceId = (await info.iosInfo).identifierForVendor ?? 'ios-unknown';
      }
    } catch (_) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    await prefs.setString(_kDeviceId, deviceId);
    return deviceId;
  }

  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final d = await info.androidInfo;
        return {
          'brand': d.brand,
          'model': d.model,
          'os': 'Android',
          'osVersion': d.version.release,
          'deviceId': d.id,
        };
      } else if (Platform.isIOS) {
        final d = await info.iosInfo;
        return {
          'brand': 'Apple',
          'model': d.utsname.machine,
          'os': 'iOS',
          'osVersion': d.systemVersion,
          'deviceId': d.identifierForVendor ?? 'ios-unknown',
        };
      }
    } catch (_) {}
    return {'deviceId': await getDeviceId()};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> saveSession({
    required String loginId,
    required String empId,
    required String role,
    required String userType,
    required String username,
    required String sessionToken,
    required String tenantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final cleanUsername = username.trim();

    await prefs.setString(_kLoginId, loginId);
    await prefs.setString(_kEmpId, empId);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kUserType, userType);
    await prefs.setString(_kUsername, cleanUsername);
    await prefs.setString(_kToken, sessionToken);
    await prefs.setString(_kTenantId, tenantId);

    // Store app admin flag
    await prefs.setBool('is_app_admin', isAppAdminUsername(cleanUsername));
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();

    final loginId = prefs.getString(_kLoginId);

    if (loginId == null) return null;

    return {
      'loginId': loginId,
      'empId': prefs.getString(_kEmpId) ?? '0',
      'role': prefs.getString(_kRole) ?? '',
      'userType': prefs.getString(_kUserType) ?? 'employee',
      'username': prefs.getString(_kUsername) ?? '',
      'session_token': prefs.getString(_kToken) ?? '',
      'tenantId': prefs.getString(_kTenantId) ?? '',
      'isAppAdmin': (prefs.getBool('is_app_admin') ?? false).toString(),
    };
  }

  static Future<bool> isAppAdminLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool('is_app_admin') ?? false;
  }

  static Future<bool> validateSession() async {
    final session = await getSession();

    if (session == null) return false;

    // ✅ Skip validation for App Admin
    final isAppAdmin = (session['isAppAdmin'] ?? 'false') == 'true';

    if (isAppAdmin) {
      return true;
    }

    final deviceId = await getDeviceId();

    try {
      final response = await http
          .post(
            Uri.parse('$_authBase/validate-session'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'login_id': session['loginId'],
              'session_token': session['session_token'],
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (data['expired'] == true || data['force_logout'] == true) {
        await clearSession(notifyServer: false);
        return false;
      }

      return data['valid'] == true;
    } on SocketException {
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final deviceId = await getDeviceId();
    final deviceInfo = await getDeviceInfo();

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_authBase/login'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'username': username,
              'password': password,
              'device_id': deviceId,
              'device_info': deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw AuthException('No internet connection. Please check your network.');
    } on Exception {
      throw AuthException('Connection timed out. Please try again.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      throw AuthException(data['message'] ?? 'Login failed');
    }

    // Save session only after password is set (not on first-login)
    if (data['firstLogin'] != true) {
      await saveSession(
        loginId: data['loginId'].toString(),
        empId: (data['empId'] ?? 0).toString(),
        role: data['roleId'].toString(),
        userType: data['userType'] ?? 'employee',
        username: data['username']?.toString() ?? username,
        sessionToken: data['sessionToken'],
        tenantId: data['tenantId']?.toString() ?? '',
      );
    }

    return data;
  }

  static Future<void> sendLoginOtp({required String username}) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_authBase/send-login-otp'),
            headers: ApiConfig.headers,
            body: jsonEncode({'username': username.trim()}),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw AuthException('No internet connection.');
    } on Exception {
      throw AuthException('Request timed out.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw AuthException(data['message'] ?? 'Failed to send OTP.');
    }
  }

  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String username,
    required String otp,
  }) async {
    final deviceId = await getDeviceId();
    final deviceInfo = await getDeviceInfo();

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_authBase/verify-login-otp'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'username': username.trim(),
              'otp': otp.trim(),
              'device_id': deviceId,
              'device_info': deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw AuthException('No internet connection.');
    } on Exception {
      throw AuthException('Request timed out.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      throw AuthException(data['message'] ?? 'OTP verification failed.');
    }

    if (data['firstLogin'] != true) {
      await saveSession(
        loginId: data['loginId'].toString(),
        empId: (data['empId'] ?? 0).toString(),
        role: data['roleId'].toString(),
        userType: data['userType'] ?? 'employee',
        username: data['username']?.toString() ?? username,
        sessionToken: data['sessionToken'],
        tenantId: data['tenantId']?.toString() ?? '',
      );
    }

    return data;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHANGE PASSWORD  (first-login flow)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> changePassword({
    required int loginId,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword.length < 8) {
      throw AuthException('Password must be at least 8 characters.');
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(newPassword)) {
      throw AuthException('Password must contain at least one letter.');
    }
    if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
      throw AuthException('Password must contain at least one number.');
    }
    if (newPassword != confirmPassword) {
      throw AuthException('Passwords do not match.');
    }

    final deviceId = await getDeviceId();
    final deviceInfo = await getDeviceInfo();

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_authBase/change-password'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'login_id': loginId,
              'new_password': newPassword,
              'confirm_password': confirmPassword,
              'device_id': deviceId,
              'device_info': deviceInfo,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on SocketException {
      throw AuthException('No internet connection.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['success'] != true) {
      throw AuthException(data['message'] ?? 'Password change failed');
    }

    await clearSession(notifyServer: false);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN RESET PASSWORD
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> resetPassword({
    required int empId,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_authBase/reset-password'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'emp_id': empId,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw AuthException(data['message'] ?? 'Password reset failed');
    }
    return data;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> logout() async => clearSession();

  static Future<void> clearSession({bool notifyServer = true}) async {
    if (notifyServer) {
      final session = await getSession();
      if (session != null) {
        try {
          await http
              .post(
                Uri.parse('$_authBase/logout'),
                headers: ApiConfig.headers,
                body: jsonEncode({'login_id': session['loginId']}),
              )
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> logoutById(int loginId) async {
    try {
      await http
          .post(
            Uri.parse('$_authBase/logout'),
            headers: ApiConfig.headers,
            body: jsonEncode({'login_id': loginId}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}
