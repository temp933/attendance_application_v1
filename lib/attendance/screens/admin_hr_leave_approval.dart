import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../providers/api_config.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _primaryLight = Color(0xFFEEF2FF);
const Color _accent = Color(0xFF0E9F6E);
const Color _accentLight = Color(0xFFECFDF5);
const Color _purple = Color(0xFF7C3AED);
const Color _purpleLight = Color(0xFFF3E8FF);
const Color _amber = Color(0xFFF59E0B);
const Color _amberLight = Color(0xFFFFFBEB);
const Color _red = Color(0xFFEF4444);
const Color _redLight = Color(0xFFFFF1F2);
const Color _surface = Color(0xFFF8FAFC);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

// ─── Inline data model ──────────────────────────────────────────────────────
class _Leave {
  final int leaveId;
  final int empId;
  final String employeeName;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final num numberOfDays;
  final String finalStatus;
  final String? reason;
  final String? cancelReason;
  final String? lastActionRemarks;
  final String? currentApproverName;
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
  );
}

// ─── Status helpers ──────────────────────────────────────────────────────────
Color _statusColor(String s) => s == 'Approved'
    ? _accent
    : s == 'Rejected'
    ? _red
    : s == 'Cancelled'
    ? _amber
    : _purple;
Color _statusBg(String s) => s == 'Approved'
    ? _accentLight
    : s == 'Rejected'
    ? _redLight
    : s == 'Cancelled'
    ? _amberLight
    : _purpleLight;
IconData _statusIcon(String s) => s == 'Approved'
    ? Icons.check_circle_rounded
    : s == 'Rejected'
    ? Icons.cancel_rounded
    : s == 'Cancelled'
    ? Icons.block_rounded
    : Icons.schedule_rounded;

String _fmt(DateTime d) {
  const m = [
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
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════
class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});
  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<_Leave> _history = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = 'All';
  bool _sortAsc = false;

  static const _filterOptions = [
    'All',
    'Approved',
    'Rejected',
    'Pending',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory(); // ApiConfig.headers already has token+tenant loaded by app boot
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── HTTP ─────────────────────────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/leave/all-history');
      // ApiConfig.headers already contains:
      //   Content-Type, ngrok-skip-browser-warning, x-tenant-id, x-employee-id, Authorization
      final resp = await http.get(uri, headers: ApiConfig.headers);

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        // backend send() uses `ok`; accept `success` too for safety
        final isOk = (body['ok'] == true) || (body['success'] == true);
        if (isOk) {
          final raw = body['data'] as List<dynamic>;
          final list = raw
              .map((e) => _Leave.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _history = list);
        } else {
          throw Exception(body['message'] ?? 'Server returned ok=false');
        }
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────
  List<_Leave> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    var list = _history.where((l) {
      final matchQ =
          q.isEmpty ||
          l.employeeName.toLowerCase().contains(q) ||
          l.leaveType.toLowerCase().contains(q) ||
          l.empId.toString().contains(q);
      final matchF = _filter == 'All' || l.finalStatus == _filter;
      return matchQ && matchF;
    }).toList();
    list.sort(
      (a, b) => _sortAsc
          ? a.fromDate.compareTo(b.fromDate)
          : b.fromDate.compareTo(a.fromDate),
    );
    return list;
  }

  int _countFor(String f) => f == 'All'
      ? _history.length
      : _history.where((l) => l.finalStatus == f).length;

  // ═════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: _appBar(),
    body: TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [_pendingTab(), _historyTab()],
    ),
  );

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() => PreferredSize(
    preferredSize: const Size.fromHeight(120),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x201A56DB),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.approval_rounded,
                      color: _primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Leave Approval',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          'Review & manage leave requests',
                          style: TextStyle(fontSize: 11, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    color: _textDark,
                    bg: _surface,
                    tooltip: 'Refresh',
                    onTap: _fetchHistory,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: TabBar(
                controller: _tabController,
                indicatorColor: _primary,
                labelColor: _primary,
                unselectedLabelColor: _textMid,
                tabs: [
                  _tab(Icons.pending_actions_outlined, 'Pending', null),
                  _tab(
                    Icons.history_rounded,
                    'History',
                    _history.isNotEmpty ? _history.length : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Tab _tab(IconData icon, String label, int? count) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
        if (count != null && count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  // ═════════════════════════════════════════════════════════════════════════
  // TAB 1 — PENDING PLACEHOLDER
  // ═════════════════════════════════════════════════════════════════════════
  Widget _pendingTab() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
              border: Border.all(
                color: _primary.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  size: 56,
                  color: _primary.withValues(alpha: 0.25),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pending approval actions are being\nrevamped with a better experience.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textMid, height: 1.5),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(child: Divider(color: _border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'In the meantime',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: _border)),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _tabController.animateTo(1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'View History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          Text(
                            'Browse all processed leave requests',
                            style: TextStyle(fontSize: 12, color: _textMid),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: _textLight,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ═════════════════════════════════════════════════════════════════════════
  // TAB 2 — HISTORY
  // ═════════════════════════════════════════════════════════════════════════
  Widget _historyTab() {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
      );
    if (_error != null)
      return _ErrorView(message: _error!, onRetry: _fetchHistory);

    final list = _filtered;
    return Column(
      children: [
        _searchAndFilter(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Text(
                '${list.length} of ${_history.length} records',
                style: const TextStyle(fontSize: 11, color: _textLight),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _sortAsc = !_sortAsc),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _sortAsc
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: _textMid,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortAsc ? 'Oldest first' : 'Newest first',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _textMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyHistory()
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  color: _primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _HistoryCard(leave: list[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _searchAndFilter() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Search by name, ID, or leave type…',
            hintStyle: const TextStyle(color: _textLight, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: _textMid,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _textMid,
                    ),
                    onPressed: () => setState(() => _searchCtrl.clear()),
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
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
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((f) {
              final count = _countFor(f);
              final selected = _filter == f;
              final chip = f == 'All'
                  ? _primary
                  : f == 'Approved'
                  ? _accent
                  : f == 'Rejected'
                  ? _red
                  : f == 'Pending'
                  ? _purple
                  : _amber;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? chip : _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? chip : _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : _textMid,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : chip.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : chip,
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
      ],
    ),
  );

  Widget _emptyHistory() {
    final any = _searchCtrl.text.isNotEmpty || _filter != 'All';
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: _primary,
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
                    color: _primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    any ? Icons.search_off_rounded : Icons.history_rounded,
                    size: 36,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  any ? 'No matching records' : 'No history yet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  any
                      ? 'Try a different search or filter'
                      : 'Processed leave requests will appear here',
                  style: const TextStyle(fontSize: 13, color: _textMid),
                ),
                if (any) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _filter = 'All';
                    }),
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Clear filters'),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
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
}

// ═══════════════════════════════════════════════════════════════════════════
// _HistoryCard
// ═══════════════════════════════════════════════════════════════════════════
class _HistoryCard extends StatefulWidget {
  final _Leave leave;
  const _HistoryCard({required this.leave});
  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.leave;
    final color = _statusColor(l.finalStatus);
    final bg = _statusBg(l.finalStatus);
    final icon = _statusIcon(l.finalStatus);
    final sameDay = _fmt(l.fromDate) == _fmt(l.toDate);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? color.withValues(alpha: 0.35) : _border,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? color.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: _expanded ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 3, color: color),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        l.employeeName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
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
                            color: _textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _primaryLight,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                l.leaveType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: _textLight,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                sameDay
                                    ? _fmt(l.fromDate)
                                    : '${_fmt(l.fromDate)} – ${_fmt(l.toDate)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 11, color: color),
                            const SizedBox(width: 4),
                            Text(
                              l.finalStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          '${l.numberOfDays}d',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _textMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded ? color : _textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _expandedDetails(l, color),
          ),
        ],
      ),
    );
  }

  Widget _expandedDetails(_Leave l, Color accentColor) => Column(
    children: [
      Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Cell(
                    icon: Icons.badge_outlined,
                    label: 'Emp ID',
                    value: '${l.empId}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Cell(
                    icon: Icons.approval_rounded,
                    label: 'Approval Level',
                    value: l.currentApprovalLevel != null
                        ? 'Level ${l.currentApprovalLevel}'
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Cell(
                    icon: Icons.calendar_today_outlined,
                    label: 'From',
                    value: _fmt(l.fromDate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Cell(
                    icon: Icons.event_outlined,
                    label: 'To',
                    value: _fmt(l.toDate),
                  ),
                ),
              ],
            ),
            if (l.isHalfDay) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _amberLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Half Day${l.halfDayPeriod != null ? ' · ${l.halfDayPeriod}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _amber,
                  ),
                ),
              ),
            ],
            if (l.reason != null && l.reason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Tile(
                icon: Icons.notes_rounded,
                label: 'Reason',
                text: l.reason!,
                iconColor: _primary,
                bg: _primaryLight,
              ),
            ],
            if (l.finalStatus == 'Rejected' &&
                l.lastActionRemarks != null &&
                l.lastActionRemarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.do_not_disturb_on_outlined,
                label: 'Rejection Reason',
                text: l.lastActionRemarks!,
                iconColor: _red,
                bg: _redLight,
              ),
            ],
            if (l.finalStatus == 'Cancelled' &&
                l.cancelReason != null &&
                l.cancelReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.cancel_outlined,
                label: 'Cancel Reason',
                text: l.cancelReason!,
                iconColor: _amber,
                bg: _amberLight,
              ),
            ],
            if (l.finalStatus == 'Pending' &&
                l.currentApproverName != null &&
                l.currentApproverName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.person_search_rounded,
                label: 'Pending With',
                text: l.currentApproverName!,
                iconColor: _purple,
                bg: _purpleLight,
              ),
            ],
            if (l.finalStatus == 'Approved') ...[
              const SizedBox(height: 8),
              _Tile(
                icon: Icons.verified_rounded,
                label: 'Status',
                text: 'This leave has been approved.',
                iconColor: _accent,
                bg: _accentLight,
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

// ─── Micro-widgets ──────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.tooltip,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Cell({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: _textMid),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
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

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label, text;
  final Color iconColor, bg;
  const _Tile({
    required this.icon,
    required this.label,
    required this.text,
    required this.iconColor,
    required this.bg,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: bg.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: iconColor.withValues(alpha: 0.18)),
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
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _textDark,
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
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
              color: _redLight,
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
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
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
