import 'package:flutter/material.dart';
import '../models/admin_hr_attendance_model.dart';
import '../services/admin_hr_attendance_service.dart';

// ── Design Tokens (same as admin screen) ─────────────────────────────────────
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
  final double height;
  const _Screen(this.width, this.height);
  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;
  double get pagePadding => isMobile
      ? 14
      : isTablet
      ? 20
      : 28;
  double get bodyFontSize => isMobile ? 13 : 14;
  double get captionFont => isMobile ? 11 : 12;
}

// ── TL Attendance Screen ──────────────────────────────────────────────────────
class TLAttendanceScreen extends StatefulWidget {
  final int loginId;

  const TLAttendanceScreen({super.key, required this.loginId});

  @override
  State<TLAttendanceScreen> createState() => _TLAttendanceScreenState();
}

class _TLAttendanceScreenState extends State<TLAttendanceScreen> {
  String _selectedStatus = 'All';
  String _selectedDateFilter = 'Today';
  DateTime _selectedDate = DateTime.now();
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<AttendanceAdminModel> _allRecords = [];
  List<AttendanceAdminModel> _filteredRecords = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const months = [
      '',
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
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month]} ${d.year}';
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminHrAttendanceService.fetchTLTeamAttendance(
        _fmtApi(_selectedDate),
        widget.loginId,
      );
      if (!mounted) return;
      _allRecords = data;
      _applyFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final search = _searchCtrl.text.toLowerCase();
    _filteredRecords = _allRecords.where((e) {
      final matchName =
          e.name.toLowerCase().contains(search) ||
          e.empId.toString().contains(search);
      final matchStatus = _selectedStatus == 'All'
          ? true
          : e.status.toUpperCase() == _selectedStatus;
      return matchName && matchStatus;
    }).toList();
    setState(() {});
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      _selectedDate = picked;
      _selectedDateFilter = 'Custom';
      await _loadAttendance();
    }
  }

  int get _total => _allRecords.length;
  int get _present =>
      _allRecords.where((e) => e.status.toUpperCase() == 'PRESENT').length;
  int get _absent =>
      _allRecords.where((e) => e.status.toUpperCase() == 'ABSENT').length;

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(70),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x201A56DB),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'My Team Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Date: ${_displayDate(_selectedDate)}',
                      style: const TextStyle(fontSize: 11, color: _textMid),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: _textDark),
                onPressed: _loadAttendance,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = _Screen(mq.size.width, mq.size.height);

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? _loader()
            : _error != null
            ? _errorWidget(_error!, _loadAttendance)
            : RefreshIndicator(
                onRefresh: _loadAttendance,
                color: _primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Summary cards ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        color: _card,
                        padding: EdgeInsets.symmetric(
                          horizontal: s.pagePadding,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            _SummaryCard(
                              label: 'Total',
                              value: _total,
                              color: _primary,
                              bgColor: const Color(0xFFEEF2FF),
                              icon: Icons.people_alt_rounded,
                              s: s,
                            ),
                            const SizedBox(width: 8),
                            _SummaryCard(
                              label: 'Present',
                              value: _present,
                              color: _accent,
                              bgColor: const Color(0xFFECFDF5),
                              icon: Icons.check_circle_outline_rounded,
                              s: s,
                            ),
                            const SizedBox(width: 8),
                            _SummaryCard(
                              label: 'Absent',
                              value: _absent,
                              color: _red,
                              bgColor: const Color(0xFFFFF1F2),
                              icon: Icons.cancel_outlined,
                              s: s,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),

                    // ── Filter bar ───────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        color: _card,
                        padding: EdgeInsets.symmetric(
                          horizontal: s.pagePadding,
                          vertical: 10,
                        ),
                        child: s.isMobile ? _mobileFilters() : _wideFilters(s),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),

                    // ── Record count ─────────────────────────────────
                    if (_filteredRecords.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            s.pagePadding,
                            14,
                            s.pagePadding,
                            4,
                          ),
                          child: Text(
                            '${_filteredRecords.length} team member${_filteredRecords.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    // ── Empty state ──────────────────────────────────
                    if (_filteredRecords.isEmpty)
                      SliverFillRemaining(child: _emptyState()),

                    // ── Employee cards ───────────────────────────────
                    if (_filteredRecords.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          s.pagePadding,
                          8,
                          s.pagePadding,
                          32 + mq.padding.bottom,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _EmployeeAttendanceCard(
                              record: _filteredRecords[i],
                              s: s,
                            ),
                            childCount: _filteredRecords.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Filters ───────────────────────────────────────────────────────────────
  Widget _mobileFilters() => Column(
    children: [
      _searchField(),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _statusDrop()),
          const SizedBox(width: 8),
          Expanded(child: _dateDrop()),
        ],
      ),
    ],
  );

  Widget _wideFilters(_Screen s) => Row(
    children: [
      Expanded(flex: 3, child: _searchField()),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: _statusDrop()),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: _dateDrop()),
    ],
  );

  Widget _searchField() => TextField(
    controller: _searchCtrl,
    decoration: InputDecoration(
      hintText: 'Search by name or ID…',
      hintStyle: const TextStyle(color: _textLight, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, color: _textLight, size: 20),
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
    onChanged: (_) => _applyFilter(),
  );

  InputDecoration _dropDec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _textMid, fontSize: 13),
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  );

  Widget _statusDrop() => DropdownButtonFormField<String>(
    initialValue: _selectedStatus,
    isExpanded: true,
    style: const TextStyle(color: _textDark, fontSize: 13),
    decoration: _dropDec('Status'),
    items: ['All', 'PRESENT', 'ABSENT']
        .map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(e, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      _selectedStatus = v!;
      _applyFilter();
    },
  );

  Widget _dateDrop() => DropdownButtonFormField<String>(
    initialValue: _selectedDateFilter,
    isExpanded: true,
    style: const TextStyle(color: _textDark, fontSize: 13),
    decoration: _dropDec('Date'),
    items: ['Today', 'Yesterday', 'Custom']
        .map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(e, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (val) async {
      if (val == null) return;
      if (val == 'Today') {
        _selectedDate = DateTime.now();
        _selectedDateFilter = val;
        await _loadAttendance();
      } else if (val == 'Yesterday') {
        _selectedDate = DateTime.now().subtract(const Duration(days: 1));
        _selectedDateFilter = val;
        await _loadAttendance();
      } else {
        await _pickCustomDate();
      }
    },
  );

  // ── State Widgets ─────────────────────────────────────────────────────────
  Widget _loader() => const Center(
    child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
  );

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
          child: const Icon(Icons.group_outlined, size: 36, color: _primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'No team members found',
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

  Widget _errorWidget(String msg, VoidCallback retry) => Center(
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
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: retry,
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

// ── Summary Stat Card (reused exactly from admin screen) ──────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color, bgColor;
  final IconData icon;
  final _Screen s;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.s,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: EdgeInsets.all(s.isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(s.isMobile ? 6 : 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: s.isMobile ? 16 : 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: s.isMobile ? 16 : 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: s.captionFont,
                  color: _textMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Employee Attendance Card (Expandable) ─────────────────────────────────────
class _EmployeeAttendanceCard extends StatefulWidget {
  final AttendanceAdminModel record;
  final _Screen s;

  const _EmployeeAttendanceCard({required this.record, required this.s});

  @override
  State<_EmployeeAttendanceCard> createState() =>
      _EmployeeAttendanceCardState();
}

class _EmployeeAttendanceCardState extends State<_EmployeeAttendanceCard>
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

  Color get _statusColor {
    switch (widget.record.status.toUpperCase()) {
      case 'PRESENT':
        return _accent;
      case 'ABSENT':
        return _red;
      default:
        return _amber;
    }
  }

  Color get _statusBg {
    switch (widget.record.status.toUpperCase()) {
      case 'PRESENT':
        return const Color(0xFFECFDF5);
      case 'ABSENT':
        return const Color(0xFFFFF1F2);
      default:
        return const Color(0xFFFFFBEB);
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.record;
    final s = widget.s;
    final sc = _statusColor;
    final initial = e.name.isNotEmpty ? e.name[0].toUpperCase() : '?';
    final hasVisits = e.visits.isNotEmpty;

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
          // ── Header row ────────────────────────────────────────────────
          InkWell(
            onTap: hasVisits ? _toggle : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: s.pagePadding,
                vertical: 14,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
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
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          style: TextStyle(
                            fontSize: s.bodyFontSize,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EMP ID: ${e.empId}',
                          style: TextStyle(
                            fontSize: s.captionFont,
                            color: _textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Visit count pill
                  if (hasVisits)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${e.visits.length} visit${e.visits.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg,
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
                          e.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sc,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand chevron
                  if (hasVisits) ...[
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

          // ── Expandable visits ─────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sc.withOpacity(0.0),
                        sc.withOpacity(0.4),
                        sc.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                if (hasVisits)
                  Container(
                    color: sc.withOpacity(0.04),
                    padding: EdgeInsets.symmetric(
                      horizontal: s.pagePadding,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _summaryPill(
                          Icons.login_rounded,
                          'First In',
                          _fmt(e.inTime),
                          _accent,
                          s,
                        ),
                        const SizedBox(width: 8),
                        _summaryPill(
                          Icons.logout_rounded,
                          'Last Out',
                          _fmt(e.outTime),
                          _primary,
                          s,
                        ),
                        const SizedBox(width: 8),
                        _summaryPill(
                          Icons.timer_outlined,
                          'Total',
                          e.workedHrs ?? '--',
                          _purple,
                          s,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    s.pagePadding,
                    10,
                    s.pagePadding,
                    14,
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < e.visits.length; i++)
                        _VisitRow(
                          visit: e.visits[i],
                          index: i,
                          isLast: i == e.visits.length - 1,
                          s: s,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Absent placeholder ────────────────────────────────────────
          if (!hasVisits && e.status.toUpperCase() == 'ABSENT')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: s.pagePadding,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8F8),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 13,
                    color: _red.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'No attendance recorded for this day',
                    style: TextStyle(fontSize: 12, color: _textLight),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryPill(
    IconData icon,
    String label,
    String value,
    Color color,
    _Screen s,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
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
}

// ── Individual Visit Row ──────────────────────────────────────────────────────
class _VisitRow extends StatelessWidget {
  final SiteVisitModel visit;
  final int index;
  final bool isLast;
  final _Screen s;

  const _VisitRow({
    required this.visit,
    required this.index,
    required this.isLast,
    required this.s,
  });

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = index.isEven ? _primary.withOpacity(0.025) : Colors.transparent;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: s.isMobile ? _mobileLayout() : _desktopLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChipFixed(
    IconData icon,
    String label,
    String value,
    Color color,
  ) => SizedBox(
    width: (s.width - s.pagePadding * 2 - 40) / 3,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color.withOpacity(0.7)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  Widget _mobileLayout() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.location_on_rounded, size: 13, color: _primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              visit.locationName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _timeChipFixed(
            Icons.login_rounded,
            'In',
            _fmt(visit.inTime),
            _accent,
          ),
          _timeChipFixed(
            Icons.logout_rounded,
            'Out',
            _fmt(visit.outTime),
            _primary,
          ),
          _timeChipFixed(
            Icons.timer_outlined,
            'Worked',
            visit.workedFormatted,
            _purple,
          ),
        ],
      ),
    ],
  );

  Widget _desktopLayout() => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      const Icon(Icons.location_on_rounded, size: 14, color: _primary),
      const SizedBox(width: 6),
      SizedBox(
        width: 160,
        child: Text(
          visit.locationName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 16),
      Container(width: 1, height: 28, color: _border),
      const SizedBox(width: 16),
      _desktopCell(
        Icons.login_rounded,
        'Check In',
        _fmt(visit.inTime),
        _accent,
      ),
      const SizedBox(width: 12),
      _desktopCell(
        Icons.logout_rounded,
        'Check Out',
        _fmt(visit.outTime),
        _primary,
      ),
      const SizedBox(width: 12),
      _desktopCell(
        Icons.timer_outlined,
        'Worked',
        visit.workedFormatted,
        _purple,
      ),
    ],
  );

  Widget _desktopCell(IconData icon, String label, String value, Color color) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 6),
          Column(
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      );
}
