import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/api_client.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final String mode; // 'normal' | 'gps' | 'gps_face' | '' (all)

  const AttendanceHistoryScreen({super.key, this.mode = ''});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _teal = Color(0xFF0F766E);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF5F6FA);

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  /// Attendance records grouped by "YYYY-MM-DD"
  Map<String, List<Map<String, dynamic>>> _byDate = {};

  /// Holidays: Set of "YYYY-MM-DD" → holiday name
  Map<String, String> _holidays = {};

  /// Leaves: "YYYY-MM-DD" → list of leave records that cover that date
  Map<String, List<Map<String, dynamic>>> _leavesByDate = {};

  /// Comp-offs: Set of earned_date "YYYY-MM-DD"
  Set<String> _compOffDates = {};

  /// Weekoff flags read from attendance_policy
  bool _isSatWeekoff = false;
  bool _isSunWeekoff = true; // sensible default until policy loads

  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final year = DateTime.now().year;

      final modeParam = widget.mode.isNotEmpty ? '&mode=${widget.mode}' : '';
      debugPrint(
        '>>> AttendanceHistory mode: "${widget.mode}" | modeParam: "$modeParam"',
      );

      final results = await Future.wait([
        ApiClient.get('/attendance/history?limit=100&offset=0$modeParam'),
        ApiClient.get('/holidays?year=$year'),
        ApiClient.get('/leave/my-leaves?year=$year'),
        ApiClient.get('/comp-off?status=earned'),
        ApiClient.get('/attendance/policy'),
      ]);

      if (!mounted) return;

      // ── Attendance ────────────────────────────────────────────────────────
      final attRes = results[0];
      if (attRes.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Attendance error ${attRes.statusCode}';
        });
        return;
      }
      final attBody = jsonDecode(attRes.body) as Map<String, dynamic>;
      if (attBody['success'] != true) {
        setState(() {
          _loading = false;
          _error = attBody['message'] ?? 'Unknown error';
        });
        return;
      }
      final records = (attBody['records'] as List).cast<Map<String, dynamic>>();
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final r in records) {
        final key = (r['work_date'] as String? ?? '').substring(0, 10);
        grouped.putIfAbsent(key, () => []).add(r);
      }

      // ── Holidays ──────────────────────────────────────────────────────────
      final holRes = results[1];
      final holidays = <String, String>{};
      if (holRes.statusCode == 200) {
        final holBody = jsonDecode(holRes.body) as Map<String, dynamic>;
        if (holBody['success'] == true) {
          for (final h in (holBody['data'] as List)) {
            final dateStr = (h['holiday_date'] as String? ?? '').substring(
              0,
              10,
            );
            holidays[dateStr] = h['holiday_name'] as String? ?? 'Holiday';
          }
        }
      }

      // ── My Leaves ─────────────────────────────────────────────────────────
      final leaveRes = results[2];
      final leavesByDate = <String, List<Map<String, dynamic>>>{};
      if (leaveRes.statusCode == 200) {
        final leaveBody = jsonDecode(leaveRes.body) as Map<String, dynamic>;
        if (leaveBody['ok'] == true || leaveBody['success'] == true) {
          final leaveList = (leaveBody['data'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          for (final lv in leaveList) {
            final status = lv['final_status'] as String? ?? '';
            if (status == 'Cancelled' || status == 'Rejected') continue;
            final startStr = (lv['leave_start_date'] as String? ?? '')
                .substring(0, 10);
            final endStr = (lv['leave_end_date'] as String? ?? '').substring(
              0,
              10,
            );
            DateTime? start, end;
            try {
              start = DateTime.parse(startStr);
              end = DateTime.parse(endStr);
            } catch (_) {
              continue;
            }
            // Expand every day in the leave range
            for (
              DateTime d = start;
              !d.isAfter(end);
              d = d.add(const Duration(days: 1))
            ) {
              final k = DateFormat('yyyy-MM-dd').format(d);
              leavesByDate.putIfAbsent(k, () => []).add(lv);
            }
          }
        }
      }

      // ── Comp-offs ─────────────────────────────────────────────────────────
      final compRes = results[3];
      final compOffDates = <String>{};
      if (compRes.statusCode == 200) {
        final compBody = jsonDecode(compRes.body) as Map<String, dynamic>;
        if (compBody['success'] == true) {
          for (final c in (compBody['records'] as List? ?? [])) {
            final d = (c['earned_date'] as String? ?? '').substring(0, 10);
            if (d.isNotEmpty) compOffDates.add(d);
          }
        }
      }
      // ── Attendance policy (weekoffs) ───────────────────────────────────────
      final policyRes = results[4];
      bool isSatWeekoff = false;
      bool isSunWeekoff = true; // default
      if (policyRes.statusCode == 200) {
        final policyBody = jsonDecode(policyRes.body) as Map<String, dynamic>;
        if (policyBody['success'] == true) {
          final p = policyBody['policy'] as Map<String, dynamic>?;
          if (p != null) {
            isSatWeekoff = (p['is_saturday_weekoff'] as num?)?.toInt() == 1;
            isSunWeekoff = (p['is_sunday_weekoff'] as num?)?.toInt() == 1;
          }
        }
      }

      setState(() {
        _byDate = grouped;
        _holidays = holidays;
        _leavesByDate = leavesByDate;
        _compOffDates = compOffDates;
        _isSatWeekoff = isSatWeekoff;
        _isSunWeekoff = isSunWeekoff;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtTime(String? raw) {
    if (raw == null) return '--';
    try {
      final part = raw.contains(' ') ? raw.split(' ')[1] : raw;
      final segs = part.split(':');
      int h = int.parse(segs[0]);
      final m = segs[1];
      final s = segs.length > 2 ? segs[2] : '00';
      final suffix = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:$m:$s $suffix';
    } catch (_) {
      return '--';
    }
  }

  String _fmtDuration(String? raw) {
    if (raw == null) return '--';
    try {
      final parts = raw.split(':').map(int.parse).toList();
      final h = parts[0];
      final m = parts.length > 1 ? parts[1] : 0;
      final s = parts.length > 2 ? parts[2] : 0;
      if (h == 0 && m == 0 && s == 0) return '--';
      if (h == 0 && m == 0) return '${s}s';
      if (h == 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    } catch (_) {
      return '--';
    }
  }

  String _fmtLate(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final str = h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
    return '$str late';
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  /// Returns true if this date is a configured weekoff day (Sat or Sun).
  bool _isWeekoff(DateTime d) {
    if (d.weekday == DateTime.saturday && _isSatWeekoff) return true;
    if (d.weekday == DateTime.sunday && _isSunWeekoff) return true;
    return false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    color: _primary,
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (widget.mode.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _modeLabel(widget.mode),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: _load,
        ),
      ],
    ),
  );

  String _modeLabel(String mode) => switch (mode) {
    'normal' => 'Standard check-in',
    'gps' => 'GPS check-in',
    'gps_face' => 'GPS + Face check-in',
    _ => mode,
  };

  Widget _buildBody() {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _primary));
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _red, size: 44),
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: _textMid, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      );
    }
    return Column(children: [_buildCalendar(), _buildLegend()]);
  }
  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _buildLegend() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Row(
      children: [
        _legendItem('H', _red, 'Holiday'),
        const SizedBox(width: 12),
        _legendItem('L', _purple, 'Leave'),
        const SizedBox(width: 12),
        _legendItem('C', _teal, 'Comp-off'),
        const SizedBox(width: 12),
        _legendItem('W', _textMid, 'Weekoff'),
        const SizedBox(width: 12),
        // dot legend
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('Present', style: TextStyle(fontSize: 10, color: _textMid)),
          ],
        ),
        const SizedBox(width: 10),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('Late', style: TextStyle(fontSize: 10, color: _textMid)),
          ],
        ),
      ],
    ),
  );

  Widget _legendItem(String label, Color color, String desc) => Row(
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text(desc, style: TextStyle(fontSize: 10, color: _textMid)),
    ],
  );

  // ── Calendar ──────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        children: [
          _buildMonthNavRow(),
          const SizedBox(height: 10),
          _buildWeekdayLabels(),
          const SizedBox(height: 4),
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthNavRow() {
    return Row(
      children: [
        _navButton(Icons.chevron_left_rounded, () {
          setState(() {
            _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
            _selectedDay = null;
          });
        }),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_viewMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
        ),
        _navButton(Icons.chevron_right_rounded, () {
          setState(() {
            _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
            _selectedDay = null;
          });
        }),
      ],
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: _textMid),
    ),
  );

  Widget _buildWeekdayLabels() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: List.generate(days.length, (i) {
        // col 0 = Sunday, col 6 = Saturday
        final isWOCol = (i == 0 && _isSunWeekoff) || (i == 6 && _isSatWeekoff);
        return Expanded(
          child: Text(
            days[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isWOCol ? _textMid : _textLight,
            ),
          ),
        );
      }),
    );
  }

  void _showDayDetail(DateTime date) {
    final key = _dateKey(date);
    final recs = _byDate[key];
    final dayLabel = DateFormat('EEEE, d MMMM yyyy').format(date);
    final holidayName = _holidays[key];
    final leaves = _leavesByDate[key];
    final hasCompOff = _compOffDates.contains(key);
    final isWeekoff = _isWeekoff(date);
    final showWeekoffBanner = isWeekoff && holidayName == null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textMid,
                            ),
                          ),
                        ),
                        if (recs != null) ...[
                          _chip(
                            '${recs.length} session${recs.length > 1 ? 's' : ''}',
                            _primary.withValues(alpha: 0.1),
                            _primary,
                          ),
                          if (recs.any(
                            (r) => (r['is_late'] as num?)?.toInt() == 1,
                          )) ...[
                            const SizedBox(width: 6),
                            _chip(
                              'Late',
                              _orange.withValues(alpha: 0.1),
                              _orange,
                            ),
                          ],
                        ],
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _textMid,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Info banners
                    if (holidayName != null) ...[
                      const SizedBox(height: 8),
                      _infoBanner(
                        Icons.celebration_rounded,
                        'H',
                        holidayName,
                        _red,
                      ),
                    ],
                    if (showWeekoffBanner) ...[
                      const SizedBox(height: 8),
                      _infoBanner(
                        Icons.weekend_rounded,
                        'W',
                        'Weekly off day',
                        _textMid,
                      ),
                    ],
                    if (leaves != null && leaves.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _infoBanner(
                        Icons.beach_access_rounded,
                        'L',
                        '${leaves.first['leave_name'] ?? 'Leave'}'
                            ' · ${leaves.first['final_status'] ?? ''}',
                        _purple,
                      ),
                    ],
                    if (hasCompOff) ...[
                      const SizedBox(height: 6),
                      _infoBanner(
                        Icons.swap_horiz_rounded,
                        'C',
                        'Comp-off earned this day',
                        _teal,
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, color: _border),

              // Records list
              Expanded(
                child: recs == null || recs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 36,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No attendance records for this day.',
                              style: TextStyle(color: _textLight, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: recs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _AttendanceCard(
                          record: recs[i],
                          fmtTime: _fmtTime,
                          fmtDuration: _fmtDuration,
                          fmtLate: _fmtLate,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayGrid() {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    const double cellH = 52.0; // taller to fit labels below the number

    final rowCount = ((startOffset + daysInMonth) / 7).ceil();

    return Column(
      children: List.generate(rowCount, (row) {
        return SizedBox(
          height: cellH,
          child: Row(
            children: List.generate(7, (col) {
              final slot = row * 7 + col;
              final d = slot - startOffset + 1;
              if (d < 1 || d > daysInMonth)
                return const Expanded(child: SizedBox());

              final date = DateTime(_viewMonth.year, _viewMonth.month, d);
              final key = _dateKey(date);
              final recs = _byDate[key];
              final isSelected =
                  _selectedDay != null && _dateKey(_selectedDay!) == key;
              final today = _isToday(date);
              final isWeekoff = _isWeekoff(date);

              // Label flags
              final isHoliday = _holidays.containsKey(key);
              final isLeave = _leavesByDate.containsKey(key);
              final isCompOff = _compOffDates.contains(key);
              final hasAttended = recs != null && recs.isNotEmpty;
              final hasLate =
                  hasAttended &&
                  recs!.any((r) => (r['is_late'] as num?)?.toInt() == 1);

              // Cell background: selection wins, then today, then holiday/weekoff
              Color cellBg = Colors.transparent;
              if (isSelected)
                cellBg = _primary;
              else if (today)
                cellBg = _primary.withValues(alpha: 0.07);
              else if (isHoliday)
                cellBg = _red.withValues(alpha: 0.05);
              else if (isWeekoff)
                cellBg = const Color(0xFF64748B).withValues(alpha: 0.06);

              // Day number colour
              Color numColor = _textDark;
              if (isSelected)
                numColor = Colors.white;
              else if (today)
                numColor = _primary;
              else if (isHoliday)
                numColor = _red;
              else if (isWeekoff)
                numColor = _textMid;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = date);
                    _showDayDetail(date);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cellBg,
                      borderRadius: BorderRadius.circular(8),
                      border: today && !isSelected
                          ? Border.all(color: _primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: numColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _buildCellLabels(
                          isSelected: isSelected,
                          isHoliday: isHoliday,
                          isLeave: isLeave,
                          isCompOff: isCompOff,
                          isWeekoff: isWeekoff,
                          hasAttended: hasAttended,
                          hasLate: hasLate,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  /// Builds the small indicator row inside a calendar cell.
  /// Priority order: H > L > C > attendance dot
  /// On a selected cell everything is white/translucent.
  Widget _buildCellLabels({
    required bool isSelected,
    required bool isHoliday,
    required bool isLeave,
    required bool isCompOff,
    required bool isWeekoff,
    required bool hasAttended,
    required bool hasLate,
  }) {
    final labels = <Widget>[];

    void addLabel(String text, Color color) {
      if (labels.isNotEmpty) labels.add(const SizedBox(width: 2));
      labels.add(
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.5)
                  : color.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      );
    }

    if (isHoliday) addLabel('H', _red);
    if (isLeave) addLabel('L', _purple);
    if (isCompOff) addLabel('C', _teal);
    // Show W only when it's a weekoff but NOT a holiday/leave/comp-off day
    // (to avoid label clutter; if it's also a holiday the H already signals the day off)
    if (isWeekoff && !isHoliday && !isLeave && !isCompOff && !hasAttended) {
      addLabel('W', _textMid);
    }

    // Attendance dot (only if no labels already, to avoid clutter)
    if (hasAttended && labels.isEmpty) {
      labels.add(
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? Colors.white.withValues(alpha: 0.8)
                : hasLate
                ? _orange
                : _green,
          ),
        ),
      );
    } else if (hasAttended) {
      // Show tiny dot alongside the labels
      labels.add(const SizedBox(width: 2));
      labels.add(
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? Colors.white.withValues(alpha: 0.7)
                : hasLate
                ? _orange
                : _green,
          ),
        ),
      );
    }

    if (labels.isEmpty) return const SizedBox(height: 13);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: labels);
  }

  // ── Day detail ────────────────────────────────────────────────────────────

  Widget _buildDayDetail() {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap a date to view records',
              style: TextStyle(color: _textLight, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final key = _dateKey(_selectedDay!);
    final recs = _byDate[key];
    final dayLabel = DateFormat('EEEE, d MMMM yyyy').format(_selectedDay!);
    final holidayName = _holidays[key];
    final leaves = _leavesByDate[key];
    final hasCompOff = _compOffDates.contains(key);
    final isWeekoff = _isWeekoff(_selectedDay!);
    // Weekoff label: only show banner when there's no holiday (H already covers it)
    final showWeekoffBanner = isWeekoff && holidayName == null;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dayLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMid,
                  ),
                ),
              ),
              if (recs != null) ...[
                _chip(
                  '${recs.length} session${recs.length > 1 ? 's' : ''}',
                  _primary.withValues(alpha: 0.1),
                  _primary,
                ),
                if (recs.any((r) => (r['is_late'] as num?)?.toInt() == 1)) ...[
                  const SizedBox(width: 6),
                  _chip('Late', _orange.withValues(alpha: 0.1), _orange),
                ],
              ],
            ],
          ),
          // Info banners
          if (holidayName != null) ...[
            const SizedBox(height: 8),
            _infoBanner(Icons.celebration_rounded, 'H', holidayName, _red),
          ],
          if (showWeekoffBanner) ...[
            const SizedBox(height: 8),
            _infoBanner(Icons.weekend_rounded, 'W', 'Weekly off day', _textMid),
          ],
          if (leaves != null && leaves.isNotEmpty) ...[
            const SizedBox(height: 6),
            _infoBanner(
              Icons.beach_access_rounded,
              'L',
              '${leaves.first['leave_name'] ?? 'Leave'}'
                  ' · ${leaves.first['final_status'] ?? ''}',
              _purple,
            ),
          ],
          if (hasCompOff) ...[
            const SizedBox(height: 6),
            _infoBanner(
              Icons.swap_horiz_rounded,
              'C',
              'Comp-off earned this day',
              _teal,
            ),
          ],
        ],
      ),
    );

    if (recs == null || recs.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Divider(height: 1, color: _border),
          Expanded(
            child: Center(
              child: Text(
                'No attendance records for this day.',
                style: const TextStyle(color: _textLight, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const Divider(height: 1, color: _border),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: recs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AttendanceCard(
              record: recs[i],
              fmtTime: _fmtTime,
              fmtDuration: _fmtDuration,
              fmtLate: _fmtLate,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoBanner(IconData icon, String label, String text, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Attendance card
// ─────────────────────────────────────────────────────────────────────────────

class _AttendanceCard extends StatelessWidget {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  final Map<String, dynamic> record;
  final String Function(String?) fmtTime;
  final String Function(String?) fmtDuration;
  final String Function(int) fmtLate;

  const _AttendanceCard({
    required this.record,
    required this.fmtTime,
    required this.fmtDuration,
    required this.fmtLate,
  });

  @override
  Widget build(BuildContext context) {
    final checkin = record['checkin_time'] as String?;
    final checkout = record['checkout_time'] as String?;
    final totalWork = record['total_work_time'] as String?;
    final isLate = (record['is_late'] as num?)?.toInt() == 1;
    final lateMin = (record['late_minutes'] as num?)?.toInt() ?? 0;
    final status = record['status'] as String? ?? 'completed';
    final isActive = status == 'active';

    final Color accent = isActive
        ? _green
        : isLate
        ? _orange
        : _primary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _timeBlock(
                      icon: Icons.login_rounded,
                      label: 'In',
                      value: fmtTime(checkin),
                      color: _green,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: _border,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    _timeBlock(
                      icon: Icons.logout_rounded,
                      label: 'Out',
                      value: isActive ? 'Active' : fmtTime(checkout),
                      color: isActive ? _green : _red,
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: _border,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    _timeBlock(
                      icon: Icons.timelapse_rounded,
                      label: 'Total',
                      value: fmtDuration(totalWork),
                      color: _primary,
                    ),
                  ],
                ),
                if (isLate && lateMin > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: _orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: _orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            fmtLate(lateMin),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBlock({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
