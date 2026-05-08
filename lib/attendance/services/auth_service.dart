// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:io';
// import '../providers/api_config.dart';

// const String baseUrl = ApiConfig.baseUrl;

// class AuthService {
//   // ── Prefs keys ───────────────────────────────────────────────────────────────
//   static const _kLoginId = 'loginId';
//   static const _kEmpId = 'empId';
//   static const _kRole = 'role';
//   static const _kUsername = 'username';
//   static const _kToken = 'session_token';
//   static const _kDeviceId = 'device_id';

//   /// Returns a stable, persistent device ID (stored in SharedPreferences).
//   static Future<String> getDeviceId() async {
//     final prefs = await SharedPreferences.getInstance();
//     final existing = prefs.getString(_kDeviceId);
//     if (existing != null && existing.isNotEmpty) return existing;

//     String deviceId = 'unknown';
//     try {
//       final info = DeviceInfoPlugin();
//       if (Platform.isAndroid) {
//         deviceId = (await info.androidInfo).id;
//       } else if (Platform.isIOS) {
//         deviceId = (await info.iosInfo).identifierForVendor ?? 'ios-unknown';
//       }
//     } catch (_) {
//       deviceId = DateTime.now().millisecondsSinceEpoch.toString();
//     }

//     await prefs.setString(_kDeviceId, deviceId);
//     return deviceId;
//   }

//   /// Returns a full device info map for audit / session_device column.
//   static Future<Map<String, dynamic>> getDeviceInfo() async {
//     final info = DeviceInfoPlugin();
//     try {
//       if (Platform.isAndroid) {
//         final d = await info.androidInfo;
//         return {
//           'brand': d.brand,
//           'model': d.model,
//           'os': 'Android',
//           'osVersion': d.version.release,
//           'deviceId': d.id,
//         };
//       } else if (Platform.isIOS) {
//         final d = await info.iosInfo;
//         return {
//           'brand': 'Apple',
//           'model': d.utsname.machine,
//           'os': 'iOS',
//           'osVersion': d.systemVersion,
//           'deviceId': d.identifierForVendor ?? 'ios-unknown',
//         };
//       }
//     } catch (_) {}
//     return {'deviceId': await getDeviceId()};
//   }

//   /// Persist session data locally after a successful login.
//   static Future<void> saveSession({
//     required String loginId,
//     required String empId,
//     required String role,
//     required String username,
//     required String sessionToken,
//   }) async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString(_kLoginId, loginId);
//     await prefs.setString(_kEmpId, empId);
//     await prefs.setString(_kRole, role);
//     await prefs.setString(_kUsername, username);
//     await prefs.setString(_kToken, sessionToken);
//   }

//   /// Read the locally stored session (returns null if not found).
//   static Future<Map<String, String>?> getSession() async {
//     final prefs = await SharedPreferences.getInstance();
//     final loginId = prefs.getString(_kLoginId);
//     if (loginId == null) return null;
//     return {
//       'loginId': loginId,
//       'empId': prefs.getString(_kEmpId) ?? '',
//       'role': prefs.getString(_kRole) ?? '',
//       'username': prefs.getString(_kUsername) ?? '',
//       'session_token': prefs.getString(_kToken) ?? '',
//     };
//   }

//   static Future<bool> validateSession() async {
//     final session = await getSession();
//     if (session == null) return false;

//     final deviceId = await getDeviceId();
//     try {
//       final response = await http
//           .post(
//             Uri.parse('$baseUrl/auth/validate-session'),
//             headers: ApiConfig.headers,
//             body: jsonEncode({
//               'login_id': session['loginId'],
//               'session_token': session['session_token'],
//               'device_id': deviceId,
//             }),
//           )
//           .timeout(const Duration(seconds: 5));

//       final data = jsonDecode(response.body);

//       if (data['expired'] == true || data['force_logout'] == true) {
//         await clearSession(notifyServer: false);
//         return false;
//       }
//       return data['valid'] == true;
//     } on SocketException {
//       return true; // Offline — allow (can't confirm forced logout without network)
//     } catch (_) {
//       return true; // Timeout etc — allow
//     }
//   }

//   /// Throws [AuthException] on any failure.
//   static Future<Map<String, dynamic>> login({
//     required String username,
//     required String password,
//   }) async {
//     final deviceId = await getDeviceId();
//     final deviceInfo = await getDeviceInfo();

//     late http.Response response;
//     try {
//       response = await http
//           .post(
//             Uri.parse('$baseUrl/auth/login'),
//             headers: ApiConfig.headers,
//             body: jsonEncode({
//               'username': username,
//               'password': password,
//               'device_id': deviceId,
//               'device_info': deviceInfo,
//             }),
//           )
//           .timeout(const Duration(seconds: 10));
//     } on SocketException {
//       throw AuthException('No internet connection. Please check your network.');
//     } on Exception {
//       throw AuthException('Connection timed out. Please try again.');
//     }

//     final data = jsonDecode(response.body) as Map<String, dynamic>;

//     if (data['success'] != true) {
//       throw AuthException(data['message'] ?? 'Login failed');
//     }

//     if (data['firstLogin'] != true) {
//       await saveSession(
//         loginId: data['loginId'].toString(),
//         empId: data['empId'].toString(),
//         role: data['roleId'].toString(),
//         username: data['username'],
//         sessionToken: data['sessionToken'],
//       );
//     }

//     return data;
//   }

//   static Future<void> changePassword({
//     required int loginId,
//     required String newPassword,
//     required String confirmPassword,
//   }) async {
//     final deviceId = await getDeviceId();
//     final deviceInfo = await getDeviceInfo();

//     if (newPassword.length < 8) {
//       throw AuthException('Password must be at least 8 characters.');
//     }
//     if (!RegExp(r'[a-zA-Z]').hasMatch(newPassword)) {
//       throw AuthException('Password must contain at least one letter.');
//     }
//     if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
//       throw AuthException('Password must contain at least one number.');
//     }
//     if (newPassword != confirmPassword) {
//       throw AuthException('Passwords do not match.');
//     }

//     late http.Response response;
//     try {
//       response = await http
//           .post(
//             Uri.parse('$baseUrl/auth/change-password'),
//             headers: ApiConfig.headers,
//             body: jsonEncode({
//               'login_id': loginId,
//               'new_password': newPassword,
//               'confirm_password': confirmPassword,
//               'device_id': deviceId,
//               'device_info': deviceInfo,
//             }),
//           )
//           .timeout(const Duration(seconds: 10));
//     } on SocketException {
//       throw AuthException('No internet connection.');
//     }

//     final data = jsonDecode(response.body) as Map<String, dynamic>;

//     if (data['success'] != true) {
//       throw AuthException(data['message'] ?? 'Password change failed');
//     }

//     // ✅ Clear any stale session — user MUST log in again from scratch.
//     await clearSession(notifyServer: false);
//   }

//   // ─────────────────────────────────────────────────────────────────────────────
//   // ADMIN PASSWORD RESET
//   // ─────────────────────────────────────────────────────────────────────────────

//   /// Admin resets a user's password. The target user will be forced to change
//   /// password on their next login.
//   static Future<Map<String, dynamic>> resetPassword({
//     required int empId,
//     required String newPassword,
//     required String confirmPassword,
//   }) async {
//     final response = await http.post(
//       Uri.parse('$baseUrl/auth/reset-password'),
//       headers: ApiConfig.headers,
//       body: jsonEncode({
//         'emp_id': empId,
//         'new_password': newPassword,
//         'confirm_password': confirmPassword,
//       }),
//     );

//     final data = jsonDecode(response.body) as Map<String, dynamic>;
//     if (data['success'] != true) {
//       throw AuthException(data['message'] ?? 'Password reset failed');
//     }
//     return data;
//   }

//   // ─────────────────────────────────────────────────────────────────────────────
//   // LOGOUT
//   // ─────────────────────────────────────────────────────────────────────────────

//   static Future<void> logout() async {
//     await clearSession();
//   }

//   /// Clears local prefs and optionally notifies the server.
//   static Future<void> clearSession({bool notifyServer = true}) async {
//     if (notifyServer) {
//       final session = await getSession();
//       if (session != null) {
//         try {
//           await http
//               .post(
//                 Uri.parse('$baseUrl/auth/logout'),
//                 headers: ApiConfig.headers,
//                 body: jsonEncode({'login_id': session['loginId']}),
//               )
//               .timeout(const Duration(seconds: 5));
//         } catch (_) {
//           // Best-effort — don't block logout on network failure
//         }
//       }
//     }
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//   }

//   // In auth_service.dart — add an overload
//   static Future<void> logoutById(int loginId) async {
//     try {
//       await http
//           .post(
//             Uri.parse('$baseUrl/auth/logout'),
//             headers: ApiConfig.headers,
//             body: jsonEncode({'login_id': loginId}),
//           )
//           .timeout(const Duration(seconds: 5));
//     } catch (_) {} // best-effort
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.clear();
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Custom exception so callers can catch AuthException specifically
// // ─────────────────────────────────────────────────────────────────────────────
// class AuthException implements Exception {
//   final String message;
//   const AuthException(this.message);

//   @override
//   String toString() => message;
// }
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../providers/api_config.dart';

const String baseUrl = ApiConfig.baseUrl;

class AuthService {
  // ── Prefs keys ────────────────────────────────────────────────────────────
  static const _kLoginId = 'loginId';
  static const _kEmpId = 'empId';
  static const _kRole = 'role';
  static const _kUserType = 'userType'; // NEW: org_admin | org_hr | employee
  static const _kUsername = 'username';
  static const _kToken = 'session_token';
  static const _kDeviceId = 'device_id';

  // ─────────────────────────────────────────────────────────────────────────
  // DEVICE
  // ─────────────────────────────────────────────────────────────────────────

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
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLoginId, loginId);
    await prefs.setString(_kEmpId, empId);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kUserType, userType);
    await prefs.setString(_kUsername, username);
    await prefs.setString(_kToken, sessionToken);
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
    };
  }

  static Future<bool> validateSession() async {
    final session = await getSession();
    if (session == null) return false;

    final deviceId = await getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/validate-session'),
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
      return true; // offline — allow
    } catch (_) {
      return true; // timeout — allow
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN  (password-based)
  // ─────────────────────────────────────────────────────────────────────────

  /// Throws [AuthException] on any failure.
  /// Returns a map with keys:
  ///   firstLogin, loginId, empId, roleId, userType, username, sessionToken
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
            Uri.parse('$baseUrl/auth/login'),
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
        username: data['username'],
        sessionToken: data['sessionToken'],
      );
    }

    return data;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN  (OTP-based)
  // ─────────────────────────────────────────────────────────────────────────

  /// Step 1 — request OTP sent to registered email
  static Future<void> sendLoginOtp({required String username}) async {
    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/auth/send-login-otp'),
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

  /// Step 2 — submit OTP, get back the same session payload as password login
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
            Uri.parse('$baseUrl/auth/verify-login-otp'),
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
        username: data['username'],
        sessionToken: data['sessionToken'],
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
            Uri.parse('$baseUrl/auth/change-password'),
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
      Uri.parse('$baseUrl/auth/reset-password'),
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
                Uri.parse('$baseUrl/auth/logout'),
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
            Uri.parse('$baseUrl/auth/logout'),
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
