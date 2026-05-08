import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── CONFIG ───────────────────────────────────────────────────────────────────
// Keep same base URL as your existing ApiConfig
class AppAdminConfig {
  static const String baseUrl =
      "https://unrivaled-headset-unmanaged.ngrok-free.dev";

  static const Map<String, String> baseHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  static const String _tokenKey = 'app_admin_token';
  static const String _adminIdKey = 'app_admin_id';
  static const String _adminNameKey = 'app_admin_name';
  static const String _adminRoleKey = 'app_admin_role';

  static Future<void> saveSession({
    required String token,
    required String adminId,
    required String name,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_adminIdKey, adminId);
    await prefs.setString(_adminNameKey, name);
    await prefs.setString(_adminRoleKey, role);
  }

  static Future<Map<String, String>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return null;
    return {
      'token': token,
      'adminId': prefs.getString(_adminIdKey) ?? '',
      'name': prefs.getString(_adminNameKey) ?? '',
      'role': prefs.getString(_adminRoleKey) ?? '',
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_adminIdKey);
    await prefs.remove(_adminNameKey);
    await prefs.remove(_adminRoleKey);
  }

  static Map<String, String> authHeaders(String token) => {
    ...baseHeaders,
    'x-app-admin-token': token,
  };
}

// ─── EXCEPTION ────────────────────────────────────────────────────────────────
class AppAdminException implements Exception {
  final String message;
  final int? statusCode;
  AppAdminException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

// ─── SERVICE ──────────────────────────────────────────────────────────────────
class AppAdminService {
  static final String _base = AppAdminConfig.baseUrl;

  // ── AUTH ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/app-admin/login'),
      headers: AppAdminConfig.baseHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data['success'] != true) {
      throw AppAdminException(data['message'] ?? 'Login failed');
    }
    return data;
  }

  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$_base/app-admin/logout'),
        headers: AppAdminConfig.authHeaders(token),
      );
    } catch (_) {}
    await AppAdminConfig.clearSession();
  }

  // ── DASHBOARD ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard(String token) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/dashboard'),
      headers: AppAdminConfig.authHeaders(token),
    );
    return _parse(res);
  }

  // ── TENANTS ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getTenants(String token) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/tenants'),
      headers: AppAdminConfig.authHeaders(token),
    );
    final data = _parse(res);
    return data['data'] as List;
  }

  static Future<Map<String, dynamic>> getTenant(
    String token,
    String tenantId,
  ) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/tenants/$tenantId'),
      headers: AppAdminConfig.authHeaders(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createTenant(
    String token,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/app-admin/tenants'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateTenant(
    String token,
    String tenantId,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/tenants/$tenantId'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> changeTenantStatus(
    String token,
    String tenantId,
    String status,
    String? reason,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/tenants/$tenantId/status'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode({'status': status, 'reason': reason}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> changeTenantPlan(
    String token,
    String tenantId,
    String planId,
    int? maxUsers,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/tenants/$tenantId/plan'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode({'plan_id': planId, 'max_users': maxUsers}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> overrideModule(
    String token,
    String tenantId,
    String moduleId,
    bool isEnabled,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/tenants/$tenantId/modules/$moduleId'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode({'is_enabled': isEnabled}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> resetTenantAdminPassword(
    String token,
    String tenantId,
    String newPassword,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/app-admin/tenants/$tenantId/reset-password'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode({'new_password': newPassword}),
    );
    return _parse(res);
  }

  // ── PLANS ───────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getPlans(String token) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/plans'),
      headers: AppAdminConfig.authHeaders(token),
    );
    final data = _parse(res);
    return data['data'] as List;
  }

  static Future<Map<String, dynamic>> createPlan(
    String token,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/app-admin/plans'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updatePlan(
    String token,
    String planId,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/plans/$planId'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  // ── MODULES ─────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getModules(String token) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/modules'),
      headers: AppAdminConfig.authHeaders(token),
    );
    final data = _parse(res);
    return data['data'] as List;
  }

  // ── APP ADMINS ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getAdmins(String token) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/admins'),
      headers: AppAdminConfig.authHeaders(token),
    );
    final data = _parse(res);
    return data['data'] as List;
  }

  static Future<Map<String, dynamic>> createAdmin(
    String token,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$_base/app-admin/admins'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> toggleAdmin(
    String token,
    String adminId,
    bool isActive,
  ) async {
    final res = await http.put(
      Uri.parse('$_base/app-admin/admins/$adminId/status'),
      headers: AppAdminConfig.authHeaders(token),
      body: jsonEncode({'is_active': isActive}),
    );
    return _parse(res);
  }

  // ── AUDIT LOGS ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getLogs(
    String token, {
    String? tenantId,
    String? action,
    int limit = 100,
  }) async {
    final params = {
      'limit': limit.toString(),
      if (tenantId != null) 'tenant_id': tenantId,
      if (action != null) 'action': action,
    };
    final uri = Uri.parse(
      '$_base/app-admin/logs',
    ).replace(queryParameters: params);
    final res = await http.get(uri, headers: AppAdminConfig.authHeaders(token));
    final data = _parse(res);
    return data['data'] as List;
  }

  // ── TENANT MODULES ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> getTenantModules(
    String token,
    String tenantId,
  ) async {
    final res = await http.get(
      Uri.parse('$_base/app-admin/tenants/$tenantId/modules'),
      headers: AppAdminConfig.authHeaders(token),
    );
    final data = _parse(res);
    return data['data'] as List;
  }

  // ── HELPER ──────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _parse(http.Response res) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw AppAdminException(
        'Invalid server response',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      throw AppAdminException(
        data['message'] ?? 'Server error (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return data;
  }
}
