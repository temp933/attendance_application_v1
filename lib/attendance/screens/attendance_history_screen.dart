import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AttendanceHistoryScreen  — fast single-call implementation
//  Uses GET /attendance/month-report/:empId?year=&month=
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceHistoryScreen extends StatefulWidget {
  final int employeeId;
  const AttendanceHistoryScreen({super.key, required this.employeeId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with SingleTickerProviderStateMixin {
  // ── Theme ─────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;

  // Parsed from API
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _days = [];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadMonth(_focusedMonth);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadMonth(DateTime month) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get(
        '/attendance/month-report/${widget.employeeId}'
        '?year=${month.year}&month=${month.month}',
      );
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Server error ${res.statusCode}';
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        setState(() {
          _loading = false;
          _error = body['message'] ?? 'Unknown error';
        });
        return;
      }

      final rawDays = (body['days'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        _summary = Map<String, dynamic>.from(body['summary'] ?? {});
        _days = rawDays;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  Map<String, dynamic>? _dayData(String dateStr) {
    for (final d in _days) {
      if (d['date'] == dateStr) return d;
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtTime(String? t) {
    if (t == null) return '--';
    try {
      final part = t.contains(' ') ? t.split(' ')[1] : t;
      return part.length >= 5 ? part.substring(0, 5) : part;
    } catch (_) {
      return '--';
    }
  }

  String _fmtMinutes(int m) {
    if (m == 0) return '--';
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '${h}h ${min.toString().padLeft(2, '0')}m' : '${min}m';
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fullDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  int get _presentDays => (_summary['present_days'] as num? ?? 0).toInt();
  int get _absentDays => (_summary['absent_days'] as num? ?? 0).toInt();
  int get _lateDays => (_summary['late_days'] as num? ?? 0).toInt();
  int get _leaveDays => (_summary['leave_days'] as num? ?? 0).toInt();
  int get _holidayDays => (_summary['holiday_days'] as num? ?? 0).toInt();
  int get _compoffDays => (_summary['compoff_days'] as num? ?? 0).toInt();
  int get _totalMinutes =>
      (_summary['total_on_site_minutes'] as num? ?? 0).toInt();
  int get _attendanceRate => (_summary['attendance_rate'] as num? ?? 0).toInt();
  int get _workingDays =>
      (_summary['working_days_in_month'] as num? ?? 0).toInt();

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: success ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Maps ──────────────────────────────────────────────────────────────────

  Future<void> _openSiteInMaps(int? siteId, String siteName) async {
    double? lat, lng;
    if (siteId != null) {
      try {
        final res = await ApiClient.get('/sites/$siteId/location');
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true) {
            lat = (body['lat'] as num?)?.toDouble();
            lng = (body['lng'] as num?)?.toDouble();
          }
        }
      } catch (_) {}
    }
    final Uri uri = lat != null && lng != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
            '&query_place_id=${Uri.encodeComponent(siteName)}',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1'
            '&query=${Uri.encodeComponent(siteName)}',
          );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showSnack('Could not open maps');
    }
  }

  // ── Day tap ───────────────────────────────────────────────────────────────

  void _onDayTap(Map<String, dynamic> dayData) {
    final status = dayData['status'] as String? ?? 'absent';
    final day = DateTime.parse(dayData['date'] as String);

    if (status == 'future') return;

    if (status == 'absent' || status == 'weekend') {
      showDialog(
        context: context,
        builder: (_) => _buildAbsentDialog(day, status),
      );
      return;
    }

    if (status == 'holiday') {
      showDialog(
        context: context,
        builder: (_) => _buildSpecialDayDialog(
          day,
          title: 'Public Holiday',
          subtitle: dayData['holiday']?['holiday_name'] as String? ?? 'Holiday',
          icon: Icons.celebration_rounded,
          color: _purple,
        ),
      );
      return;
    }

    if (status == 'leave') {
      final leave = dayData['leave'] as Map<String, dynamic>?;
      showDialog(
        context: context,
        builder: (_) => _buildSpecialDayDialog(
          day,
          title: 'On Leave',
          subtitle: leave?['leave_type'] as String? ?? 'Leave',
          icon: Icons.beach_access_rounded,
          color: _blue,
        ),
      );
      return;
    }

    // present / late — show sessions
    final sessions = (dayData['sessions'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final totalMin = (dayData['total_minutes'] as num? ?? 0).toInt();
    final isLate = dayData['is_late'] == true;
    final lateText = dayData['late_text'] as String?;

    showDialog(
      context: context,
      builder: (_) =>
          _buildDetailDialog(day, sessions, totalMin, isLate, lateText),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: () => _loadMonth(_focusedMonth),
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildAppBar()),
                  SliverToBoxAdapter(child: _buildSummaryBar()),
                  SliverToBoxAdapter(child: _buildStatCards()),
                  SliverToBoxAdapter(child: _buildMonthNav()),
                  SliverToBoxAdapter(child: _buildCalendarHeader()),
                  SliverToBoxAdapter(child: _buildWeekdayHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildCalendarGrid(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildLegend()),
                  SliverToBoxAdapter(child: _buildDaysList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _textMid)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _loadMonth(_focusedMonth),
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        4,
        12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Attendance History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_attendanceRate%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: () => _loadMonth(_focusedMonth),
          ),
        ],
      ),
    );
  }

  // ── Summary bar ───────────────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            _statItem('$_presentDays', 'Present', Colors.white),
            _vDiv(),
            _statItem('$_absentDays', 'Absent', const Color(0xFFFCA5A5)),
            _vDiv(),
            _statItem('$_lateDays', 'Late', const Color(0xFFFDE68A)),
            _vDiv(),
            _statItem(
              _fmtMinutes(_totalMinutes),
              'On-Site',
              const Color(0xFF6EE7B7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: c.withValues(alpha: 0.75),
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _vDiv() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.2),
  );

  // ── Stat cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final worked = _presentDays + _absentDays;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _statCard(
                '$_leaveDays',
                'Leave Days',
                _blue,
                Icons.beach_access_rounded,
              ),
              const SizedBox(width: 10),
              _statCard(
                '$_holidayDays',
                'Holidays',
                _purple,
                Icons.celebration_rounded,
              ),
              const SizedBox(width: 10),
              _statCard(
                '$_compoffDays',
                'Comp-Off\nWorked',
                _amber,
                Icons.swap_horiz_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monthly Attendance Rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMid,
                      ),
                    ),
                    Text(
                      '$_presentDays / $worked working days',
                      style: const TextStyle(fontSize: 11, color: _textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: worked > 0 ? _presentDays / worked : 0,
                    backgroundColor: _red.withValues(alpha: 0.12),
                    color: _attendanceRate >= 90
                        ? _accent
                        : _attendanceRate >= 75
                        ? _orange
                        : _red,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _progressLegend(_accent, 'Present: $_presentDays'),
                    _progressLegend(_red, 'Absent: $_absentDays'),
                    _progressLegend(_orange, 'Late: $_lateDays'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLegend(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: _textMid)),
    ],
  );

  Widget _statCard(String val, String label, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                val,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: _textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  // ── Month navigator ───────────────────────────────────────────────────────

  Widget _buildMonthNav() {
    final now = DateTime.now();
    final canGoNext = !DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
    ).isAfter(DateTime(now.year, now.month));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          _navBtn(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              final prev = DateTime(
                _focusedMonth.year,
                _focusedMonth.month - 1,
              );
              setState(() {
                _focusedMonth = prev;
                _days = [];
                _summary = {};
              });
              _loadMonth(prev);
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                _monthLabel(_focusedMonth),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          _navBtn(
            icon: Icons.chevron_right_rounded,
            disabled: !canGoNext,
            onTap: canGoNext
                ? () {
                    final next = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    );
                    setState(() {
                      _focusedMonth = next;
                      _days = [];
                      _summary = {};
                    });
                    _loadMonth(next);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    VoidCallback? onTap,
    bool disabled = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Icon(icon, size: 20, color: disabled ? _textLight : _primary),
    ),
  );

  // ── Calendar header ───────────────────────────────────────────────────────

  Widget _buildCalendarHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.calendar_month_rounded,
            color: _primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Monthly Calendar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
      ],
    ),
  );

  // ── Weekday header ────────────────────────────────────────────────────────

  Widget _buildWeekdayHeader() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map(
              (d) => Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: d == 'Sun'
                        ? _red.withValues(alpha: 0.7)
                        : _textLight,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────────────

  Widget _buildCalendarGrid() {
    if (_days.isEmpty) return const SizedBox();

    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startOff = (firstDay.weekday - 1) % 7;
    final daysInMon = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final totalCells = startOff + daysInMon;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 5,
        childAspectRatio: 0.70,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, index) {
        final dayNum = index - startOff + 1;
        if (dayNum < 1 || dayNum > daysInMon) return const SizedBox();
        final day = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
        final dateStr = _fmtDate(day);
        final data = _dayData(dateStr);
        if (data == null) return const SizedBox();
        return _buildDayCell(data);
      },
    );
  }

  // ── Day cell ──────────────────────────────────────────────────────────────

  Widget _buildDayCell(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'future';
    final dayNum = data['day'] as int? ?? 0;
    final isToday = data['is_today'] == true;
    final isSunday = data['is_sunday'] == true;
    final isFuture = data['is_future'] == true;
    final totalMin = (data['total_minutes'] as num? ?? 0).toInt();
    final isLate = data['is_late'] == true;
    final holiday = data['holiday'] as Map<String, dynamic>?;
    final leave = data['leave'] as Map<String, dynamic>?;
    final hasCompoff = data['compoff'] != null;

    Color bgColor = Colors.white, borderColor = _border;
    switch (status) {
      case 'present':
        bgColor = _accent.withValues(alpha: 0.06);
        borderColor = _accent.withValues(alpha: 0.3);
        break;
      case 'late':
        bgColor = _orange.withValues(alpha: 0.06);
        borderColor = _orange.withValues(alpha: 0.3);
        break;
      case 'absent':
        bgColor = _red.withValues(alpha: 0.04);
        borderColor = _red.withValues(alpha: 0.2);
        break;
      case 'holiday':
        bgColor = _purple.withValues(alpha: 0.05);
        borderColor = _purple.withValues(alpha: 0.25);
        break;
      case 'leave':
        bgColor = _blue.withValues(alpha: 0.05);
        borderColor = _blue.withValues(alpha: 0.25);
        break;
      case 'weekend':
        bgColor = const Color(0xFFF8FAFC);
        borderColor = Colors.transparent;
        break;
      case 'future':
        bgColor = const Color(0xFFF8FAFC);
        borderColor = Colors.transparent;
        break;
      case 'compoff':
        bgColor = _amber.withValues(alpha: 0.06);
        borderColor = _amber.withValues(alpha: 0.25);
        break;
    }
    if (isToday) {
      bgColor = _primary.withValues(alpha: 0.06);
      borderColor = _primary;
    }

    final dayNumColor = isFuture
        ? _textLight
        : isSunday
        ? _red.withValues(alpha: 0.8)
        : isToday
        ? _primary
        : _textDark;

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTap(data),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isToday ? 1.5 : 1),
          boxShadow: (status == 'present' || status == 'late') && !isFuture
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Container(
              width: 22,
              height: 22,
              decoration: isToday
                  ? const BoxDecoration(color: _primary, shape: BoxShape.circle)
                  : null,
              child: Center(
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isToday ? Colors.white : dayNumColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Content by status
            if (status == 'present' || status == 'late') ...[
              Text(
                _fmtMinutes(totalMin),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isLate ? _orange : _accent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              if (isLate)
                _miniTag('Late', _orange)
              else
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (hasCompoff) ...[
                const SizedBox(height: 2),
                _miniTag('CO', _amber),
              ],
            ] else if (status == 'absent') ...[
              Text(
                'Abs',
                style: TextStyle(
                  fontSize: 8,
                  color: _red.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ] else if (status == 'holiday') ...[
              _miniTag('Holi', _purple),
            ] else if (status == 'leave') ...[
              _miniTag('Leave', _blue),
            ] else if (status == 'compoff') ...[
              _miniTag('CO', _amber),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 7,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem(_accent.withValues(alpha: 0.1), _accent, 'Present'),
              _legendItem(
                _red.withValues(alpha: 0.06),
                _red.withValues(alpha: 0.4),
                'Absent',
              ),
              _legendItem(_primary.withValues(alpha: 0.06), _primary, 'Today'),
              _legendItem(
                _orange.withValues(alpha: 0.08),
                _orange.withValues(alpha: 0.5),
                'Late',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendBadge(_blue, 'Leave'),
              _legendBadge(_purple, 'Holiday'),
              _legendBadge(_amber, 'Comp-Off'),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _legendBadge(Color color, String label) => Expanded(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label == 'Comp-Off' ? 'CO' : label.substring(0, 4),
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _legendItem(Color bg, Color border, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.2),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _textMid,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  // ── Days list (detailed report below calendar) ────────────────────────────

  Widget _buildDaysList() {
    // Only show worked days with sessions
    final workedDays = _days.where((d) {
      final status = d['status'] as String? ?? '';
      return status == 'present' || status == 'late';
    }).toList();

    if (workedDays.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [const SizedBox(width: 10)]),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(Map<String, dynamic> data) {
    final dateStr = data['date'] as String;
    final day = DateTime.parse(dateStr);
    final isLate = data['is_late'] == true;
    final lateText = data['late_text'] as String?;
    final totalMin = (data['total_minutes'] as num? ?? 0).toInt();
    final sessions = (data['sessions'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final firstIn = data['first_in'] as String?;
    final lastOut = data['last_out'] as String?;

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dayLabel =
        '${days[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';

    return GestureDetector(
      onTap: () => _onDayTap(data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLate
                ? _orange.withValues(alpha: 0.3)
                : _accent.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: isLate ? _orange : _accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Date badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: (isLate ? _orange : _accent).withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isLate ? _orange : _accent,
                              ),
                            ),
                            Text(
                              months[day.month - 1],
                              style: const TextStyle(
                                fontSize: 9,
                                color: _textMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  dayLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isLate ? _orange : _accent)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _fmtMinutes(totalMin),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isLate ? _orange : _accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                if (firstIn != null) ...[
                                  _timeChip(
                                    Icons.login_rounded,
                                    _fmtTime(firstIn),
                                    _accent,
                                  ),
                                  const SizedBox(width: 6),
                                  if (lastOut != null) ...[
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 11,
                                      color: _textLight,
                                    ),
                                    const SizedBox(width: 6),
                                    _timeChip(
                                      Icons.logout_rounded,
                                      _fmtTime(lastOut),
                                      _red,
                                    ),
                                  ],
                                ],
                                const Spacer(),
                                if (isLate && lateText != null)
                                  _miniTag('Late $lateText', _orange)
                                else
                                  _miniTag('On Time', _accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (sessions.length > 1) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.layers_rounded,
                          size: 13,
                          color: _textLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${sessions.length} sessions',
                          style: const TextStyle(fontSize: 11, color: _textMid),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _textLight,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(IconData icon, String time, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Widget _buildAbsentDialog(DateTime day, String status) {
    final isSunday = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    final isWeekend = isSunday || isSat;
    final color = isWeekend ? _textLight : _red;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWeekend ? Icons.weekend_rounded : Icons.event_busy_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSunday
                      ? 'Weekly Off'
                      : isSat
                      ? 'Weekend'
                      : 'No Attendance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fullDate(day),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textMid,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(
              isWeekend ? Icons.info_outline_rounded : Icons.cancel_outlined,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isWeekend
                    ? '${isSunday ? 'Sunday' : 'Saturday'} — weekly off day.'
                    : 'No attendance recorded for this day.',
                style: const TextStyle(fontSize: 13, color: _textMid),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: const Text(
            'Close',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialDayDialog(
    DateTime day, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fullDate(day),
                  style: const TextStyle(fontSize: 11, color: _textMid),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          child: const Text(
            'Close',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDialog(
    DateTime day,
    List<Map<String, dynamic>> sessions,
    int totalMin,
    bool isLate,
    String? lateText,
  ) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            decoration: const BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isLate
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullDate(day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (isLate && lateText != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Late by $lateText',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          _dialogChip(
                            icon: Icons.timelapse_rounded,
                            label: _fmtMinutes(totalMin),
                          ),
                          const SizedBox(width: 6),
                          _dialogChip(
                            icon: Icons.layers_rounded,
                            label:
                                '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sessions list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: sessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _textLight.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.inbox_rounded,
                            color: _textLight,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No session data available.',
                          style: TextStyle(color: _textMid, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(14),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, si) {
                      final sess = sessions[si];
                      final visits = (sess['visits'] as List? ?? [])
                          .cast<Map<String, dynamic>>();
                      final sessMin = (sess['site_minutes'] as num? ?? 0)
                          .toInt();
                      final sessNum = sess['session_number'] ?? (si + 1);
                      final sessLate = sess['is_late'] == true;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sessLate
                                ? _orange.withValues(alpha: 0.3)
                                : _border,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 3,
                              color: sessLate ? _orange : _accent,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _primary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'S$sessNum',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _timeTag(
                                              icon: Icons.login_rounded,
                                              time: _fmtTime(
                                                sess['started_at']?.toString(),
                                              ),
                                              color: _accent,
                                              bg: _accent.withValues(
                                                alpha: 0.08,
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 5,
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 12,
                                                color: _textLight,
                                              ),
                                            ),
                                            _timeTag(
                                              icon: Icons.logout_rounded,
                                              time: sess['ended_at'] != null
                                                  ? _fmtTime(
                                                      sess['ended_at']
                                                          .toString(),
                                                    )
                                                  : 'Active',
                                              color: sess['ended_at'] != null
                                                  ? _red
                                                  : _orange,
                                              bg: sess['ended_at'] != null
                                                  ? _red.withValues(alpha: 0.08)
                                                  : _orange.withValues(
                                                      alpha: 0.08,
                                                    ),
                                            ),
                                          ],
                                        ),
                                        if (sessLate &&
                                            sess['late_text'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              // const Icon(
                                              //   Icons.schedule_rounded,
                                              //   size: 11,
                                              //   color: _orange,
                                              // ),
                                              // const SizedBox(width: 3),
                                              // Text(
                                              //   'Late: ${sess['late_text']}',
                                              //   style: const TextStyle(
                                              //     fontSize: 10,
                                              //     color: _orange,
                                              //     fontWeight: FontWeight.w600,
                                              //   ),
                                              // ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sessLate
                                          ? _orange.withValues(alpha: 0.08)
                                          : _accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _fmtMinutes(sessMin),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sessLate ? _orange : _accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: Colors.grey.shade100),
                            if (visits.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'No site visits in this session.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textMid,
                                  ),
                                ),
                              )
                            else
                              ...visits.asMap().entries.map((e) {
                                final v = e.value;
                                final isOpen = v['out_time'] == null;
                                final vMin =
                                    (v['worked_minutes'] as num?)?.toInt() ?? 0;
                                final sName =
                                    v['site_name'] as String? ?? 'Unknown';
                                final siteId = v['site_id'] as int?;
                                final isLast = e.key == visits.length - 1;

                                return InkWell(
                                  onTap: () => _openSiteInMaps(siteId, sName),
                                  borderRadius: isLast
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(14),
                                        )
                                      : BorderRadius.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? _accent.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(color: _border),
                                          ),
                                          child: Icon(
                                            isOpen
                                                ? Icons.location_on_rounded
                                                : Icons
                                                      .check_circle_outline_rounded,
                                            size: 18,
                                            color: isOpen
                                                ? _accent
                                                : _textLight,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      sName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                        color: _textDark,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 11,
                                                    color: _textLight,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 5,
                                                runSpacing: 3,
                                                children: [
                                                  _timeTag(
                                                    icon: Icons.login_rounded,
                                                    time: _fmtTime(
                                                      v['in_time']?.toString(),
                                                    ),
                                                    color: _accent,
                                                    bg: _accent.withValues(
                                                      alpha: 0.08,
                                                    ),
                                                  ),
                                                  _timeTag(
                                                    icon: Icons.logout_rounded,
                                                    time: isOpen
                                                        ? 'Active'
                                                        : _fmtTime(
                                                            v['out_time']
                                                                ?.toString(),
                                                          ),
                                                    color: isOpen
                                                        ? _orange
                                                        : _red,
                                                    bg: isOpen
                                                        ? _orange.withValues(
                                                            alpha: 0.08,
                                                          )
                                                        : _red.withValues(
                                                            alpha: 0.08,
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? _accent.withValues(
                                                    alpha: 0.08,
                                                  )
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            _fmtMinutes(vMin),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isOpen
                                                  ? _accent
                                                  : _textMid,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary.withValues(alpha: 0.08),
                  foregroundColor: _primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogChip({required IconData icon, required String label}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _timeTag({
    required IconData icon,
    required String time,
    required Color color,
    required Color bg,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
