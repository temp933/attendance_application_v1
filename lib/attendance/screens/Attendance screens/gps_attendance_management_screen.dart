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
  double get caption => isMobile ? 11 : 12;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class GpsAttendanceRecord {
  final int attendanceId;
  final int employeeId;
  final String employeeName;
  final String? department;
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
  final String attendanceMode;
  final String? remarks;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final String? lastLocationUpdatedAt;

  GpsAttendanceRecord({
    required this.attendanceId,
    required this.employeeId,
    required this.employeeName,
    this.department,
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
    required this.attendanceMode,
    this.remarks,
    this.lastKnownLat,
    this.lastKnownLng,
    this.lastLocationUpdatedAt,
  });

  factory GpsAttendanceRecord.fromJson(Map<String, dynamic> j) {
    double? parseCoord(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return GpsAttendanceRecord(
      attendanceId: j['attendance_id'] ?? 0,
      employeeId: j['employee_id'] ?? 0,
      employeeName: j['employee_name'] ?? 'Unknown',
      department: j['department'],
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
      attendanceMode: j['attendance_mode'] ?? 'gps',
      remarks: j['remarks'],
      lastKnownLat: parseCoord(j['last_known_latitude']),
      lastKnownLng: parseCoord(j['last_known_longitude']),
      lastLocationUpdatedAt: j['last_location_updated_at'] as String?,
    );
  }
}

class GpsAttendanceSummaryStats {
  final int totalEmployees, presentToday, absentToday, lateToday, activeNow;
  GpsAttendanceSummaryStats({
    required this.totalEmployees,
    required this.presentToday,
    required this.absentToday,
    required this.lateToday,
    required this.activeNow,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class GpsAttendanceManagementService {
  static Future<Map<String, dynamic>> fetchAll({
    required String authToken,
    required String tenantId,
    required String date,
    String status = '',
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/gps/admin/all').replace(
      queryParameters: {
        'date': date,
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
    throw Exception('Failed to load GPS attendance data');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class GpsAttendanceManagementScreen extends StatefulWidget {
  final String authToken;
  final String tenantId;
  final bool canEdit;
  const GpsAttendanceManagementScreen({
    super.key,
    required this.authToken,
    required this.tenantId,
    this.canEdit = false, 
  });

  @override
  State<GpsAttendanceManagementScreen> createState() =>
      _GpsAttendanceManagementScreenState();
}

class _GpsAttendanceManagementScreenState
    extends State<GpsAttendanceManagementScreen> {
  bool _loading = true;
  String? _error;
  List<GpsAttendanceRecord> _records = [];
  Map<int, List<GpsAttendanceRecord>> _groupedRecords = {};
  List<int> _employeeOrder = [];
  GpsAttendanceSummaryStats? _stats;

  DateTime _selectedDate = DateTime.now();
  String _statusFilter = '';
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

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await GpsAttendanceManagementService.fetchAll(
        authToken: widget.authToken,
        tenantId: widget.tenantId,
        date: dateStr,
        status: _statusFilter,
        search: _searchQuery,
      );
      if (!mounted) return;

      final rawRecords = (data['records'] as List? ?? [])
          .map((e) => GpsAttendanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();

      // Group by employee
      final grouped = <int, List<GpsAttendanceRecord>>{};
      final order = <int>[];
      for (final r in rawRecords) {
        if (!grouped.containsKey(r.employeeId)) {
          grouped[r.employeeId] = [];
          order.add(r.employeeId);
        }
        grouped[r.employeeId]!.add(r);
      }

      final rawStats = data['stats'] as Map<String, dynamic>? ?? {};
      final totalEmp =
          int.tryParse(rawStats['total_employees']?.toString() ?? '0') ?? 0;
      final present =
          int.tryParse(rawStats['present_today']?.toString() ?? '0') ?? 0;

      setState(() {
        _records = rawRecords;
        _groupedRecords = grouped;
        _employeeOrder = order;
        _stats = GpsAttendanceSummaryStats(
          totalEmployees: totalEmp,
          presentToday: present,
          absentToday: totalEmp - present,
          lateToday:
              int.tryParse(rawStats['late_today']?.toString() ?? '0') ?? 0,
          activeNow:
              int.tryParse(rawStats['active_now']?.toString() ?? '0') ?? 0,
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

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatTime(String? datetime) {
    if (datetime == null) return '—';
    try {
      final parts = datetime.split(' ');
      if (parts.length < 2) return datetime;
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      final dt = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
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

  Future<void> _openMap({
    required double checkinLat,
    required double checkinLng,
    double? checkoutLat,
    double? checkoutLng,
  }) async {
    final Uri uri;
    if (checkoutLat != null && checkoutLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/$checkinLat,$checkinLng/$checkoutLat,$checkoutLng',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$checkinLat,$checkinLng',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open map.')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
                            '${_employeeOrder.length} employee${_employeeOrder.length == 1 ? '' : 's'}',
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
                            return _GpsEmployeeCard(
                              sessions: sessions,
                              formatTime: _formatTime,
                              s: s,
                              openMap: _openMap,
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
             if (widget.canEdit) Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.report, color: _red),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminAttendanceReportScreen(
                          mode: 'gps',  // pass 'gps' or 'gps_face' as needed
                        ),
                      ),
                    ).then((_) => _loadData()),
                  ),
                  // Badge — only show when there are active sessions
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
             if (widget.canEdit) Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Force close open sessions',
                    icon: const Icon(Icons.lock_open_rounded, color: _red),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminForceCloseScreen(loginId: 57, mode: 'gps'),
                      ),
                    ).then((_) => _loadData()),
                  ),
                  // Badge — only show when there are active sessions
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
            'Total',
            '${_stats!.totalEmployees}',
            _primary,
            Icons.people_alt_rounded,
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
            'Absent',
            '${_stats!.absentToday}',
            _red,
            Icons.cancel_outlined,
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
      children: [
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
        Row(
          children: [
            _chip('All', ''),
            const SizedBox(width: 8),
            _chip('Active', 'active'),
            const SizedBox(width: 8),
            _chip('Completed', 'completed'),
          ],
        ),
      ],
    ),
  );

  Widget _chip(String label, String value) {
    final sel = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _primary : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _primary : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
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
          child: const Icon(Icons.gps_off_rounded, size: 36, color: _primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'No GPS records found',
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
// Employee Card
// ─────────────────────────────────────────────────────────────────────────────

class _GpsEmployeeCard extends StatefulWidget {
  final List<GpsAttendanceRecord> sessions;
  final String Function(String?) formatTime;
  final _Screen s;
  final Future<void> Function({
    required double checkinLat,
    required double checkinLng,
    double? checkoutLat,
    double? checkoutLng,
  })
  openMap;

  const _GpsEmployeeCard({
    required this.sessions,
    required this.formatTime,
    required this.s,
    required this.openMap,
  });

  @override
  State<_GpsEmployeeCard> createState() => _GpsEmployeeCardState();
}

class _GpsEmployeeCardState extends State<_GpsEmployeeCard>
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

  GpsAttendanceRecord get _latest => widget.sessions.first;
  GpsAttendanceRecord get _oldest => widget.sessions.last;
  bool get _isMulti => widget.sessions.length > 1;

  Color get _sc {
    if (_latest.status == 'active') return _accent;
    if (_latest.status == 'completed') return _primary;
    return _textLight;
  }

  Color get _scBg {
    if (_latest.status == 'active') return const Color(0xFFECFDF5);
    if (_latest.status == 'completed') return const Color(0xFFEEF2FF);
    return const Color(0xFFF8FAFC);
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
          // ── Header row ────────────────────────────────────────────────────
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
                        Row(
                          children: [
                            if (_latest.department != null) ...[
                              _tag(
                                _latest.department!,
                                _primary.withOpacity(0.08),
                                _primary,
                              ),
                              const SizedBox(width: 6),
                            ],
                            _tag('#${_latest.employeeId}', _surface, _textMid),
                            const SizedBox(width: 6),
                            // GPS mode badge
                            _tag(
                              'GPS',
                              const Color(0xFFECFDF5),
                              _accent,
                              icon: Icons.gps_fixed_rounded,
                            ),
                            if (_isMulti) ...[
                              const SizedBox(width: 6),
                              _tag(
                                '${widget.sessions.length} sessions',
                                const Color(0xFFEDE9FE),
                                _purple,
                              ),
                            ],
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
                          _latest.status == 'active' ? 'Active' : 'Completed',
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

          // ── Location row (single session, always visible) ─────────────────
          if (!_isMulti && _latest.checkinLat != null)
            _LocationRow(session: _latest, fmtCoord: _fmtCoord),

          // ── Expandable multi-session list ─────────────────────────────────
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
                        // Time row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Row(
                            children: [
                              // Session badge
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
                              const Spacer(),
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
                              else if (s.status == 'active')
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
                        // Location row inside session
                        if (s.checkinLat != null)
                          _LocationRow(
                            session: s,
                            fmtCoord: _fmtCoord,
                            compact: true,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Remarks ───────────────────────────────────────────────────────
          if (_latest.remarks != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FF),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, size: 13, color: _purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _latest.remarks!,
                      style: const TextStyle(fontSize: 12, color: _textMid),
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
// Location Row — shows coords + map button
// ─────────────────────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final GpsAttendanceRecord session;
  final String Function(double?) fmtCoord;
  final bool compact;

  const _LocationRow({
    required this.session,
    required this.fmtCoord,
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
    final lat = session.lastKnownLat!;
    final lng = session.lastKnownLng!;
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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 7 : 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0FDF4),
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Icon(Icons.login_rounded, size: 12, color: _accent),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${fmtCoord(session.checkinLat)}, ${fmtCoord(session.checkinLng)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    ),
                    if (isLive) ...[
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Pin button — opens inline map sheet ───────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Live button — only when last_known coords exist ───────────
              if (session.lastKnownLat != null) ...[
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
              // ── Pin button — opens inline map sheet ───────────────────────
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

class _LocationMapSheet extends StatelessWidget {
  final GpsAttendanceRecord session;
  const _LocationMapSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final checkinPoint = LatLng(session.checkinLat!, session.checkinLng!);
    final checkoutPoint = session.checkoutLat != null
        ? LatLng(session.checkoutLat!, session.checkoutLng!)
        : null;

    // Center map between both points if both exist
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
          // ── Handle + header ───────────────────────────────────────────────
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
                // ── Legend ────────────────────────────────────────────────
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
          // ── Map ───────────────────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: checkoutPoint != null ? 14.0 : 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Check-in marker (green)
                      Marker(
                        point: checkinPoint,
                        width: 40,
                        height: 50,
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
                            // Pin tail
                            Container(width: 2, height: 8, color: _accent),
                          ],
                        ),
                      ),
                      // Check-out marker (red) — only if exists
                      if (checkoutPoint != null)
                        Marker(
                          point: checkoutPoint,
                          width: 40,
                          height: 50,
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
                  // Draw a line between checkin and checkout if both exist
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

class _LiveLocationMapSheet extends StatelessWidget {
  final GpsAttendanceRecord session;
  const _LiveLocationMapSheet({required this.session});

  String _fmtUpdatedAt(String? raw) {
    if (raw == null) return 'Unknown';
    try {
      final parts = raw.split(' ');
      if (parts.length < 2) return raw;
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      final dt = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      return DateFormat('hh:mm a, dd MMM').format(dt);
    } catch (_) {
      return raw.length >= 16 ? raw.substring(0, 16) : raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkinPoint = session.checkinLat != null
        ? LatLng(session.checkinLat!, session.checkinLng!)
        : null;
    final checkoutPoint = session.checkoutLat != null
        ? LatLng(session.checkoutLat!, session.checkoutLng!)
        : null;
    final livePoint = LatLng(session.lastKnownLat!, session.lastKnownLng!);
    const liveColor = Color(0xFFF59E0B);

    // Center on live point
    final allLats = [
      if (checkinPoint != null) checkinPoint.latitude,
      if (checkoutPoint != null) checkoutPoint.latitude,
      livePoint.latitude,
    ];
    final allLngs = [
      if (checkinPoint != null) checkinPoint.longitude,
      if (checkoutPoint != null) checkoutPoint.longitude,
      livePoint.longitude,
    ];
    final centerLat = allLats.reduce((a, b) => a + b) / allLats.length;
    final centerLng = allLngs.reduce((a, b) => a + b) / allLngs.length;
    final center = LatLng(centerLat, centerLng);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle + header ───────────────────────────────────────────────
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
                        color: liveColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: liveColor,
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
                          Text(
                            'Last known location · ${_fmtUpdatedAt(session.lastLocationUpdatedAt)}',
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
                // ── Legend ────────────────────────────────────────────────
                Row(
                  children: [
                    if (checkinPoint != null) ...[
                      _legendDot(_accent, 'Check-in'),
                      const SizedBox(width: 14),
                    ],
                    if (checkoutPoint != null) ...[
                      _legendDot(_red, 'Check-out'),
                      const SizedBox(width: 14),
                    ],
                    _legendDot(
                      liveColor,
                      'Live · ${_fmtUpdatedAt(session.lastLocationUpdatedAt)}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          // ── Map ───────────────────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 14.5),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  // Polyline connecting all points
                  PolylineLayer(
                    polylines: [
                      if (checkinPoint != null)
                        Polyline(
                          points: [
                            checkinPoint,
                            if (checkoutPoint != null) checkoutPoint,
                            livePoint,
                          ],
                          strokeWidth: 2.5,
                          color: _primary.withOpacity(0.4),
                          isDotted: true,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Check-in marker (green)
                      if (checkinPoint != null)
                        Marker(
                          point: checkinPoint,
                          width: 40,
                          height: 50,
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
                      // Check-out marker (red)
                      if (checkoutPoint != null)
                        Marker(
                          point: checkoutPoint,
                          width: 40,
                          height: 50,
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
                      // Live / last known marker (yellow) with time label
                      Marker(
                        point: livePoint,
                        width: 80,
                        height: 70,
                        child: Column(
                          children: [
                            // Time bubble above marker
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: liveColor,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: liveColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _fmtUpdatedAt(
                                  session.lastLocationUpdatedAt,
                                ).split(',').first,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: liveColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: liveColor.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: _textMid),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
