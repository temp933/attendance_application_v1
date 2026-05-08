import 'dart:convert';
import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'emp_holiday_view.dart';
import '../providers/api_client.dart';

class TL_HR_LeaveScreen extends StatefulWidget {
  final String employeeId;
  const TL_HR_LeaveScreen({super.key, required this.employeeId});

  @override
  State<TL_HR_LeaveScreen> createState() => _TL_HR_LeaveScreenState();
}

class _TL_HR_LeaveScreenState extends State<TL_HR_LeaveScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> leaves = [];
  bool loading = true;
  String? errorMessage;

  DateTime? fromDate;
  DateTime? toDate;
  String? leaveType;
  String? reason;
  int? editingLeaveId;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final Map<String, String> _personNames = {};

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const int _totalAllowed = 12;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    fetchLeaves();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────────
  Future<void> fetchLeaves() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      // ✅ REPLACE the http.get call with:
      final res = await ApiClient.get('/employees/${widget.employeeId}/leaves');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final list = data['data'] as List;
          setState(() => leaves = list);
          _animCtrl.forward(from: 0);

          // Resolve names for TL (recommended_by) and Manager (approved_by)
          final ids = <String>{};
          for (final l in list) {
            if (l['recommended_by'] != null) {
              ids.add(l['recommended_by'].toString());
            }
            if (l['approved_by'] != null) {
              ids.add(l['approved_by'].toString());
            }
          }
          for (final id in ids) {
            _fetchPersonName(id);
          }
        }
      } else {
        setState(() => errorMessage = 'Server error (${res.statusCode})');
      }
    } catch (e) {
      setState(
        () => errorMessage = 'Unable to load leaves. Check your connection.',
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _fetchPersonName(String id) async {
    if (_personNames.containsKey(id)) return;
    try {
      // ✅ REPLACE the http.get call with:
      final res = await ApiClient.get('/employee-user/$id');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final name = (data['full_name'] ?? '').toString().trim();
          final role = (data['role_name'] ?? '').toString().trim();
          final display = role.isNotEmpty ? '$name · $role' : name;
          if (mounted) {
            setState(
              () =>
                  _personNames[id] = display.isNotEmpty ? display : 'User #$id',
            );
          }
        }
      }
    } catch (_) {}
  }

  String _resolvePerson(dynamic id) {
    if (id == null) return '-';
    return _personNames[id.toString()] ?? 'Loading…';
  }

  Future<void> submitLeave() async {
    if (leaveType == null || fromDate == null || toDate == null) return;

    try {
      final bodyMap = {
        'leave_type': leaveType,
        'leave_start_date': fromDate!.toIso8601String().split('T')[0],
        'leave_end_date': toDate!.toIso8601String().split('T')[0],
        'reason': reason ?? '',
      };

      // ✅ REPLACE the http calls with ApiClient:
      final res = editingLeaveId != null
          ? await ApiClient.put('/leave/$editingLeaveId', bodyMap)
          : await ApiClient.post(
              '/employees/${widget.employeeId}/apply-leave',
              bodyMap,
            );

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        _showSnack(data['message'], success: true);
        if (mounted) Navigator.pop(context);
        clearForm();
        fetchLeaves();
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> cancelLeave(int id, String cancelReason) async {
    try {
      // ✅ REPLACE the http.put call with:
      final res = await ApiClient.put('/leave/$id/cancel', {
        'cancel_reason': cancelReason,
      });

      final data = jsonDecode(res.body);
      _showSnack(data['message'], success: data['success'] == true);
      if (data['success'] == true) fetchLeaves();
    } catch (e) {
      _showSnack('Error cancelling: $e');
    }
  }

  void clearForm() {
    leaveType = null;
    reason = null;
    fromDate = null;
    toDate = null;
    editingLeaveId = null;
  }

  void _showSnack(String msg, {bool success = false}) {
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

  static int _parseDays(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.ceil(); // 0.5 → 1, 1.0 → 1
    if (value is String) {
      // handles "1", "1.0", "0.5"
      final d = double.tryParse(value);
      if (d != null) return d.ceil();
    }
    return 0;
  }

  // ─── Summary computations ──────────────────────────────────────────────────
  int get _approvedDays => leaves
      .where((e) => e['status'] == 'Approved')
      .fold<int>(0, (s, e) => s + _parseDays(e['number_of_days']));
  int get _remainingDays =>
      (_totalAllowed - _approvedDays).clamp(0, _totalAllowed);

  // Pending = any status still awaiting action (TL or Manager queue)
  int get _pendingCount =>
      leaves.where((e) => e['status'] == 'Pending_Manager').length;

  // ─── Root ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: _buildFAB(r),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : errorMessage != null
          ? _buildError(r)
          : RefreshIndicator(
              onRefresh: fetchLeaves,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(r),
                  SliverToBoxAdapter(child: _buildSummaryBar(r)),
                  SliverToBoxAdapter(child: _buildHistoryHeader(r)),
                  if (leaves.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(r))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 100),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: r.contentMaxWidth,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: r.useTwoColSections
                                  ? _buildLeaveGrid(r)
                                  : _buildLeaveList(r),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLeaveGrid(Responsive r) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        const cols = 2;
        const gap = 12.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            leaves.length,
            (i) => SizedBox(
              width: itemW,
              child: _LeaveCard(
                leave: leaves[i],
                resolvePerson: _resolvePerson,
                onEdit: leaves[i]['status'] == 'Pending_Manager'
                    ? () => _openEdit(leaves[i])
                    : null,
                onCancel: leaves[i]['status'] == 'Pending_Manager'
                    ? (r) => cancelLeave(leaves[i]['leave_id'], r)
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveList(Responsive r) => Column(
    children: List.generate(
      leaves.length,
      (i) => _LeaveCard(
        leave: leaves[i],
        resolvePerson: _resolvePerson,
        onEdit: leaves[i]['status'] == 'Pending_Manager'
            ? () => _openEdit(leaves[i])
            : null,
        onCancel: leaves[i]['status'] == 'Pending_Manager'
            ? (r) => cancelLeave(leaves[i]['leave_id'], r)
            : null,
      ),
    ),
  );

  void _openEdit(dynamic leave) {
    editingLeaveId = leave['leave_id'];
    leaveType = leave['leave_type'];
    reason = leave['reason'];
    fromDate = DateTime.parse(leave['leave_start_date']);
    toDate = DateTime.parse(leave['leave_end_date']);
    _showApplySheet(context);
  }

  // ─── Sliver AppBar ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(Responsive r) => SliverToBoxAdapter(
    child: Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        r.hPad,
        MediaQuery.of(context).padding.top + 8,
        4,
        12,
      ),
      child: Row(
        children: [
          const Text(
            'My Leaves',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Refresh',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: loading ? null : fetchLeaves,
          ),
        ],
      ),
    ),
  );

  // ─── Summary Bar ───────────────────────────────────────────────────────────
  // Widget _buildSummaryBar(Responsive r) => Container(
  //   color: _primary,
  //   padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
  //   child: Center(
  //     child: ConstrainedBox(
  //       constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
  //         decoration: BoxDecoration(
  //           color: Colors.white.withOpacity(0.12),
  //           borderRadius: BorderRadius.circular(14),
  //           border: Border.all(color: Colors.white.withOpacity(0.15)),
  //         ),
  //         child: Row(
  //           children: [
  //             _statItem('$_totalAllowed', 'Total', Colors.white),
  //             _vDiv(),
  //             _statItem(
  //               '$_remainingDays',
  //               'Remaining',
  //               const Color(0xFF6EE7B7),
  //             ),
  //             _vDiv(),
  //             _statItem('$_approvedDays', 'Used', const Color(0xFFFDE68A)),
  //             _vDiv(),
  //             _statItem('$_pendingCount', 'Pending', Colors.white70),
  //           ],
  //         ),
  //       ),
  //     ),
  //   ),
  // );

  Widget _buildSummaryBar(Responsive r) => Container(
    color: _primary,
    padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              _statItem('$_totalAllowed', 'Total', Colors.white),
              _vDiv(),
              _statItem(
                '$_remainingDays',
                'Remaining',
                const Color(0xFF6EE7B7),
              ),
              _vDiv(),
              _statItem('$_approvedDays', 'Used', const Color(0xFFFDE68A)),
              _vDiv(),
              _statItem('${leaves.length}', 'Records', Colors.white70),
            ],
          ),
        ),
      ),
    ),
  );

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

  Widget _buildHistoryHeader(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Leave History',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            // ── Holiday view button ──────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmpHolidayView()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 13,
                      color: Color(0xFFF59E0B),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Holidays',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Records chip ─────────────────────────────────────────────
            if (leaves.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${leaves.length} records',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _buildFAB(Responsive r) => FloatingActionButton.extended(
    backgroundColor: _primary,
    elevation: 4,
    onPressed: () {
      clearForm();
      _showApplySheet(context);
    },
    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
    label: const Text(
      'Apply Leave',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.3,
      ),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  Widget _buildError(Responsive r) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load leaves',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: fetchLeaves,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildEmpty(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.beach_access_rounded,
              size: 44,
              color: _textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No leaves applied yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Apply Leave to submit a request',
            style: TextStyle(color: _textMid, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(
        employeeId: widget.employeeId,
        isEdit: editingLeaveId != null,
        initialLeaveType: leaveType,
        initialFromDate: fromDate,
        initialToDate: toDate,
        initialReason: reason,
        onSubmit: (lType, fDate, tDate, r) {
          leaveType = lType;
          fromDate = fDate;
          toDate = tDate;
          reason = r;
          submitLeave();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Leave Card
// ═══════════════════════════════════════════════════════════════════════════════
class _LeaveCard extends StatefulWidget {
  final Map<String, dynamic> leave;
  final String Function(dynamic) resolvePerson;
  final VoidCallback? onEdit;
  final Function(String)? onCancel;

  const _LeaveCard({
    required this.leave,
    required this.resolvePerson,
    this.onEdit,
    this.onCancel,
  });

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  bool _expanded = false;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);

  // ── Status config ──────────────────────────────────────────────────────────
  // Flow: Employee → Pending_TL → Pending_Manager → Approved/Rejected_By_Manager
  //       TL/HR   → Pending_Manager → Approved/Rejected_By_Manager
  //       Manager → Approved (self)
  // No HR approval role exists. Pending_HR and Rejected_By_HR are legacy only.
  static const _statusCfg = <String, Map<String, dynamic>>{
    'Approved': {
      'label': 'Approved',
      'color': Color(0xFF0E9F6E),
      'bg': Color(0xFFECFDF5),
      'icon': Icons.check_circle_rounded,
    },
    'Pending_TL': {
      'label': 'Pending TL',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'icon': Icons.schedule_rounded,
    },
    'Pending_Manager': {
      'label': 'Pending Manager',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'icon': Icons.schedule_rounded,
    },
    // legacy — old DB records only
    'Pending_HR': {
      'label': 'Pending Manager',
      'color': Color(0xFFF59E0B),
      'bg': Color(0xFFFFFBEB),
      'icon': Icons.schedule_rounded,
    },
    'Rejected_By_TL': {
      'label': 'Not Recommended by TL',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFFF1F2),
      'icon': Icons.cancel_rounded,
    },
    'Not_Recommended_By_TL': {
      'label': 'Not Recommended',
      'color': Color(0xFFF97316),
      'bg': Color(0xFFFFF7ED),
      'icon': Icons.thumb_down_alt_rounded,
    },
    'Rejected_By_Manager': {
      'label': 'Rejected by Manager',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFFF1F2),
      'icon': Icons.cancel_rounded,
    },
    // legacy — map to same as Rejected_By_Manager
    'Rejected_By_HR': {
      'label': 'Rejected by Manager',
      'color': Color(0xFFEF4444),
      'bg': Color(0xFFFFF1F2),
      'icon': Icons.cancel_rounded,
    },
    'Cancelled': {
      'label': 'Cancelled',
      'color': Color(0xFF94A3B8),
      'bg': Color(0xFFF1F5F9),
      'icon': Icons.block_rounded,
    },
  };

  String _fmtDate(String s) {
    try {
      final d = DateTime.parse(s);
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
      return '${d.day} ${m[d.month]} ${d.year}';
    } catch (_) {
      return s;
    }
  }

  String _fmtDateTime(String? s) {
    if (s == null) return '-';
    try {
      final d = DateTime.parse(s);
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
      return '${d.day} ${m[d.month]} ${d.year}, '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  static int _parseDays(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.ceil(); // 0.5 → 1, 1.0 → 1
    if (value is String) {
      // handles "1", "1.0", "0.5"
      final d = double.tryParse(value);
      if (d != null) return d.ceil();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    final status = leave['status'] as String? ?? 'Pending_Manager';
    final cfg =
        _statusCfg[status] ??
        {
          'label': status,
          'color': _textLight,
          'bg': const Color(0xFFF0F4FF),
          'icon': Icons.help_outline,
        };
    final statusColor = cfg['color'] as Color;
    final statusBg = cfg['bg'] as Color;
    final statusLabel = cfg['label'] as String;
    final statusIcon = cfg['icon'] as IconData;
    final sameDay = leave['leave_start_date'] == leave['leave_end_date'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? statusColor.withOpacity(0.3)
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
            Container(height: 3, color: statusColor),
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
                        Icons.event_note_rounded,
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
                            '${leave['leave_type']} Leave',
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
                              Flexible(
                                child: Text(
                                  sameDay
                                      ? _fmtDate(leave['leave_start_date'])
                                      : '${_fmtDate(leave['leave_start_date'])}  →  ${_fmtDate(leave['leave_end_date'])}',
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
                                  color: _primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${_parseDays(leave['number_of_days'])}d',
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
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textLight,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildDetails(leave, statusColor),
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

  Widget _buildDetails(Map<String, dynamic> leave, Color statusColor) {
    final status = leave['status'] as String? ?? '';
    final hasTLAction = leave['recommended_by'] != null;
    final hasManagerAction = leave['approved_by'] != null;
    final hasRejection = (leave['rejection_reason'] ?? '')
        .toString()
        .isNotEmpty;
    final hasCancelNote = (leave['cancel_reason'] ?? '').toString().isNotEmpty;

    final tlNotRecommended = status == 'Not_Recommended_By_TL';
    final tlRejected = status == 'Rejected_By_TL';

    // TL/HR applied directly — no TL review step exists for this leave
    final skippedTLStep = !hasTLAction && !tlNotRecommended && !tlRejected;

    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration
              _infoBlock(
                icon: Icons.today_rounded,
                iconColor: _primary,
                title: 'Duration',
                content:
                    '${_parseDays(leave['number_of_days'])} day${_parseDays(leave['number_of_days']) == 1 ? '' : 's'}'
                    '  ·  ${_fmtDate(leave['leave_start_date'])}  →  ${_fmtDate(leave['leave_end_date'])}',
              ),
              const SizedBox(height: 10),

              // Reason
              _infoBlock(
                icon: Icons.person_outline_rounded,
                iconColor: _primary,
                title: 'Reason',
                content: (leave['reason'] ?? '').toString().isEmpty
                    ? '-'
                    : leave['reason'],
              ),
              const SizedBox(height: 10),

              // ── TL Review block ─────────────────────────────────────────
              // Only shown when TL actually acted on this leave.
              // Hidden for TL/HR self-applies that went directly to Manager.
              if (!skippedTLStep) ...[
                _actionBlock(
                  icon: Icons.supervisor_account_rounded,
                  title: 'Team Lead Review',
                  person: hasTLAction
                      ? widget.resolvePerson(leave['recommended_by'])
                      : 'Team Lead',
                  timestamp: _fmtDateTime(leave['recommended_at']?.toString()),
                  statusLabel: tlNotRecommended
                      ? 'Not Recommended'
                      : tlRejected
                      ? 'Rejected'
                      : 'Recommended',
                  statusColor: tlNotRecommended
                      ? _orange
                      : tlRejected
                      ? _red
                      : _accent,
                  remark: (tlNotRecommended || tlRejected) && hasRejection
                      ? leave['rejection_reason']
                      : null,
                ),
                const SizedBox(height: 10),
              ],

              // ── Manager Action block ────────────────────────────────────
              if (hasManagerAction) ...[
                _actionBlock(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Manager Action',
                  person: widget.resolvePerson(leave['approved_by']),
                  timestamp: null,
                  statusLabel: status == 'Approved' ? 'Approved' : 'Rejected',
                  statusColor: status == 'Approved' ? _accent : _red,
                  remark:
                      (status == 'Rejected_By_Manager' ||
                              status == 'Rejected_By_HR') &&
                          hasRejection
                      ? leave['rejection_reason']
                      : null,
                ),
                const SizedBox(height: 10),
              ],

              // Cancellation note
              if (hasCancelNote) ...[
                _infoBlock(
                  icon: Icons.block_rounded,
                  iconColor: _textLight,
                  title: 'Cancellation Reason',
                  content: leave['cancel_reason'],
                  contentColor: _textMid,
                ),
                const SizedBox(height: 10),
              ],

              // Timestamps
              Row(
                children: [
                  Expanded(
                    child: _miniDetail(
                      'Applied',
                      _fmtDateTime(leave['created_at']?.toString()),
                    ),
                  ),
                  Expanded(
                    child: _miniDetail(
                      'Last Updated',
                      _fmtDateTime(leave['updated_at']?.toString()),
                    ),
                  ),
                ],
              ),

              // Edit / Cancel buttons (only while Pending_TL)
              if (widget.onEdit != null || widget.onCancel != null) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onEdit != null)
                      _actionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: _primary,
                        onTap: widget.onEdit!,
                      ),
                    if (widget.onEdit != null && widget.onCancel != null)
                      const SizedBox(width: 8),
                    if (widget.onCancel != null)
                      _actionBtn(
                        label: 'Cancel Leave',
                        icon: Icons.close_rounded,
                        color: _red,
                        onTap: () => _showCancelDialog(context),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Sub-widgets ───────────────────────────────────────────────────────────
  Widget _infoBlock({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    Color contentColor = const Color(0xFF0F172A),
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13,
                  color: contentColor,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _actionBlock({
    required IconData icon,
    required String title,
    required String person,
    String? timestamp,
    required String statusLabel,
    required Color statusColor,
    String? remark,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: statusColor.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: statusColor.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: statusColor),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: _textMid,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person_rounded, size: 13, color: _textLight),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                person,
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
        if (timestamp != null && timestamp != '-') ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 12, color: _textLight),
              const SizedBox(width: 4),
              Text(
                timestamp,
                style: const TextStyle(fontSize: 11, color: _textMid),
              ),
            ],
          ),
        ],
        if (remark != null && remark.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.comment_outlined,
                  size: 13,
                  color: statusColor.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    remark,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _miniDetail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: _textLight,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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

  void _showCancelDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Leave',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for cancellation.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              widget.onCancel!(ctrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Apply Leave Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _ApplyLeaveSheet extends StatefulWidget {
  final String employeeId;
  final bool isEdit;
  final String? initialLeaveType;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final String? initialReason;
  final Function(String, DateTime, DateTime, String) onSubmit;

  const _ApplyLeaveSheet({
    required this.employeeId,
    required this.isEdit,
    this.initialLeaveType,
    this.initialFromDate,
    this.initialToDate,
    this.initialReason,
    required this.onSubmit,
  });

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);

  late String? leaveType;
  late DateTime? fromDate;
  late DateTime? toDate;
  late String reason;

  List<Map<String, dynamic>> _leaveOptions = [];
  bool _loadingBalance = true;
  Map<String, dynamic>? _selectedTypeInfo;

  @override
  void initState() {
    super.initState();
    leaveType = widget.initialLeaveType;
    fromDate = widget.initialFromDate;
    toDate = widget.initialToDate;
    reason = widget.initialReason ?? '';
    _fetchLeaveBalance();
  }

  Future<void> _fetchLeaveBalance() async {
    try {
      final res = await ApiClient.get(
        '/employees/${widget.employeeId}/leave-balance',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final List balances = data['data'] as List;
          final Map<String, Map<String, dynamic>> balMap = {
            for (final b in balances) b['leave_type'] as String: b,
          };
          final options = <Map<String, dynamic>>[];

          final casual = balMap['Casual'];
          if (casual != null) {
            final rem =
                (casual['remaining_this_month'] as num?)?.toDouble() ?? 0.0;
            options.add({
              'type': 'Casual',
              'label': 'Casual Leave',
              'icon': Icons.beach_access_rounded,
              'remaining': rem,
              'has_balance': rem > 0,
              'subtitle': rem > 0
                  ? '${rem.toStringAsFixed(1)} day${rem == 1.0 ? '' : 's'} left this month'
                  : 'No balance this month',
            });
          }

          final sick = balMap['Sick'];
          if (sick != null) {
            final rem =
                (sick['remaining_this_month'] as num?)?.toDouble() ?? 0.0;
            options.add({
              'type': 'Sick',
              'label': 'Sick Leave',
              'icon': Icons.sick_rounded,
              'remaining': rem,
              'has_balance': rem > 0,
              'subtitle': rem > 0
                  ? '${rem.toStringAsFixed(1)} day${rem == 1.0 ? '' : 's'} left this month'
                  : 'No balance this month',
            });
          }

          final paid = balMap['Paid'];
          if (paid != null) {
            final isUnlimited = paid['is_unlimited'] == true;
            final rem = isUnlimited
                ? 999.0
                : (paid['remaining_days'] as num?)?.toDouble() ?? 0.0;
            options.add({
              'type': 'Paid',
              'label': 'Paid Leave',
              'icon': Icons.event_available_rounded,
              'remaining': rem,
              'has_balance': isUnlimited || rem > 0,
              'subtitle': isUnlimited
                  ? 'Unlimited'
                  : '${rem.toStringAsFixed(1)} days left',
            });
          }

          if (mounted) {
            setState(() {
              _leaveOptions = options.isEmpty ? _fallbackOptions() : options;
              _loadingBalance = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _leaveOptions = _fallbackOptions();
        _loadingBalance = false;
      });
    }
  }

  List<Map<String, dynamic>> _fallbackOptions() => [
    {
      'type': 'Casual',
      'label': 'Casual Leave',
      'icon': Icons.beach_access_rounded,
      'remaining': 0.0,
      'has_balance': false,
      'subtitle': 'Unable to load balance',
    },
    {
      'type': 'Sick',
      'label': 'Sick Leave',
      'icon': Icons.sick_rounded,
      'remaining': 0.0,
      'has_balance': false,
      'subtitle': 'Unable to load balance',
    },
    {
      'type': 'Paid',
      'label': 'Paid Leave',
      'icon': Icons.event_available_rounded,
      'remaining': 999.0,
      'has_balance': true,
      'subtitle': 'Unlimited',
    },
  ];
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  Color _typeColor(String type) {
    switch (type) {
      case 'Casual':
        return Colors.orange;
      case 'Sick':
        return Colors.red;
      case 'Paid':
        return Colors.green;
      case 'CompOff':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final sheetWidth = r.isMobile ? double.infinity : 520.0;
    return Center(
      child: Container(
        width: sheetWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: r.isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : BorderRadius.circular(24),
        ),
        margin: r.isMobile ? EdgeInsets.zero : const EdgeInsets.all(32),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isEdit ? 'Edit Leave Request' : 'Apply for Leave',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Your leave goes to Manager for approval',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),
              if (_loadingBalance)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _leaveOptions.map((opt) {
                    final type = opt['type'] as String;
                    final label = opt['label'] as String;
                    final icon = opt['icon'] as IconData;
                    final subtitle = opt['subtitle'] as String;
                    final noBalance = opt['has_balance'] == false;
                    final selected = leaveType == type;
                    final color = _typeColor(type);

                    return GestureDetector(
                      onTap: noBalance
                          ? null
                          : () => setState(() {
                              leaveType = type;
                              _selectedTypeInfo = opt;
                            }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: (MediaQuery.of(context).size.width - 40 - 8) / 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withOpacity(0.08)
                              : noBalance
                              ? const Color(0xFFF8FAFC)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? color : const Color(0xFFE2E8F0),
                            width: selected ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: noBalance ? Colors.grey : color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: noBalance
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: noBalance ? Colors.grey : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle, size: 16, color: color),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _datePicker(
                      label: 'From Date *',
                      value: fromDate,
                      onPick: () async {
                        final p = await showDatePicker(
                          context: context,
                          initialDate: fromDate ?? DateTime.now(),
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
                            fromDate = p;
                            toDate = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePicker(
                      label: 'To Date *',
                      value: toDate,
                      enabled: fromDate != null,
                      onPick: fromDate == null
                          ? null
                          : () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: toDate ?? fromDate!,
                                firstDate: fromDate!,
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
                              if (p != null) setState(() => toDate = p);
                            },
                    ),
                  ),
                ],
              ),
              if (fromDate != null && toDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${toDate!.difference(fromDate!).inDays + 1} day(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                initialValue: reason,
                maxLines: 3,
                onChanged: (v) => reason = v,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                  onPressed: () {
                    if (leaveType == null) return _snack('Select leave type');
                    if (fromDate == null) return _snack('Select from date');
                    if (toDate == null) return _snack('Select to date');
                    if (reason.trim().isEmpty) return _snack('Enter reason');

                    if (_selectedTypeInfo?['has_balance'] == false) {
                      return _snack('No balance remaining');
                    }

                    widget.onSubmit(leaveType!, fromDate!, toDate!, reason);
                  },
                  child: Text(
                    widget.isEdit ? 'UPDATE REQUEST' : 'SUBMIT REQUEST',
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
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    bool enabled = true,
    VoidCallback? onPick,
  }) => GestureDetector(
    onTap: enabled ? onPick : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value != null
              ? _primary.withOpacity(0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: enabled ? _primary : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value == null ? label : _fmt(value),
              style: TextStyle(
                fontSize: 13,
                color: value == null ? const Color(0xFF94A3B8) : _textDark,
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
