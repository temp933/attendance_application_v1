import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../providers/api_config.dart';
import 'attendance_policy_screen.dart';
import 'admin_force_close_screen.dart';
import '../admin_attendance_report.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _orange = Color(0xFFF97316);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

// ── Responsive Helper ─────────────────────────────────────────────────────────
class _Screen {
  final double width;
  const _Screen(this.width);
  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;
  double get pad => isMobile
      ? 14
      : isTablet
      ? 20
      : 28;
  double get body => isMobile ? 13 : 14;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class SiteAttendanceRecord {
  final int attendanceId;
  final int employeeId;
  final String employeeName;
  final String? department;
  final int? siteId;
  final String? siteName;
  final String workDate;
  final String? checkinTime;
  final String? checkoutTime;
  final String status;
  final String? totalWorkTime;
  final bool isLate;
  final int lateMinutes;
  final double? checkinLat;
  final double? checkinLng;
  final double? checkoutLat;
  final double? checkoutLng;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final String? lastLocationUpdatedAt;
  final bool forceClosed;
  final String? forceCloseReason;
  final String? pausedAt;
  final int totalPauseSecs;

  SiteAttendanceRecord({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeName,
    this.department,
    this.siteId,
    this.siteName,
    required this.workDate,
    this.checkinTime,
    this.checkoutTime,
    required this.status,
    this.totalWorkTime,
    required this.isLate,
    required this.lateMinutes,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastLocationUpdatedAt,
    this.forceClosed = false,
    this.forceCloseReason,
    this.pausedAt,
    this.totalPauseSecs = 0,
  });

  factory SiteAttendanceRecord.fromJson(Map<String, dynamic> j) {
    double? parseCoord(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return SiteAttendanceRecord(
      attendanceId: j['attendance_id'] ?? 0,
      employeeId: j['employee_id'] ?? 0,
      employeeName: j['employee_name'] ?? 'Unknown',
      department: j['department'],
      siteId: j['site_id'] != null
          ? int.tryParse(j['site_id'].toString())
          : null,
      siteName: j['site_name'],
      workDate: j['work_date'] ?? '',
      checkinTime: j['checkin_time'],
      checkoutTime: j['checkout_time'],
      status: j['status'] ?? 'unknown',
      totalWorkTime: j['total_work_time'],
      isLate: (j['is_late'] == 1 || j['is_late'] == true),
      lateMinutes: int.tryParse(j['late_minutes']?.toString() ?? '0') ?? 0,
      checkinLat: parseCoord(j['checkin_latitude']),
      checkinLng: parseCoord(j['checkin_longitude']),
      checkoutLat: parseCoord(j['checkout_latitude']),
      checkoutLng: parseCoord(j['checkout_longitude']),
      lastKnownLat: parseCoord(j['last_known_latitude']),
      lastKnownLng: parseCoord(j['last_known_longitude']),
      lastLocationUpdatedAt: j['last_location_updated_at'] as String?,
      forceClosed: (j['force_closed'] == 1 || j['force_closed'] == true),
      forceCloseReason: j['force_close_reason'],
      pausedAt: j['paused_at'],
      totalPauseSecs:
          int.tryParse(j['total_pause_secs']?.toString() ?? '0') ?? 0,
    );
  }
}

class SiteAttendanceSummaryStats {
  final int presentToday, lateToday, activeNow, totalSessions;
  SiteAttendanceSummaryStats({
    required this.presentToday,
    required this.lateToday,
    required this.activeNow,
    required this.totalSessions,
  });
}

class SiteOption {
  final int id;
  final String name;
  SiteOption({required this.id, required this.name});
  factory SiteOption.fromJson(Map<String, dynamic> j) =>
      SiteOption(id: j['id'] ?? 0, name: j['site_name'] ?? '');
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class SiteAttendanceManagementService {
  static Future<Map<String, dynamic>> fetchAll({
    required String authToken,
    required String tenantId,
    required String date,
    String siteId = '',
    String status = '',
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/site-entry/admin/all').replace(
      queryParameters: {
        'date': date,
        'site_id': siteId,
        'status': status,
        'search': search,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $authToken', 'x-tenant-id': tenantId},
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load site attendance data');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class SiteAttendanceManagementScreen extends StatefulWidget {
  final String authToken;
  final String tenantId;
  const SiteAttendanceManagementScreen({
    super.key,
    required this.authToken,
    required this.tenantId,
  });

  @override
  State<SiteAttendanceManagementScreen> createState() =>
      _SiteAttendanceManagementScreenState();
}

class _SiteAttendanceManagementScreenState
    extends State<SiteAttendanceManagementScreen> {
  bool _loading = true;
  String? _error;
  List<SiteAttendanceRecord> _records = [];
  Map<int, List<SiteAttendanceRecord>> _groupedRecords = {};
  List<int> _employeeOrder = [];
  SiteAttendanceSummaryStats? _stats;
  List<SiteOption> _sites = [];

  DateTime _selectedDate = DateTime.now();
  String _statusFilter = '';
  String _siteFilter = '';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await SiteAttendanceManagementService.fetchAll(
        authToken: widget.authToken,
        tenantId: widget.tenantId,
        date: dateStr,
        siteId: _siteFilter,
        status: _statusFilter,
        search: _searchQuery,
      );
      if (!mounted) return;

      final rawRecords = (data['records'] as List? ?? [])
          .map((e) => SiteAttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      // Collect unique sites from records for filter chips
      final siteMap = <int, String>{};
      for (final r in rawRecords) {
        if (r.siteId != null && r.siteName != null) {
          siteMap[r.siteId!] = r.siteName!;
        }
      }
      final sites =
          siteMap.entries
              .map((e) => SiteOption(id: e.key, name: e.value))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      // Group by employee
      final grouped = <int, List<SiteAttendanceRecord>>{};
      final order = <int>[];
      for (final r in rawRecords) {
        if (!grouped.containsKey(r.employeeId)) {
          grouped[r.employeeId] = [];
          order.add(r.employeeId);
        }
        grouped[r.employeeId]!.add(r);
      }

      final rawStats = data['stats'] as Map<String, dynamic>? ?? {};

      setState(() {
        _records = rawRecords;
        _groupedRecords = grouped;
        _employeeOrder = order;
        _sites = sites;
        _stats = SiteAttendanceSummaryStats(
          presentToday:
              int.tryParse(rawStats['present_today']?.toString() ?? '0') ?? 0,
          lateToday:
              int.tryParse(rawStats['late_today']?.toString() ?? '0') ?? 0,
          activeNow:
              int.tryParse(rawStats['active_now']?.toString() ?? '0') ?? 0,
          totalSessions:
              int.tryParse(rawStats['total_sessions']?.toString() ?? '0') ?? 0,
        );
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  String _formatTime(String? datetime) {
    if (datetime == null) return '—';
    try {
      final parts = datetime.split(' ');
      if (parts.length < 2) return datetime;
      final dp = parts[0].split('-');
      final tp = parts[1].split(':');
      final dt = DateTime(
        int.parse(dp[0]),
        int.parse(dp[1]),
        int.parse(dp[2]),
        int.parse(tp[0]),
        int.parse(tp[1]),
      );
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return datetime.length >= 16 ? datetime.substring(11, 16) : datetime;
    }
  }

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day == n.day;
  }

  String _fmtPause(int secs) {
    if (secs <= 0) return '0m';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2.5,
                ),
              )
            : _error != null
            ? _errorWidget()
            : RefreshIndicator(
                onRefresh: _loadData,
                color: _primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildStats(s)),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
                    SliverToBoxAdapter(child: _buildFilters(s)),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
                    if (_employeeOrder.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(s.pad, 12, s.pad, 4),
                          child: Text(
                            '${_employeeOrder.length} employee${_employeeOrder.length == 1 ? '' : 's'} · ${_records.length} session${_records.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (_employeeOrder.isEmpty)
                      SliverFillRemaining(child: _emptyState()),
                    if (_employeeOrder.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          s.pad,
                          8,
                          s.pad,
                          32 + MediaQuery.of(context).padding.bottom,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((_, i) {
                            final empId = _employeeOrder[i];
                            final sessions = _groupedRecords[empId]!;
                            return _SiteEmployeeCard(
                              sessions: sessions,
                              formatTime: _formatTime,
                              fmtPause: _fmtPause,
                              s: s,
                            );
                          }, childCount: _employeeOrder.length),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x301A56DB),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isToday
                          ? 'Today — ${DateFormat('dd MMM yyyy').format(_selectedDate)}'
                          : DateFormat(
                              'dd MMM yyyy, EEEE',
                            ).format(_selectedDate),
                      style: const TextStyle(fontSize: 11, color: _textMid),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Change date',
                icon: const Icon(Icons.edit_calendar_rounded, color: _primary),
                onPressed: _pickDate,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.report, color: _red),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminAttendanceReportScreen(mode: 'site_entry'),
                      ),
                    ).then((_) => _loadData()),
                  ),
                  if ((_stats?.activeNow ?? 0) > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Force close open sessions',
                    icon: const Icon(Icons.lock_open_rounded, color: _red),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminForceCloseScreen(
                          loginId: 57,
                          mode: 'site_entry',
                        ),
                      ),
                    ).then((_) => _loadData()),
                  ),
                  if ((_stats?.activeNow ?? 0) > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Policy settings',
                icon: const Icon(Icons.tune_rounded, color: _primary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendancePolicyScreen(
                      authToken: widget.authToken,
                      tenantId: widget.tenantId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildStats(_Screen s) {
    if (_stats == null) return const SizedBox.shrink();
    return Container(
      color: _card,
      padding: EdgeInsets.symmetric(horizontal: s.pad, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statChip(
            'Sessions',
            '${_stats!.totalSessions}',
            _purple,
            Icons.list_alt_rounded,
          ),
          _vDivider(),
          _statChip(
            'Present',
            '${_stats!.presentToday}',
            _accent,
            Icons.check_circle_outline_rounded,
          ),
          _vDivider(),
          _statChip(
            'Late',
            '${_stats!.lateToday}',
            _amber,
            Icons.schedule_rounded,
          ),
          _vDivider(),
          _statChip(
            'Active',
            '${_stats!.activeNow}',
            _accent,
            Icons.radio_button_checked_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color, IconData icon) =>
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 10, color: _textMid)),
          ],
        ),
      );

  Widget _vDivider() => Container(height: 36, width: 1, color: _border);

  Widget _buildFilters(_Screen s) => Container(
    color: _card,
    padding: EdgeInsets.fromLTRB(s.pad, 10, s.pad, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by name or employee ID…',
            hintStyle: const TextStyle(color: _textLight, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _textLight,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      _loadData();
                    },
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
          onSubmitted: (val) {
            setState(() => _searchQuery = val.trim());
            _loadData();
          },
        ),
        const SizedBox(height: 8),
        // Status chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip('All', '', isStatus: true),
              const SizedBox(width: 8),
              _chip('Active', 'active', isStatus: true),
              const SizedBox(width: 8),
              _chip('Completed', 'completed', isStatus: true),
              if (_sites.isNotEmpty) ...[
                const SizedBox(width: 16),
                Container(width: 1, height: 20, color: _border),
                const SizedBox(width: 16),
                _chip('All Sites', '', isStatus: false),
                ..._sites.map(
                  (site) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _chip(site.name, '${site.id}', isStatus: false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, String value, {required bool isStatus}) {
    final current = isStatus ? _statusFilter : _siteFilter;
    final sel = current == value;
    final color = isStatus ? _primary : _purple;
    return GestureDetector(
      onTap: () {
        if (isStatus)
          setState(() => _statusFilter = value);
        else
          setState(() => _siteFilter = value);
        _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: sel ? Colors.white : _textMid,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_off_rounded,
            size: 36,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No site attendance records',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Try adjusting your date or filters.',
          style: TextStyle(fontSize: 13, color: _textMid),
        ),
      ],
    ),
  );

  Widget _errorWidget() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: _red, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loadData,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee Card — groups all sessions for one employee
// ─────────────────────────────────────────────────────────────────────────────

class _SiteEmployeeCard extends StatefulWidget {
  final List<SiteAttendanceRecord> sessions;
  final String Function(String?) formatTime;
  final String Function(int) fmtPause;
  final _Screen s;

  const _SiteEmployeeCard({
    required this.sessions,
    required this.formatTime,
    required this.fmtPause,
    required this.s,
  });

  @override
  State<_SiteEmployeeCard> createState() => _SiteEmployeeCardState();
}

class _SiteEmployeeCardState extends State<_SiteEmployeeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  SiteAttendanceRecord get _latest => widget.sessions.first;
  SiteAttendanceRecord get _oldest => widget.sessions.last;
  bool get _isMulti => widget.sessions.length > 1;

  bool get _anyActive => widget.sessions.any((s) => s.status == 'active');

  Color get _sc {
    if (_anyActive) return _accent;
    return _primary;
  }

  Color get _scBg {
    if (_anyActive) return const Color(0xFFECFDF5);
    return const Color(0xFFEEF2FF);
  }

  String get _totalWork {
    int totalSec = 0;
    for (final s in widget.sessions) {
      if (s.totalWorkTime != null) {
        final p = s.totalWorkTime!.split(':');
        if (p.length >= 2) {
          totalSec += (int.tryParse(p[0]) ?? 0) * 3600;
          totalSec += (int.tryParse(p[1]) ?? 0) * 60;
          if (p.length >= 3) totalSec += int.tryParse(p[2]) ?? 0;
        }
      }
    }
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    if (h == 0 && m == 0) return '--';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _fmtWork(String? t) {
    if (t == null) return '--';
    final p = t.split(':');
    if (p.length < 2) return t;
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    if (h == 0 && m == 0) return '< 1m';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _fmtCoord(double? v) => v == null ? '--' : v.toStringAsFixed(5);

  @override
  Widget build(BuildContext context) {
    final sc = _sc;
    final initial = _latest.employeeName.isNotEmpty
        ? _latest.employeeName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? sc.withOpacity(0.35) : _border,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? sc.withOpacity(0.10)
                : Colors.black.withOpacity(0.04),
            blurRadius: _expanded ? 16 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          InkWell(
            onTap: _isMulti ? _toggle : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.s.pad,
                vertical: 14,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _expanded
                            ? [sc, sc.withOpacity(0.7)]
                            : [
                                const Color(0xFF1A56DB),
                                const Color(0xFF1E3A8A),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _latest.employeeName,
                          style: TextStyle(
                            fontSize: widget.s.body,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (_latest.department != null)
                              _tag(
                                _latest.department!,
                                _primary.withOpacity(0.08),
                                _primary,
                              ),
                            _tag('#${_latest.employeeId}', _surface, _textMid),
                            _tag(
                              'Site',
                              const Color(0xFFECFDF5),
                              _accent,
                              icon: Icons.location_on_rounded,
                            ),
                            if (_isMulti)
                              _tag(
                                '${widget.sessions.length} sessions',
                                const Color(0xFFEDE9FE),
                                _purple,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _scBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sc.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: sc,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _anyActive ? 'Active' : 'Completed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sc,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isMulti) ...[
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _expanded ? sc : _textLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Summary strip ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: sc.withOpacity(0.04),
              border: Border(top: BorderSide(color: sc.withOpacity(0.15))),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.s.pad,
              vertical: 10,
            ),
            child: Row(
              children: [
                _summaryPill(
                  Icons.login_rounded,
                  'First In',
                  widget.formatTime(_oldest.checkinTime),
                  _accent,
                  widget.s,
                ),
                const SizedBox(width: 6),
                _summaryPill(
                  Icons.logout_rounded,
                  'Last Out',
                  widget.formatTime(_latest.checkoutTime),
                  _primary,
                  widget.s,
                ),
                const SizedBox(width: 6),
                _summaryPill(
                  Icons.timer_outlined,
                  'Total',
                  _totalWork,
                  _purple,
                  widget.s,
                ),
                if (_latest.isLate && _latest.lateMinutes > 0) ...[
                  const SizedBox(width: 6),
                  _summaryPill(
                    Icons.watch_later_outlined,
                    'Late',
                    '${_latest.lateMinutes}m',
                    _amber,
                    widget.s,
                  ),
                ],
              ],
            ),
          ),

          // ── Single session: location row ───────────────────────────────────
          if (!_isMulti && _latest.checkinLat != null)
            _LocationRow(
              session: _latest,
              fmtCoord: _fmtCoord,
              fmtPause: widget.fmtPause,
            ),

          // ── Multi-session expandable ───────────────────────────────────────
          if (_isMulti) ...[
            InkWell(
              onTap: _toggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _expanded ? sc.withOpacity(0.06) : _surface,
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotateAnim,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Hide sessions'
                          : 'View all ${widget.sessions.length} sessions',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1,
              child: Column(
                children: widget.sessions.asMap().entries.map((e) {
                  final idx = e.key;
                  final s = e.value;
                  final isLast = idx == widget.sessions.length - 1;
                  final isActive = s.status == 'active';
                  final isPaused = s.pausedAt != null;

                  return Container(
                    decoration: BoxDecoration(
                      color: idx.isEven
                          ? const Color(0xFFF8FAFF)
                          : const Color(0xFFF2F5FF),
                      border: Border(
                        top: BorderSide(color: _border),
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(color: _border.withOpacity(0.5)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Row(
                            children: [
                              // Session number
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Site name tag
                              if (s.siteName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _purple.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _purple.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 10,
                                        color: _purple,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.siteName!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              // Status/duration badge
                              if (s.totalWorkTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _purple.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _purple.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    _fmtWork(s.totalWorkTime),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _purple,
                                    ),
                                  ),
                                )
                              else if (isActive && isPaused)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Paused',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _amber,
                                    ),
                                  ),
                                )
                              else if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Time row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              _sessionTimeBlock(
                                Icons.login_rounded,
                                'In',
                                widget.formatTime(s.checkinTime),
                                _accent,
                              ),
                              Container(
                                height: 32,
                                width: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                color: _border,
                              ),
                              _sessionTimeBlock(
                                Icons.logout_rounded,
                                'Out',
                                widget.formatTime(s.checkoutTime),
                                _primary,
                              ),
                              if (s.totalPauseSecs > 0) ...[
                                Container(
                                  height: 32,
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  color: _border,
                                ),
                                _sessionTimeBlock(
                                  Icons.pause_circle_outline_rounded,
                                  'Pause',
                                  widget.fmtPause(s.totalPauseSecs),
                                  _amber,
                                ),
                              ],
                              if (s.forceClosed) ...[
                                const Spacer(),
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: _orange,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Force closed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Location row
                        if (s.checkinLat != null)
                          _LocationRow(
                            session: s,
                            fmtCoord: _fmtCoord,
                            fmtPause: widget.fmtPause,
                            compact: true,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Force close reason ────────────────────────────────────────────
          if (_latest.forceClosed && _latest.forceCloseReason != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF7ED),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: _orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _latest.forceCloseReason!,
                      style: const TextStyle(fontSize: 12, color: _orange),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 9, color: fg),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: fg,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _summaryPill(
    IconData icon,
    String label,
    String value,
    Color color,
    _Screen s,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: s.isMobile ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sessionTimeBlock(
    IconData icon,
    String label,
    String time,
    Color color,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: _textLight)),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        time,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Row
// ─────────────────────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final SiteAttendanceRecord session;
  final String Function(double?) fmtCoord;
  final String Function(int) fmtPause;
  final bool compact;

  const _LocationRow({
    required this.session,
    required this.fmtCoord,
    required this.fmtPause,
    this.compact = false,
  });

  void _showMap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationMapSheet(session: session),
    );
  }

  void _showLiveMap(BuildContext context) async {
    final lat = session.lastKnownLat ?? session.checkinLat!;
    final lng = session.lastKnownLng ?? session.checkinLng!;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open map.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCheckout = session.checkoutLat != null;
    final isLive = session.status == 'active';
    final isPaused = session.pausedAt != null;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 7 : 10),
      decoration: BoxDecoration(
        color: isPaused ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
        border: const Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.login_rounded,
            size: 12,
            color: isPaused ? _amber : _accent,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Site name
                if (session.siteName != null) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 10, color: _purple),
                      const SizedBox(width: 3),
                      Text(
                        session.siteName!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                      if (isPaused) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PAUSED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _amber,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ] else if (isLive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                ],
                // Check-in coords
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${fmtCoord(session.checkinLat)}, ${fmtCoord(session.checkinLng)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPaused ? _amber : _accent,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasCheckout) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 11, color: _red),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${fmtCoord(session.checkoutLat)}, ${fmtCoord(session.checkoutLng)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Pause time
                if (session.totalPauseSecs > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.pause_circle_outline_rounded,
                        size: 10,
                        color: _amber,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Paused: ${fmtPause(session.totalPauseSecs)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: _amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live button
              if (isLive && !isPaused) ...[
                GestureDetector(
                  onTap: () => _showLiveMap(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Live',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Pin button
              GestureDetector(
                onTap: () => _showMap(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_pin, size: 13, color: _primary),
                      SizedBox(width: 4),
                      Text(
                        'Pin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Map Sheet (inline flutter_map)
// ─────────────────────────────────────────────────────────────────────────────

class _LocationMapSheet extends StatelessWidget {
  final SiteAttendanceRecord session;
  const _LocationMapSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final checkinPoint = LatLng(session.checkinLat!, session.checkinLng!);
    final checkoutPoint = session.checkoutLat != null
        ? LatLng(session.checkoutLat!, session.checkoutLng!)
        : null;

    final center = checkoutPoint != null
        ? LatLng(
            (checkinPoint.latitude + checkoutPoint.latitude) / 2,
            (checkinPoint.longitude + checkoutPoint.longitude) / 2,
          )
        : checkinPoint;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        size: 16,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.employeeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          if (session.siteName != null)
                            Text(
                              session.siteName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          Text(
                            checkoutPoint != null
                                ? 'Check-in & Check-out locations'
                                : 'Check-in location',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _textMid,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _legendDot(_accent, 'Check-in'),
                    if (checkoutPoint != null) ...[
                      const SizedBox(width: 16),
                      _legendDot(_red, 'Check-out'),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: checkoutPoint != null
                      ? CameraFit.coordinates(
                          coordinates: [checkinPoint, checkoutPoint],
                          padding: const EdgeInsets.all(60),
                        )
                      : CameraFit.coordinates(
                          coordinates: [checkinPoint],
                          padding: const EdgeInsets.all(80),
                        ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: checkinPoint,
                        width: 40,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.login_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            Container(width: 2, height: 8, color: _accent),
                          ],
                        ),
                      ),
                      if (checkoutPoint != null)
                        Marker(
                          point: checkoutPoint,
                          width: 40,
                          height: 50,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _red.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              Container(width: 2, height: 8, color: _red),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (checkoutPoint != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [checkinPoint, checkoutPoint],
                          strokeWidth: 2.5,
                          color: _primary.withOpacity(0.5),
                          isDotted: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
    ],
  );
}
