import 'admin_force_close_attendance_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_attendance_report.dart';
import 'package:flutter/material.dart';
import '../models/admin_hr_attendance_model.dart';
import '../services/admin_hr_attendance_service.dart';

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

// ── Main Screen ───────────────────────────────────────────────────────────────
class AdminHrAttendanceScreen extends StatefulWidget {
  final int loginId;
  const AdminHrAttendanceScreen({super.key, required this.loginId});
  @override
  State<AdminHrAttendanceScreen> createState() =>
      _AdminHrAttendanceScreenState();
}

class _AdminHrAttendanceScreenState extends State<AdminHrAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    _tabController = TabController(length: 1, vsync: this);
    _loadAttendance();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      final data = await AdminHrAttendanceService.fetchAttendance(
        _fmtApi(_selectedDate),
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

  Future<void> _openForceClose() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminForceCloseScreen(loginId: widget.loginId),
      ),
    );
    await _loadAttendance();
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
            color: Color(0x401A56DB),
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
                    const SizedBox(height: 2),
                    Text(
                      'Date: ${_displayDate(_selectedDate)}',
                      style: const TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ],
                ),
              ),
              // ── Force Close Sessions button ──────────────────────────────
              IconButton(
                tooltip: 'Close Open Sessions',
                icon: const Icon(
                  Icons.lock_clock_rounded,
                  color: Color(0xFFEF4444),
                ),
                onPressed: _openForceClose,
              ),
              IconButton(
                tooltip: 'Download Report',
                icon: const Icon(Icons.download_rounded, color: Colors.black),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAttendanceReportScreen(),
                  ),
                ),
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
                    SliverToBoxAdapter(
                      child: Container(
                        color: _card,
                        padding: EdgeInsets.symmetric(
                          horizontal: s.pagePadding,
                          vertical: 14,
                        ),
                        child: s.isMobile ? _mobileSummary(s) : _wideSummary(s),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: _card,
                        padding: EdgeInsets.symmetric(
                          horizontal: s.pagePadding,
                          vertical: 10,
                        ),
                        child: s.isMobile ? _mobileFilters() : _wideFilters(),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Divider(height: 1, thickness: 1, color: _border),
                    ),
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
                            '${_filteredRecords.length} employee${_filteredRecords.length == 1 ? '' : 's'} found',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (_filteredRecords.isEmpty)
                      SliverFillRemaining(child: _emptyState()),
                    if (_filteredRecords.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          s.pagePadding,
                          8,
                          s.pagePadding,
                          32 + MediaQuery.of(context).padding.bottom,
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

  // ── Summary Cards ─────────────────────────────────────────────────────────
  Widget _mobileSummary(_Screen s) => Row(
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
  );

  Widget _wideSummary(_Screen s) => Row(
    children: [
      _SummaryCard(
        label: 'Total',
        value: _total,
        color: _primary,
        bgColor: const Color(0xFFEEF2FF),
        icon: Icons.people_alt_rounded,
        s: s,
      ),
      const SizedBox(width: 10),
      _SummaryCard(
        label: 'Present',
        value: _present,
        color: _accent,
        bgColor: const Color(0xFFECFDF5),
        icon: Icons.check_circle_outline_rounded,
        s: s,
      ),
      const SizedBox(width: 10),
      _SummaryCard(
        label: 'Absent',
        value: _absent,
        color: _red,
        bgColor: const Color(0xFFFFF1F2),
        icon: Icons.cancel_outlined,
        s: s,
      ),
    ],
  );

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

  Widget _wideFilters() => Row(
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
            color: _primary.withValues(alpha: 0.08),
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

  Widget _errorWidget(String msg, VoidCallback retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
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

// ── Summary Stat Card ─────────────────────────────────────────────────────────
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
            color: Colors.black.withValues(alpha: 0.04),
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
    final hasSessions = e.sessions.isNotEmpty;
    final totalVisits = e.visits.length;
    final totalSessions = e.sessions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? sc.withValues(alpha: 0.35) : _border,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? sc.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
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
            onTap: hasSessions ? _toggle : null,
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
                            ? [sc, sc.withValues(alpha: 0.7)]
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
                        Row(
                          children: [
                            Text(
                              'EMP ID: ${e.empId}',
                              style: TextStyle(
                                fontSize: s.captionFont,
                                color: _textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Session / visit count pills
                  if (hasSessions) ...[
                    if (totalSessions > 1)
                      _pill(
                        '${totalSessions}x',
                        Icons.repeat_rounded,
                        _purple,
                        const Color(0xFFF5F3FF),
                      ),
                    const SizedBox(width: 6),
                    _pill(
                      '$totalVisits visit${totalVisits != 1 ? 's' : ''}',
                      Icons.location_on_rounded,
                      _primary,
                      const Color(0xFFEFF6FF),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sc.withValues(alpha: 0.3)),
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
                  if (hasSessions) ...[
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

          // ── Expandable section ────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                // Gradient divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        sc.withValues(alpha: 0.0),
                        sc.withValues(alpha: 0.4),
                        sc.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                // Overall summary strip
                if (hasSessions)
                  Container(
                    color: sc.withValues(alpha: 0.04),
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
                        if (e.isLate && e.lateText != null) ...[
                          const SizedBox(width: 8),
                          _summaryPill(
                            Icons.watch_later_outlined,
                            'Late By',
                            e.lateText!,
                            _amber,
                            s,
                          ),
                        ],
                      ],
                    ),
                  ),

                // Session blocks
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    s.pagePadding,
                    10,
                    s.pagePadding,
                    14,
                  ),
                  child: Column(
                    children: [
                      for (int si = 0; si < e.sessions.length; si++)
                        _SessionBlock(
                          session: e.sessions[si],
                          sessionIndex: si,
                          totalSessions: e.sessions.length,
                          s: s,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Absent placeholder ─────────────────────────────────────────────
          if (!hasSessions && e.status.toUpperCase() == 'ABSENT')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: s.pagePadding,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9F9),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 13,
                    color: _red.withValues(alpha: 0.5),
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

  Widget _pill(String label, IconData icon, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.15)),
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
                    color: color.withValues(alpha: 0.7),
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

// ── Session Block ─────────────────────────────────────────────────────────────
class _SessionBlock extends StatelessWidget {
  final SessionModel session;
  final int sessionIndex;
  final int totalSessions;
  final _Screen s;

  const _SessionBlock({
    required this.session,
    required this.sessionIndex,
    required this.totalSessions,
    required this.s,
  });

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _endReasonLabel(String? reason) {
    switch (reason) {
      case 'manual_end':
        return 'Ended manually';
      case 'force_logout':
        return 'Force logged out';
      case 'logout':
        return 'Logged out';
      case 'app_restart':
        return 'App restarted';
      default:
        return reason ?? 'Ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = sessionIndex == totalSessions - 1;
    final isOpen = session.endedAt == null;

    // Only show session header when there are multiple sessions
    final showSessionHeader = totalSessions > 1;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      decoration: showSessionHeader
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session header (only when multiple sessions exist)
          if (showSessionHeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Session ${session.sessionNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Session time range
                  Icon(Icons.access_time_rounded, size: 11, color: _textMid),
                  const SizedBox(width: 3),
                  Text(
                    '${_fmt(session.startedAt)} – ${_fmt(session.endedAt)}',
                    style: const TextStyle(fontSize: 11, color: _textMid),
                  ),
                  const Spacer(),
                  // Duration
                  Text(
                    session.sessionDuration,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                  // Open session indicator
                  if (isOpen) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // End reason (only for multi-session, closed sessions)
          if (showSessionHeader && !isOpen && session.endReason != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Text(
                _endReasonLabel(session.endReason),
                style: TextStyle(
                  fontSize: 10,
                  color: _textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Visit rows
          Padding(
            padding: EdgeInsets.fromLTRB(
              showSessionHeader ? 10 : 0,
              showSessionHeader ? 8 : 0,
              showSessionHeader ? 10 : 0,
              showSessionHeader ? 10 : 0,
            ),
            child: Column(
              children: [
                if (session.visits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_off_rounded,
                          size: 13,
                          color: _textLight.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No site visits recorded in this session',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textLight,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (int vi = 0; vi < session.visits.length; vi++)
                    _VisitRow(
                      visit: session.visits[vi],
                      index: vi,
                      isLast: vi == session.visits.length - 1,
                      s: s,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openMapFromVisit(
  BuildContext context,
  SiteVisitModel visit,
) async {
  double? lat = visit.latitude;
  double? lng = visit.longitude;

  // If visit has no coordinates, fetch from site polygon centroid
  if ((lat == null || lng == null) && visit.siteId != null) {
    try {
      final loc = await AdminHrAttendanceService.fetchSiteLocation(
        visit.siteId!,
      );
      lat = loc?['lat'];
      lng = loc?['lng'];
    } catch (_) {}
  }

  final Uri uri;
  if (lat != null && lng != null) {
    uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
  } else {
    uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(visit.locationName)}',
    );
  }

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  } catch (e) {
    debugPrint("Map error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Map failed to open')));
    }
  }
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
    final bg = index.isEven
        ? _primary.withValues(alpha: 0.025)
        : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(10),

      // ✅ TAP → open map
      onTap: () => openMapFromVisit(context, visit),

      // ✅ LONG PRESS → options
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text("Open in Maps"),
                onTap: () {
                  Navigator.pop(context);
                  openMapFromVisit(context, visit);
                },
              ),

              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy Coordinates"),
                onTap: () {
                  if (visit.latitude != null && visit.longitude != null) {
                    Clipboard.setData(
                      ClipboardData(
                        text: '${visit.latitude}, ${visit.longitude}',
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
      child: Container(
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
                  color: _primary.withValues(alpha: 0.25),
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
                  child: s.isMobile ? _mobileLayout(context) : _desktopLayout(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Location row
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                    GestureDetector(
                      onTap: () => openMapFromVisit(context, visit),
                      child: const Icon(
                        Icons.map_rounded,
                        size: 14,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                if (visit.latitude != null && visit.longitude != null)
                  GestureDetector(
                    onTap: () => openMapFromVisit(context, visit),
                    child: Text(
                      '${visit.latitude!.toStringAsFixed(5)}, ${visit.longitude!.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      // Time chips — separate row below location
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _timeChip(
              Icons.login_rounded,
              'In',
              _fmt(visit.inTime),
              _accent,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _timeChip(
              Icons.logout_rounded,
              'Out',
              _fmt(visit.outTime),
              _primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _timeChip(
              Icons.timer_outlined,
              'Worked',
              visit.workedFormatted,
              _purple,
            ),
          ),
        ],
      ),
    ],
  );
  Widget _timeChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.7),
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
    );
  }

  Widget _desktopLayout() => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.1),
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
              color: color.withValues(alpha: 0.08),
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
                  color: color.withValues(alpha: 0.7),
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
