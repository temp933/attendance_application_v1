import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String face_url = 'http://192.168.1.19:8000';
  static const String baseUrl = 'http://192.168.1.19:5000/api';

  // ── Single source of truth for all SharedPreferences keys ─────────
  static const _kToken = 'session_token';
  static const _kTenantId = 'tenantId';
  static const _kEmployeeId = 'employeeId';
  static const _kLoginId = 'loginId';
  static const _kRole = 'role';
  static const _kUserType = 'userType';
  static const _kUsername = 'username';
  // ──────────────────────────────────────────────────────────────────

  static String tenantId = '';
  static String employeeId = '';
  static String _token = '';

  static void setToken(String token) => _token = token;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (tenantId.isNotEmpty) 'x-tenant-id': tenantId,
    if (employeeId.isNotEmpty) 'x-employee-id': employeeId,
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  /// Load token + ids from disk into memory. Call once at app start.
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Check both key names for token
    _token =
        prefs.getString(_kToken) ?? // 'session_token'
        prefs.getString('sessionToken') ??
        '';

    tenantId = prefs.getString(_kTenantId) ?? '';

    // Check both key names for employeeId
    employeeId =
        prefs.getString(_kEmployeeId) ?? // 'employeeId'
        prefs.getString('empId') ??
        '';

    loginId = prefs.getString(_kLoginId) ?? '';
    role = prefs.getString(_kRole) ?? '';
    userType = prefs.getString(_kUserType) ?? '';
    username = prefs.getString(_kUsername) ?? '';
  }

  static String loginId = '';
  static String role = '';
  static String userType = '';
  static String username = '';

  /// Persist session to disk AND set in memory immediately.
  static Future<void> saveSession({
    required String loginId,
    required String empId,
    required String role,
    required String userType,
    required String username,
    required String sessionToken,
    required String tenantId,
  }) async {
    // Set in memory first so requests work immediately after login
    _token = sessionToken;
    ApiConfig.tenantId = tenantId;
    ApiConfig.employeeId = empId;
    ApiConfig.loginId = loginId;
    ApiConfig.role = role;
    ApiConfig.userType = userType;
    ApiConfig.username = username;
    // Persist to disk for next app launch
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, sessionToken);
    await prefs.setString(_kTenantId, tenantId);
    await prefs.setString(_kEmployeeId, empId);
    await prefs.setString(_kLoginId, loginId);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kUserType, userType);
    await prefs.setString(_kUsername, username);
  }

  /// Read session from disk. Returns null if no token saved.
  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Check both key names — AuthService uses 'session_token', ApiConfig uses 'sessionToken'
    final token =
        prefs.getString(_kToken) ?? // 'session_token'
        prefs.getString('sessionToken') ??
        '';

    if (token.isEmpty) return null;

    return {
      'sessionToken': token,
      'tenantId': prefs.getString(_kTenantId) ?? '',
      'empId':
          prefs.getString(_kEmployeeId) ??
          prefs.getString('empId') ??
          '', // fallback key
      'loginId': prefs.getString(_kLoginId) ?? '',
      'role': prefs.getString(_kRole) ?? '',
      'userType': prefs.getString(_kUserType) ?? '',
      'username': prefs.getString(_kUsername) ?? '',
    };
  }

  /// Wipe session from disk and memory.
  static Future<void> clearSession() async {
    _token = '';
    tenantId = '';
    employeeId = '';
    loginId = '';
    role = '';
    userType = '';
    username = '';

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_kToken);
    await prefs.remove(_kTenantId);
    await prefs.remove(_kEmployeeId);
    await prefs.remove(_kLoginId);
    await prefs.remove(_kRole);
    await prefs.remove(_kUserType);
    await prefs.remove(_kUsername);
  }
}
