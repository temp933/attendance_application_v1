import 'package:flutter/material.dart';
import '../../common/utils/greeting_util.dart';
import '../services/employee_service.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
const _surface = Color(0xFFF4F5F9);
const _card = Colors.white;
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF64748B);
const _textLight = Color(0xFF94A3B8);
const _border = Color(0xFFE8EAF0);

// Semantic
const _green = Color(0xFF0A7A50);
const _greenBg = Color(0xFFE6F9F2);
const _amber = Color(0xFF92520A);
const _amberBg = Color(0xFFFEF3E2);
const _amberBdr = Color(0xFFF5D99A);
const _indigo = Color(0xFF3730A3);
const _indigoBg = Color(0xFFEEF2FF);
const _indigoBdr = Color(0xFFC7D2FE);
const _teal = Color(0xFF0F6E56);
const _tealBg = Color(0xFFE1F5EE);
const _tealBdr = Color(0xFF6EE7C0);
const _pink = Color(0xFF86186A);
const _pinkBg = Color(0xFFFDF2F8);
const _pinkBdr = Color(0xFFF0ABD9);
const _red = Color(0xFFA32D2D);
const _redBg = Color(0xFFFCEBEB);

// ── Status dot + text colour ──────────────────────────────────────────────────
Color _statusDot(String? s) {
  switch (s?.toLowerCase()) {
    case 'present':
      return _green;
    case 'late entry':
      return _amber;
    case 'on leave':
      return _indigo;
    case 'absent':
      return _red;
    default:
      return _textLight;
  }
}

String _statusLabel(String? s) {
  switch (s?.toLowerCase()) {
    case 'present':
      return 'Checked in';
    case 'late entry':
      return 'Checked in · late';
    case 'on leave':
      return 'On approved leave';
    case 'absent':
      return 'Not checked in';
    default:
      return 'Not marked';
  }
}

String _statusSub(String? s, String? checkIn) {
  switch (s?.toLowerCase()) {
    case 'present':
    case 'late entry':
      return checkIn != null
          ? 'Since $checkIn · active session'
          : 'Active session';
    case 'on leave':
      return 'Leave approved';
    case 'absent':
      return 'No attendance recorded today';
    default:
      return '';
  }
}

// ── Flag config ───────────────────────────────────────────────────────────────
class _FlagStyle {
  final Color bg, text, border;
  final IconData icon;
  const _FlagStyle(this.bg, this.text, this.border, this.icon);
}

_FlagStyle _flagStyle(String type) {
  switch (type) {
    case 'holiday':
      return const _FlagStyle(
        _amberBg,
        _amber,
        _amberBdr,
        Icons.wb_sunny_outlined,
      );
    case 'onleave':
      return const _FlagStyle(
        _indigoBg,
        _indigo,
        _indigoBdr,
        Icons.beach_access_outlined,
      );
    case 'compoff':
      return const _FlagStyle(
        _tealBg,
        _teal,
        _tealBdr,
        Icons.schedule_outlined,
      );
    case 'halfday':
      return const _FlagStyle(
        _pinkBg,
        _pink,
        _pinkBdr,
        Icons.timelapse_outlined,
      );
    default:
      return const _FlagStyle(
        _indigoBg,
        _indigo,
        _indigoBdr,
        Icons.info_outline,
      );
  }
}

// ── Initials from full name ───────────────────────────────────────────────────
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
}

// ── Date label ────────────────────────────────────────────────────────────────
String _todayLabel() {
  final now = DateTime.now();
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
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
}

// ── Upcoming leave date range label ──────────────────────────────────────────
String _dateRangeLabel(String start, String end) {
  DateTime s, e;
  try {
    s = DateTime.parse(start);
    e = DateTime.parse(end);
  } catch (_) {
    return '$start – $end';
  }
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
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final sd = '${days[s.weekday - 1]}, ${s.day} ${months[s.month - 1]}';
  final ed = '${days[e.weekday - 1]}, ${e.day} ${months[e.month - 1]}';
  return s == e ? sd : '$sd – $ed';
}

String _daysUntilLabel(int n) {
  if (n == 0) return 'today';
  if (n == 1) return 'tomorrow';
  return 'in $n days';
}

// ═════════════════════════════════════════════════════════════════════════════
class UserHomeScreen extends StatefulWidget {
  final String employeeId;
  final void Function(int index)? onNavigate;

  const UserHomeScreen({super.key, required this.employeeId, this.onNavigate});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String _empName = '';
  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _attendanceStatus;
  String? _checkIn;
  String? _checkOut;

  List<Map<String, dynamic>> _todayFlags = [];
  int _pendingLeave = 0;
  Map<String, dynamic>? _upcomingLeave;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll({bool isRefresh = false}) async {
    if (isRefresh) setState(() => _isRefreshing = true);
    try {
      final results = await Future.wait([
        EmployeeService.fetchEmployeeName(int.parse(widget.employeeId)),
        EmployeeService.fetchUserDashboard(widget.employeeId),
      ]);
      final name = results[0] as String;
      final dash = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _empName = name;
        _attendanceStatus = dash['attendanceStatus'];
        _checkIn = dash['checkIn'];
        _checkOut = dash['checkOut'];
        _todayFlags = List<Map<String, dynamic>>.from(dash['todayFlags'] ?? []);
        _pendingLeave = (dash['pendingLeaveCount'] as num?)?.toInt() ?? 0;
        _upcomingLeave = dash['upcomingLeave'] as Map<String, dynamic>?;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('UserHome error: $e');
      if (!mounted) return;
      setState(() {
        _empName = _empName.isEmpty ? 'there' : _empName;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1A56DB),
                  strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF1A56DB),
                onRefresh: () => _fetchAll(isRefresh: true),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildHeroCard()),
                    if (_todayFlags.isNotEmpty)
                      SliverToBoxAdapter(child: _buildTodayFlags()),
                    SliverToBoxAdapter(child: _buildPendingSection()),
                    if (_upcomingLeave != null)
                      SliverToBoxAdapter(child: _buildUpcomingLeave()),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getGreeting(),
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
                const SizedBox(height: 2),
                Text(
                  _empName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        
        ],
      ),
    );
  }

  // ── Hero attendance card ────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final dot = _statusDot(_attendanceStatus);
    final label = _statusLabel(_attendanceStatus);
    final sub = _statusSub(_attendanceStatus, _checkIn);
    final hasCheckedOut = _checkOut != null;
    final checkedIn =
        _attendanceStatus?.toLowerCase() == 'present' ||
        _attendanceStatus?.toLowerCase() == 'late entry';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today · ${_todayLabel()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textLight,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text(
                        sub,
                        style: const TextStyle(fontSize: 13, color: _textMid),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Check-in / Check-out row (only when relevant)
            if (checkedIn) ...[
              const Divider(height: 1, thickness: 0.5, color: _border),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _MetaCell(label: 'Check-in', value: _checkIn ?? '--:--'),
                    const VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: _border,
                    ),
                    _MetaCell(
                      label: 'Check-out',
                      value: hasCheckedOut ? _checkOut! : '—',
                      dimmed: !hasCheckedOut,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Today's status flags ────────────────────────────────────────────────────
  Widget _buildTodayFlags() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "TODAY'S STATUS",
              style: TextStyle(
                fontSize: 11,
                color: _textLight,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _todayFlags.map((f) {
              final type = f['type']?.toString() ?? '';
              final lbl = f['label']?.toString() ?? '';
              final style = _flagStyle(type);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: style.border, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 14, color: style.text),
                    const SizedBox(width: 6),
                    Text(
                      lbl,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: style.text,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Pending requests ────────────────────────────────────────────────────────
  Widget _buildPendingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "PENDING REQUESTS",
              style: TextStyle(
                fontSize: 11,
                color: _textLight,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => widget.onNavigate?.call(2),
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: _textMid,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Leave requests',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _pendingLeave == 0
                              ? 'No pending requests'
                              : '$_pendingLeave awaiting approval',
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  if (_pendingLeave > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _indigoBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_pendingLeave',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _indigo,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _textLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming leave ──────────────────────────────────────────────────────────
  Widget _buildUpcomingLeave() {
    final u = _upcomingLeave!;
    final name = u['leaveName']?.toString() ?? 'Leave';
    final days = (u['numberOfDays'] as num?)?.toDouble() ?? 0;
    final daysUntil = (u['daysUntil'] as num?)?.toInt() ?? 0;
    final start = u['startDate']?.toString() ?? '';
    final end = u['endDate']?.toString() ?? '';
    final daysLabel = days == days.truncate()
        ? '${days.toInt()} day${days.toInt() == 1 ? '' : 's'}'
        : '${days} days';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              "UPCOMING LEAVE",
              style: TextStyle(
                fontSize: 11,
                color: _textLight,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _indigoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_outlined,
                    size: 18,
                    color: _indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name · $daysLabel',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateRangeLabel(start, end),
                        style: const TextStyle(fontSize: 12, color: _textMid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _indigoBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _daysUntilLabel(daysUntil),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _indigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  final bool dimmed;
  const _MetaCell({
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: _textLight),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: dimmed ? _textLight : _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
