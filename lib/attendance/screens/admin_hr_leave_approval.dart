import 'package:flutter/material.dart';
import '../models/leavemodel.dart';
import '../services/leave_service.dart';
import 'admin_leave_report.dart'; // ← import the report screen
import 'holiday_management_screen.dart';

// Design Tokens — kept in sync with EmployeeProfileScreen

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

// ─────────────────────────────────────────────────────────────────────────────
class LeaveApprovalScreen extends StatefulWidget {
  final int loginId;
  const LeaveApprovalScreen({super.key, required this.loginId});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>
    with SingleTickerProviderStateMixin {
  final LeaveService _leaveService = LeaveService();
  late TabController _tabController;

  List<LeaveModel> _pendingLeaves = [];
  List<LeaveModel> _historyLeaves = [];
  bool _pendingLoading = true;
  bool _historyLoading = true;
  String? _pendingError;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() => Future.wait([_loadPending(), _loadHistory()]);

  // Search & filter state
  final TextEditingController _searchCtrl = TextEditingController();
  String _historyFilter = 'All';
  bool _historySortAsc = false;

  List<LeaveModel> get _filteredHistory {
    var list = _historyLeaves.where((l) {
      final q = _searchCtrl.text.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          (l.employeeName?.toLowerCase().contains(q) ?? false) ||
          l.leaveType.toLowerCase().contains(q) ||
          (l.departmentName?.toLowerCase().contains(q) ?? false) ||
          l.empId.toString().contains(q);

      final matchesFilter =
          _historyFilter == 'All' ||
          (_historyFilter == 'Rejected' &&
              (l.status.contains('Rejected') ||
                  l.status.contains('Not_Recommended'))) ||
          (_historyFilter == 'Pending' && l.status.contains('Pending')) ||
          (_historyFilter == 'Cancelled' && l.status == 'Cancelled') ||
          (_historyFilter == 'Approved' && l.status == 'Approved');

      return matchesSearch && matchesFilter;
    }).toList();

    list.sort(
      (a, b) => _historySortAsc
          ? a.fromDate.compareTo(b.fromDate)
          : b.fromDate.compareTo(a.fromDate),
    );
    return list;
  }

  Future<void> _loadPending() async {
    setState(() {
      _pendingLoading = true;
      _pendingError = null;
    });
    try {
      final data = await _leaveService.getAllPendingLeaves();
      if (mounted) {
        setState(() {
          _pendingLeaves = data
              .where((l) => l.status == 'Pending_Manager')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _pendingError = '$e');
    } finally {
      if (mounted) setState(() => _pendingLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final data = await _leaveService.getAllLeavesHistory();
      if (mounted) setState(() => _historyLeaves = data);
    } catch (e) {
      if (mounted) setState(() => _historyError = '$e');
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}';

  String _mon(int m) => const [
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
  ][m];

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildPendingTab(), _buildHistoryTab()],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(130),
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
                        color: _primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.approval_rounded,
                        color: _textDark,
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
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          Text(
                            'Review & manage leave requests',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: _textMid),
                          ),
                        ],
                      ),
                    ),

                    // ── Download / Report icon ──────────────────────────
                    Tooltip(
                      message: 'Leave Report',
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LeaveReportScreen(),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: _accent,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    Tooltip(
                      message: 'Holiday Calendar',
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HolidayManagementScreen(
                                loginId: widget.loginId,
                              ),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1), // _amber
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.25), // _amber
                            ),
                          ),
                          child: const Icon(
                            Icons.event_note_rounded,
                            color: Color(0xFFF59E0B), // _amber
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: _textDark),
                      onPressed: _loadPending,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              Flexible(
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  labelColor: _textDark,
                  unselectedLabelColor: _textMid,
                  tabs: [
                    _buildTab(
                      Icons.pending_actions_outlined,
                      'Pending',
                      _pendingLeaves.length,
                    ),
                    _buildTab(Icons.history_rounded, 'History', null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Tab _buildTab(IconData icon, String label, int? count) => Tab(
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

  // TAB 1 — PENDING
  Widget _buildPendingTab() {
    if (_pendingLoading) return _loader();
    if (_pendingError != null) return _error(_pendingError!, _loadPending);
    if (_pendingLeaves.isEmpty) {
      return _empty(
        icon: Icons.inbox_outlined,
        title: 'All clear!',
        subtitle: 'No pending leave requests right now.',
        onRefresh: _loadPending,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      color: _primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            itemCount: _pendingLeaves.length,
            itemBuilder: (_, i) => _PendingCard(
              leave: _pendingLeaves[i],
              fmt: _fmt,
              onApprove: (l) {
                if (l.status == 'Pending_TL') {
                  _handleLeaveAction(l, 'recommend');
                } else if (l.status == 'Pending_Manager') {
                  _handleLeaveAction(l, 'Approved');
                }
              },
              onReject: (l) => _showRejectionDialog(l),
            ),
          ),
        ),
      ),
    );
  }

  // TAB 2 — HISTORY
  Widget _buildHistoryTab() {
    if (_historyLoading) return _loader();
    if (_historyError != null) return _error(_historyError!, _loadHistory);

    return Column(
      children: [
        _buildHistorySearchBar(),
        Expanded(
          child: _filteredHistory.isEmpty
              ? _empty(
                  icon: Icons.search_off_rounded,
                  title: 'No results',
                  subtitle: 'Try a different search or filter.',
                  onRefresh: _loadHistory,
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: _primary,
                  child: LayoutBuilder(
                    builder: (ctx, cs) => cs.maxWidth >= 860
                        ? _DesktopHistory(leaves: _filteredHistory, fmt: _fmt)
                        : _MobileHistory(leaves: _filteredHistory, fmt: _fmt),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHistorySearchBar() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 13, color: _textDark),
            decoration: InputDecoration(
              hintText: 'Search employee, ID, leave type…',
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _historyFilter == 'All',
                        color: _primary,
                        onTap: () => setState(() => _historyFilter = 'All'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Approved',
                        selected: _historyFilter == 'Approved',
                        color: _accent,
                        onTap: () =>
                            setState(() => _historyFilter = 'Approved'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Rejected',
                        selected: _historyFilter == 'Rejected',
                        color: _red,
                        onTap: () =>
                            setState(() => _historyFilter = 'Rejected'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Pending',
                        selected: _historyFilter == 'Pending',
                        color: _purple,
                        onTap: () => setState(() => _historyFilter = 'Pending'),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Cancelled',
                        selected: _historyFilter == 'Cancelled',
                        color: _amber,
                        onTap: () =>
                            setState(() => _historyFilter = 'Cancelled'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _historySortAsc = !_historySortAsc),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _historySortAsc
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: _textMid,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _historySortAsc ? 'Oldest' : 'Newest',
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
          const SizedBox(height: 6),
          Text(
            '${_filteredHistory.length} of ${_historyLeaves.length} records',
            style: const TextStyle(fontSize: 11, color: _textLight),
          ),
        ],
      ),
    );
  }

  // ── Shared state widgets ──────────────────────────────────────────────────
  Widget _loader() => const Center(
    child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
  );

  Widget _error(String msg, VoidCallback retry) => Center(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRefresh,
  }) => RefreshIndicator(
    onRefresh: () async => onRefresh(),
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
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: _primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Dialogs & Actions ─────────────────────────────────────────────────────
  void _showRejectionDialog(LeaveModel leave) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.do_not_disturb_on_rounded,
                color: _red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Leave Request',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for rejection',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMid,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Briefly describe the reason…',
                hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                filled: true,
                fillColor: _surface,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMid,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              String status;
              if (leave.status == 'Pending_TL') {
                status = 'Not_Recommended_By_TL';
              } else if (leave.status == 'Pending_Manager') {
                status = 'Rejected_By_Manager';
              } else {
                status = 'Rejected_By_Manager';
              }
              _handleLeaveAction(leave, status, rejectionReason: reason);
            },
            child: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveAction(
    LeaveModel leave,
    String status, {
    String? rejectionReason,
  }) async {
    final ok = await _leaveService.managerLeaveAction(
      leaveId: leave.leaveId!,
      status: status,
      loginId: widget.loginId,
      rejectionReason: rejectionReason,
    );
    if (!mounted) return;
    final approved = status == 'Approved';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok
                  ? (approved
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded)
                  : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              ok
                  ? (approved
                        ? 'Leave approved successfully'
                        : 'Leave rejected')
                  : 'Action failed. Please try again.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: ok ? (approved ? _accent : _red) : _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
    if (ok) _loadAll();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textMid,
          ),
        ),
      ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────
class _PendingCard extends StatefulWidget {
  final LeaveModel leave;
  final String Function(DateTime) fmt;
  final void Function(LeaveModel) onApprove;
  final void Function(LeaveModel) onReject;

  const _PendingCard({
    required this.leave,
    required this.fmt,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final isPendingManager = leave.status == 'Pending_Manager';
    final insufficient =
        leave.remainingDays != null &&
        leave.remainingDays! < leave.numberOfDays;
    final accentColor = _statusColor(leave.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded ? accentColor.withValues(alpha: 0.4) : _border,
          width: _expanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _expanded
                ? accentColor.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: _expanded ? 16 : 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        (leave.employeeName ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
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
                          leave.employeeName ?? 'Employee #${leave.empId}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [leave.departmentName, leave.roleName]
                              .where((e) => e != null && e.isNotEmpty)
                              .join('  ·  '),
                          style: const TextStyle(fontSize: 12, color: _textMid),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(leave.status),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded ? accentColor : _textLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              children: [
                const Divider(height: 1, thickness: 1, color: _border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _InfoCell(
                            icon: Icons.badge_outlined,
                            label: 'Emp ID',
                            value: leave.empId.toString(),
                          ),
                          const SizedBox(width: 10),
                          _InfoCell(
                            icon: Icons.category_outlined,
                            label: 'Leave Type',
                            value: leave.leaveType,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoCell(
                            icon: Icons.calendar_today_outlined,
                            label: 'From',
                            value: widget.fmt(leave.fromDate),
                          ),
                          const SizedBox(width: 10),
                          _InfoCell(
                            icon: Icons.event_outlined,
                            label: 'To',
                            value: widget.fmt(leave.toDate),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoCell(
                            icon: Icons.today_outlined,
                            label: 'Total Days',
                            value: '${leave.numberOfDays} day(s)',
                          ),
                          const SizedBox(width: 10),
                          _InfoCell(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Balance',
                            value: '${leave.remainingDays ?? 0} remaining',
                            valueColor: insufficient ? _red : null,
                          ),
                        ],
                      ),
                      if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notes_rounded,
                                size: 14,
                                color: _textMid,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  leave.reason!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPendingManager) ...[
                  const Divider(height: 1, thickness: 1, color: _border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      children: [
                        if (insufficient) ...[
                          _Banner(
                            icon: Icons.warning_amber_rounded,
                            message:
                                'Insufficient balance — only ${leave.remainingDays} day(s) remaining',
                            color: const Color(0xFF92400E),
                            bg: const Color(0xFFFFFBEB),
                            borderColor: const Color(0xFFFCD34D),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _red,
                                side: BorderSide(
                                  color: _red.withValues(alpha: 0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 15),
                              label: const Text(
                                'Reject',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => widget.onReject(leave),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: insufficient
                                    ? _textLight
                                    : _accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 9,
                                ),
                              ),
                              icon: const Icon(Icons.check_rounded, size: 15),
                              label: const Text(
                                'Approve',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => widget.onApprove(leave),
                            ),
                          ],
                        ),
                      ],
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

// ── Mobile History ────────────────────────────────────────────────────────────
class _MobileHistory extends StatefulWidget {
  final List<LeaveModel> leaves;
  final String Function(DateTime) fmt;
  const _MobileHistory({required this.leaves, required this.fmt});

  @override
  State<_MobileHistory> createState() => _MobileHistoryState();
}

class _MobileHistoryState extends State<_MobileHistory> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: widget.leaves.length,
      itemBuilder: (_, i) {
        final l = widget.leaves[i];
        final isOpen = _expanded.contains(i);
        final accentColor = _statusColor(l.status);

        final hasAnyDetail =
            l.reason?.isNotEmpty == true ||
            l.rejectionReason?.isNotEmpty == true ||
            l.cancelReason?.isNotEmpty == true ||
            l.approvedBy?.isNotEmpty == true;

        return GestureDetector(
          onTap: hasAnyDetail
              ? () => setState(
                  () => isOpen ? _expanded.remove(i) : _expanded.add(i),
                )
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOpen ? accentColor.withValues(alpha: 0.4) : _border,
                width: isOpen ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOpen
                      ? accentColor.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: isOpen ? 14 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 4, color: accentColor),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.employeeName ?? 'Emp #${l.empId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${l.empId}  ·  '
                                    '${l.leaveType}  ·  '
                                    '${widget.fmt(l.fromDate)} – ${widget.fmt(l.toDate)}'
                                    '  ·  ${l.numberOfDays} day(s)',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _StatusBadge(l.status),
                                if (hasAnyDetail) ...[
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: isOpen ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 220),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: isOpen ? accentColor : _textLight,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: _ReasonSection(leave: l),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopHistory extends StatefulWidget {
  final List<LeaveModel> leaves;
  final String Function(DateTime) fmt;

  static const List<int> _flex = [3, 2, 3, 1, 2, 2];
  static const List<String> _headers = [
    'Employee',
    'Leave Type',
    'Duration',
    'Days',
    'Status',
    'Processed By',
  ];

  const _DesktopHistory({required this.leaves, required this.fmt});

  @override
  State<_DesktopHistory> createState() => _DesktopHistoryState();
}

class _DesktopHistoryState extends State<_DesktopHistory> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A56DB),
                        Color(0xFF1E3A8A),
                        Color(0xFF1e1b4b),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 28),
                      ...List.generate(_DesktopHistory._headers.length, (i) {
                        return Expanded(
                          flex: _DesktopHistory._flex[i],
                          child: Text(
                            _DesktopHistory._headers[i],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                ...widget.leaves.asMap().entries.map((e) {
                  final i = e.key;
                  final l = e.value;
                  final isOpen = _expanded.contains(i);
                  final accentColor = _statusColor(l.status);

                  final hasAnyDetail =
                      l.reason?.isNotEmpty == true ||
                      l.rejectionReason?.isNotEmpty == true ||
                      l.cancelReason?.isNotEmpty == true ||
                      l.approvedBy?.isNotEmpty == true;

                  return Column(
                    children: [
                      InkWell(
                        onTap: hasAnyDetail
                            ? () => setState(
                                () => isOpen
                                    ? _expanded.remove(i)
                                    : _expanded.add(i),
                              )
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isOpen
                                ? accentColor.withValues(alpha: 0.04)
                                : (i.isEven ? _card : const Color(0xFFF8FAFF)),
                            border: Border(
                              bottom: BorderSide(
                                color: isOpen
                                    ? accentColor.withValues(alpha: 0.2)
                                    : _border,
                                width: 1,
                              ),
                              left: BorderSide(
                                color: isOpen
                                    ? accentColor
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 28,
                                child: hasAnyDetail
                                    ? AnimatedRotation(
                                        turns: isOpen ? 0.5 : 0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: isOpen
                                              ? accentColor
                                              : _textLight,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[0],
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          (l.employeeName ?? '?')
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: _primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        l.employeeName ?? 'Emp #${l.empId}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[1],
                                child: Text(
                                  l.leaveType,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[2],
                                child: Text(
                                  '${widget.fmt(l.fromDate)} – ${widget.fmt(l.toDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[3],
                                child: Text(
                                  '${l.numberOfDays}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[4],
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _StatusBadge(l.status),
                                ),
                              ),
                              Expanded(
                                flex: _DesktopHistory._flex[5],
                                child: Text(
                                  l.approvedBy ?? '—',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 220),
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: isOpen
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.03),
                            border: Border(
                              bottom: const BorderSide(color: _border),
                              left: BorderSide(color: accentColor, width: 3),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(52, 12, 20, 16),
                          child: _ReasonSection(leave: l),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared micro-components ───────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'Pending_TL':
      return 'Awaiting TL';
    case 'Pending_Manager':
      return 'Awaiting Manager';
    case 'Approved':
      return 'Approved';
    case 'Rejected_By_Manager':
      return 'Rejected by Manager';
    case 'Not_Recommended_By_TL':
      return 'Not Recommended';
    case 'Cancelled':
      return 'Cancelled';
    default:
      return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'Approved':
      return _accent;
    case 'Rejected_By_Manager':
    case 'Rejected_By_TL':
      return _red;
    case 'Not_Recommended_By_TL':
      return _red;
    case 'Cancelled':
      return _amber;
    case 'Pending_Manager':
      return _purple;
    case 'Pending_TL':
    default:
      return _primary;
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _textMid),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: _textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? _textDark,
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
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color, bg, borderColor;

  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
    required this.bg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonSection extends StatelessWidget {
  final LeaveModel leave;
  const _ReasonSection({required this.leave});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (leave.reason?.isNotEmpty == true) {
      tiles.add(
        _ReasonTile(
          icon: Icons.person_outline_rounded,
          label: 'Employee Reason',
          text: leave.reason!,
          iconColor: _primary,
          iconBg: const Color(0xFFEEF2FF),
          textColor: _textDark,
        ),
      );
    }

    if (leave.status == 'Approved') {
      tiles.add(
        _ReasonTile(
          icon: Icons.verified_rounded,
          label: 'Approved by',
          text: leave.approvedBy?.isNotEmpty == true
              ? leave.approvedBy!
              : 'Manager',
          iconColor: _accent,
          iconBg: const Color(0xFFD1FAE5),
          textColor: _textDark,
        ),
      );
    }

    if (leave.status == 'Pending_TL') {
      tiles.add(
        _ReasonTile(
          icon: Icons.hourglass_top_rounded,
          label: 'Awaiting Team Lead',
          text: 'This leave request is waiting for team lead review.',
          iconColor: _primary,
          iconBg: const Color(0xFFEEF2FF),
          textColor: _textDark,
        ),
      );
    }

    if (leave.status == 'Pending_Manager') {
      tiles.add(
        _ReasonTile(
          icon: Icons.thumb_up_alt_outlined,
          label: 'Recommended by Team Lead',
          text: leave.recommendedByName?.isNotEmpty == true
              ? leave.recommendedByName!
              : 'Team lead has recommended this leave.',
          iconColor: _purple,
          iconBg: const Color(0xFFF3E8FF),
          textColor: _textDark,
        ),
      );
      tiles.add(
        _ReasonTile(
          icon: Icons.schedule_outlined,
          label: 'Awaiting Manager Approval',
          text: 'Pending final approval by the manager.',
          iconColor: _amber,
          iconBg: const Color(0xFFFFF8E1),
          textColor: const Color(0xFF92400E),
        ),
      );
    }

    if (leave.status == 'Not_Recommended_By_TL') {
      if (leave.recommendedByName?.isNotEmpty == true) {
        tiles.add(
          _ReasonTile(
            icon: Icons.supervisor_account_outlined,
            label: 'Not Recommended by',
            text: leave.recommendedByName!,
            iconColor: _red,
            iconBg: const Color(0xFFFEE2E2),
            textColor: _textDark,
          ),
        );
      }
      tiles.add(
        _ReasonTile(
          icon: Icons.thumb_down_alt_outlined,
          label: 'Reason',
          text: leave.rejectionReason?.isNotEmpty == true
              ? leave.rejectionReason!
              : 'No reason provided.',
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }

    if (leave.status == 'Rejected_By_Manager') {
      if (leave.approvedBy?.isNotEmpty == true) {
        tiles.add(
          _ReasonTile(
            icon: Icons.manage_accounts_outlined,
            label: 'Rejected by',
            text: leave.approvedBy!,
            iconColor: _red,
            iconBg: const Color(0xFFFEE2E2),
            textColor: _textDark,
          ),
        );
      }
      tiles.add(
        _ReasonTile(
          icon: Icons.do_not_disturb_on_outlined,
          label: 'Rejection Reason',
          text: leave.rejectionReason?.isNotEmpty == true
              ? leave.rejectionReason!
              : 'No reason provided.',
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }

    if (leave.status == 'Rejected_By_HR') {
      if (leave.approvedBy?.isNotEmpty == true) {
        tiles.add(
          _ReasonTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Rejected by',
            text: leave.approvedBy!,
            iconColor: _red,
            iconBg: const Color(0xFFFEE2E2),
            textColor: _textDark,
          ),
        );
      }
      tiles.add(
        _ReasonTile(
          icon: Icons.do_not_disturb_on_outlined,
          label: 'Rejection Reason',
          text: leave.rejectionReason?.isNotEmpty == true
              ? leave.rejectionReason!
              : 'No reason provided.',
          iconColor: _red,
          iconBg: const Color(0xFFFEE2E2),
          textColor: _red,
        ),
      );
    }

    if (leave.status == 'Cancelled') {
      tiles.add(
        _ReasonTile(
          icon: Icons.cancel_outlined,
          label: 'Cancelled by Employee',
          text: leave.cancelReason?.isNotEmpty == true
              ? leave.cancelReason!
              : 'No reason provided.',
          iconColor: _amber,
          iconBg: const Color(0xFFFFF8E1),
          textColor: const Color(0xFF92400E),
        ),
      );
    }

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: LayoutBuilder(
        builder: (ctx, cs) {
          final isDesktop = cs.maxWidth > 500;
          if (isDesktop) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: tiles
                  .map(
                    (t) => SizedBox(
                      width:
                          (cs.maxWidth - (tiles.length > 1 ? 10 : 0)) /
                          (tiles.length > 2
                              ? 3
                              : tiles.length > 1
                              ? 2
                              : 1),
                      child: t,
                    ),
                  )
                  .toList(),
            );
          }
          return Column(
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                tiles[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color iconColor;
  final Color iconBg;
  final Color textColor;

  const _ReasonTile({
    required this.icon,
    required this.label,
    required this.text,
    required this.iconColor,
    required this.iconBg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: iconBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textColor,
                    height: 1.45,
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
