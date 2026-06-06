// report_screen.dart

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
const Color _orange = Color(0xFFD97706); // ← NEW: comp-off colour
const Color _surface = Color(0xFFF0F4FF);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);
const Color _hdr1 = Color(0xFF1E3A8A);
const Color _hdr2 = Color(0xFF2563EB);
const Color _divCol = Color(0xFF93C5FD);

// Status colors for matrix cells: P A L H W C
const Map<String, (Color, Color)> _statusColors = {
  'P': (Color(0xFFECFDF5), Color(0xFF16A34A)),
  'A': (Color(0xFFFEF2F2), Color(0xFFDC2626)),
  'L': (Color(0xFFFFE4E6), Color(0xFFBE123C)),
  'H': (Color(0xFFE0F2FE), Color(0xFF0369A1)),
  'W': (Color(0xFFF5F3FF), _purple),
  'C': (Color(0xFFFFFBEB), _orange), // ← NEW
};

// Status colors for daily table rows: full labels
const Map<String, (Color, Color)> _dailyStatusColors = {
  'Present': (Color(0xFFECFDF5), Color(0xFF16A34A)),
  'Absent': (Color(0xFFFEF2F2), Color(0xFFDC2626)),
  'Leave': (Color(0xFFFFE4E6), Color(0xFFBE123C)),
  'Holiday': (Color(0xFFE0F2FE), Color(0xFF0369A1)),
  'Weekend': (Color(0xFFF5F3FF), _purple),
  'Comp-Off': (Color(0xFFFFFBEB), _orange), // ← NEW
};

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
              'Normal mode only  ·  Export to Excel',
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
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    // Dynamically compute height: status bar + title row + tab bar
    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeight = topPadding + 48 + 46; // 48=title row, 46=tab bar

    return PreferredSize(
      preferredSize: Size.fromHeight(totalHeight),
      child: Container(
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
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            'Normal mode only  ·  Export to Excel',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              TabBar(
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
                  Tab(
                    icon: Icon(Icons.today_rounded, size: 16),
                    text: 'Day-Wise',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      print('Departments loaded: ${list.length}');
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

  bool _compOffEnabled = true; // field

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
      _snack('Matrix exported successfully');
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad), // ← changed
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

  Widget _legendRow() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      const _LegendChip('P', 'Present', Color(0xFFECFDF5), Color(0xFF16A34A)),
      const _LegendChip('A', 'Absent', Color(0xFFFEF2F2), Color(0xFFDC2626)),
      const _LegendChip('L', 'Leave', Color(0xFFFFE4E6), Color(0xFFBE123C)),
      const _LegendChip('H', 'Holiday', Color(0xFFE0F2FE), Color(0xFF0369A1)),
      const _LegendChip('W', 'Week-off', Color(0xFFF5F3FF), _purple),
      if (_compOffEnabled)
        const _LegendChip('C', 'Comp-Off', Color(0xFFFFFBEB), _orange),
    ],
  );

  Widget _matrixTable() {
    final rows = _filtered;
    if (rows.isEmpty) return const _EmptyState();

    const snoW = 44.0;
    const empIdW = 70.0;
    const nameW = 170.0;
    const dayW = 28.0;
    const summaryW = 62.0;
    const hdrTopH = 18.0;
    const hdrBotH = 22.0;
    const hdrTotalH = hdrTopH + 1 + hdrBotH; // 41px — includes inner divider

    final int summaryCols = _compOffEnabled ? 10 : 7;
    final totalW =
        snoW +
        empIdW +
        nameW +
        (_dates.length * dayW) +
        (summaryCols * summaryW) +
        (_dates.length + summaryCols + 2) -
        2; // subtract outer border width (1px each side)

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

    // Day columns: day-name sub-row on top, day-number sub-row below
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
            height: hdrTopH,
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
            height: hdrBotH,
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

    // Summary columns span the full header height
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
                  // ── Single unified header row ─────────────────────────
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
                        summaryHdr('Lv\nApp', bg: _accent),
                        div(),
                        summaryHdr('Lv\nRej', bg: _red),
                        div(),
                        summaryHdr('Att %'),
                      ],
                    ),
                  ), // IntrinsicHeight
                  hdiv(totalW),
                  // ── Data rows ─────────────────────────────────────────
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
      ), // IntrinsicWidth
    ); // Center
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

    Widget statusCell(String s) {
      final c = _statusColors[s] ?? (rowBg, _textDark);
      return Container(
        width: dayW,
        height: rowH,
        color: c.$1,
        alignment: Alignment.center,
        child: Text(
          s,
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
        // Present
        summaryCell(
          '${emp.presentDays}',
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
        // Leave
        summaryCell(
          '${emp.leaveDays}',
          emp.leaveDays > 0 ? const Color(0xFFFFE4E6) : rowBg,
          emp.leaveDays > 0 ? const Color(0xFFBE123C) : _textMid,
        ),

        if (_compOffEnabled) ...[
          div(),
          // C.Off Earned (all-time)
          summaryCell(
            '${emp.compOffEarned}',
            emp.compOffEarned > 0 ? const Color(0xFFFFFBEB) : rowBg,
            emp.compOffEarned > 0 ? _orange : _textMid,
          ),
          div(),
          // C.Off Used (all-time)
          summaryCell(
            '${emp.compOffUsed}',
            emp.compOffUsed > 0 ? const Color(0xFFFEF3C7) : rowBg,
            emp.compOffUsed > 0 ? _amber : _textMid,
          ),
          div(),
          // C.Off Expired (all-time)
          summaryCell(
            '${emp.compOffExpired}',
            emp.compOffExpired > 0 ? const Color(0xFFFEE2E2) : rowBg,
            emp.compOffExpired > 0 ? _red : _textMid,
          ),
        ],

        div(),
        // Leave Approved
        summaryCell(
          '${emp.leaveApproved}',
          emp.leaveApproved > 0 ? const Color(0xFFECFDF5) : rowBg,
          emp.leaveApproved > 0 ? _accent : _textMid,
        ),
        div(),
        // Leave Rejected
        summaryCell(
          '${emp.leaveRejected}',
          emp.leaveRejected > 0 ? const Color(0xFFFEE2E2) : rowBg,
          emp.leaveRejected > 0 ? _red : _textMid,
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
      await ReportService.exportDaily(_data, _date);
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad), // ← changed
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // ← changed
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
    final present = _data.where((e) => e.status == 'Present').length;
    final absent = _data.where((e) => e.status == 'Absent').length;
    final onLeave = _data.where((e) => e.status == 'Leave').length;
    final compOff = _data.where((e) => e.compOffEarned).length;
    final late = _data.where((e) => e.isLate).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // constraints.maxWidth is the actual available width inside the card
        // 3 chips per row, spacing 8 between them (2 gaps for 3 chips)
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

    // Index: 0=SNo 1=EmpID 2=Name 3=In 4=Out 5=Hrs 6=Status 7=Late 8=LateBy 9=CO-Today
    // Index: 0=SNo 1=EmpID 2=Name 3=In 4=Out 5=Hrs 6=Status 7=Late 8=LateBy [9=CO-Today]
    final cols = [
      ('S.No', 52.0, true),
      ('Emp ID', 70.0, true),
      ('Employee Name', 190.0, false),
      ('Check In', 80.0, true),
      ('Check Out', 80.0, true),
      ('Worked Hrs', 90.0, true),
      ('Status', 90.0, true),
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
      final sc = _dailyStatusColors[emp.status] ?? (rowBg, _textDark);

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
          cell(emp.status, cols[6].$2, bg: sc.$1, fg: sc.$2, bold: true),
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
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
