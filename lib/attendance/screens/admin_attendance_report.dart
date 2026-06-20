import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/report_model.dart';
import '../services/report_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────

const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);
const Color _purple = Color(0xFF7C3AED);
const Color _orange = Color(0xFFD97706);
const Color _surface = Color(0xFFF0F4FF);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);
const Color _hdr1 = Color(0xFF1E3A8A);
const Color _hdr2 = Color(0xFF2563EB);
const Color _divCol = Color(0xFF93C5FD);

// ─────────────────────────────────────────────────────────────────────────────
// Status colors — grouped by family for quick visual scanning
//
//  GREEN family   = present, fully paid     → P, PL, PH, PLH
//  YELLOW family  = present + unpaid half   → PU, PLU
//  SKY            = paid half-day only      → HD
//  PINK           = unpaid half-day only    → HU
//  ROSE           = full-day leave          → L
//  RED            = absent                  → A
//  BLUE           = holiday                 → H
//  PURPLE         = weekend                 → W
//  ORANGE         = comp-off                → C
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, (Color, Color)> _statusColors = {
  // Present family (green) ────────────────────────────────────────────────
  'P': (Color(0xFFECFDF5), Color(0xFF16A34A)), // Present
  'PL': (Color(0xFFECFDF5), Color(0xFFB45309)), // Present + Late (amber text)
  'PH': (Color(0xFFCCFBF1), Color(0xFF0D9488)), // Present + Paid Half
  'PLH': (Color(0xFFCCFBF1), Color(0xFFB45309)), // Present + Paid Half + Late
  // Present + unpaid-half family (yellow) ──────────────────────────────────
  'PU': (Color(0xFFFEF9C3), Color(0xFF65A30D)), // Present + Unpaid Half
  'PLU': (Color(0xFFFEF9C3), Color(0xFFB45309)), // Present + Unpaid Half + Late
  // Half-day leave only (no presence) ───────────────────────────────────────
  'HD': (
    Color(0xFFE0F2FE),
    Color(0xFF0369A1),
  ), // Half-Day Paid (absent other half)
  'HU': (
    Color(0xFFFCE7F3),
    Color(0xFFBE185D),
  ), // Half-Day Unpaid (absent other half)
  // Full-day leave ───────────────────────────────────────────────────────────
  'L': (Color(0xFFFFE4E6), Color(0xFFBE123C)),

  // Absent ─────────────────────────────────────────────────────────────────
  'A': (Color(0xFFFEF2F2), Color(0xFFDC2626)),

  // Holiday / Weekend ──────────────────────────────────────────────────────
  'H': (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
  'W': (Color(0xFFF5F3FF), _purple),

  // Comp-off ───────────────────────────────────────────────────────────────
  'C': (Color(0xFFFFFBEB), _orange),
};

// Short text shown inside each 28px matrix cell
String _cellText(String code) {
  switch (code) {
    case 'PL':
      return 'P';
    case 'PH':
    case 'PLH':
    case 'PU':
    case 'PLU':
      return 'P½';
    case 'HD':
    case 'HU':
      return '½';
    default:
      return code; // P, L, A, H, W, C
  }
}

// Medium label for the Day-Wise status column
const Map<String, String> _statusShortLabel = {
  'P': 'Present',
  'PL': 'Present (Late)',
  'PH': 'Present + ½ Leave',
  'PLH': 'Present + ½ Leave (Late)',
  'PU': 'Present + ½ Unpaid',
  'PLU': 'Present + ½ Unpaid (Late)',
  'HD': 'Half Day (Paid)',
  'HU': 'Half Day (Unpaid)',
  'L': 'Leave',
  'A': 'Absent',
  'H': 'Holiday',
  'W': 'Weekend',
  'C': 'Comp-Off',
};

// Format a decimal day-count: trims ".0" but keeps ".5"
String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({
    super.key,
    required this.mode, // 'normal' | 'gps' | 'gps_face'
  });
  final String mode;

  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: _DragScrollBehavior(),
    child: Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x401A56DB),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '  Export to Excel',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.grid_on_rounded, size: 16),
              text: 'Monthly Matrix',
            ),
            Tab(icon: Icon(Icons.today_rounded, size: 16), text: 'Day-Wise'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _MatrixTab(mode: widget.mode),
          _DailyTab(mode: widget.mode),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Department dropdown state — shared mixin
// ─────────────────────────────────────────────────────────────────────────────

mixin _DepartmentMixin<T extends StatefulWidget> on State<T> {
  List<DepartmentModel> _departments = [];
  DepartmentModel _selectedDept = kAllDepartments;
  bool _deptLoading = false;

  int? get _deptId => _selectedDept.id == -1 ? null : _selectedDept.id;

  Future<void> loadDepartments() async {
    setState(() => _deptLoading = true);
    try {
      final list = await ReportService.fetchDepartments();
      setState(() => _departments = [kAllDepartments, ...list]);
    } catch (_) {
      setState(() => _departments = [kAllDepartments]);
    } finally {
      setState(() => _deptLoading = false);
    }
  }

  Widget buildDeptDropdown() => _deptLoading
      ? const SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
        )
      : DropdownButtonHideUnderline(
          child: DropdownButton<DepartmentModel>(
            value: _selectedDept,
            isExpanded: true,
            isDense: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _primary,
              size: 18,
            ),
            style: const TextStyle(
              fontSize: 13,
              color: _textDark,
              fontWeight: FontWeight.w600,
            ),
            items: _departments
                .map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(
                      d.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: d.id == -1 ? _primary : _textDark,
                        fontWeight: d.id == -1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedDept = v);
            },
          ),
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Monthly Matrix
// ─────────────────────────────────────────────────────────────────────────────

class _MatrixTab extends StatefulWidget {
  const _MatrixTab({required this.mode});
  final String mode;

  @override
  State<_MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<_MatrixTab>
    with AutomaticKeepAliveClientMixin, _DepartmentMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<MatrixEmp> _data = [];
  List<MatrixDate> _dates = [];
  String _search = '';

  bool _compOffEnabled = true;

  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await ReportService.fetchMatrix(
        _fromDate,
        _toDate,
        departmentId: _deptId,
        mode: widget.mode,
      );
      final List rawDates = body['dates'] ?? [];
      final List rawData = body['data'] ?? [];
      setState(() {
        _dates = rawDates
            .map((d) => MatrixDate.fromJson(d as Map<String, dynamic>))
            .toList();
        _data = rawData
            .map((e) => MatrixEmp.fromJson(e as Map<String, dynamic>))
            .toList();
        _fetched = true;
        _search = '';
        _compOffEnabled = body['comp_off_enabled'] == true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_data.isEmpty) {
      _snack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ReportService.exportMatrix(_data, _dates, _fromDate, _toDate);
      _snack('Report exported successfully');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  List<MatrixEmp> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.name.toLowerCase().contains(_search.toLowerCase()) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterCard(
                  fromDate: _fromDate,
                  toDate: _toDate,
                  onFromPick: () => _pickDate(true),
                  onToPick: () => _pickDate(false),
                  deptDropdown: buildDeptDropdown(),
                  onSearch: _fetch,
                  onExport: _fetched ? _export : null,
                  loading: _loading,
                  quickChips: [
                    _QuickChip('This Month', () {
                      final n = DateTime.now();
                      setState(() {
                        _fromDate = DateTime(n.year, n.month, 1);
                        _toDate = n;
                      });
                    }),
                    _QuickChip('Last Month', () {
                      final n = DateTime.now();
                      setState(() {
                        _fromDate = DateTime(n.year, n.month - 1, 1);
                        _toDate = DateTime(n.year, n.month, 0);
                      });
                    }),
                    _QuickChip(
                      'Last 30 Days',
                      () => setState(() {
                        _toDate = DateTime.now();
                        _fromDate = _toDate.subtract(const Duration(days: 29));
                      }),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(_error!),
                ],
                if (_loading) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                ],
                if (_fetched && !_loading) ...[
                  const SizedBox(height: 14),
                  _DateBanner(
                    label: 'Report Period',
                    value:
                        '${fmtDisplay(_fromDate)}  →  ${fmtDisplay(_toDate)}',
                    icon: Icons.grid_on_rounded,
                    color: _primary,
                  ),
                  const SizedBox(height: 10),
                  _legendRow(),
                  const SizedBox(height: 12),
                  _SearchBar(onChanged: (v) => setState(() => _search = v)),
                  const SizedBox(height: 12),
                  _matrixTable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(_toDate)) _fromDate = _toDate;
      }
    });
  }

  // ── Legend ────────────────────────────────────────────────────────────────
  // Grouped to match the cell color families:
  //   green   = fully present / paid
  //   yellow  = present + unpaid half
  //   sky     = paid half-day only
  //   pink    = unpaid half-day only
  //   rose    = full leave
  //   red     = absent
  //   blue    = holiday
  //   purple  = weekend
  //   orange  = comp-off
  Widget _legendRow() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      _legendChip('P', 'Present', 'P'),
      _legendChip('PL', 'Late', 'P'),
      _legendChip('PH', 'Half Leave (Paid)', 'P½'),
      _legendChip('PU', 'Half Leave (Unpaid)', 'P½'),
      _legendChip('HD', 'Half-Day Only (Paid)', '½'),
      _legendChip('HU', 'Half-Day Only (Unpaid)', '½'),
      _legendChip('L', 'Full Leave', 'L'),
      _legendChip('A', 'Absent', 'A'),
      _legendChip('H', 'Holiday', 'H'),
      _legendChip('W', 'Week-off', 'W'),
      if (_compOffEnabled) _legendChip('C', 'Comp-Off', 'C'),
    ],
  );

  Widget _legendChip(String code, String label, String displayCode) {
    final c = _statusColors[code] ?? (_surface, _textMid);
    return _LegendChip(displayCode, label, c.$1, c.$2);
  }

  Widget _matrixTable() {
    final rows = _filtered;
    if (rows.isEmpty) return const _EmptyState();

    const snoW = 44.0;
    const empIdW = 70.0;
    const nameW = 170.0;
    const dayW = 28.0;
    const summaryW = 62.0;

    // Summary columns:
    //   Present, Absent, Leave, [CO Earned, CO Used, CO Expired],
    //   Paid Leave, Unpaid Leave, Half Day, Late Days, Late Hrs, Att%
    final int summaryCols = _compOffEnabled ? 12 : 9;
    final totalW =
        snoW +
        empIdW +
        nameW +
        (_dates.length * dayW) +
        (summaryCols * summaryW) +
        (_dates.length + summaryCols + 2) -
        2;

    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);

    Widget fixedHdr(String label, double w, {bool center = true}) => Container(
      width: w,
      constraints: const BoxConstraints(minHeight: 41),
      color: _hdr2,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget dayCol(MatrixDate d) {
      final bg = d.isHoliday
          ? const Color(0xFF1D4ED8)
          : d.isWeekend
          ? _purple
          : _hdr2;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dayW,
            height: 18,
            color: bg,
            alignment: Alignment.center,
            child: Text(
              d.dayLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(height: 1, width: dayW, color: _divCol),
          Container(
            width: dayW,
            height: 22,
            color: bg,
            alignment: Alignment.center,
            child: Text(
              '${d.dayOfMonth}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    Widget summaryHdr(String label, {Color bg = _hdr2}) => Container(
      width: summaryW,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );

    return Center(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TableHeader(title: 'Attendance Matrix', count: rows.length),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _divCol),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                color: Colors.white,
              ),
              child: ScrollConfiguration(
                behavior: _DragScrollBehavior(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 1),
                  child: Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            fixedHdr('S.No', snoW),
                            div(),
                            fixedHdr('Emp ID', empIdW),
                            div(),
                            fixedHdr('Employee Name', nameW, center: false),
                            div(),
                            for (int i = 0; i < _dates.length; i++) ...[
                              dayCol(_dates[i]),
                              if (i < _dates.length - 1) div(),
                            ],
                            div(),
                            summaryHdr('Present'),
                            div(),
                            summaryHdr('Absent'),
                            div(),
                            summaryHdr('Leave'),
                            if (_compOffEnabled) ...[
                              div(),
                              summaryHdr('C.Off\nEarned', bg: _orange),
                              div(),
                              summaryHdr('C.Off\nUsed', bg: _amber),
                              div(),
                              summaryHdr('C.Off\nExpired', bg: _red),
                            ],
                            div(),
                            summaryHdr(
                              'Paid\nLeave',
                              bg: const Color(0xFF0369A1),
                            ),
                            div(),
                            summaryHdr('Unpaid\nLeave', bg: _purple),
                            div(),
                            summaryHdr(
                              'Half\nDay',
                              bg: const Color(0xFFBE185D),
                            ),
                            div(),
                            summaryHdr('Late\nDays', bg: _amber),
                            div(),
                            summaryHdr('Late\nHrs', bg: _amber),
                            div(),
                            summaryHdr('Att %'),
                          ],
                        ),
                      ),
                      hdiv(totalW),
                      for (int i = 0; i < rows.length; i++) ...[
                        _matrixRow(
                          rows[i],
                          i,
                          dayW,
                          snoW,
                          empIdW,
                          nameW,
                          summaryW,
                          div,
                        ),
                        hdiv(totalW),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _matrixRow(
    MatrixEmp emp,
    int idx,
    double dayW,
    double snoW,
    double empIdW,
    double nameW,
    double summaryW,
    Widget Function() div,
  ) {
    final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);
    const rowH = 28.0;

    Color pctBg, pctFg;
    if (emp.percentage >= 90) {
      pctBg = const Color(0xFFDCFCE7);
      pctFg = const Color(0xFF16A34A);
    } else if (emp.percentage >= 75) {
      pctBg = const Color(0xFFE0F2FE);
      pctFg = const Color(0xFF0369A1);
    } else if (emp.percentage >= 50) {
      pctBg = const Color(0xFFFEF3C7);
      pctFg = const Color(0xFFB45309);
    } else {
      pctBg = const Color(0xFFFEE2E2);
      pctFg = const Color(0xFFDC2626);
    }

    Widget statusCell(String code) {
      final c = _statusColors[code] ?? (rowBg, _textDark);
      return Container(
        width: dayW,
        height: rowH,
        color: c.$1,
        alignment: Alignment.center,
        child: Text(
          _cellText(code),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: c.$2,
          ),
        ),
      );
    }

    Widget summaryCell(String val, Color bg, Color fg) => Container(
      width: summaryW,
      height: rowH,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        val,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );

    return Row(
      children: [
        _dataCell('${idx + 1}', snoW, rowH, rowBg, fg: _textMid),
        div(),
        _dataCell(
          emp.empId.toString(),
          empIdW,
          rowH,
          rowBg,
          fg: _primary,
          bold: true,
        ),
        div(),
        _dataCell(emp.name, nameW, rowH, rowBg, bold: true, center: false),
        div(),
        for (int j = 0; j < emp.days.length; j++) ...[
          statusCell(emp.days[j]),
          if (j < emp.days.length - 1) div(),
        ],
        div(),
        // Present (decimal-aware)
        summaryCell(
          _fmtNum(emp.presentDays),
          const Color(0xFFECFDF5),
          const Color(0xFF16A34A),
        ),
        div(),
        // Absent
        summaryCell(
          '${emp.absentDays}',
          emp.absentDays > 0 ? const Color(0xFFFEF2F2) : rowBg,
          emp.absentDays > 0 ? const Color(0xFFDC2626) : _textMid,
        ),
        div(),
        // Leave (decimal-aware)
        summaryCell(
          _fmtNum(emp.leaveDays),
          emp.leaveDays > 0 ? const Color(0xFFFFE4E6) : rowBg,
          emp.leaveDays > 0 ? const Color(0xFFBE123C) : _textMid,
        ),

        if (_compOffEnabled) ...[
          div(),
          summaryCell(
            '${emp.compOffEarned}',
            emp.compOffEarned > 0 ? const Color(0xFFFFFBEB) : rowBg,
            emp.compOffEarned > 0 ? _orange : _textMid,
          ),
          div(),
          summaryCell(
            '${emp.compOffUsed}',
            emp.compOffUsed > 0 ? const Color(0xFFFEF3C7) : rowBg,
            emp.compOffUsed > 0 ? _amber : _textMid,
          ),
          div(),
          summaryCell(
            '${emp.compOffExpired}',
            emp.compOffExpired > 0 ? const Color(0xFFFEE2E2) : rowBg,
            emp.compOffExpired > 0 ? _red : _textMid,
          ),
        ],

        div(),
        // Paid Leave (decimal — full + half*0.5)
        summaryCell(
          _fmtNum(emp.paidLeaveDays),
          emp.paidLeaveDays > 0 ? const Color(0xFFE0F2FE) : rowBg,
          emp.paidLeaveDays > 0 ? const Color(0xFF0369A1) : _textMid,
        ),
        div(),
        // Unpaid Leave (decimal — full + half*0.5)
        summaryCell(
          _fmtNum(emp.unpaidLeaveDays),
          emp.unpaidLeaveDays > 0 ? const Color(0xFFF5F3FF) : rowBg,
          emp.unpaidLeaveDays > 0 ? _purple : _textMid,
        ),
        div(),
        // Half Day (count of half-day leaves, paid + unpaid)
        summaryCell(
          '${emp.halfDayCount}',
          emp.halfDayCount > 0 ? const Color(0xFFFCE7F3) : rowBg,
          emp.halfDayCount > 0 ? const Color(0xFFBE185D) : _textMid,
        ),
        div(),
        // Late Days
        summaryCell(
          '${emp.lateDays}',
          emp.lateDays > 0 ? const Color(0xFFFEF3C7) : rowBg,
          emp.lateDays > 0 ? _amber : _textMid,
        ),
        div(),
        // Late Hrs
        summaryCell(
          emp.lateMinutes > 0
              ? () {
                  final h = emp.lateMinutes ~/ 60;
                  final m = emp.lateMinutes % 60;
                  if (h == 0) return '${m}m';
                  if (m == 0) return '${h}h';
                  return '${h}h${m}m';
                }()
              : '--',
          emp.lateMinutes > 0 ? const Color(0xFFFEF3C7) : rowBg,
          emp.lateMinutes > 0 ? _amber : _textMid,
        ),
        div(),
        // Att %
        summaryCell('${emp.percentage.toStringAsFixed(1)}%', pctBg, pctFg),
      ],
    );
  }

  Widget _dataCell(
    String text,
    double w,
    double h,
    Color bg, {
    Color? fg,
    bool bold = false,
    bool center = true,
  }) => Container(
    width: w,
    height: h,
    color: bg,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: fg ?? _textDark,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Day-Wise
// ─────────────────────────────────────────────────────────────────────────────

class _DailyTab extends StatefulWidget {
  const _DailyTab({required this.mode});
  final String mode;

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab>
    with AutomaticKeepAliveClientMixin, _DepartmentMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _date = DateTime.now();

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<EmpDaily> _data = [];
  bool _isHoliday = false;
  bool _isWeekend = false;
  String? _holidayName;
  String _search = '';
  bool _compOffEnabled = true;

  @override
  void initState() {
    super.initState();
    loadDepartments();
  }

  String _dayName(DateTime d) => const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ][d.weekday % 7];

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await ReportService.fetchDaily(
        _date,
        departmentId: _deptId,
        mode: widget.mode,
      );
      final List rows = body['data'] ?? [];
      setState(() {
        _data = rows
            .map((r) => EmpDaily.fromJson(r as Map<String, dynamic>))
            .toList();
        _isHoliday = body['is_holiday'] == true;
        _isWeekend = body['is_weekend'] == true;
        _holidayName = body['holiday_name']?.toString();
        _fetched = true;
        _search = '';
        _compOffEnabled = body['comp_off_enabled'] == true;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_data.isEmpty) {
      _snack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ReportService.exportDaily(_data, _date, mode: widget.mode);
      _snack('Daily report exported');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  List<EmpDaily> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.name.toLowerCase().contains(_search.toLowerCase()) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DailyFilterCard(
                  date: _date,
                  onPickDate: _pickDate,
                  onPrev: () => setState(
                    () => _date = _date.subtract(const Duration(days: 1)),
                  ),
                  onNext: () {
                    final next = _date.add(const Duration(days: 1));
                    if (!next.isAfter(DateTime.now())) {
                      setState(() => _date = next);
                    }
                  },
                  onToday: () => setState(() => _date = DateTime.now()),
                  deptDropdown: buildDeptDropdown(),
                  onSearch: _fetch,
                  onExport: _fetched ? _export : null,
                  loading: _loading,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(_error!),
                ],
                if (_loading) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
                ],
                if (_fetched && !_loading) ...[
                  const SizedBox(height: 14),
                  _DateBanner(
                    label: _dayName(_date),
                    value: fmtDisplay(_date),
                    icon: Icons.event_rounded,
                    color: _isHoliday
                        ? const Color(0xFF0369A1)
                        : _isWeekend
                        ? _purple
                        : _primary,
                    suffix: _isHoliday
                        ? '  🎉 ${_holidayName ?? 'Holiday'}'
                        : _isWeekend
                        ? '  🏖 Weekend'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  _dailyStats(),
                  const SizedBox(height: 12),
                  _SearchBar(onChanged: (v) => setState(() => _search = v)),
                  const SizedBox(height: 12),
                  if (widget.mode == 'site_entry')
                    _siteEntryCards()
                  else
                    _dailyTable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _dailyStats() {
    // New status codes: P, PL, PH, PLH, PU, PLU, HD, HU, L, A, H, W, C
    final present = _data.where((e) => e.isPresentStatus).length;
    final absent = _data.where((e) => e.status == 'A').length;
    final onLeave = _data
        .where((e) => e.status == 'L' || e.status == 'HD' || e.status == 'HU')
        .length;
    final compOff = _data.where((e) => e.compOffEarned).length;
    final late = _data.where((e) => e.isLate).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = ((constraints.maxWidth - 16) / 3).clamp(90.0, 200.0);

        Widget chip(
          IconData icon,
          String label,
          String value,
          Color color,
        ) => SizedBox(
          width: tileW,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(fontSize: 9, color: _textMid),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip(
              Icons.people_alt_rounded,
              'Total',
              '${_data.length}',
              _primary,
            ),
            chip(Icons.check_circle_rounded, 'Present', '$present', _accent),
            chip(Icons.cancel_rounded, 'Absent', '$absent', _red),
            chip(
              Icons.beach_access_rounded,
              'On Leave',
              '$onLeave',
              const Color(0xFFBE123C),
            ),
            if (_compOffEnabled)
              chip(
                Icons.event_available_rounded,
                'CO Earned',
                '$compOff',
                _orange,
              ),
            chip(Icons.timelapse_rounded, 'Late', '$late', _amber),
          ],
        );
      },
    );
  }

  Widget _dailyTable() {
    final rows = _filtered;
    if (rows.isEmpty) return const _EmptyState();

    final cols = [
      ('S.No', 52.0, true),
      ('Emp ID', 70.0, true),
      ('Employee Name', 190.0, false),
      ('Check In', 80.0, true),
      ('Check Out', 80.0, true),
      ('Worked Hrs', 90.0, true),
      ('Status', 140.0, true),
      ('Late', 55.0, true),
      ('Late By', 75.0, true),
      if (_compOffEnabled) ('Comp-Off\nToday', 90.0, true),
    ];

    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);
    final totalW = cols.fold(0.0, (s, c) => s + c.$2) + (cols.length - 1);

    Widget hdrCell((String, double, bool) col) => Container(
      width: col.$2,
      height: 44,
      color: _hdr2,
      alignment: col.$3 ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        col.$1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
      ),
    );

    Widget rowW(EmpDaily emp, int idx) {
      final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);
      const rowH = 38.0;
      final sc = _statusColors[emp.status] ?? (rowBg, _textDark);
      final label = _statusShortLabel[emp.status] ?? emp.statusLabel;

      Widget cell(
        String text,
        double w, {
        Color? bg,
        Color? fg,
        bool bold = false,
        bool center = true,
      }) => Container(
        width: w,
        height: rowH,
        color: bg ?? rowBg,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: fg ?? _textDark,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );

      return Row(
        children: [
          cell('${idx + 1}', cols[0].$2),
          div(),
          cell(emp.empId.toString(), cols[1].$2, fg: _primary, bold: true),
          div(),
          cell(emp.name, cols[2].$2, center: false, bold: true),
          div(),
          cell(
            emp.checkIn ?? '-',
            cols[3].$2,
            fg: emp.checkIn != null ? _accent : _textMid,
          ),
          div(),
          cell(
            emp.checkOut ?? '-',
            cols[4].$2,
            fg: emp.checkOut != null ? _accent : _textMid,
          ),
          div(),
          cell(emp.workedFormatted, cols[5].$2),
          div(),
          cell(
            label,
            cols[6].$2,
            bg: sc.$1,
            fg: sc.$2,
            bold: true,
            center: false,
          ),
          div(),
          cell(
            emp.isLate ? 'Yes' : 'No',
            cols[7].$2,
            bg: emp.isLate ? const Color(0xFFFEF3C7) : null,
            fg: emp.isLate ? const Color(0xFFB45309) : _textMid,
            bold: emp.isLate,
          ),
          div(),
          cell(
            emp.lateFormatted,
            cols[8].$2,
            fg: emp.lateMinutes > 0 ? const Color(0xFFB45309) : _textMid,
          ),
          if (_compOffEnabled) ...[
            div(),
            cell(
              emp.compOffEarned ? '✓ Yes' : '-',
              cols[9].$2,
              fg: emp.compOffEarned ? const Color(0xFF92400E) : _textMid,
              bold: emp.compOffEarned,
            ),
          ],
        ],
      );
    }

    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(
            title: 'Day-Wise Attendance Register',
            count: rows.length,
          ),
          ScrollConfiguration(
            behavior: _DragScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _divCol),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < cols.length; i++) ...[
                          hdrCell(cols[i]),
                          if (i < cols.length - 1) div(),
                        ],
                      ],
                    ),
                    hdiv(totalW),
                    for (int i = 0; i < rows.length; i++) ...[
                      rowW(rows[i], i),
                      hdiv(totalW),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Site-entry helpers ─────────────────────────────────────────────────────

  String _fmtTime(String? dt) {
    if (dt == null) return '—';
    try {
      final p = dt.split(' ');
      if (p.length < 2) return dt;
      final tp = p[1].split(':');
      final h = int.parse(tp[0]);
      final m = int.parse(tp[1]);
      final hh = h % 12 == 0 ? 12 : h % 12;
      final mm = m.toString().padLeft(2, '0');
      return '$hh:$mm ${h < 12 ? 'AM' : 'PM'}';
    } catch (_) {
      return dt.length >= 16 ? dt.substring(11, 16) : dt;
    }
  }

  String _fmtWork(String? t) {
    if (t == null) return '—';
    final p = t.split(':');
    if (p.length < 2) return t;
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    if (h == 0 && m == 0) return '< 1m';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _sumWork(List<SiteSession> sessions) {
    int secs = 0;
    for (final s in sessions) {
      if (s.totalWorkTime != null) {
        final p = s.totalWorkTime!.split(':');
        if (p.length >= 2) {
          secs += (int.tryParse(p[0]) ?? 0) * 3600;
          secs += (int.tryParse(p[1]) ?? 0) * 60;
          if (p.length >= 3) secs += int.tryParse(p[2]) ?? 0;
        }
      }
    }
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0 && m == 0) return '—';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String _fmtPauseSecs(int secs) {
    if (secs <= 0) return '';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h == 0) return '${m}m pause';
    if (m == 0) return '${h}h pause';
    return '${h}h ${m}m pause';
  }

  Widget _siteEntryCards() {
    final rows = _filtered;
    if (rows.isEmpty) return const _EmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TableHeader(title: 'Site Attendance — Day View', count: rows.length),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map(
          (e) => _SiteEmpDayCard(
            emp: e.value,
            index: e.key,
            fmtTime: _fmtTime,
            fmtWork: _fmtWork,
            sumWork: _sumWork,
            fmtPauseSecs: _fmtPauseSecs,
            compOffEnabled: _compOffEnabled,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared filter cards
// ─────────────────────────────────────────────────────────────────────────────

class _FilterCard extends StatelessWidget {
  final DateTime fromDate, toDate;
  final VoidCallback onFromPick, onToPick, onSearch;
  final VoidCallback? onExport;
  final Widget deptDropdown;
  final bool loading;
  final List<Widget> quickChips;

  const _FilterCard({
    required this.fromDate,
    required this.toDate,
    required this.onFromPick,
    required this.onToPick,
    required this.deptDropdown,
    required this.onSearch,
    required this.onExport,
    required this.loading,
    required this.quickChips,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filters',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _DateField('From', fromDate, onFromPick)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: _textMid,
                size: 18,
              ),
            ),
            Expanded(child: _DateField('To', toDate, onToPick)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded, size: 16, color: _primary),
              const SizedBox(width: 8),
              Expanded(child: deptDropdown),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: quickChips),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Search',
                icon: Icons.search_rounded,
                color: _primary,
                loading: loading,
                onTap: onSearch,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Export Excel',
                icon: Icons.download_rounded,
                color: _accent,
                loading: false,
                enabled: onExport != null,
                onTap: onExport ?? () {},
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DailyFilterCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPickDate, onPrev, onNext, onToday, onSearch;
  final VoidCallback? onExport;
  final Widget deptDropdown;
  final bool loading;

  const _DailyFilterCard({
    required this.date,
    required this.onPickDate,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.deptDropdown,
    required this.onSearch,
    required this.onExport,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filters',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _DateField('Date', date, onPickDate)),
            const SizedBox(width: 12),
            _NavBtn(Icons.chevron_left_rounded, onPrev),
            const SizedBox(width: 6),
            _NavBtn(Icons.chevron_right_rounded, onNext),
            const SizedBox(width: 6),
            _NavBtn(Icons.today_rounded, onToday),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              const Icon(Icons.business_rounded, size: 16, color: _primary),
              const SizedBox(width: 8),
              Expanded(child: deptDropdown),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Search',
                icon: Icons.search_rounded,
                color: _primary,
                loading: loading,
                onTap: onSearch,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionBtn(
                label: 'Export Excel',
                icon: Icons.download_rounded,
                color: _accent,
                loading: false,
                enabled: onExport != null,
                onTap: onExport ?? () {},
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField(this.label, this.date, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: _primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _textMid),
              ),
              Text(
                fmtDisplay(date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 18, color: _primary),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading, enabled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DateBanner extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? suffix;

  const _DateBanner({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value + (suffix ?? ''),
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TableHeader extends StatelessWidget {
  final String title;
  final int count;
  const _TableHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _hdr1,
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count employee${count == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) => _Card(
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search employee by name or ID…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _LegendChip extends StatelessWidget {
  final String code, label;
  final Color bg, fg;
  const _LegendChip(this.code, this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: fg)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => _Card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 44,
              color: _textMid.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 10),
            const Text(
              'No records found.',
              style: TextStyle(color: _textMid, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _red.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: _red, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _red),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll behaviour — supports mouse drag on web/desktop
// ─────────────────────────────────────────────────────────────────────────────

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Site-entry employee day card
// ─────────────────────────────────────────────────────────────────────────────

class _SiteEmpDayCard extends StatelessWidget {
  final EmpDaily emp;
  final int index;
  final String Function(String?) fmtTime;
  final String Function(String?) fmtWork;
  final String Function(List<SiteSession>) sumWork;
  final String Function(int) fmtPauseSecs;
  final bool compOffEnabled;

  const _SiteEmpDayCard({
    required this.emp,
    required this.index,
    required this.fmtTime,
    required this.fmtWork,
    required this.sumWork,
    required this.fmtPauseSecs,
    required this.compOffEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final sessions = emp.siteSessions;
    final totalWork = sumWork(sessions);
    final anyActive = sessions.any((s) => s.status == 'active');
    final sc = _statusColors[emp.status] ?? (const Color(0xFFEEF2FF), _primary);
    final label = _statusShortLabel[emp.status] ?? emp.statusLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Employee header ──────────────────────────────────────────────
          Container(
            color: _hdr1,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '#${emp.empId}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                          if (emp.department.isNotEmpty) ...[
                            const Text(
                              '  ·  ',
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 10,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                emp.department,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sc.$1,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sc.$2,
                    ),
                  ),
                ),
                if (anyActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Sessions ─────────────────────────────────────────────────────
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  emp.status == 'A' ? 'No check-in recorded' : 'No sessions',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ),
            )
          else
            ...sessions.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              // A session is "active" if it has no check-out yet (still
              // ongoing today). Within an active session, `totalPauseSecs > 0`
              // means the employee paused at some point (see site_entry
              // pause/resume state machine) — that's what flips the badge
              // from LIVE to PAUSED below. A *completed* session (checked
              // out) never shows either badge, even if it was paused at some
              // point during the day.
              final isActive = s.status == 'active';
              final isPaused = isActive && s.totalPauseSecs > 0;
              final sessionBg = i.isEven
                  ? Colors.white
                  : const Color(0xFFF8FAFF);

              return Container(
                decoration: BoxDecoration(
                  color: sessionBg,
                  border: Border(top: BorderSide(color: _border)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Session number bubble
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Site name + times
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 11,
                                color: _purple,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  s.siteName ?? 'Unknown Site',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _purple,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isActive && !isPaused) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: _accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ] else if (isPaused) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PAUSED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: _amber,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _TimeChip(
                                icon: Icons.login_rounded,
                                label: 'In',
                                time: fmtTime(s.checkIn),
                                color: _accent,
                              ),
                              const SizedBox(width: 10),
                              _TimeChip(
                                icon: Icons.logout_rounded,
                                label: 'Out',
                                time: fmtTime(s.checkOut),
                                color: _red,
                              ),
                              if (s.totalPauseSecs > 0) ...[
                                const SizedBox(width: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.pause_circle_outline_rounded,
                                      size: 10,
                                      color: _amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      fmtPauseSecs(s.totalPauseSecs),
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
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),
                    // Per-session duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _accent.withValues(alpha: 0.08)
                            : _purple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isActive
                              ? _accent.withValues(alpha: 0.2)
                              : _purple.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        fmtWork(s.totalWorkTime),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? _accent : _purple,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // ── Total footer ──────────────────────────────────────────────────
          if (sessions.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _border, width: 1.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: _primary),
                  const SizedBox(width: 5),
                  Text(
                    '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Total worked:',
                    style: TextStyle(fontSize: 11, color: _textMid),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      totalWork,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                  if (compOffEnabled && emp.compOffEarned) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✓ CO Earned',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _orange,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared time chip
// ─────────────────────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final Color color;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 3),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: _textMid)),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ],
  );
}
