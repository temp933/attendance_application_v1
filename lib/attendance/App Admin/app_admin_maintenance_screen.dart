import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/api_config.dart';
import '../providers/api_client.dart';
import 'org_profile_screen.dart';
import 'global_notify.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS — match rest of app
// ─────────────────────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _border = Color(0xFFE2E8F0);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _green = Color(0xFF10B981);
const Color _yellow = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _orange = Color(0xFFF97316);

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ApiClient is fully static; path is relative (ApiClient prepends baseUrl).
// patch(path, {String? body}) — body must be a JSON string.
// delete(path)                — no body; cleanup uses POST instead.
// ─────────────────────────────────────────────────────────────────────────────
class _MaintenanceService {
  static const _base = '/app-admin/maintenance';

  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? params,
  }) async {
    String route = '$_base$path';
    if (params != null && params.isNotEmpty) {
      route +=
          '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    }
    final res = await ApiClient.get(route);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // patch — body serialised to JSON string to match ApiClient.patch(path, {String? body})
  static Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.patch('$_base$path', body: jsonEncode(body));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // post — two positional args: path, body map
  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.post('$_base$path', body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ApiClient.delete has no body param — use a POST endpoint for cleanup instead
  static Future<Map<String, dynamic>> _deleteViaPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.post('$_base$path', body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchOverview() => _get('/overview');
  static Future<Map<String, dynamic>> fetchHealth() => _get('/health');

  static Future<Map<String, dynamic>> fetchOrgs({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  }) => _get(
    '/organizations',
    params: {
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status != 'all') 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    },
  );

  static Future<Map<String, dynamic>> updateOrgStatus(
    String tenantId,
    String status,
  ) => _patch('/organizations/$tenantId/status', {'status': status});

  static Future<Map<String, dynamic>> fetchLogs({
    int page = 1,
    String? actionType,
    String? tenantId,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) => _get(
    '/activity-logs',
    params: {
      'page': page.toString(),
      if (actionType != null && actionType != 'all') 'action_type': actionType,
      if (tenantId != null) 'tenant_id': tenantId,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (search != null && search.isNotEmpty) 'search': search,
    },
  );

  static Future<Map<String, dynamic>> cleanupLogs(int days) =>
      _deleteViaPost('/activity-logs/cleanup', {'older_than_days': days});

  static Future<Map<String, dynamic>> fetchAlerts({bool resolved = false}) =>
      _get('/alerts', params: {'is_resolved': resolved.toString()});

  static Future<Map<String, dynamic>> resolveAlert(int alertId) =>
      _patch('/alerts/$alertId/resolve', {});

  static Future<Map<String, dynamic>> autoGenerateAlerts() =>
      _post('/alerts/auto-generate', {});

  static Future<Map<String, dynamic>> startBackup({
    String type = 'full',
    String? tenant,
  }) => _post('/backup/start', {
    'backup_type': type,
    if (tenant != null) 'tenant': tenant,
  });

  static Future<Map<String, dynamic>> fetchBackups({int page = 1}) =>
      _get('/backup/history', params: {'page': page.toString()});

  static Future<Map<String, dynamic>> optimizeDb() =>
      _post('/tasks/optimize-db', {});

  static Future<Map<String, dynamic>> runHealthCheck() =>
      _post('/tasks/health-check', {});

  static String exportLogsUrl() =>
      '${ApiConfig.baseUrl}$_base/activity-logs/export';
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AppAdminMaintenanceScreen extends StatefulWidget {
  const AppAdminMaintenanceScreen({super.key});

  @override
  State<AppAdminMaintenanceScreen> createState() =>
      _AppAdminMaintenanceScreenState();
}

class _AppAdminMaintenanceScreenState extends State<AppAdminMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Administrator',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Color(0xFF1A56DB),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm != true || !mounted) return;
              try {
                await ApiClient.post('/auth/app-admin/logout', {});
              } catch (_) {}
              if (!mounted) return;
              await AuthService.clearSession();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Tab bar ──
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _primary,
              unselectedLabelColor: const Color.fromARGB(122, 0, 0, 0),
              indicatorColor: _primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard_outlined, size: 18),
                  text: 'Dashboard',
                ),
                Tab(
                  icon: Icon(Icons.business_outlined, size: 18),
                  text: 'Organizations',
                ),
                Tab(
                  icon: Icon(Icons.monitor_heart_outlined, size: 18),
                  text: 'Health',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Activity',
                ),
                Tab(
                  icon: Icon(Icons.backup_outlined, size: 18),
                  text: 'Backup',
                ),
                Tab(
                  icon: Icon(Icons.notifications_outlined, size: 18),
                  text: 'Notify',
                ),
              ],
            ),
          ), // ← closes SizedBox.expand
          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                _DashboardTab(),
                _OrgsTab(),
                _HealthTab(),
                _ActivityTab(),
                _BackupTab(),
                _NotifyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — DASHBOARD
// ═════════════════════════════════════════════════════════════════════════════
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _MaintenanceService.fetchOverview();
      if (!mounted) return;
      setState(() {
        _data = res['data'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _primary));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    final d = _data!;
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stat grid ──────────────────────────────────────────────────
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                label: 'Total Orgs',
                value: '${d['total_orgs'] ?? 0}',
                icon: Icons.business,
                color: _primary,
              ),
              _StatCard(
                label: 'Active',
                value: '${d['active_orgs'] ?? 0}',
                icon: Icons.check_circle,
                color: _green,
              ),
              _StatCard(
                label: 'Trial',
                value: '${d['trial_orgs'] ?? 0}',
                icon: Icons.timer_outlined,
                color: _yellow,
              ),
              _StatCard(
                label: 'Suspended',
                value: '${d['suspended_orgs'] ?? 0}',
                icon: Icons.pause_circle,
                color: _orange,
              ),
              _StatCard(
                label: 'Expired',
                value: '${d['expired_orgs'] ?? 0}',
                icon: Icons.cancel,
                color: _red,
              ),
              _StatCard(
                label: 'New Today',
                value: '${d['new_today'] ?? 0}',
                icon: Icons.add_business,
                color: _primary,
              ),
              _StatCard(
                label: 'Total Employees',
                value: '${d['total_employees'] ?? 0}',
                icon: Icons.people,
                color: _textDark,
              ),
              _StatCard(
                label: 'Active Alerts',
                value: '${d['active_alerts'] ?? 0}',
                icon: Icons.notifications,
                color: _red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── System Health pill ─────────────────────────────────────────
          _SectionCard(
            title: 'System Health',
            child: Row(
              children: [
                _HealthDot(status: d['system_health'] ?? 'unknown'),
                const SizedBox(width: 10),
                Text(
                  (d['system_health'] ?? 'unknown').toString().toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _statusColor(d['system_health'] ?? 'unknown'),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  'Avg ${d['avg_days_remaining'] ?? 0} days remaining',
                  style: const TextStyle(color: _textMid, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Org status breakdown ───────────────────────────────────────
          _SectionCard(
            title: 'Organisation Status Breakdown',
            child: Column(
              children: [
                _BreakdownBar(
                  items: [
                    _BarItem('Active', (d['active_orgs'] ?? 0) as num, _green),
                    _BarItem('Trial', (d['trial_orgs'] ?? 0) as num, _yellow),
                    _BarItem(
                      'Suspended',
                      (d['suspended_orgs'] ?? 0) as num,
                      _orange,
                    ),
                    _BarItem('Expired', (d['expired_orgs'] ?? 0) as num, _red),
                  ],
                  total: (d['total_orgs'] ?? 1) as num,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Legend('Active', _green),
                    _Legend('Trial', _yellow),
                    _Legend('Suspended', _orange),
                    _Legend('Expired', _red),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — ORGANIZATIONS
// ═════════════════════════════════════════════════════════════════════════════
class _OrgsTab extends StatefulWidget {
  const _OrgsTab();
  @override
  State<_OrgsTab> createState() => _OrgsTabState();
}

class _OrgsTabState extends State<_OrgsTab> {
  List<dynamic> _orgs = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _status = 'all';
  final _searchCtrl = TextEditingController();
  bool _updating = false;

  final _statusFilters = ['all', 'active', 'trial', 'suspended', 'expired'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _MaintenanceService.fetchOrgs(
        page: _page,
        status: _status,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _orgs = res['data'] as List? ?? [];
        _totalPages = (res['pagination']?['total_pages'] ?? 1) as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _changeStatus(
    String tenantId,
    String newStatus,
    String orgName,
  ) async {
    setState(() => _updating = true);
    try {
      await _MaintenanceService.updateOrgStatus(tenantId, newStatus);
      if (!mounted) return;
      _showSnack('$orgName status updated to $newStatus');
      _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or ID…',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: _textMid,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _load(reset: true);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(reset: true),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _statusFilters
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  s[0].toUpperCase() + s.substring(1),
                                ),
                                selected: _status == s,
                                onSelected: (_) {
                                  setState(() => _status = s);
                                  _load(reset: true);
                                },
                                selectedColor: _primary.withValues(alpha: 0.15),
                                checkmarkColor: _primary,
                                labelStyle: TextStyle(
                                  color: _status == s ? _primary : _textMid,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: _status == s ? _primary : _border,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorView(message: _error!, onRetry: _load),
            )
          else if (_orgs.isEmpty)
            const SliverFillRemaining(
              child: _EmptyView(message: 'No organizations found.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList.separated(
                itemCount: _orgs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  if (i == _orgs.length) return _buildPagination();
                  return _OrgCard(
                    org: _orgs[i],
                    updating: _updating,
                    onStatusChange: (status) => _changeStatus(
                      _orgs[i]['tenant_id'],
                      status,
                      _orgs[i]['company_name'],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
          ),
          Text(
            '$_page / $_totalPages',
            style: const TextStyle(color: _textMid, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — HEALTH
// ═════════════════════════════════════════════════════════════════════════════
class _HealthTab extends StatefulWidget {
  const _HealthTab();
  @override
  State<_HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<_HealthTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _MaintenanceService.fetchHealth();
      if (!mounted) return;
      setState(() {
        _data = res['data'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runCheck() async {
    setState(() => _running = true);
    try {
      await _MaintenanceService.runHealthCheck();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _primary));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    final checks = (_data!['checks'] as List?) ?? [];
    final overall = _data!['overall'] ?? 'unknown';
    final checkedAt = _data!['checked_at'] ?? '';

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Overall status banner ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _statusColor(overall).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _statusColor(overall).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusIcon(overall),
                  color: _statusColor(overall),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System ${overall.toString().toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _statusColor(overall),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Last checked: ${_fmtTime(checkedAt)}',
                      style: const TextStyle(fontSize: 11, color: _textMid),
                    ),
                  ],
                ),
                const Spacer(),
                _running
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _runCheck,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Re-check'),
                        style: TextButton.styleFrom(foregroundColor: _primary),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Check cards ────────────────────────────────────────────────
          ...checks.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HealthCheckCard(check: c),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — ACTIVITY LOGS
// ═════════════════════════════════════════════════════════════════════════════
class _ActivityTab extends StatefulWidget {
  const _ActivityTab();
  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  List<dynamic> _logs = [];
  bool _loading = true;
  String? _error;
  int _page = 1, _totalPages = 1;
  String _actionType = 'all';
  final _searchCtrl = TextEditingController();
  bool _cleaning = false;

  final _actionTypes = [
    'all',
    'UPDATE_ORG_STATUS',
    'RESET_ADMIN_PASSWORD',
    'BACKUP_STARTED',
    'CLEANUP_LOGS',
    'DB_OPTIMIZE',
    'RESOLVE_ALERT',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _MaintenanceService.fetchLogs(
        page: _page,
        actionType: _actionType,
        search: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _logs = res['data'] as List? ?? [];
        _totalPages = (res['pagination']?['total_pages'] ?? 1) as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _cleanup() async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _CleanupDialog(),
    );
    if (days == null) return;
    setState(() => _cleaning = true);
    try {
      final res = await _MaintenanceService.cleanupLogs(days);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Cleanup done'),
          backgroundColor: _green,
        ),
      );
      _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primary,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: _searchDeco('Search logs…'),
                          onSubmitted: (_) => _load(reset: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _cleaning
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            )
                          : IconButton(
                              tooltip: 'Cleanup old logs',
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                color: _red,
                              ),
                              onPressed: _cleanup,
                            ),
                      IconButton(
                        tooltip: 'Export CSV',
                        icon: const Icon(
                          Icons.download_outlined,
                          color: _primary,
                        ),
                        onPressed: () {
                          final url = _MaintenanceService.exportLogsUrl();
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export URL copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _actionTypes.map((t) {
                        final label = t == 'all'
                            ? 'All'
                            : t.replaceAll('_', ' ');
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _actionType == t,
                            onSelected: (_) {
                              setState(() => _actionType = t);
                              _load(reset: true);
                            },
                            selectedColor: _primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _actionType == t ? _primary : _textMid,
                            ),
                            side: BorderSide(
                              color: _actionType == t ? _primary : _border,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _primary)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorView(message: _error!, onRetry: _load),
            )
          else if (_logs.isEmpty)
            const SliverFillRemaining(
              child: _EmptyView(message: 'No activity logs found.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList.separated(
                itemCount: _logs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == _logs.length) return _buildPagination();
                  return _LogCard(log: _logs[i]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _load();
                  }
                : null,
          ),
          Text(
            '$_page / $_totalPages',
            style: const TextStyle(color: _textMid, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages
                ? () {
                    setState(() => _page++);
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 5 — BACKUP & MAINTENANCE
// ═════════════════════════════════════════════════════════════════════════════
class _BackupTab extends StatefulWidget {
  const _BackupTab();
  @override
  State<_BackupTab> createState() => _BackupTabState();
}

class _BackupTabState extends State<_BackupTab> {
  List<dynamic> _backups = [];
  List<dynamic> _alerts = [];
  bool _loading = true;
  bool _backing = false;
  bool _optimizing = false;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _MaintenanceService.fetchBackups(),
        _MaintenanceService.fetchAlerts(),
      ]);
      if (!mounted) return;
      setState(() {
        _backups = results[0]['data'] as List? ?? [];
        _alerts = results[1]['data'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startBackup() async {
    // Show picker dialog first
    final result = await showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BackupPickerDialog(),
    );
    if (result == null) return; // user cancelled

    setState(() => _backing = true);
    try {
      final res = await _MaintenanceService.startBackup(
        type: result['type'] ?? 'full',
        tenant: result['tenant'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Backup started'),
          backgroundColor: _green,
        ),
      );
      await Future.delayed(const Duration(seconds: 3));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    } finally {
      if (mounted) setState(() => _backing = false);
    }
  }

  Future<void> _optimizeDb() async {
    setState(() => _optimizing = true);
    try {
      final res = await _MaintenanceService.optimizeDb();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Done'),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<void> _generateAlerts() async {
    setState(() => _generating = true);
    try {
      final res = await _MaintenanceService.autoGenerateAlerts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Done'),
          backgroundColor: _green,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _resolveAlert(int alertId) async {
    try {
      await _MaintenanceService.resolveAlert(alertId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert resolved'),
          backgroundColor: _green,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _primary));
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Action buttons ─────────────────────────────────────────────
          _SectionCard(
            title: 'Maintenance Tasks',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TaskButton(
                  label: 'Start Backup',
                  icon: Icons.backup,
                  color: _primary,
                  loading: _backing,
                  onTap: _startBackup,
                ),
                _TaskButton(
                  label: 'Optimise DB',
                  icon: Icons.storage,
                  color: _green,
                  loading: _optimizing,
                  onTap: _optimizeDb,
                ),
                _TaskButton(
                  label: 'Auto-generate Alerts',
                  icon: Icons.auto_fix_high,
                  color: _orange,
                  loading: _generating,
                  onTap: _generateAlerts,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Active alerts ──────────────────────────────────────────────
          _SectionCard(
            title: 'Active Alerts (${_alerts.length})',
            child: _alerts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No active alerts.',
                      style: TextStyle(color: _textMid),
                    ),
                  )
                : Column(
                    children: _alerts
                        .map(
                          (a) => _AlertRow(
                            alert: a,
                            onResolve: () =>
                                _resolveAlert(a['alert_id'] as int),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // ── Backup history ─────────────────────────────────────────────
          _SectionCard(
            title: 'Recent Backups',
            child: _backups.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No backups yet.',
                      style: TextStyle(color: _textMid),
                    ),
                  )
                : Column(
                    children: _backups
                        .map((b) => _BackupRow(backup: b))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
          ],
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _OrgCard extends StatefulWidget {
  final Map<String, dynamic> org;
  final bool updating;
  final void Function(String status) onStatusChange;
  const _OrgCard({
    required this.org,
    required this.updating,
    required this.onStatusChange,
  });

  @override
  State<_OrgCard> createState() => _OrgCardState();
}

class _OrgCardState extends State<_OrgCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.org;
    final status = o['status'] ?? 'unknown';
    final days = o['days_remaining'];
    final empCnt = o['employee_count'] ?? 0;
    final maxEmp = o['max_users'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    o['company_name'] ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _textDark,
                    ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                o['admin_email'] ?? '',
                style: const TextStyle(fontSize: 12, color: _textMid),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: _textMid,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.people_outline,
                        label: '$empCnt / $maxEmp employees',
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: days != null ? '$days days left' : 'No expiry',
                        color: days != null && (days as num) < 7
                            ? _red
                            : _textMid,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _InfoChip(icon: Icons.tag, label: o['tenant_id'] ?? ''),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.star_outline,
                        label: o['plan_id'] ?? 'free-trial',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Quick actions ──────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status != 'active')
                        _ActionBtn(
                          label: 'Activate',
                          color: _green,
                          icon: Icons.check_circle_outline,
                          onTap: widget.updating
                              ? null
                              : () => widget.onStatusChange('active'),
                        ),
                      if (status != 'suspended')
                        _ActionBtn(
                          label: 'Suspend',
                          color: _orange,
                          icon: Icons.pause_circle_outline,
                          onTap: widget.updating
                              ? null
                              : () => widget.onStatusChange('suspended'),
                        ),
                      if (status != 'expired')
                        _ActionBtn(
                          label: 'Expire',
                          color: _red,
                          icon: Icons.cancel_outlined,
                          onTap: widget.updating
                              ? null
                              : () => widget.onStatusChange('expired'),
                        ),
                    ],
                  ),
                  // inside _OrgCardState._expanded block, after the action buttons Wrap:
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrgProfileScreen(
                            tenantId: widget.org['tenant_id'],
                            canEdit: true,
                            isAppAdmin: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_outlined, size: 14),
                      label: const Text(
                        'View Full Profile',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthCheckCard extends StatelessWidget {
  final Map<String, dynamic> check;
  const _HealthCheckCard({required this.check});

  @override
  Widget build(BuildContext context) {
    final status = check['status'] ?? 'unknown';
    final name = (check['name'] ?? '')
        .toString()
        .replaceAll('_', ' ')
        .toUpperCase();
    final msg = check['message'] ?? '';
    final ms = check['response_ms'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _HealthDot(status: status),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _textDark,
                  ),
                ),
                Text(
                  msg,
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
            ),
          ),
          if (ms != null)
            Text(
              '${ms}ms',
              style: const TextStyle(fontSize: 11, color: _textMid),
            ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action_type'] ?? '—';
    final org = log['company_name'] ?? log['tenant_id'] ?? '—';
    final details = log['action_details'] ?? '';
    final before = log['status_before'];
    final after = log['status_after'];
    final at = log['created_at'] ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _textDark,
                  ),
                ),
              ),
              Text(
                _fmtTime(at),
                style: const TextStyle(fontSize: 11, color: _textMid),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(org, style: const TextStyle(fontSize: 12, color: _primary)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              details,
              style: const TextStyle(fontSize: 12, color: _textMid),
            ),
          ],
          if (before != null && after != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _StatusBadge(status: before),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward, size: 12, color: _textMid),
                const SizedBox(width: 6),
                _StatusBadge(status: after),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onResolve;
  const _AlertRow({required this.alert, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] ?? 'info';
    final color = severity == 'critical'
        ? _red
        : severity == 'warning'
        ? _yellow
        : _primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_severityIcon(severity), color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _textDark,
                  ),
                ),
                Text(
                  alert['message'] ?? '',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResolve,
            style: TextButton.styleFrom(foregroundColor: _green),
            child: const Text('Resolve', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  final Map<String, dynamic> backup;
  const _BackupRow({required this.backup});

  @override
  Widget build(BuildContext context) {
    final status = backup['status'] ?? 'unknown';
    final type = backup['backup_type'] ?? 'full';
    final size = backup['backup_size_mb'];
    final duration = backup['backup_duration_seconds'];
    final at = backup['completed_at'] ?? backup['created_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.backup,
            color: _statusColor(status == 'completed' ? 'healthy' : status),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.toUpperCase()} backup',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _fmtTime(at),
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(status: status),
              if (size != null)
                Text(
                  '${(size as num).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
              if (duration != null)
                Text(
                  '${duration}s',
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _TaskButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: loading ? null : onTap,
    icon: loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 13)),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = _textMid,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class _HealthDot extends StatelessWidget {
  final String status;
  const _HealthDot({required this.status});

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _statusColor(status),
      shape: BoxShape.circle,
    ),
  );
}

class _BreakdownBar extends StatelessWidget {
  final List<_BarItem> items;
  final num total;
  const _BreakdownBar({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = total == 0 ? 1 : total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 14,
        child: Row(
          children: items
              .map(
                (item) => Expanded(
                  flex: ((item.value / t) * 100).round().clamp(0, 100),
                  child: Container(color: item.color),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final num value;
  final Color color;
  const _BarItem(this.label, this.value, this.color);
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: _textMid)),
    ],
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _red, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMid),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, color: _textMid, size: 40),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: _textMid)),
      ],
    ),
  );
}

// ── Cleanup dialog ────────────────────────────────────────────────────────────
class _CleanupDialog extends StatefulWidget {
  @override
  State<_CleanupDialog> createState() => _CleanupDialogState();
}

class _CleanupDialogState extends State<_CleanupDialog> {
  int _days = 90;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(
      'Cleanup Activity Logs',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Delete logs older than:',
          style: TextStyle(color: _textMid, fontSize: 13),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _days,
          items: [30, 60, 90, 180, 365]
              .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
              .toList(),
          onChanged: (v) => setState(() => _days = v!),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(context, _days),
        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
        ),
        child: const Text('Delete'),
      ),
    ],
  );
}

// ── Backup picker dialog ──────────────────────────────────────────────────────
class _BackupPickerDialog extends StatefulWidget {
  const _BackupPickerDialog();
  @override
  State<_BackupPickerDialog> createState() => _BackupPickerDialogState();
}

class _BackupPickerDialogState extends State<_BackupPickerDialog> {
  bool _isTenant = false;
  final _searchCtrl = TextEditingController();
  List<dynamic> _results = [];
  bool _searching = false;
  Map<String, dynamic>? _selected;
  String? _searchError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _selected = null;
    });
    try {
      final res = await _MaintenanceService.fetchOrgs(
        search: query.trim(),
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _results = res['data'] as List? ?? [];
        _searching = false;
        if (_results.isEmpty) _searchError = 'No organisations found.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  void _confirm() {
    if (_isTenant && _selected == null) return;
    Navigator.pop(context, {
      'type': _isTenant ? 'tenant' : 'full',
      'tenant': _isTenant ? (_selected!['tenant_id'] as String?) : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.backup_outlined, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Start Backup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Choose backup scope:',
              style: TextStyle(fontSize: 13, color: _textMid),
            ),
            const SizedBox(height: 12),

            // ── Toggle chips ────────────────────────────────────────────
            Row(
              children: [
                _ScopeChip(
                  label: 'Full Database',
                  icon: Icons.storage_outlined,
                  selected: !_isTenant,
                  onTap: () => setState(() {
                    _isTenant = false;
                    _results = [];
                    _selected = null;
                    _searchCtrl.clear();
                  }),
                ),
                const SizedBox(width: 10),
                _ScopeChip(
                  label: 'Single Org',
                  icon: Icons.business_outlined,
                  selected: _isTenant,
                  onTap: () => setState(() => _isTenant = true),
                ),
              ],
            ),

            // ── Tenant search (visible only in tenant mode) ─────────────
            if (_isTenant) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by org name or ID…',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: _textMid,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          ),
                        )
                      : _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _results = [];
                              _selected = null;
                              _searchError = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) {
                  setState(() {}); // refresh suffix icon
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (_searchCtrl.text == v) _search(v);
                  });
                },
              ),

              // ── Selected org pill ─────────────────────────────────────
              if (_selected != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: _primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selected!['company_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ),
                      Text(
                        _selected!['tenant_id'] ?? '',
                        style: const TextStyle(fontSize: 11, color: _textMid),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Results dropdown ──────────────────────────────────────
              if (_results.isNotEmpty && _selected == null) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _border),
                    itemBuilder: (_, i) {
                      final org = _results[i];
                      return InkWell(
                        onTap: () => setState(() {
                          _selected = org;
                          _results = [];
                          _searchCtrl.text = org['company_name'] ?? '';
                        }),
                        borderRadius: i == 0
                            ? const BorderRadius.vertical(
                                top: Radius.circular(8),
                              )
                            : i == _results.length - 1
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              )
                            : BorderRadius.zero,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      org['company_name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _textDark,
                                      ),
                                    ),
                                    Text(
                                      org['tenant_id'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _textMid,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusBadge(status: org['status'] ?? ''),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (_searchError != null && _selected == null) ...[
                const SizedBox(height: 8),
                Text(
                  _searchError!,
                  style: const TextStyle(fontSize: 12, color: _red),
                ),
              ],
            ],

            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _textMid)),
        ),
        ElevatedButton.icon(
          onPressed: (!_isTenant || _selected != null) ? _confirm : null,
          icon: const Icon(Icons.backup, size: 16),
          label: Text(
            _isTenant ? 'Backup Org' : 'Backup All',
            style: const TextStyle(fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// Small toggle chip used only inside _BackupPickerDialog
class _ScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ScopeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? _primary : _border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: selected ? Colors.white : _textMid),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _textMid,
            ),
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 6 — NOTIFICATIONS
// ═════════════════════════════════════════════════════════════════════════════
class _NotifyTab extends StatelessWidget {
  const _NotifyTab();

  @override
  Widget build(BuildContext context) {
    // Strip the GlobalNotifyConsole's own Scaffold/AppBar so it
    // sits cleanly inside the maintenance screen's TabBarView.
    return const _NotifyTabBody();
  }
}

class _NotifyTabBody extends StatefulWidget {
  const _NotifyTabBody();

  @override
  State<_NotifyTabBody> createState() => _NotifyTabBodyState();
}

class _NotifyTabBodyState extends State<_NotifyTabBody> {
  late final GnService _svc;

  @override
  void initState() {
    super.initState();
    _svc = GnService(baseUrl: ApiConfig.baseUrl, token: ApiConfig.getToken());
  }

  int _tab = 0;

  static const _tabs = [
    (icon: Icons.dashboard_outlined, label: 'Overview'),
    (icon: Icons.send_outlined, label: 'Send'),
    (icon: Icons.history_outlined, label: 'History'),
    (icon: Icons.schedule_outlined, label: 'Scheduled'),
    (icon: Icons.bar_chart_outlined, label: 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      GnOverviewScreen(svc: _svc),
      GnSendScreen(svc: _svc),
      GnHistoryScreen(svc: _svc),
      GnScheduledScreen(svc: _svc),
      GnAnalyticsScreen(svc: _svc),
    ];

    return Column(
      children: [
        // ── Inner sub-tab bar ──────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final sel = _tab == i;
                return GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? _primary : _border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          t.icon,
                          size: 14,
                          color: sel ? Colors.white : _textMid,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: TextStyle(
                            color: sel ? Colors.white : _textMid,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const Divider(height: 1, color: _border),
        // ── Screen body ────────────────────────────────────────────────
        Expanded(
          child: IndexedStack(index: _tab, children: screens),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'healthy':
    case 'active':
    case 'completed':
      return _green;
    case 'warning':
    case 'trial':
    case 'running':
      return _yellow;
    case 'critical':
    case 'suspended':
    case 'failed':
      return _red;
    case 'expired':
      return _orange;
    default:
      return _textMid;
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'healthy':
      return Icons.check_circle;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'critical':
      return Icons.error;
    default:
      return Icons.help_outline;
  }
}

IconData _severityIcon(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return Icons.error;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline;
  }
}

String _fmtTime(String raw) {
  if (raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return raw;
  }
}

InputDecoration _searchDeco(String hint) => InputDecoration(
  hintText: hint,
  prefixIcon: const Icon(Icons.search, size: 20, color: _textMid),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: _primary),
  ),
  contentPadding: const EdgeInsets.symmetric(vertical: 10),
  isDense: true,
);
