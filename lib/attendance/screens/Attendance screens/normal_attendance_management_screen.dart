import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'attendance_policy_screen.dart';
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

class NormalAttendanceRecord {
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
  final bool checkinFaceVerified;
  final bool checkoutFaceVerified;
  final String attendanceMode;
  final String? remarks;
  final String? gptCheckinNotes;
  final String? gptCheckoutNotes;

  NormalAttendanceRecord({
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
    required this.checkinFaceVerified,
    required this.checkoutFaceVerified,
    required this.attendanceMode,
    this.remarks,
    this.gptCheckinNotes,
    this.gptCheckoutNotes,
  });

  factory NormalAttendanceRecord.fromJson(Map<String, dynamic> j) =>
      NormalAttendanceRecord(
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
        checkinFaceVerified:
            (j['checkin_face_verified'] == 1 ||
            j['checkin_face_verified'] == true),
        checkoutFaceVerified:
            (j['checkout_face_verified'] == 1 ||
            j['checkout_face_verified'] == true),
        attendanceMode: j['attendance_mode'] ?? 'normal',
        remarks: j['remarks'],
        gptCheckinNotes: j['gpt_checkin_notes'],
        gptCheckoutNotes: j['gpt_checkout_notes'],
      );
}

class NormalAttendanceSummaryStats {
  final int totalEmployees, presentToday, absentToday, lateToday, activeNow;
  NormalAttendanceSummaryStats({
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

class NormalAttendanceManagementService {
  static const String _baseUrl = '${ApiConfig.baseUrl}/attendance';

  static Future<Map<String, dynamic>> fetchAllAttendance({
    required String authToken,
    required String tenantId,
    required String date,
    String status = '',
    String search = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/all').replace(
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
    throw Exception('Failed to load attendance data');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class NormalAttendanceManagementScreen extends StatefulWidget {
  final String authToken;
  final String tenantId;
  final bool canEdit;
  const NormalAttendanceManagementScreen({
    super.key,
    required this.authToken,
    required this.tenantId,
    this.canEdit = true,
  });
  @override
  State<NormalAttendanceManagementScreen> createState() =>
      _NormalAttendanceManagementScreenState();
}

class _NormalAttendanceManagementScreenState
    extends State<NormalAttendanceManagementScreen> {
  bool _loading = true;
  String? _error;
  List<NormalAttendanceRecord> _records = [];
  Map<int, List<NormalAttendanceRecord>> _groupedRecords = {};
  List<int> _employeeOrder = [];
  NormalAttendanceSummaryStats? _stats;

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
      final data = await NormalAttendanceManagementService.fetchAllAttendance(
        authToken: widget.authToken,
        tenantId: widget.tenantId,
        date: dateStr,
        status: _statusFilter,
        search: _searchQuery,
      );
      if (!mounted) return;

      final rawRecords = (data['records'] as List? ?? [])
          .map(
            (e) => NormalAttendanceRecord.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      // Group by employee
      final grouped = <int, List<NormalAttendanceRecord>>{};
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
        _stats = NormalAttendanceSummaryStats(
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
                    // Stats
                    SliverToBoxAdapter(child: _buildStats(s)),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
                    // Filters
                    SliverToBoxAdapter(child: _buildFilters(s)),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
                    // Count
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
                    // Empty
                    if (_employeeOrder.isEmpty)
                      SliverFillRemaining(child: _emptyState()),
                    // List
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
                            return _EmployeeCard(
                              sessions: sessions,
                              formatTime: _formatTime,
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
                        builder: (_) => AdminAttendanceReportScreen(
                          mode: 'normal', // pass 'gps' or 'gps_face' as needed
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
              if (widget.canEdit)
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
                            mode: 'normal',
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
          child: const Icon(
            Icons.fingerprint_rounded,
            size: 36,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No records found',
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
// Employee Card (expandable, matches reference UI style)
// ─────────────────────────────────────────────────────────────────────────────

class _EmployeeCard extends StatefulWidget {
  final List<NormalAttendanceRecord> sessions;
  final String Function(String?) formatTime;
  final _Screen s;

  const _EmployeeCard({
    required this.sessions,
    required this.formatTime,
    required this.s,
  });

  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard>
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

  // Helpers
  NormalAttendanceRecord get _latest => widget.sessions.first;
  NormalAttendanceRecord get _oldest => widget.sessions.last;
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
          // ── Header row ─────────────────────────────────────────────────────
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

                  // Chevron
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

          // ── Summary strip (always visible) ──────────────────────────────────
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

          // ── Expandable session list ──────────────────────────────────────────
          if (_isMulti) ...[
            // Toggle button
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

            // Session rows
            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1,
              child: Column(
                children: widget.sessions.asMap().entries.map((e) {
                  final idx = e.key;
                  final s = e.value;
                  final isLast = idx == widget.sessions.length - 1;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                    child: Row(
                      children: [
                        // Session number badge
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
                        // In block
                        _sessionTimeBlock(
                          Icons.login_rounded,
                          'In',
                          widget.formatTime(s.checkinTime),
                          _accent,
                          s.checkinFaceVerified,
                        ),
                        Container(
                          height: 32,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: _border,
                        ),
                        // Out block
                        _sessionTimeBlock(
                          Icons.logout_rounded,
                          'Out',
                          widget.formatTime(s.checkoutTime),
                          _primary,
                          s.checkoutFaceVerified,
                        ),
                        const Spacer(),
                        // Duration
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
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Remarks / notes ─────────────────────────────────────────────────
          if (_latest.remarks != null ||
              _latest.gptCheckinNotes != null ||
              _latest.gptCheckoutNotes != null)
            _NotesRow(record: _latest),
        ],
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500),
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
    bool verified,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: _textLight)),
          if (verified) ...[
            const SizedBox(width: 3),
            const Icon(Icons.verified_rounded, size: 11, color: _accent),
          ],
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

// ── Notes row ─────────────────────────────────────────────────────────────────

class _NotesRow extends StatefulWidget {
  final NormalAttendanceRecord record;
  const _NotesRow({required this.record});
  @override
  State<_NotesRow> createState() => _NotesRowState();
}

class _NotesRowState extends State<_NotesRow> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _show = !_show),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FF),
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notes_rounded, size: 13, color: _purple),
                const SizedBox(width: 5),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 12,
                    color: _purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _show
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _textLight,
                ),
              ],
            ),
            if (_show) ...[
              const SizedBox(height: 6),
              if (widget.record.remarks != null)
                Text(
                  'Remark: ${widget.record.remarks}',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              if (widget.record.gptCheckinNotes != null)
                Text(
                  'Check-in: ${widget.record.gptCheckinNotes}',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              if (widget.record.gptCheckoutNotes != null)
                Text(
                  'Check-out: ${widget.record.gptCheckoutNotes}',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
