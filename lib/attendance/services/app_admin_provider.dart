import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'app_admin_service.dart';
import '../providers/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────────────

class SystemModule {
  final String moduleId;
  final String moduleName;
  final String moduleCode;
  final String category;
  final String? description;
  bool isIncluded;

  SystemModule({
    required this.moduleId,
    required this.moduleName,
    required this.moduleCode,
    required this.category,
    this.description,
    this.isIncluded = false,
  });

  factory SystemModule.fromJson(Map<String, dynamic> j) => SystemModule(
    moduleId: j['module_id'] as String,
    moduleName: j['module_name'] as String,
    moduleCode: j['module_code'] as String,
    category: j['category'] as String? ?? 'core',
    description: j['description'] as String?,
    isIncluded: (j['is_included'] as int? ?? 0) == 1,
  );
}

class Plan {
  final String planId;
  final String planName;
  final String planCode;
  final int maxUsers;
  final double priceMonthly;
  final double priceYearly;
  final bool isActive;
  final int moduleCount;
  final List<SystemModule> modules;
  final int tenantCount;

  Plan({
    required this.planId,
    required this.planName,
    required this.planCode,
    required this.maxUsers,
    required this.priceMonthly,
    required this.priceYearly,
    required this.isActive,
    this.moduleCount = 0,
    this.modules = const [],
    this.tenantCount = 0,
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    planId: j['plan_id'] as String,
    planName: j['plan_name'] as String,
    planCode: j['plan_code'] as String,
    maxUsers: (j['max_users'] as num?)?.toInt() ?? 50,
    priceMonthly: double.tryParse(j['price_monthly'].toString()) ?? 0,
    priceYearly: double.tryParse(j['price_yearly'].toString()) ?? 0,
    isActive: (j['is_active'] as int? ?? 1) == 1,
    moduleCount: (j['module_count'] as num?)?.toInt() ?? 0,
    tenantCount: (j['tenant_count'] as num?)?.toInt() ?? 0,
    modules: (j['modules'] as List? ?? [])
        .map((m) => SystemModule.fromJson(m as Map<String, dynamic>))
        .toList(),
  );

  List<SystemModule> get includedModules =>
      modules.where((m) => m.isIncluded).toList();

  /// Allows map-style access: plan['plan_id'], plan['plan_name'], etc.
  dynamic operator [](String key) {
    switch (key) {
      case 'plan_id':
        return planId;
      case 'plan_name':
        return planName;
      case 'plan_code':
        return planCode;
      case 'max_users':
        return maxUsers;
      case 'price_monthly':
        return priceMonthly;
      case 'price_yearly':
        return priceYearly;
      case 'is_active':
        return isActive;
      case 'module_count':
        return moduleCount;
      case 'tenant_count':
        return tenantCount;
      case 'modules':
        return modules;
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Enum
// ─────────────────────────────────────────────────────────────────────────────

enum AdminStatus { idle, loading, error }

// ─────────────────────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────────────────────

class AppAdminProvider extends ChangeNotifier {
  // ── Session ────────────────────────────────────────────────────────────────
  String? _token;
  String? _adminId;
  String? _adminName;
  String? _adminRole;

  String? get token => _token;
  String? get adminName => _adminName;
  String? get adminRole => _adminRole;
  bool get isLoggedIn => _token != null;
  bool get isSuperAdmin => _adminRole == 'super_admin';

  // ── Status ─────────────────────────────────────────────────────────────────
  AdminStatus _status = AdminStatus.idle;
  String? _error;

  AdminStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == AdminStatus.loading;

  // ── Data ───────────────────────────────────────────────────────────────────
  Map<String, dynamic>? dashboard;
  List<dynamic> tenants = [];
  List<dynamic> admins = [];
  List<dynamic> logs = [];

  List<Plan> _plans = [];
  List<SystemModule> _allModules = [];

  List<Plan> get plans => _plans;
  List<SystemModule> get allModules => _allModules;

  Map<String, List<SystemModule>> get modulesByCategory {
    final Map<String, List<SystemModule>> grouped = {};
    for (final m in _allModules) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }
    return grouped;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _setLoading() {
    _status = AdminStatus.loading;
    _error = null;
    notifyListeners();
  }

  void _setIdle() {
    _status = AdminStatus.idle;
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AdminStatus.error;
    _error = msg;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _status = AdminStatus.idle;
    notifyListeners();
  }

  // ── AUTH ───────────────────────────────────────────────────────────────────
  Future<bool> restoreSession() async {
    final session = await AppAdminConfig.getSession();
    if (session == null) return false;
    _token = session['token'];
    _adminId = session['adminId'];
    _adminName = session['name'];
    _adminRole = session['role'];
    notifyListeners();
    return true;
  }

  Future<void> login(String email, String password) async {
    _setLoading();
    try {
      final data = await AppAdminService.login(
        email: email,
        password: password,
      );
      _token = data['token'];
      _adminId = data['admin_id'];
      _adminName = data['name'];
      _adminRole = data['role'];
      await AppAdminConfig.saveSession(
        token: _token!,
        adminId: _adminId!,
        name: _adminName!,
        role: _adminRole!,
      );
      _setIdle();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_token != null) await AppAdminService.logout(_token!);
    _token = null;
    _adminId = null;
    _adminName = null;
    _adminRole = null;
    dashboard = null;
    tenants = [];
    _plans = [];
    notifyListeners();
  }

  // ── DASHBOARD ──────────────────────────────────────────────────────────────
  Future<void> loadDashboard() async {
    _setLoading();
    try {
      dashboard = await AppAdminService.getDashboard(_token!);
      _setIdle();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ── TENANTS ────────────────────────────────────────────────────────────────
  Future<void> loadTenants() async {
    _setLoading();
    try {
      tenants = await AppAdminService.getTenants(_token!);
      _setIdle();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<Map<String, dynamic>> getTenantDetail(String tenantId) async {
    return await AppAdminService.getTenant(_token!, tenantId);
  }

  Future<void> createCompany(Map<String, dynamic> body) async {
    _setLoading();
    try {
      await AppAdminService.createTenant(_token!, body);
      await loadTenants();
      _setIdle();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> createTenant(Map<String, dynamic> body) async {
    _setLoading();
    try {
      await AppAdminService.createTenant(_token!, body);
      await loadTenants();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> updateTenant(String tenantId, Map<String, dynamic> body) async {
    _setLoading();
    try {
      await AppAdminService.updateTenant(_token!, tenantId, body);
      await loadTenants();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> changeTenantStatus(
    String tenantId,
    String status,
    String? reason,
  ) async {
    await AppAdminService.changeTenantStatus(_token!, tenantId, status, reason);
    await loadTenants();
  }

  Future<void> changeTenantPlan(
    String tenantId,
    String planId,
    int? maxUsers,
  ) async {
    await AppAdminService.changeTenantPlan(_token!, tenantId, planId, maxUsers);
    await loadTenants();
  }

  Future<void> overrideModule(
    String tenantId,
    String moduleId,
    bool isEnabled,
  ) async {
    await AppAdminService.overrideModule(
      _token!,
      tenantId,
      moduleId,
      isEnabled,
    );
  }

  Future<void> resetTenantAdminPassword(
    String tenantId,
    String newPassword,
  ) async {
    await AppAdminService.resetTenantAdminPassword(
      _token!,
      tenantId,
      newPassword,
    );
  }

  // ── PLANS ──────────────────────────────────────────────────────────────────
  Future<void> loadPlans() async {
    _setLoading();
    try {
      final res = await ApiClient.get('/app-admin/plans');
      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Error');
      }
      _plans = (body['data'] as List)
          .map((p) => Plan.fromJson(p as Map<String, dynamic>))
          .toList();
      _setIdle();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> createPlan(Map<String, dynamic> data) async {
    _setLoading();
    try {
      final res = await ApiClient.post('/app-admin/plans', data);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 201 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to create plan');
      }
      await loadPlans();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> updatePlan(String planId, Map<String, dynamic> data) async {
    _setLoading();
    try {
      final res = await ApiClient.put('/app-admin/plans/$planId', data);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to update plan');
      }
      await loadPlans();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> togglePlan(String planId) async {
    _setLoading();
    try {
      final res = await ApiClient.put('/app-admin/plans/$planId/toggle', {});
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to toggle plan');
      }
      await loadPlans();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> deletePlan(String planId) async {
    _setLoading();
    try {
      final res = await ApiClient.delete('/app-admin/plans/$planId');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Failed to delete plan');
      }
      _plans.removeWhere((p) => p.planId == planId);
      _setIdle();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<Plan> getPlanDetail(String planId) async {
    final res = await ApiClient.get('/app-admin/plans/$planId');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to load plan');
    }
    return Plan.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── MODULES ────────────────────────────────────────────────────────────────
  Future<void> loadSystemModules() async {
    try {
      final res = await ApiClient.get('/app-admin/system-modules');

      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Error');
      }

      final data = body['data'] as List<dynamic>;

      _allModules = data
          .map((m) => SystemModule.fromJson(m as Map<String, dynamic>))
          .toList();

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<List<dynamic>> getTenantModules(String tenantId) async {
    return await AppAdminService.getTenantModules(_token!, tenantId);
  }

  // ── APP ADMINS ─────────────────────────────────────────────────────────────
  Future<void> loadAdmins() async {
    _setLoading();
    try {
      admins = await AppAdminService.getAdmins(_token!);
      _setIdle();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> createAdmin(Map<String, dynamic> body) async {
    await AppAdminService.createAdmin(_token!, body);
    await loadAdmins();
  }

  Future<void> toggleAdmin(String adminId, bool isActive) async {
    await AppAdminService.toggleAdmin(_token!, adminId, isActive);
    await loadAdmins();
  }

  // ── LOGS ───────────────────────────────────────────────────────────────────
  Future<void> loadLogs({String? tenantId, String? action}) async {
    _setLoading();
    try {
      logs = await AppAdminService.getLogs(
        _token!,
        tenantId: tenantId,
        action: action,
      );
      _setIdle();
    } catch (e) {
      _setError(e.toString());
    }
  }
}
