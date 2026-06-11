import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../providers/api_config.dart';
import 'leave_report.dart';

// ─── Design Tokens ───────────────────────────────────────────────────────────
const _p900 = Color(0xFF1E3A8A);
const _p700 = Color(0xFF1D4ED8);
const _p500 = Color(0xFF3B82F6);
const _p100 = Color(0xFFDBEAFE);
const _p50 = Color(0xFFEFF6FF);

const _g600 = Color(0xFF16A34A);
const _g100 = Color(0xFFDCFCE7);
const _r600 = Color(0xFFDC2626);
const _r100 = Color(0xFFFEE2E2);
const _a600 = Color(0xFFD97706);
const _a100 = Color(0xFFFEF3C7);
const _v600 = Color(0xFF7C3AED);
const _v100 = Color(0xFFEDE9FE);

const _slate900 = Color(0xFF0F172A);
const _slate700 = Color(0xFF334155);
const _slate500 = Color(0xFF64748B);
const _slate300 = Color(0xFFCBD5E1);
const _slate200 = Color(0xFFE2E8F0);
const _slate100 = Color(0xFFF1F5F9);
const _slate50 = Color(0xFFF8FAFC);
const _white = Color(0xFFFFFFFF);

// ─── Model ───────────────────────────────────────────────────────────────────
class _Leave {
  final int leaveId, empId;
  final String employeeName, leaveType, finalStatus;
  final DateTime fromDate, toDate;
  final num numberOfDays;
  final String? reason,
      cancelReason,
      lastActionRemarks,
      currentApproverName,
      department;
  final int? currentApprovalLevel;
  final bool isHalfDay;
  final String? halfDayPeriod;

  const _Leave({
    required this.leaveId,
    required this.empId,
    required this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    required this.finalStatus,
    this.reason,
    this.cancelReason,
    this.lastActionRemarks,
    this.currentApproverName,
    this.currentApprovalLevel,
    required this.isHalfDay,
    this.halfDayPeriod,
    this.department,
  });

  factory _Leave.fromJson(Map<String, dynamic> j) => _Leave(
    leaveId: j['leave_id'] as int,
    empId: j['emp_id'] as int,
    employeeName: ((j['employee_name'] as String?)?.trim().isNotEmpty == true)
        ? j['employee_name'] as String
        : 'Emp #${j['emp_id']}',
    leaveType: (j['leave_name'] as String?) ?? 'Leave',
    fromDate: DateTime.parse(j['leave_start_date'] as String),
    toDate: DateTime.parse(j['leave_end_date'] as String),
    numberOfDays: num.tryParse(j['number_of_days']?.toString() ?? '') ?? 0,
    finalStatus: (j['final_status'] as String?) ?? 'Pending',
    reason: j['reason'] as String?,
    cancelReason: j['cancel_reason'] as String?,
    lastActionRemarks: j['last_action_remarks'] as String?,
    currentApproverName: j['current_approver_name'] as String?,
    currentApprovalLevel: j['current_approval_level'] as int?,
    isHalfDay: (j['is_half_day'] == 1 || j['is_half_day'] == true),
    halfDayPeriod: j['half_day_period'] as String?,
    // Map whichever field your API returns; fall back to null gracefully.
    department: (j['designation_name'] as String?)?.trim().isNotEmpty == true
        ? j['designation_name'] as String?
        : null,
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
const _months = [
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

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month]} ${d.year}';

_StatusStyle _style(String s) => switch (s) {
  'Approved' => const _StatusStyle(_g600, _g100, Icons.check_circle_rounded),
  'Rejected' => const _StatusStyle(_r600, _r100, Icons.cancel_rounded),
  'Cancelled' => const _StatusStyle(_a600, _a100, Icons.block_rounded),
  _ => const _StatusStyle(_v600, _v100, Icons.schedule_rounded),
};

class _StatusStyle {
  final Color fg, bg;
  final IconData icon;
  const _StatusStyle(this.fg, this.bg, this.icon);
}

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════
class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});
  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<_Leave> _history = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _filter = 'All';
  String _deptFilter = 'All'; // ← NEW
  bool _sortAsc = false;

  static const _filters = [
    'All',
    'Approved',
    'Rejected',
    'Pending',
    'Cancelled',
  ];

  // Derived list of unique department names present in the loaded data.
  List<String> get _departments {
    final depts =
        _history.map((l) => l.department).whereType<String>().toSet().toList()
          ..sort();
    return ['All', ...depts];
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/leave/all-history'),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true || body['success'] == true) {
          final list = (body['data'] as List)
              .map((e) => _Leave.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _history = list);
        } else {
          throw Exception(body['message'] ?? 'Server error');
        }
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Filtered + sorted list ───────────────────────────────────────────────
  List<_Leave> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _history.where((l) {
      final mq =
          q.isEmpty ||
          l.employeeName.toLowerCase().contains(q) ||
          l.leaveType.toLowerCase().contains(q) ||
          l.empId.toString().contains(q);
      final mf = _filter == 'All' || l.finalStatus == _filter;
      // Department filter: if the leave has no dept data treat it as "—"
      final md =
          _deptFilter == 'All' ||
          (l.department == _deptFilter) ||
          (_deptFilter == '—' && l.department == null);
      return mq && mf && md;
    }).toList()..sort(
      (a, b) => _sortAsc
          ? a.fromDate.compareTo(b.fromDate)
          : b.fromDate.compareTo(a.fromDate),
    );
  }

  int _count(String f) => f == 'All'
      ? _history.length
      : _history.where((l) => l.finalStatus == f).length;

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _slate50,
    body: Column(
      children: [
        _Header(
          tab: _tab,
          onRefresh: _fetchHistory,
          totalCount: _history.length,
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const NeverScrollableScrollPhysics(),
            children: [const _PendingTab(), _historyTab()],
          ),
        ),
      ],
    ),
  );

  // ─── History Tab ──────────────────────────────────────────────────────────
  Widget _historyTab() {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: _p700, strokeWidth: 2),
      );
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetchHistory);

    final list = _filtered;

    if (list.isEmpty) {
      return Column(
        children: [
          _SearchFilter(
            ctrl: _searchCtrl,
            filter: _filter,
            filters: _filters,
            count: _count,
            onFilter: (f) => setState(() => _filter = f),
            onChanged: (v) => setState(() {
              if (v.isEmpty) _searchCtrl.clear();
            }),
            deptFilter: _deptFilter,
            departments: _departments,
            onDeptFilter: (d) => setState(() => _deptFilter = d),
          ),
          Expanded(
            child: _EmptyHistory(
              hasFilter:
                  _searchCtrl.text.isNotEmpty ||
                  _filter != 'All' ||
                  _deptFilter != 'All',
              onClear: () => setState(() {
                _searchCtrl.clear();
                _filter = 'All';
                _deptFilter = 'All';
              }),
              onRefresh: _fetchHistory,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: _p700,
      child: CustomScrollView(
        slivers: [
          // ── Search + filter ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SearchFilter(
              ctrl: _searchCtrl,
              filter: _filter,
              filters: _filters,
              count: _count,
              onFilter: (f) => setState(() => _filter = f),
              onChanged: (v) => setState(() {
                if (v.isEmpty) _searchCtrl.clear();
              }),
              deptFilter: _deptFilter,
              departments: _departments,
              onDeptFilter: (d) => setState(() => _deptFilter = d),
            ),
          ),

          // ── Sort bar ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: _white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    '${list.length} of ${_history.length} records',
                    style: const TextStyle(fontSize: 11, color: _slate500),
                  ),
                  const Spacer(),
                  _SortChip(
                    asc: _sortAsc,
                    onTap: () => setState(() => _sortAsc = !_sortAsc),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: Divider(height: 1, color: _slate100)),

          // ── Cards ────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _LeaveCard(leave: list[i]),
                childCount: list.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Header
// ═════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final TabController tab;
  final VoidCallback onRefresh;
  final int totalCount;
  const _Header({
    required this.tab,
    required this.onRefresh,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: tab,
                  indicatorColor: _p700,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: _p700,
                  unselectedLabelColor: _slate500,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Pending'),
                    Tab(text: 'History'),
                  ],
                ),
              ),
              Builder(
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: 'Leave Report',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => const LeaveReportScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _p50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _p100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.bar_chart_rounded,
                              size: 16,
                              color: _p700,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Report',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _p700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: _slate100),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Stats Row  (fixed — was missing Row children)
// ═════════════════════════════════════════════════════════════════════════════
// class _StatsRow extends StatelessWidget {
//   final List<_Leave> history;
//   const _StatsRow({required this.history});

//   @override
//   Widget build(BuildContext context) {
//     final total = history.length;
//     final approved = history.where((l) => l.finalStatus == 'Approved').length;
//     final rejected = history.where((l) => l.finalStatus == 'Rejected').length;
//     final pending = history.where((l) => l.finalStatus == 'Pending').length;
//     final cancelled = history.where((l) => l.finalStatus == 'Cancelled').length;

//     final stats = [
//       _StatData('Total', '$total', _p700, _p50),
//       _StatData('Approved', '$approved', _g600, _g100),
//       _StatData('Pending', '$pending', _v600, _v100),
//       _StatData('Rejected', '$rejected', _r600, _r100),
//       _StatData('Cancelled', '$cancelled', _a600, _a100),
//     ];

//     return Container(
//       color: _white,
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: Row(
//           children: stats
//               .map(
//                 (s) => Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: _StatTile(
//                     label: s.label,
//                     value: s.value,
//                     color: s.color,
//                     bg: s.bg,
//                   ),
//                 ),
//               )
//               .toList(),
//         ),
//       ),
//     );
//   }
// }

class _StatData {
  final String label, value;
  final Color color, bg;
  const _StatData(this.label, this.value, this.color, this.bg);
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _slate500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Search + Filter  (NEW: department row added)
// ═════════════════════════════════════════════════════════════════════════════
class _SearchFilter extends StatelessWidget {
  final TextEditingController ctrl;
  final String filter;
  final List<String> filters;
  final int Function(String) count;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onChanged;

  // Department filter
  final String deptFilter;
  final List<String> departments;
  final ValueChanged<String> onDeptFilter;

  const _SearchFilter({
    required this.ctrl,
    required this.filter,
    required this.filters,
    required this.count,
    required this.onFilter,
    required this.onChanged,
    required this.deptFilter,
    required this.departments,
    required this.onDeptFilter,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: _white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search field ──────────────────────────────────────────────
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: _slate900),
          decoration: InputDecoration(
            hintText: 'Search by name, ID or leave type…',
            hintStyle: const TextStyle(color: _slate500, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: _slate500,
            ),
            suffixIcon: ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _slate500,
                    ),
                    onPressed: () {
                      ctrl.clear();
                      onChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: _slate50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _slate300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _slate300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _p500, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Status filter chips ───────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final sel = filter == f;
              final c = f == 'All'
                  ? _p700
                  : f == 'Approved'
                  ? _g600
                  : f == 'Rejected'
                  ? _r600
                  : f == 'Pending'
                  ? _v600
                  : _a600;
              final n = count(f);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilter(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? c : _white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? c : _slate300),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? _white : _slate700,
                          ),
                        ),
                        if (n > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _white.withValues(alpha: 0.25)
                                  : c.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sel ? _white : c,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Department filter row ─────────────────────────────────────
        // Only show the row when there are actual departments to filter by.
        if (departments.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.business_rounded, size: 13, color: _slate500),
              const SizedBox(width: 6),
              const Text(
                'Department',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _slate500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: departments.map((d) {
                      final sel = deptFilter == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => onDeptFilter(d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? _p700 : _white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sel ? _p700 : _slate300,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: _p700.withValues(alpha: 0.2),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: sel ? _white : _slate600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Leave Card
// ═════════════════════════════════════════════════════════════════════════════
class _LeaveCard extends StatefulWidget {
  final _Leave leave;
  const _LeaveCard({required this.leave});
  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _anim;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotate = Tween(
      begin: 0.0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.leave;
    final st = _style(l.finalStatus);
    final sameDay = _fmt(l.fromDate) == _fmt(l.toDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? st.fg.withValues(alpha: 0.3) : _slate100,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? st.fg.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: _expanded ? 16 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [st.fg, st.fg.withValues(alpha: 0.5)],
              ),
            ),
          ),

          // Main row
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: st.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: st.fg.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Text(
                        _initials(l.employeeName),
                        style: TextStyle(
                          color: st.fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name + tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.employeeName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _Tag(l.leaveType, _p700, _p50),
                            if (l.isHalfDay) ...[
                              const SizedBox(width: 5),
                              _Tag('Half Day', _a600, _a100),
                            ],
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: _slate500,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                sameDay
                                    ? _fmt(l.fromDate)
                                    : '${_fmt(l.fromDate)} – ${_fmt(l.toDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _slate500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Department badge (shown when data is available)
                        if (l.department != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.business_rounded,
                                size: 11,
                                color: _slate400,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                l.department!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _slate500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status badge + days
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: st.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: st.fg.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(st.icon, size: 11, color: st.fg),
                            const SizedBox(width: 4),
                            Text(
                              l.finalStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: st.fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _slate50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _slate200),
                        ),
                        child: Text(
                          '${l.numberOfDays}d',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns: _rotate,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded ? st.fg : _slate500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _ExpandedDetails(leave: l, st: st),
          ),
        ],
      ),
    );
  }
}

// ─── Expanded Details ────────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  final _Leave leave;
  final _StatusStyle st;
  const _ExpandedDetails({required this.leave, required this.st});

  @override
  Widget build(BuildContext context) {
    final l = leave;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: st.fg.withValues(alpha: 0.1)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.badge_outlined,
                      label: 'Employee ID',
                      value: '#${l.empId}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.layers_outlined,
                      label: 'Approval Level',
                      value: l.currentApprovalLevel != null
                          ? 'Level ${l.currentApprovalLevel}'
                          : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.calendar_today_outlined,
                      label: 'From',
                      value: _fmt(l.fromDate),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCell(
                      icon: Icons.event_outlined,
                      label: 'To',
                      value: _fmt(l.toDate),
                    ),
                  ),
                ],
              ),
              // Department info cell (shown when data present)
              if (l.department != null) ...[
                const SizedBox(height: 8),
                _InfoCell(
                  icon: Icons.business_rounded,
                  label: 'Department',
                  value: l.department!,
                ),
              ],

              if (l.reason != null && l.reason!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailTile(
                  icon: Icons.notes_rounded,
                  label: 'Reason',
                  text: l.reason!,
                  iconColor: _p700,
                  bg: _p50,
                ),
              ],
              if (l.finalStatus == 'Rejected' &&
                  l.lastActionRemarks != null &&
                  l.lastActionRemarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.do_not_disturb_on_outlined,
                  label: 'Rejection Reason',
                  text: l.lastActionRemarks!,
                  iconColor: _r600,
                  bg: _r100,
                ),
              ],
              if (l.finalStatus == 'Cancelled' &&
                  l.cancelReason != null &&
                  l.cancelReason!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel Reason',
                  text: l.cancelReason!,
                  iconColor: _a600,
                  bg: _a100,
                ),
              ],
              if (l.finalStatus == 'Pending' &&
                  l.currentApproverName != null &&
                  l.currentApproverName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.person_search_rounded,
                  label: 'Pending With',
                  text: l.currentApproverName!,
                  iconColor: _v600,
                  bg: _v100,
                ),
              ],
              if (l.finalStatus == 'Approved') ...[
                const SizedBox(height: 8),
                _DetailTile(
                  icon: Icons.verified_rounded,
                  label: 'Status',
                  text: 'This leave has been approved.',
                  iconColor: _g600,
                  bg: _g100,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Pending Placeholder
// ═════════════════════════════════════════════════════════════════════════════
// ═════════════════════════════════════════════════════════════════════════════
// Pending Approvals Tab
// ═════════════════════════════════════════════════════════════════════════════
class _PendingTab extends StatefulWidget {
  const _PendingTab();
  @override
  State<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<_PendingTab> {
  List<_Leave> _pending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/leave/pending-approvals'),
        headers: ApiConfig.headers,
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          final list = (body['data'] as List)
              .map((e) => _Leave.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _pending = list);
        } else {
          throw Exception(body['message'] ?? 'Server error');
        }
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(int leaveId) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/leave/approve/$leaveId'),
        headers: ApiConfig.headers,
        body: json.encode({'remarks': ''}),
      );
      final body = json.decode(res.body) as Map<String, dynamic>;
      _snack(body['message'] ?? 'Done', success: body['ok'] == true);
      if (body['ok'] == true) _fetch();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _reject(int leaveId) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Reject Leave',
          style: TextStyle(fontWeight: FontWeight.w800, color: _slate900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection.',
              style: TextStyle(fontSize: 13, color: _slate500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rejection remarks…',
                hintStyle: const TextStyle(color: _slate500, fontSize: 13),
                filled: true,
                fillColor: _slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _slate300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _r600, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _slate500)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _r600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/leave/reject/$leaveId'),
        headers: ApiConfig.headers,
        body: json.encode({'remarks': ctrl.text.trim()}),
      );
      final body = json.decode(res.body) as Map<String, dynamic>;
      _snack(body['message'] ?? 'Done', success: body['ok'] == true);
      if (body['ok'] == true) _fetch();
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: _white,
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
        backgroundColor: success ? _g600 : _r600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _p700, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return _ErrorView(msg: _error!, onRetry: _fetch);
    }
    if (_pending.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        color: _p700,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: _p50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: _p700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All caught up!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No pending approvals right now.',
                    style: TextStyle(fontSize: 13, color: _slate500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: _p700,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: _pending.length,
        itemBuilder: (_, i) => _PendingCard(
          leave: _pending[i],
          onApprove: () => _approve(_pending[i].leaveId),
          onReject: () => _reject(_pending[i].leaveId),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final _Leave leave;
  final VoidCallback onApprove, onReject;
  const _PendingCard({
    required this.leave,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = leave;
    final sameDay = _fmt(l.fromDate) == _fmt(l.toDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _v600.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _v600.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_v600, _v600.withValues(alpha: 0.4)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employee row
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _v100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _v600.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          _initials(l.employeeName),
                          style: const TextStyle(
                            color: _v600,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.employeeName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              _Tag(l.leaveType, _p700, _p50),
                              if (l.isHalfDay) ...[
                                const SizedBox(width: 5),
                                _Tag('Half Day', _a600, _a100),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Days badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _v100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _v600.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${l.numberOfDays}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _v600,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'days',
                            style: TextStyle(
                              fontSize: 9,
                              color: _v600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: _slate100),
                const SizedBox(height: 12),

                // Date + level info
                Row(
                  children: [
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: sameDay
                            ? _fmt(l.fromDate)
                            : '${_fmt(l.fromDate)} → ${_fmt(l.toDate)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoCell(
                        icon: Icons.layers_outlined,
                        label: 'Approval Level',
                        value: l.currentApprovalLevel != null
                            ? 'Level ${l.currentApprovalLevel}'
                            : '—',
                      ),
                    ),
                  ],
                ),

                if (l.reason != null && l.reason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailTile(
                    icon: Icons.notes_rounded,
                    label: 'Reason',
                    text: l.reason!,
                    iconColor: _p700,
                    bg: _p50,
                  ),
                ],

                const SizedBox(height: 14),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _r600,
                          side: const BorderSide(color: _r600),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _g600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Micro widgets
// ═════════════════════════════════════════════════════════════════════════════

// Add _slate400 and _slate600 used in the card dept badge
const _slate600 = Color(0xFF475569);
const _slate400 = Color(0xFF94A3B8);

class _Tag extends StatelessWidget {
  final String label;
  final Color fg, bg;
  const _Tag(this.label, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: fg.withValues(alpha: 0.2)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _slate50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _slate200),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: _slate500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: _slate500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _slate900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label, text;
  final Color iconColor, bg;
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.text,
    required this.iconColor,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: iconColor.withValues(alpha: 0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _slate900,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SortChip extends StatelessWidget {
  final bool asc;
  final VoidCallback onTap;
  const _SortChip({required this.asc, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: _slate500,
          ),
          const SizedBox(width: 4),
          Text(
            asc ? 'Oldest first' : 'Newest first',
            style: const TextStyle(
              fontSize: 11,
              color: _slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClear, onRefresh;
  const _EmptyHistory({
    required this.hasFilter,
    required this.onClear,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => onRefresh(),
    color: _p700,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: _p50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFilter ? Icons.search_off_rounded : Icons.history_rounded,
                  size: 32,
                  color: _p700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hasFilter ? 'No matching records' : 'No history yet',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _slate900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasFilter
                    ? 'Try a different search or filter'
                    : 'Processed requests will appear here',
                style: const TextStyle(fontSize: 13, color: _slate500),
              ),
              if (hasFilter) ...[
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: _p700,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
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

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: _r100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: _r600, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _slate900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _slate500),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _p700,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
