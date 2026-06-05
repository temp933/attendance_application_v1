import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'holiday_management_screen.dart';
import '../providers/api_client.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class ApprovalRule {
  double minDays;
  double? maxDays;
  int approvalLevels;

  ApprovalRule({
    required this.minDays,
    this.maxDays,
    required this.approvalLevels,
  });

  Map<String, dynamic> toJson() {
    return {
      'min_days': minDays,
      'max_days': maxDays,
      'approval_levels': approvalLevels,
    };
  }

  factory ApprovalRule.fromJson(Map<String, dynamic> json) {
    return ApprovalRule(
      minDays: double.parse(json['min_days'].toString()),
      maxDays: json['max_days'] == null
          ? null
          : double.parse(json['max_days'].toString()),
      approvalLevels: int.parse(json['approval_levels'].toString()),
    );
  }
}

class LeavePolicy {
  final int leaveTypeId;
  final String leaveName;
  final int maxDays;
  final bool isPaid;
  final bool requiresApproval;
  final int totalApprovalLevels;

  LeavePolicy({
    required this.leaveTypeId,
    required this.leaveName,
    required this.maxDays,
    required this.isPaid,
    required this.requiresApproval,
    required this.totalApprovalLevels,
  });

  factory LeavePolicy.fromJson(Map<String, dynamic> j) => LeavePolicy(
    leaveTypeId: j['leave_type_id'] ?? 0,
    leaveName: j['leave_name'] ?? '',
    maxDays: j['max_days'] ?? 0,
    isPaid: (j['is_paid'] == 1 || j['is_paid'] == true),
    requiresApproval:
        (j['requires_approval'] == 1 || j['requires_approval'] == true),
    totalApprovalLevels:
        int.tryParse(j['total_approval_rules']?.toString() ?? '0') ?? 0,
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class LeavePolicyManagementScreen extends StatefulWidget {
  final bool hideAppBar;
  const LeavePolicyManagementScreen({super.key, this.hideAppBar = false});

  @override
  State<LeavePolicyManagementScreen> createState() =>
      _LeavePolicyManagementScreenState();
}

class _LeavePolicyManagementScreenState
    extends State<LeavePolicyManagementScreen> {
  // ── Theme — mirrors LeaveScreen exactly ────────────────────────────
  static const _primary = Color(0xFF1A56DB);
  static const _accent = Color(0xFF0E9F6E);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);
  static const _surface = Color(0xFFF0F4FF);
  static const _textDark = Color(0xFF0F172A);
  static const _textMid = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);

  // ── State ──────────────────────────────────────────────────────────
  List<LeavePolicy> _policies = [];
  bool _loading = false;
  bool _listLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPolicies();
  }

  // ── API ────────────────────────────────────────────────────────────

  Future<void> _fetchPolicies() async {
    if (!mounted) return;
    setState(() => _listLoading = true);
    try {
      final resp = await ApiClient.get('/leave/policy/list');
      if (!mounted) return;
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200 && body['ok'] == true) {
        final list = (body['data'] as List)
            .map((j) => LeavePolicy.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() => _policies = list);
      } else {
        _showSnack(body['message'] ?? 'Failed to fetch policies');
      }
    } catch (e) {
      if (mounted) _showSnack('Network error: $e');
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  Future<void> _deletePolicy(int id, String name) async {
    final confirmed = await _showConfirmDialog(name);
    if (!confirmed || !mounted) return;
    setState(() => _listLoading = true);
    try {
      final resp = await ApiClient.delete('/leave/policy/delete/$id');
      if (!mounted) return;
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200 && body['ok'] == true) {
        _showSnack('Policy deleted', success: true);
        await _fetchPolicies();
      } else {
        _showSnack(body['message'] ?? 'Delete failed');
      }
    } catch (e) {
      if (mounted) _showSnack('Network error: $e');
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool success = false}) {
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

  Future<bool> _showConfirmDialog(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Delete Policy',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            content: Text(
              'Delete "$name"? This cannot be undone.',
              style: const TextStyle(fontSize: 13, color: _textMid),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: _textMid)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: Column(
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
                builder: (_) => HolidayManagementScreen(canEdit: true),
              ),
            ),
            icon: const Icon(Icons.celebration_rounded, color: _primary),
            label: const Text(
              'Holidays',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
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
            heroTag: 'fab_new_policy',
            backgroundColor: _primary,
            elevation: 4,
            onPressed: () => _showPolicySheet(context),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            label: const Text(
              'New Policy',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPolicies,
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──
            if (!widget.hideAppBar)
              SliverToBoxAdapter(
                child: Container(
                  color: _primary,
                  padding: EdgeInsets.fromLTRB(
                    8,
                    MediaQuery.of(context).padding.top + 8,
                    8,
                    12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Leave Policies',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: _listLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: _listLoading ? null : _fetchPolicies,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Summary bar ──
            // ── Summary bar ──
            if (!widget.hideAppBar)
              SliverToBoxAdapter(child: _buildSummaryBar()),
            if (widget.hideAppBar)
              SliverToBoxAdapter(child: _buildSummaryBarLight()),

            // ── Section header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'All Policies (${_policies.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
            ),

            // ── List or empty ──
            if (_listLoading && _policies.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _primary),
                ),
              )
            else if (_policies.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      // 2 columns on wide screens (>= 600 px), 1 on mobile
                      final useGrid = constraints.maxWidth >= 600;
                      if (!useGrid) {
                        return Column(
                          children: List.generate(
                            _policies.length,
                            (i) => _PolicyCard(
                              policy: _policies[i],
                              onEdit: () => _showPolicySheet(
                                context,
                                policyId: _policies[i].leaveTypeId,
                              ),
                              onDelete: () => _deletePolicy(
                                _policies[i].leaveTypeId,
                                _policies[i].leaveName,
                              ),
                            ),
                          ),
                        );
                      }
                      // 2-column Wrap — mirrors _buildLeaveGrid
                      const cols = 2;
                      const gap = 16.0;
                      final itemW =
                          (constraints.maxWidth - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: List.generate(
                          _policies.length,
                          (i) => SizedBox(
                            width: itemW,
                            child: _PolicyCard(
                              policy: _policies[i],
                              onEdit: () => _showPolicySheet(
                                context,
                                policyId: _policies[i].leaveTypeId,
                              ),
                              onDelete: () => _deletePolicy(
                                _policies[i].leaveTypeId,
                                _policies[i].leaveName,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final paid = _policies.where((p) => p.isPaid).length;
    final unpaid = _policies.where((p) => !p.isPaid).length;
    final withApproval = _policies.where((p) => p.requiresApproval).length;

    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            _statItem('${_policies.length}', 'Total', Colors.white),
            _vDiv(),
            _statItem('$paid', 'Paid', const Color(0xFF6EE7B7)),
            _vDiv(),
            _statItem('$unpaid', 'Unpaid', const Color(0xFFFDE68A)),
            _vDiv(),
            _statItem('$withApproval', 'Approval', Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: c.withOpacity(0.75),
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _vDiv() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2));

  Widget _vDiv2() =>
      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0));

  Widget _buildSummaryBarLight() {
    final paid = _policies.where((p) => p.isPaid).length;
    final unpaid = _policies.where((p) => !p.isPaid).length;
    final withApproval = _policies.where((p) => p.requiresApproval).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          _statItem('${_policies.length}', 'Total', _primary),
          _vDiv2(),
          _statItem('$paid', 'Paid', _accent),
          _vDiv2(),
          _statItem('$unpaid', 'Unpaid', _orange),
          _vDiv2(),
          _statItem('$withApproval', 'Approval', _textMid),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.policy_outlined,
              size: 44,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No leave policies yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap New Policy to create one',
            style: TextStyle(color: _textMid, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  // ── Bottom Sheet ───────────────────────────────────────────────────

  void _showPolicySheet(BuildContext context, {int? policyId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PolicySheet(
        policyId: policyId,
        onSaved: () {
          Navigator.pop(context);
          _fetchPolicies();
        },
        onError: (msg) => _showSnack(msg),
        onSuccess: (msg) => _showSnack(msg, success: true),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Policy Card  — mirrors _LeaveCard layout
// ═══════════════════════════════════════════════════════════════════════════════

class _PolicyCard extends StatefulWidget {
  final LeavePolicy policy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PolicyCard({
    required this.policy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  bool _expanded = false;

  static const _primary = Color(0xFF1A56DB);
  static const _accent = Color(0xFF0E9F6E);
  static const _red = Color(0xFFEF4444);
  static const _textDark = Color(0xFF0F172A);
  static const _textMid = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    final p = widget.policy;
    final accentColor = p.isPaid ? _accent : _textMid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? _primary.withOpacity(0.3)
                : const Color(0xFFE2E8F0),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_expanded ? 0.08 : 0.04),
              blurRadius: _expanded ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // colour strip
            Container(height: 3, color: _primary),

            // ── Header row ──
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
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.policy_outlined,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.leaveName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textDark,
                              letterSpacing: 0.1,
                            ),
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
                              Text(
                                '${p.maxDays} days max',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _badge(p.isPaid ? 'Paid' : 'Unpaid', accentColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // approval levels chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_tree_outlined,
                            size: 12,
                            color: _primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${p.totalApprovalLevels} lvl',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
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

            // ── Expanded detail ──
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(p),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(LeavePolicy p) {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info tiles
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      icon: Icons.calendar_month_outlined,
                      label: 'Max Days',
                      value: '${p.maxDays} days',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      icon: Icons.attach_money_rounded,
                      label: 'Type',
                      value: p.isPaid ? 'Paid' : 'Unpaid',
                      valueColor: p.isPaid ? _accent : _textMid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      icon: Icons.verified_user_outlined,
                      label: 'Approval',
                      value: p.requiresApproval ? 'Required' : 'Not required',
                      valueColor: p.requiresApproval
                          ? const Color(0xFFF97316)
                          : _textMid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      icon: Icons.account_tree_outlined,
                      label: 'Approval Levels',
                      value: '${p.totalApprovalLevels} level(s)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade100),
              const SizedBox(height: 10),

              // Action buttons — same pattern as _LeaveCard
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionBtn(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    color: _primary,
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 8),
                  _actionBtn(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    color: _red,
                    onTap: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(9),
        color: color.withOpacity(0.04),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Policy Bottom Sheet  — mirrors _ApplyLeaveSheet layout
// ═══════════════════════════════════════════════════════════════════════════════

class _PolicySheet extends StatefulWidget {
  final int? policyId;
  final VoidCallback onSaved;
  final void Function(String) onError;
  final void Function(String) onSuccess;

  const _PolicySheet({
    this.policyId,
    required this.onSaved,
    required this.onError,
    required this.onSuccess,
  });

  @override
  State<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends State<_PolicySheet> {
  static const _primary = Color(0xFF1A56DB);
  static const _accent = Color(0xFF0E9F6E);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF97316);
  static const _textDark = Color(0xFF0F172A);
  static const _textMid = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);

  static const _approverTypes = [
    'REPORTING_MANAGER',
    'DEPARTMENT_HEAD',
    'HR',
    'ADMIN',
    'SPECIFIC_EMPLOYEE',
  ];

  final _formKey = GlobalKey<FormState>();
  final _leaveNameCtrl = TextEditingController();
  final _maxDaysCtrl = TextEditingController();

  bool _isPaid = true;
  bool _requiresApproval = true;
  List<ApprovalRule> _approvalRules = [
    ApprovalRule(minDays: 0.5, maxDays: null, approvalLevels: 1),
  ];
  bool _loading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.policyId != null;
    if (_isEdit) _loadPolicy();
  }

  @override
  void dispose() {
    _leaveNameCtrl.dispose();
    _maxDaysCtrl.dispose();

    super.dispose();
  }

  Future<void> _loadPolicy() async {
    setState(() => _loading = true);
    try {
      final resp = await ApiClient.get('/leave/policy/${widget.policyId}');
      if (!mounted) return;
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200 && body['ok'] == true) {
        final data = body['data'] as Map<String, dynamic>;

        _leaveNameCtrl.text = data['leave_name'] ?? '';
        _maxDaysCtrl.text = (data['max_days'] ?? '').toString();
        final rules = (data['approval_rules'] as List?) ?? [];
        setState(() {
          _isPaid = (data['is_paid'] == 1 || data['is_paid'] == true);

          _requiresApproval =
              (data['requires_approval'] == 1 ||
              data['requires_approval'] == true);

          _approvalRules = rules.isEmpty
              ? [ApprovalRule(minDays: 0.5, maxDays: 2, approvalLevels: 1)]
              : rules
                    .map(
                      (e) => ApprovalRule.fromJson(e as Map<String, dynamic>),
                    )
                    .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final payload = {
        'leave_name': _leaveNameCtrl.text.trim(),
        'max_days': int.tryParse(_maxDaysCtrl.text.trim()) ?? 0,
        'is_paid': _isPaid,
        'requires_approval': _requiresApproval,
        'approval_rules': _approvalRules.map((e) => e.toJson()).toList(),
      };
      final resp = _isEdit
          ? await ApiClient.put(
              '/leave/policy/update/${widget.policyId}',
              payload,
            )
          : await ApiClient.post('/leave/policy/create', payload);
      if (!mounted) return;
      final body = jsonDecode(resp.body);
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          body['ok'] == true) {
        widget.onSuccess(body['message'] ?? 'Saved successfully');
        widget.onSaved();
      } else {
        _snack(body['message'] ?? 'Operation failed');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  void _addRule() {
    setState(() {
      _approvalRules.add(
        ApprovalRule(minDays: 0, maxDays: null, approvalLevels: 1),
      );
    });
  }

  void _removeRule(int index) {
    if (_approvalRules.length == 1) {
      _snack('At least one rule required');
      return;
    }

    setState(() {
      _approvalRules.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
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
              const SizedBox(height: 16),

              // ── Title ──
              Text(
                _isEdit ? 'Edit Leave Policy' : 'Create Leave Policy',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Fill in the details below',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _primary),
                  ),
                )
              else ...[
                // ── Leave Name ──
                _label('Leave Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _leaveNameCtrl,
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: _inputDec(
                    hint: 'e.g. Annual Leave',
                    icon: Icons.label_outline,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Max Days ──
                _label('Max Days'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _maxDaysCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Must be > 0';
                    return null;
                  },
                  decoration: _inputDec(
                    hint: '0',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Toggles ── (chip-style like leave type cards)
                _label('Settings'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _toggleCard(
                        label: 'Paid Leave',
                        icon: Icons.attach_money_rounded,
                        value: _isPaid,
                        activeColor: _accent,
                        onTap: () => setState(() => _isPaid = !_isPaid),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _toggleCard(
                        label: 'Needs Approval',
                        icon: Icons.verified_user_outlined,
                        value: _requiresApproval,
                        activeColor: _orange,
                        onTap: () => setState(
                          () => _requiresApproval = !_requiresApproval,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Approval Flow ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _label('Duration Based Approval Rules', inline: true),
                    GestureDetector(
                      onTap: _addRule,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_rounded, size: 14, color: _primary),
                            SizedBox(width: 4),
                            Text(
                              'Add Level',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                ...List.generate(
                  _approvalRules.length,
                  (i) => KeyedSubtree(
                    key: ValueKey('flow_$i'),
                    child: _buildRuleRow(i),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Submit ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isEdit ? 'UPDATE POLICY' : 'SAVE POLICY',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleRow(int index) {
    final rule = _approvalRules[index];
    final isUnlimited = rule.maxDays == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Rule ${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeRule(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: _red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: rule.minDays.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 13, color: _textDark),
                  decoration: _inputDec(
                    hint: '0.5',
                    icon: Icons.arrow_forward_rounded,
                  ).copyWith(labelText: 'Min Days'),
                  onChanged: (v) => rule.minDays = double.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  enabled: !isUnlimited,
                  initialValue: isUnlimited ? '' : rule.maxDays.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 13, color: _textDark),
                  decoration: _inputDec(
                    hint: isUnlimited ? '∞' : '30',
                    icon: Icons.arrow_back_rounded,
                  ).copyWith(labelText: 'Max Days'),
                  onChanged: (v) =>
                      setState(() => rule.maxDays = double.tryParse(v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: rule.approvalLevels.toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 13, color: _textDark),
                  decoration: _inputDec(
                    hint: '1',
                    icon: Icons.account_tree_outlined,
                  ).copyWith(labelText: 'Levels'),
                  onChanged: (v) => rule.approvalLevels = int.tryParse(v) ?? 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() {
              rule.maxDays = isUnlimited ? rule.minDays : null;
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isUnlimited ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isUnlimited ? _primary : _border,
                      width: 1.5,
                    ),
                  ),
                  child: isUnlimited
                      ? const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                const Text(
                  'No upper limit (unlimited days)',
                  style: TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 13),
        prefixIcon: Icon(icon, color: _textMid, size: 18),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      );

  Widget _label(String text, {bool inline = false}) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _textMid,
    ),
  );

  Widget _toggleCard({
    required String label,
    required IconData icon,
    required bool value,
    required Color activeColor,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: value ? activeColor.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? activeColor : _border,
          width: value ? 1.8 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withOpacity(0.12)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              icon,
              size: 14,
              color: value ? activeColor : _textLight,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: value ? _textDark : _textMid,
              ),
            ),
          ),
          if (value)
            Icon(Icons.check_circle_rounded, size: 15, color: activeColor),
        ],
      ),
    ),
  );
}


// this is my current code guide me step by step to chnage to match with the backend code 