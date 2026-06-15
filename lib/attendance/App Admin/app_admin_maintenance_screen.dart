// lib/attendance/App Admin/app_admin_maintenance_screen.dart
//
// Add fl_chart to pubspec.yaml:
//   fl_chart: ^0.68.0
//
// Mount in your app_admin_dashboard_screen.dart navigation:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => const AppAdminMaintenanceScreen()));

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── adjust to your actual base URL helper ──────────────────────
import '../providers/api_config.dart'; // provides ApiConfig.baseUrl

class AppAdminMaintenanceScreen extends StatefulWidget {
  const AppAdminMaintenanceScreen({super.key});

  @override
  State<AppAdminMaintenanceScreen> createState() =>
      _AppAdminMaintenanceScreenState();
}

class _AppAdminMaintenanceScreenState extends State<AppAdminMaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.business, size: 18), text: 'Orgs'),
            Tab(icon: Icon(Icons.monitor_heart, size: 18), text: 'Health'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Logs'),
            Tab(icon: Icon(Icons.backup, size: 18), text: 'Backup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SystemDashboardTab(),
          _OrgMonitorTab(), // Placeholder — built in next phase
          _HealthTab(), // Placeholder — built in next phase
          _ActivityLogsTab(), // Placeholder — built in next phase
          _BackupTab(), // Placeholder — built in next phase
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1 — SYSTEM DASHBOARD
// ═══════════════════════════════════════════════════════════════
class _SystemDashboardTab extends StatefulWidget {
  const _SystemDashboardTab();

  @override
  State<_SystemDashboardTab> createState() => _SystemDashboardTabState();
}

class _SystemDashboardTabState extends State<_SystemDashboardTab> {
  bool _loading = true;
  String? _error;

  // Overview data
  Map<String, dynamic> _orgs = {};
  Map<String, dynamic> _employees = {};
  Map<String, dynamic> _alertsInfo = {};

  // Chart data
  List<Map<String, dynamic>> _growthData = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_admin_token');
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_fetchOverview(), _fetchGrowth(), _fetchAlerts()]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchOverview() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/app-admin/dashboard/overview'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(res.body);
    if (body['success'] == true) {
      setState(() {
        _orgs = body['data']['orgs'] ?? {};
        _employees = body['data']['employees'] ?? {};
        _alertsInfo = body['data']['alerts'] ?? {};
      });
    }
  }

  Future<void> _fetchGrowth() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/app-admin/dashboard/growth-chart'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(res.body);
    if (body['success'] == true) {
      setState(
        () => _growthData = List<Map<String, dynamic>>.from(body['data'] ?? []),
      );
    }
  }

  Future<void> _fetchAlerts() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/app-admin/dashboard/alerts'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(res.body);
    if (body['success'] == true) {
      setState(
        () => _alerts = List<Map<String, dynamic>>.from(body['data'] ?? []),
      );
    }
  }

  Future<void> _resolveAlert(int alertId) async {
    final token = await _getToken();
    await http.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/app-admin/dashboard/alerts/$alertId/resolve',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    _fetchAlerts();
    _fetchOverview();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A237E)),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              'Failed to load dashboard',
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFF1A237E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Organization Stats'),
            const SizedBox(height: 10),
            _buildOrgStatsGrid(),
            const SizedBox(height: 20),
            _buildSectionHeader('Employee Stats'),
            const SizedBox(height: 10),
            _buildEmpStatsRow(),
            const SizedBox(height: 20),
            _buildSectionHeader('Org Status Breakdown'),
            const SizedBox(height: 10),
            _buildPieCard(),
            const SizedBox(height: 20),
            _buildSectionHeader('New Registrations — Last 30 Days'),
            const SizedBox(height: 10),
            _buildGrowthChart(),
            const SizedBox(height: 20),
            _buildAlertsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A237E),
      ),
    );
  }

  // ── Org stat cards ──────────────────────────────────────────
  Widget _buildOrgStatsGrid() {
    final cards = [
      _StatCardData(
        'Total Orgs',
        '${_orgs['total'] ?? 0}',
        Icons.business,
        const Color(0xFF1A237E),
      ),
      _StatCardData(
        'Active',
        '${_orgs['active'] ?? 0}',
        Icons.check_circle,
        const Color(0xFF2E7D32),
      ),
      _StatCardData(
        'Trial',
        '${_orgs['trial'] ?? 0}',
        Icons.access_time,
        const Color(0xFFF57C00),
      ),
      _StatCardData(
        'Suspended',
        '${_orgs['suspended'] ?? 0}',
        Icons.pause_circle,
        const Color(0xFFD32F2F),
      ),
      _StatCardData(
        'Expired',
        '${_orgs['expired'] ?? 0}',
        Icons.cancel,
        const Color(0xFF616161),
      ),
      _StatCardData(
        'New Today',
        '${_orgs['new_today'] ?? 0}',
        Icons.fiber_new,
        const Color(0xFF0288D1),
      ),
      _StatCardData(
        'Expiry Soon',
        '${_orgs['expiring_soon'] ?? 0}',
        Icons.warning,
        const Color(0xFFE65100),
      ),
      _StatCardData(
        'Avg Days Left',
        '${_orgs['avg_days_left'] ?? 0}',
        Icons.hourglass_bottom,
        const Color(0xFF6A1B9A),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => _buildStatCard(cards[i]),
    );
  }

  Widget _buildStatCard(_StatCardData d) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: d.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(d.icon, color: d.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: d.color,
                  ),
                ),
                Text(
                  d.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Employee stats row ───────────────────────────────────────
  Widget _buildEmpStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            _StatCardData(
              'Total',
              '${_employees['total'] ?? 0}',
              Icons.people,
              const Color(0xFF1A237E),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            _StatCardData(
              'Active',
              '${_employees['active'] ?? 0}',
              Icons.people_outline,
              const Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            _StatCardData(
              'Inactive',
              '${_employees['inactive'] ?? 0}',
              Icons.person_off,
              const Color(0xFF616161),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pie Chart ────────────────────────────────────────────────
  Widget _buildPieCard() {
    final total = (_orgs['total'] ?? 0) as int;
    final active = (_orgs['active'] ?? 0) as int;
    final trial = (_orgs['trial'] ?? 0) as int;
    final suspended = (_orgs['suspended'] ?? 0) as int;
    final expired = (_orgs['expired'] ?? 0) as int;

    if (total == 0) {
      return _emptyCard('No organization data yet.');
    }

    final sections = <PieChartSectionData>[
      if (active > 0)
        PieChartSectionData(
          value: active.toDouble(),
          color: const Color(0xFF2E7D32),
          title: 'Active\n$active',
          radius: 70,
          titleStyle: _pieTextStyle,
        ),
      if (trial > 0)
        PieChartSectionData(
          value: trial.toDouble(),
          color: const Color(0xFFF57C00),
          title: 'Trial\n$trial',
          radius: 70,
          titleStyle: _pieTextStyle,
        ),
      if (suspended > 0)
        PieChartSectionData(
          value: suspended.toDouble(),
          color: const Color(0xFFD32F2F),
          title: 'Suspended\n$suspended',
          radius: 70,
          titleStyle: _pieTextStyle,
        ),
      if (expired > 0)
        PieChartSectionData(
          value: expired.toDouble(),
          color: const Color(0xFF616161),
          title: 'Expired\n$expired',
          radius: 70,
          titleStyle: _pieTextStyle,
        ),
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 3,
        ),
      ),
    );
  }

  static const _pieTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // ── Growth Line Chart ────────────────────────────────────────
  Widget _buildGrowthChart() {
    if (_growthData.isEmpty) return _emptyCard('No growth data available.');

    final orgSpots = <FlSpot>[];
    final empSpots = <FlSpot>[];

    for (int i = 0; i < _growthData.length; i++) {
      final d = _growthData[i];
      orgSpots.add(FlSpot(i.toDouble(), (d['new_orgs'] as num).toDouble()));
      empSpots.add(
        FlSpot(i.toDouble(), (d['new_employees'] as num).toDouble()),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(const Color(0xFF1A237E)),
              const SizedBox(width: 4),
              const Text('New Orgs', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFF2E7D32)),
              const SizedBox(width: 4),
              const Text('New Employees', style: TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= _growthData.length) {
                          return const SizedBox.shrink();
                        }
                        final date = _growthData[idx]['date'] as String;
                        return Text(
                          date.substring(5), // MM-DD
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: orgSpots,
                    isCurved: true,
                    color: const Color(0xFF1A237E),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1A237E).withOpacity(0.08),
                    ),
                  ),
                  LineChartBarData(
                    spots: empSpots,
                    isCurved: true,
                    color: const Color(0xFF2E7D32),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2E7D32).withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── Alerts Section ───────────────────────────────────────────
  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionHeader('Active Alerts'),
            const SizedBox(width: 8),
            if ((_alertsInfo['unresolved'] ?? 0) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_alertsInfo['unresolved']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_alerts.isEmpty)
          _emptyCard('✓ No active alerts. System is healthy.')
        else
          ..._alerts.map(_buildAlertCard),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = alert['severity'] as String? ?? 'info';
    final Color color;
    final IconData icon;
    switch (severity) {
      case 'critical':
        color = const Color(0xFFD32F2F);
        icon = Icons.error;
        break;
      case 'warning':
        color = const Color(0xFFF57C00);
        icon = Icons.warning;
        break;
      default:
        color = const Color(0xFF0288D1);
        icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
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
                  ),
                ),
                if ((alert['message'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert['message'],
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(alert['created_at']),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _resolveAlert(alert['alert_id'] as int),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: EdgeInsets.zero,
              minimumSize: const Size(60, 28),
            ),
            child: const Text('Resolve', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _emptyCard(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration,
    child: Text(
      msg,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black45, fontSize: 13),
    ),
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════
//  PLACEHOLDER TABS (built in subsequent phases)
// ═══════════════════════════════════════════════════════════════
class _OrgMonitorTab extends StatelessWidget {
  const _OrgMonitorTab();
  @override
  Widget build(BuildContext context) => _comingSoon(
    context,
    Icons.business,
    'Organization Monitor',
    'Full org list with search, filter, quick actions.',
  );
}

class _HealthTab extends StatelessWidget {
  const _HealthTab();
  @override
  Widget build(BuildContext context) => _comingSoon(
    context,
    Icons.monitor_heart,
    'System Health',
    'DB, API, storage, and alert health checks.',
  );
}

class _ActivityLogsTab extends StatelessWidget {
  const _ActivityLogsTab();
  @override
  Widget build(BuildContext context) => _comingSoon(
    context,
    Icons.list_alt,
    'Activity Logs',
    'Paginated admin action history with filters.',
  );
}

class _BackupTab extends StatelessWidget {
  const _BackupTab();
  @override
  Widget build(BuildContext context) => _comingSoon(
    context,
    Icons.backup,
    'Backup & Maintenance',
    'Trigger backups, run cleanup tasks, schedule maintenance.',
  );
}

Widget _comingSoon(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: const Color(0xFF1A237E).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Coming in next phase',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════
class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCardData(this.label, this.value, this.icon, this.color);
}
