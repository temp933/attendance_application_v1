  import 'package:collection/collection.dart';
  import 'dart:convert';
  import 'package:flutter/material.dart';
  import 'package:intl/intl.dart';
  import '../providers/api_client.dart';
  import 'holiday_management_screen.dart'; //HolidayManagementScreen(canEdit: false),

  // ─── Color palette ─────────────────────────────────────────────────────────
  const _primary = Color(0xFF1A56DB);
  const _primaryLight = Color(0xFFEEF2FF);
  const _accent = Color(0xFF0E9F6E);
  const _accentLight = Color(0xFFECFDF5);
  const _red = Color(0xFFEF4444);
  const _redLight = Color(0xFFFFF1F2);
  const _amber = Color(0xFFF59E0B);
  const _amberLight = Color(0xFFFFFBEB);
  const _surface = Color(0xFFF8FAFC);
  const _textDark = Color(0xFF0F172A);
  const _textMid = Color(0xFF64748B);
  const _textLight = Color(0xFF94A3B8);
  const _border = Color(0xFFE2E8F0);

  // ─── Layout constants ───────────────────────────────────────────────────────
  const double _kMaxContentWidth = 960.0; // max width for desktop content
  const double _kDesktopBreak = 720.0; // switch to 2-col cards above this

  // ─── Date helpers ───────────────────────────────────────────────────────────
  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _fmtFull(String? s) {
    if (s == null) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return s;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // LeaveScreen
  // ══════════════════════════════════════════════════════════════════════════════
  class LeaveScreen extends StatefulWidget {
    const LeaveScreen({super.key});

    @override
    State<LeaveScreen> createState() => _LeaveScreenState();
  }

  class _LeaveScreenState extends State<LeaveScreen>
      with SingleTickerProviderStateMixin {
    List<Map<String, dynamic>> _leaves = [];
    List<Map<String, dynamic>> _leaveTypes = [];
    bool _loading = true;
    String? _error;

    late final AnimationController _animCtrl;
    late final Animation<double> _fadeAnim;

    @override
    void initState() {
      super.initState();
      _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 450),
      );
      _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
      _load();
    }

    @override
    void dispose() {
      _animCtrl.dispose();
      super.dispose();
    }

    Future<void> _load() async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final results = await Future.wait([
          ApiClient.get('/leave/my-leaves'),
          ApiClient.get('/leave/policy/list'),
        ]);
        final leavesRes = results[0];
        final typesRes = results[1];

        if (leavesRes.statusCode == 200) {
          final body = jsonDecode(leavesRes.body) as Map<String, dynamic>;
          if (body['ok'] == true) {
            setState(
              () => _leaves = List<Map<String, dynamic>>.from(body['data'] ?? []),
            );
            _animCtrl.forward(from: 0);
          }
        }
        if (typesRes.statusCode == 200) {
          final body = jsonDecode(typesRes.body) as Map<String, dynamic>;
          if (body['ok'] == true) {
            setState(
              () => _leaveTypes = List<Map<String, dynamic>>.from(
                body['data'] ?? [],
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _error = 'Unable to load data. Check your connection.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    int get _total => _leaves.length;
    int get _pending =>
        _leaves.where((l) => l['final_status'] == 'Pending').length;
    int get _approved =>
        _leaves.where((l) => l['final_status'] == 'Approved').length;
    int get _cancelled =>
        _leaves.where((l) => l['final_status'] == 'Cancelled').length;

    int get _rejected =>
        _leaves.where((l) => l['final_status'] == 'Rejected').length;

    bool _canCancel(Map<String, dynamic> leave) {
      final status = leave['final_status'] as String? ?? '';
      if (status == 'Cancelled' || status == 'Rejected') return false;
      if (status == 'Approved') {
        try {
          final start = DateTime.parse(leave['leave_start_date']);
          return start.isAfter(DateTime.now());
        } catch (_) {
          return false;
        }
      }
      return true;
    }

    @override
    Widget build(BuildContext context) {
      final screenW = MediaQuery.of(context).size.width;
      final isDesktop = screenW >= _kDesktopBreak;

      return Scaffold(
        backgroundColor: _surface,
        floatingActionButton: _loading ? null : _buildFAB(),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(
                color: _primary,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(child: _buildStatsBar()),
                    _leaves.isEmpty
                        ? SliverToBoxAdapter(child: const _EmptyState())
                        : _buildLeaveList(isDesktop),
                  ],
                ),
              ),
      );
    }

    // ── App Bar ───────────────────────────────────────────────────────────────
    Widget _buildAppBar() {
      return SliverToBoxAdapter(
        child: Container(
          color: _surface,
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 12,
            16,
            8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            ),
          ),
        ),
      );
    }

    // ── Stats Bar ─────────────────────────────────────────────────────────────
    Widget _buildStatsBar() {
      return Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  _StatItem(value: '$_total', label: 'Total', color: _primary),
                  _StatDivider(),
                  _StatItem(
                    value: '$_approved',
                    label: 'Approved',
                    color: _accent,
                  ),
                  _StatDivider(),
                  _StatItem(value: '$_pending', label: 'Pending', color: _amber),
                  _StatDivider(),
                  _StatItem(
                    value: '$_cancelled',
                    label: 'Cancelled',
                    color: _textMid,
                  ),
                  _StatDivider(),
                  _StatItem(value: '$_rejected', label: 'Rejected', color: _red),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── Leave List / Grid ─────────────────────────────────────────────────────
    Widget _buildLeaveList(bool isDesktop) {
      if (isDesktop) {
        // Two-column grid on desktop
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _buildTwoColGrid(),
                ),
              ),
            ),
          ),
        );
      }

      // Single column on mobile
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => FadeTransition(
              opacity: _fadeAnim,
              child: _LeaveCard(
                leave: _leaves[i],
                onCancel: _canCancel(_leaves[i])
                    ? () => _confirmCancel(_leaves[i])
                    : null,
              ),
            ),
            childCount: _leaves.length,
          ),
        ),
      );
    }

    Widget _buildTwoColGrid() {
      final rows = <Widget>[];
      for (int i = 0; i < _leaves.length; i += 2) {
        final left = _leaves[i];
        final right = i + 1 < _leaves.length ? _leaves[i + 1] : null;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LeaveCard(
                    leave: left,
                    onCancel: _canCancel(left)
                        ? () => _confirmCancel(left)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: right != null
                      ? _LeaveCard(
                          leave: right,
                          onCancel: _canCancel(right)
                              ? () => _confirmCancel(right)
                              : null,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Column(children: rows);
    }

    // ── FAB ───────────────────────────────────────────────────────────────────
    // ── FAB ───────────────────────────────────────────────────────────────────
    Widget _buildFAB() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab_holidays',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HolidayManagementScreen(canEdit: false),
              ),
            ),
            icon: const Icon(Icons.celebration_rounded, color: _primary),
            label: const Text(
              'Holidays',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _primary.withOpacity(0.3)),
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab_apply',
            backgroundColor: _primary,
            elevation: 4,
            onPressed: _openApplySheet,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Apply Leave',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      );
    }

    // ── Dialogs / Sheets ──────────────────────────────────────────────────────
    void _confirmCancel(Map<String, dynamic> leave) {
      final ctrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Cancel Leave',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide a reason for cancellation.',
                style: TextStyle(color: _textMid, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Reason…',
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: _textMid)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _cancelLeave(leave['leave_id'], ctrl.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }

    Future<void> _cancelLeave(int leaveId, String reason) async {
      try {
        final res = await ApiClient.post('/leave/cancel/$leaveId', {
          'cancel_reason': reason,
        });
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _snack(body['message'] ?? 'Done', success: body['ok'] == true);
        if (body['ok'] == true) _load();
      } catch (e) {
        _snack('Error: $e');
      }
    }

    void _openApplySheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ApplyLeaveSheet(
          leaveTypes: _leaveTypes,
          onSuccess: (msg) {
            _load();
            _snack(msg, success: true);
          },
        ),
      );
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
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // _LeaveCard
  // ══════════════════════════════════════════════════════════════════════════════
  class _LeaveCard extends StatefulWidget {
    final Map<String, dynamic> leave;
    final VoidCallback? onCancel;
    const _LeaveCard({required this.leave, this.onCancel});

    @override
    State<_LeaveCard> createState() => _LeaveCardState();
  }

  class _LeaveCardState extends State<_LeaveCard> {
    bool _expanded = false;

    static const _statusCfg = <String, Map<String, dynamic>>{
      'Pending': {
        'label': 'Pending',
        'color': _amber,
        'bg': _amberLight,
        'icon': Icons.schedule_rounded,
      },
      'Approved': {
        'label': 'Approved',
        'color': _accent,
        'bg': _accentLight,
        'icon': Icons.check_circle_rounded,
      },
      'Rejected': {
        'label': 'Rejected',
        'color': _red,
        'bg': _redLight,
        'icon': Icons.cancel_rounded,
      },
      'Cancelled': {
        'label': 'Cancelled',
        'color': _textLight,
        'bg': _surface,
        'icon': Icons.block_rounded,
      },
    };

    Map<String, dynamic> get _cfg {
      final status = widget.leave['final_status'] as String? ?? '';
      return _statusCfg[status] ??
          {
            'label': status,
            'color': _textLight,
            'bg': _surface,
            'icon': Icons.help_outline,
          };
    }

    @override
    Widget build(BuildContext context) {
      final leave = widget.leave;
      final cfg = _cfg;
      final statusColor = cfg['color'] as Color;
      final statusBg = cfg['bg'] as Color;

      DateTime? startDt, endDt;
      try {
        startDt = DateTime.parse(leave['leave_start_date']);
        endDt = DateTime.parse(leave['leave_end_date']);
      } catch (_) {}

      final sameDay =
          startDt != null && endDt != null && _fmt(startDt) == _fmt(endDt);
      final days = leave['number_of_days'];
      final daysStr = days is num
          ? (days % 1 == 0 ? '${days.toInt()}d' : '${days.toStringAsFixed(1)}d')
          : '$days d';

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16), // spacing handled by parent
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? statusColor.withOpacity(0.35) : _border,
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_expanded ? 0.07 : 0.04),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Status accent strip
            Container(height: 3, color: statusColor),

            // Card header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    // Icon box
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + dates
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${leave['leave_name'] ?? 'Leave'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: _textLight,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  startDt == null
                                      ? '-'
                                      : sameDay
                                      ? _fmt(startDt)
                                      : '${_fmt(startDt)}  →  ${_fmt(endDt!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryLight,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  daysStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cfg['icon'] as IconData,
                            size: 12,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cfg['label'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textLight,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded details
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpanded(leave, statusColor),
            ),
          ],
        ),
      );
    }

    Widget _buildExpanded(Map<String, dynamic> leave, Color statusColor) {
      return Column(
        children: [
          Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.comment_outlined,
                  label: 'Reason',
                  value: leave['reason'] ?? '-',
                ),
                if ((leave['current_approver_name'] ?? '')
                        .toString()
                        .isNotEmpty &&
                    leave['final_status'] == 'Pending') ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.person_search_rounded,
                    label: 'Pending With',
                    value: leave['current_approver_name'],
                    valueColor: _amber,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.account_tree_outlined,
                    label: 'Approval Level',
                    value: 'Level ${leave['current_approval_level'] ?? 1}',
                    valueColor: _amber,
                  ),
                ],
                if ((leave['last_action_remarks'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.note_alt_outlined,
                    label: 'Approver Remarks',
                    value: leave['last_action_remarks'],
                  ),
                ],
                if ((leave['cancel_reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.block_rounded,
                    label: 'Cancel Reason',
                    value: leave['cancel_reason'],
                    valueColor: _red,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniDetail(
                        'Applied',
                        _fmtFull(leave['created_at']),
                      ),
                    ),
                    Expanded(
                      child: _MiniDetail(
                        'Updated',
                        _fmtFull(leave['updated_at']),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _OutlineBtn(
                      label: 'View Details',
                      icon: Icons.info_outline_rounded,
                      color: _primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              LeaveDetailsScreen(leaveId: leave['leave_id']),
                        ),
                      ),
                    ),
                    if (widget.onCancel != null) ...[
                      const SizedBox(width: 8),
                      _OutlineBtn(
                        label: 'Cancel',
                        icon: Icons.close_rounded,
                        color: _red,
                        onTap: widget.onCancel!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Apply Leave Bottom Sheet
  // ══════════════════════════════════════════════════════════════════════════════
  class _ApplyLeaveSheet extends StatefulWidget {
    final List<Map<String, dynamic>> leaveTypes;
    final void Function(String message) onSuccess;
    const _ApplyLeaveSheet({required this.leaveTypes, required this.onSuccess});

    @override
    State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
  }

  class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
    Map<String, dynamic>? _selectedType;
    DateTime? _fromDate;
    DateTime? _toDate;
    bool _isHalfDay = false;
    String? _halfDayPeriod;
    final _reasonCtrl = TextEditingController();
    bool _submitting = false;

    // ── Comp-off state ─────────────────────────────────────────────────────────
    bool _useCompOff = false;
    List<Map<String, dynamic>> _compOffs = [];
    bool _loadingCompOffs = true;
    Map<String, dynamic>? _attendancePolicy;
    List<String> _holidayDates = [];
    Map<String, dynamic>? get _compOffType => widget.leaveTypes.firstWhereOrNull(
      (lt) => (lt['leave_code'] as String? ?? '').toUpperCase() == 'COMP_OFF',
    );
    static const _teal = Color(0xFF0F766E);
    static const _tealLight = Color(0xFFECFDF5);

    @override
    void initState() {
      super.initState();
      _fetchCompOffs();
      _fetchAttendancePolicy();
    }

    @override
    void dispose() {
      _reasonCtrl.dispose();
      super.dispose();
    }

    Future<void> _fetchAttendancePolicy() async {
      try {
        final now = DateTime.now();
        // Fetch current year and next year to cover cross-year ranges
        final results = await Future.wait([
          ApiClient.get('/attendance/policy'),
          ApiClient.get('/holidays?year=${now.year}'),
          ApiClient.get('/holidays?year=${now.year + 1}'),
        ]);

        if (!mounted) return;

        // Policy
        final policyBody = jsonDecode(results[0].body) as Map<String, dynamic>;
        if (policyBody['ok'] == true) {
          setState(
            () => _attendancePolicy = policyBody['data'] as Map<String, dynamic>?,
          );
        }

        // Holidays — combine both year responses
        final allHolidays = <String>[];
        for (final res in [results[1], results[2]]) {
          if (res.statusCode == 200) {
            final body = jsonDecode(res.body) as Map<String, dynamic>;
            if (body['success'] == true) {
              final rows = List<Map<String, dynamic>>.from(body['data'] ?? []);
              for (final h in rows) {
                final raw = h['holiday_date'] as String?;
                if (raw != null) {
                  // Normalize to "YYYY-MM-DD"
                  try {
                    allHolidays.add(
                      DateTime.parse(raw).toIso8601String().split('T')[0],
                    );
                  } catch (_) {}
                }
              }
            }
          }
        }
        if (mounted) setState(() => _holidayDates = allHolidays);
      } catch (_) {
        // non-fatal
      }
    }

    Future<void> _fetchCompOffs() async {
      try {
        final res = await ApiClient.get('/leave/available-compoffs');
        if (!mounted) return;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          setState(() {
            _compOffs = List<Map<String, dynamic>>.from(body['data'] ?? []);
          });
        }
      } catch (_) {
        // non-fatal — comp-off section just won't show
      } finally {
        if (mounted) setState(() => _loadingCompOffs = false);
      }
    }

    // Max days allowed when using comp-off = number of earned comp-offs
    int get _compOffMaxDays => _compOffs.length;

    int get _days {
      if (_isHalfDay || _fromDate == null || _toDate == null) return 0;
      final policy = _attendancePolicy;
      final skipSat = policy?['is_saturday_weekoff'] == 1;
      final skipSun = policy?['is_sunday_weekoff'] == 1;
      final holidaySet = _holidayDates.toSet();

      int count = 0;
      DateTime it = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);

      while (!it.isAfter(end)) {
        final w = it.weekday;
        final dateStr =
            '${it.year.toString().padLeft(4, '0')}'
            '-${it.month.toString().padLeft(2, '0')}'
            '-${it.day.toString().padLeft(2, '0')}';

        final isWeekend =
            (skipSun && w == DateTime.sunday) ||
            (skipSat && w == DateTime.saturday);
        final isHoliday = holidaySet.contains(dateStr);

        if (!isWeekend && !isHoliday) count++;
        it = it.add(const Duration(days: 1));
      }
      return count;
    }

    void _snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    void _onToggleCompOff(bool val) {
      setState(() {
        _useCompOff = val;
        _fromDate = null;
        _toDate = null;
        _isHalfDay = false;
        _halfDayPeriod = null;
        _selectedType = val ? _compOffType : null;
      });
    }

    Future<void> _submit() async {
      if (_selectedType == null) return _snack('Please select a leave type');
      if (_fromDate == null) return _snack('Please select a start date');
      if (_toDate == null) return _snack('Please select an end date');
      if (_reasonCtrl.text.trim().isEmpty) return _snack('Reason is required');
      if (_isHalfDay && _halfDayPeriod == null)
        return _snack('Please select AM or PM for half day');
      if (!_isHalfDay && _days == 0)
        return _snack('Selected range has no working days');

      // Comp-off guard: days requested must not exceed available comp-offs
      if (_useCompOff && _days > _compOffMaxDays) {
        return _snack(
          'You only have $_compOffMaxDays comp-off${_compOffMaxDays == 1 ? '' : 's'} '
          'available. Please reduce the date range.',
        );
      }

      setState(() => _submitting = true);
      try {
        final body = <String, dynamic>{
          'leave_type_id': _selectedType!['leave_type_id'],
          'leave_start_date': DateFormat('yyyy-MM-dd').format(_fromDate!),
          'leave_end_date': DateFormat('yyyy-MM-dd').format(_toDate!),
          'is_half_day': _isHalfDay,
          'half_day_period': _isHalfDay ? _halfDayPeriod : null,
          'reason': _reasonCtrl.text.trim(),
        };

        final res = await ApiClient.post('/leave/apply', body);
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        if (data['ok'] != true) {
          _snack(data['message'] ?? 'Submission failed');
          return;
        }

        final approvalLevels = data['approval_levels'];
        final msg = (approvalLevels != null && approvalLevels > 0)
            ? 'Leave applied — pending $approvalLevels level${approvalLevels == 1 ? '' : 's'} of approval'
            : data['message'] ?? 'Leave applied successfully';

        if (mounted) Navigator.pop(context);
        widget.onSuccess(msg);
      } catch (e) {
        _snack('Error: $e');
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      final screenW = MediaQuery.of(context).size.width;
      final isWide = screenW >= _kDesktopBreak;

      final sheetContent = Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isWide
              ? BorderRadius.circular(24)
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: _primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apply for Leave',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        'Fill in the leave details below',
                        style: TextStyle(fontSize: 13, color: _textMid),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Comp-off banner ───────────────────────────────────────────
              if (!_loadingCompOffs && _compOffs.isNotEmpty) ...[
                _buildCompOffBanner(),
                const SizedBox(height: 20),
              ],

              // ── Leave type ────────────────────────────────────────────────
              if (!_useCompOff) ...[
                const _FieldLabel('Leave Type *'),
                const SizedBox(height: 10),
                widget.leaveTypes.isEmpty
                    ? const Text(
                        'No leave types configured.',
                        style: TextStyle(color: _textMid),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.leaveTypes
                            .where((t) {
                              final code = (t['leave_code'] as String? ?? '')
                                  .toUpperCase();
                              final name = (t['leave_name'] as String? ?? '')
                                  .trim();
                              final id = t['leave_type_id'];
                              return code != 'COMP_OFF' &&
                                  name.isNotEmpty &&
                                  id != null &&
                                  id != 0;
                            })
                            .map((t) {
                              final selected =
                                  _selectedType?['leave_type_id'] ==
                                  t['leave_type_id'];
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedType = t;
                                  _isHalfDay = false;
                                  _halfDayPeriod = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? _primary.withOpacity(0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? _primary : _border,
                                      width: selected ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event_note_rounded,
                                        size: 16,
                                        color: selected ? _primary : _textMid,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        t['leave_name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? _primary : _textDark,
                                        ),
                                      ),
                                      if (selected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: _primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(),
                      ),
                const SizedBox(height: 20),
              ],

              if (_useCompOff) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _tealLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0F766E).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: _teal),
                      SizedBox(width: 8),
                      Text(
                        'Comp Off',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, size: 14, color: _teal),
                      Spacer(),
                      Text(
                        'Auto-selected',
                        style: TextStyle(fontSize: 11, color: _teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Half day toggle (only for normal leave) ───────────────────
              if (_selectedType != null && !_useCompOff) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Switch(
                        value: _isHalfDay,
                        activeColor: _primary,
                        onChanged: (v) => setState(() {
                          _isHalfDay = v;
                          if (v)
                            _toDate = _fromDate;
                          else
                            _halfDayPeriod = null;
                        }),
                      ),
                      const Text(
                        'Half Day',
                        style: TextStyle(
                          fontSize: 13,
                          color: _textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isHalfDay) ...[
                        const Spacer(),
                        _PeriodChip(
                          label: 'AM',
                          selected: _halfDayPeriod == 'AM',
                          onTap: () => setState(() => _halfDayPeriod = 'AM'),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: 'PM',
                          selected: _halfDayPeriod == 'PM',
                          onTap: () => setState(() => _halfDayPeriod = 'PM'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Date pickers ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'From Date *',
                      value: _fromDate,
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 2),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _primary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (p != null) {
                          setState(() {
                            _fromDate = p;
                            if (_isHalfDay) {
                              _toDate = p;
                            } else {
                              // In comp-off mode auto-set end date,
                              // cap at fromDate + (compOffs - 1) days
                              if (_useCompOff) {
                                _toDate = p; // start with same day
                              } else if (_toDate != null &&
                                  _toDate!.isBefore(p)) {
                                _toDate = null;
                              }
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'To Date *',
                      value: _toDate,
                      enabled: _fromDate != null && !_isHalfDay,
                      onTap: _fromDate == null || _isHalfDay
                          ? null
                          : () async {
                              // Cap lastDate for comp-off mode
                              final lastDate = _useCompOff
                                  ? _fromDate!.add(
                                      Duration(days: _compOffMaxDays - 1),
                                    )
                                  : DateTime(DateTime.now().year + 2);

                              final p = await showDatePicker(
                                context: context,
                                initialDate: _toDate ?? _fromDate!,
                                firstDate: _fromDate!,
                                lastDate: lastDate,
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: _primary,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (p != null) setState(() => _toDate = p);
                            },
                    ),
                  ),
                ],
              ),

              // Comp-off limit hint
              if (_useCompOff && _fromDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _tealLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0F766E).withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: _teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Max $_compOffMaxDays day${_compOffMaxDays == 1 ? '' : 's'} '
                        '($_compOffMaxDays comp-off${_compOffMaxDays == 1 ? '' : 's'} available)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Days count pill
              if (_fromDate != null && _toDate != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Reason ────────────────────────────────────────────────────
              const _FieldLabel('Reason *'),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the reason for leave…',
                  hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _useCompOff ? _teal : _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _useCompOff ? 'SUBMIT WITH COMP-OFF' : 'SUBMIT REQUEST',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );

      if (isWide) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: sheetContent,
            ),
          ),
        );
      }
      return sheetContent;
    }

    // ── Comp-off banner ───────────────────────────────────────────────────────
    Widget _buildCompOffBanner() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _useCompOff ? _tealLight : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _useCompOff ? const Color(0xFF0F766E).withOpacity(0.4) : _border,
          width: _useCompOff ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: _teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_compOffs.length} comp-off${_compOffs.length == 1 ? '' : 's'} available',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _teal,
                  ),
                ),
                Text(
                  _useCompOff
                      ? 'Max $_compOffMaxDays day${_compOffMaxDays == 1 ? '' : 's'} — date picker is capped'
                      : 'Toggle to use instead of leave balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF0F766E).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _useCompOff,
            activeColor: _teal,
            onChanged: _onToggleCompOff,
          ),
        ],
      ),
    );
  }

  class LeaveDetailsScreen extends StatefulWidget {
    final int leaveId;
    const LeaveDetailsScreen({super.key, required this.leaveId});

    @override
    State<LeaveDetailsScreen> createState() => _LeaveDetailsScreenState();
  }

  class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
    Map<String, dynamic>? _data;
    bool _loading = true;
    String? _error;

    @override
    void initState() {
      super.initState();
      _load();
    }

    Future<void> _load() async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final res = await ApiClient.get('/leave/details/${widget.leaveId}');
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['ok'] == true) {
          setState(() => _data = body['data'] as Map<String, dynamic>?);
        } else {
          setState(() => _error = body['message'] ?? 'Failed to load');
        }
      } catch (e) {
        setState(() => _error = 'Network error: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          title: const Text(
            'Leave Details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : _data == null
            ? const Center(child: Text('No data'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          title: 'Leave Information',
                          icon: Icons.info_outline_rounded,
                          children: [
                            _InfoRow(
                              icon: Icons.bookmark_rounded,
                              label: 'Type',
                              value: _data!['leave_name'] ?? '-',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.person_rounded,
                              label: 'Employee',
                              value: _data!['employee_name'] ?? '-',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.date_range_rounded,
                              label: 'Dates',
                              value:
                                  '${_fmtFull(_data!['leave_start_date']?.toString())} → ${_fmtFull(_data!['leave_end_date']?.toString())}',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.access_time_rounded,
                              label: 'Duration',
                              value:
                                  '${_data!['number_of_days']} day(s)${_data!['is_half_day'] == 1 ? ' — Half Day (${_data!['half_day_period']})' : ''}',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              icon: Icons.comment_rounded,
                              label: 'Reason',
                              value: _data!['reason'] ?? '-',
                            ),
                            const SizedBox(height: 8),
                            _StatusBadge(_data!['final_status'] ?? ''),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if ((_data!['approval_timeline'] as List?)?.isNotEmpty ==
                            true)
                          _SectionCard(
                            title: 'Approval Timeline',
                            icon: Icons.timeline_rounded,
                            children: (_data!['approval_timeline'] as List)
                                .asMap()
                                .entries
                                .map(
                                  (e) => _TimelineStep(
                                    step: e.value as Map<String, dynamic>,
                                    isLast:
                                        e.key ==
                                        (_data!['approval_timeline'] as List)
                                                .length -
                                            1,
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HolidaysScreen  –  shows all holidays for the current financial year
  // Financial year: 1 Apr → 31 Mar  (India standard)
  // ══════════════════════════════════════════════════════════════════════════════
  class HolidaysScreen extends StatefulWidget {
    const HolidaysScreen({super.key});

    @override
    State<HolidaysScreen> createState() => _HolidaysScreenState();
  }

  class _HolidaysScreenState extends State<HolidaysScreen> {
    List<Map<String, dynamic>> _holidays = [];
    bool _loading = true;
    String? _error;

    // ── Financial year helpers ─────────────────────────────────────────────────
    static int _fyStartYear() {
      final now = DateTime.now();
      // FY starts April 1; if we're in Jan–Mar the FY started the previous year
      return now.month >= 4 ? now.year : now.year - 1;
    }

    String get _fyLabel {
      final s = _fyStartYear();
      return 'FY ${s}–${(s + 1).toString().substring(2)}';
    }

    @override
    void initState() {
      super.initState();
      _load();
    }

    Future<void> _load() async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final year = _fyStartYear();
        // Fetch both halves of the FY in parallel
        final results = await Future.wait([
          ApiClient.get('/holidays?year=$year'),
          ApiClient.get('/holidays?year=${year + 1}'),
        ]);

        final all = <Map<String, dynamic>>[];
        for (final res in results) {
          if (res.statusCode == 200) {
            final body = jsonDecode(res.body) as Map<String, dynamic>;
            if (body['success'] == true) {
              all.addAll(List<Map<String, dynamic>>.from(body['data'] ?? []));
            }
          }
        }

        // Keep only dates within the financial year (Apr 1 → Mar 31 next year)
        final fyStart = DateTime(_fyStartYear(), 4, 1);
        final fyEnd = DateTime(_fyStartYear() + 1, 3, 31, 23, 59, 59);

        all.retainWhere((h) {
          try {
            final d = DateTime.parse(h['holiday_date'] as String);
            return !d.isBefore(fyStart) && !d.isAfter(fyEnd);
          } catch (_) {
            return false;
          }
        });

        // Sort ascending
        all.sort((a, b) {
          try {
            return DateTime.parse(
              a['holiday_date'] as String,
            ).compareTo(DateTime.parse(b['holiday_date'] as String));
          } catch (_) {
            return 0;
          }
        });

        if (mounted) setState(() => _holidays = all);
      } catch (e) {
        if (mounted)
          setState(
            () => _error = 'Unable to load holidays. Check your connection.',
          );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }

    // ── Group by month ─────────────────────────────────────────────────────────
    Map<String, List<Map<String, dynamic>>> get _grouped {
      final map = <String, List<Map<String, dynamic>>>{};
      for (final h in _holidays) {
        try {
          final d = DateTime.parse(h['holiday_date'] as String);
          final key = DateFormat('MMMM yyyy').format(d);
          (map[key] ??= []).add(h);
        } catch (_) {}
      }
      return map;
    }

    int get _upcoming => _holidays.where((h) {
      try {
        return !DateTime.parse(
          h['holiday_date'] as String,
        ).isBefore(DateTime.now());
      } catch (_) {
        return false;
      }
    }).length;

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Public Holidays',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                _fyLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : _holidays.isEmpty
            ? const _EmptyState(
                message: 'No holidays found',
                icon: Icons.celebration_rounded,
              )
            : RefreshIndicator(
                color: _primary,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Summary strip ──────────────────────────────
                    SliverToBoxAdapter(
                      child: _HolidaySummaryStrip(
                        total: _holidays.length,
                        upcoming: _upcoming,
                      ),
                    ),

                    // ── Month sections ─────────────────────────────
                    for (final entry in _grouped.entries) ...[
                      SliverToBoxAdapter(child: _MonthHeader(month: entry.key)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _HolidayRow(
                              holiday: entry.value[i],
                              isLast: i == entry.value.length - 1,
                            ),
                            childCount: entry.value.length,
                          ),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
      );
    }
  }

  // ── Summary strip ────────────────────────────────────────────────────────────
  class _HolidaySummaryStrip extends StatelessWidget {
    final int total, upcoming;
    const _HolidaySummaryStrip({required this.total, required this.upcoming});

    @override
    Widget build(BuildContext context) {
      final past = total - upcoming;
      return Container(
        color: _primary,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              _StatItem(value: '$total', label: 'Total', color: Colors.white),
              _StatDivider(),
              _StatItem(
                value: '$upcoming',
                label: 'Upcoming',
                color: const Color(0xFF6EE7B7),
              ),
              _StatDivider(),
              _StatItem(value: '$past', label: 'Past', color: Colors.white60),
            ],
          ),
        ),
      );
    }
  }

  // ── Month section header ─────────────────────────────────────────────────────
  class _MonthHeader extends StatelessWidget {
    final String month;
    const _MonthHeader({required this.month});

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                month,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Divider(color: _border)),
          ],
        ),
      );
    }
  }

  // ── Single holiday row ───────────────────────────────────────────────────────
  class _HolidayRow extends StatelessWidget {
    final Map<String, dynamic> holiday;
    final bool isLast;
    const _HolidayRow({required this.holiday, required this.isLast});

    static const _typeColors = <String, Color>{
      'National': _primary,
      'Regional': _accent,
      'Optional': _amber,
      'Religious': Color(0xFF7C3AED),
    };

    bool get _isPast {
      try {
        return DateTime.parse(
          holiday['holiday_date'] as String,
        ).isBefore(DateTime.now());
      } catch (_) {
        return false;
      }
    }

    bool get _isToday {
      try {
        final d = DateTime.parse(holiday['holiday_date'] as String);
        final now = DateTime.now();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) {
        return false;
      }
    }

    @override
    Widget build(BuildContext context) {
      DateTime? date;
      try {
        date = DateTime.parse(holiday['holiday_date'] as String);
      } catch (_) {}

      final type = holiday['holiday_type'] as String? ?? 'National';
      final typeColor = _typeColors[type] ?? _primary;
      final isPast = _isPast;
      final isToday = _isToday;
      final name = holiday['holiday_name'] as String? ?? '-';
      final desc = holiday['description'] as String? ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: isToday
              ? _primaryLight
              : isPast
              ? const Color(0xFFF8F9FA)
              : Colors.white,
          border: Border(
            left: BorderSide(
              color: isToday
                  ? _primary
                  : typeColor.withOpacity(isPast ? 0.3 : 0.6),
              width: isToday ? 3 : 2,
            ),
            bottom: isLast
                ? BorderSide.none
                : const BorderSide(color: _border, width: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Date badge ──────────────────────────────────────────────
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text(
                      date != null ? DateFormat('dd').format(date) : '--',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isPast ? _textLight : _textDark,
                        height: 1,
                      ),
                    ),
                    Text(
                      date != null ? DateFormat('EEE').format(date) : '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPast ? _textLight : _textMid,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── Name + description ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPast ? _textMid : _textDark,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 11, color: _textLight),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Right side badges ───────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Type pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withOpacity(0.25)),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: typeColor.withOpacity(isPast ? 0.5 : 1),
                      ),
                    ),
                  ),

                  // Today / Past badge
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ] else if (isPast) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Past',
                      style: TextStyle(
                        fontSize: 10,
                        color: _textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
  // ══════════════════════════════════════════════════════════════════════════════
  // Reusable micro-widgets
  // ══════════════════════════════════════════════════════════════════════════════

  class _StatItem extends StatelessWidget {
    final String value, label;
    final Color color;
    const _StatItem({
      required this.value,
      required this.label,
      required this.color,
    });

    @override
    Widget build(BuildContext context) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _textMid,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  class _StatDivider extends StatelessWidget {
    @override
    Widget build(BuildContext context) =>
        Container(width: 1, height: 36, color: _border);
  }

  class _FieldLabel extends StatelessWidget {
    final String text;
    const _FieldLabel(this.text);

    @override
    Widget build(BuildContext context) => Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _textMid,
      ),
    );
  }

  class _InfoRow extends StatelessWidget {
    final IconData icon;
    final String label, value;
    final Color? valueColor;
    const _InfoRow({
      required this.icon,
      required this.label,
      required this.value,
      this.valueColor,
    });

    @override
    Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _textMid,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? _textDark,
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

  class _MiniDetail extends StatelessWidget {
    final String label, value;
    const _MiniDetail(this.label, this.value);

    @override
    Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _textLight,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: _textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  class _OutlineBtn extends StatelessWidget {
    final String label;
    final IconData icon;
    final Color color;
    final VoidCallback onTap;
    const _OutlineBtn({
      required this.label,
      required this.icon,
      required this.color,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(9),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  class _PeriodChip extends StatelessWidget {
    final String label;
    final bool selected;
    final VoidCallback onTap;
    const _PeriodChip({
      required this.label,
      required this.selected,
      required this.onTap,
    });

    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _primary : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _textMid,
          ),
        ),
      ),
    );
  }

  class _DateField extends StatelessWidget {
    final String label;
    final DateTime? value;
    final bool enabled;
    final VoidCallback? onTap;
    const _DateField({
      required this.label,
      required this.value,
      this.enabled = true,
      this.onTap,
    });

    @override
    Widget build(BuildContext context) => GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? _surface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? _primary.withOpacity(0.4) : _border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: enabled ? _primary : _textLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value == null ? label : _fmt(value!),
                style: TextStyle(
                  fontSize: 13,
                  color: value == null ? _textLight : _textDark,
                  fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  class _SectionCard extends StatelessWidget {
    final String title;
    final IconData icon;
    final List<Widget> children;
    const _SectionCard({
      required this.title,
      required this.icon,
      required this.children,
    });

    @override
    Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: _primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  class _TimelineStep extends StatelessWidget {
    final Map<String, dynamic> step;
    final bool isLast;
    const _TimelineStep({required this.step, required this.isLast});

    Color _actionColor(String? action) {
      switch (action) {
        case 'Approved':
          return _accent;
        case 'Rejected':
          return _red;
        default:
          return _amber;
      }
    }

    @override
    Widget build(BuildContext context) {
      final action = step['action'] as String? ?? 'Pending';
      final color = _actionColor(action);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  action == 'Approved'
                      ? Icons.check_rounded
                      : action == 'Rejected'
                      ? Icons.close_rounded
                      : Icons.schedule_rounded,
                  size: 15,
                  color: color,
                ),
              ),
              if (!isLast) Container(width: 2, height: 40, color: _border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Level ${step['approval_level']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['approver_name'] ?? '-',
                    style: const TextStyle(fontSize: 13, color: _textMid),
                  ),
                  if ((step['action_at'] ?? '').toString().isNotEmpty &&
                      action != 'Pending')
                    Text(
                      _fmtFull(step['action_at']),
                      style: const TextStyle(fontSize: 11, color: _textLight),
                    ),
                  if ((step['remarks'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        step['remarks'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textMid,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  class _StatusBadge extends StatelessWidget {
    final String status;
    const _StatusBadge(this.status);

    static const _cfg = <String, Map<String, dynamic>>{
      'Pending': {'color': _amber, 'bg': _amberLight},
      'Approved': {'color': _accent, 'bg': _accentLight},
      'Rejected': {'color': _red, 'bg': _redLight},
      'Cancelled': {'color': _textLight, 'bg': _surface},
    };

    @override
    Widget build(BuildContext context) {
      final cfg = _cfg[status] ?? {'color': _textLight, 'bg': _surface};
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cfg['bg'] as Color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cfg['color'] as Color,
          ),
        ),
      );
    }
  }

  class _EmptyState extends StatelessWidget {
    final String message;
    final IconData icon;
    const _EmptyState({
      this.message = 'No leaves applied yet',
      this.icon = Icons.beach_access_rounded,
    });

    @override
    Widget build(BuildContext context) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: _textLight),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pull down to refresh',
              style: TextStyle(color: _textMid, fontSize: 13),
            ),
          ],
        ),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _redLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
