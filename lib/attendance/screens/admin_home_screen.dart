import 'package:flutter/material.dart';
import '../../common/utils/greeting_util.dart';
import '../services/employee_service.dart';

// ── Design tokens ───────────────────────────────────────────────────────────
// Centralized color palette for the admin home screen — keeps theming
// consistent and avoids scattering raw hex values across the widget tree.
const _primary = Color(0xFF1A56DB);
const _primaryLight = Color(0xFFEEF2FF);
const _surface = Color(0xFFF8FAFF);
const _card = Colors.white;
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF64748B);
const _textLight = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _success = Color(0xFF10B981);
const _successLight = Color(0xFFD1FAE5);
const _danger = Color(0xFFEF4444);
const _dangerLight = Color(0xFFFFE4E6);
const _warning = Color(0xFFF59E0B);
const _warningLight = Color(0xFFFEF3C7);
const _indigo = Color(0xFF4F46E5);
const _indigoLight = Color(0xFFEEF2FF);
const _purple = Color(0xFF9333EA);
const _purpleLight = Color(0xFFF3E8FF);

// ─────────────────────────────────────────────────────────────────────────────
/// Admin dashboard home screen.
/// Shows today's attendance overview, a 7-day trend chart, pending
/// approvals, and an optional department-wise breakdown.
class AdminHomeScreen extends StatefulWidget {
  final String employeeId;
  // Used to jump to other tabs (e.g. approvals screen, profile requests screen)
  final void Function(int index)? onNavigate;

  /// Role gates — pass these from wherever you already resolve permissions
  /// (e.g. PermissionService.canView('leave_management') etc.)
  final bool canViewApprovals;
  final bool canViewDepartmentBreakdown;

  const AdminHomeScreen({
    super.key,
    required this.employeeId,
    this.onNavigate,
    this.canViewApprovals = true,
    this.canViewDepartmentBreakdown = true,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  String _adminName = '';
  bool _isLoading = true; // full-screen spinner on first load
  bool _isRefreshing = false; // small inline spinner during pull-to-refresh
  // Today's attendance summary numbers, populated from /api/dashboard
  int totalEmployees = 0;
  int presentCount = 0;
  int absentCount = 0;
  int lateEntryCount = 0;
  int onSiteCount = 0;
  bool hasSiteModule = false;
  int pendingLeaveCount = 0;
  int pendingProfileCount = 0;

  List<Map<String, dynamic>> _trend = []; // last 7 days of present-count data
  List<Map<String, dynamic>> _deptBreakdown = []; // per-department attendance %

  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  /// Fetches admin name, dashboard summary, and 7-day trend in parallel.
  /// Department breakdown is only fetched if canViewDepartmentBreakdown
  /// is true, to avoid an unnecessary/unauthorized API call.
  Future<void> _fetchAll({bool isRefresh = false}) async {
    if (isRefresh) setState(() => _isRefreshing = true);

    try {
      // Fire all required requests concurrently instead of sequentially
      final futures = <Future>[
        EmployeeService.fetchEmployeeName(int.parse(widget.employeeId)),
        EmployeeService.fetchDashboardData(),
        EmployeeService.fetchDashboardTrend(days: 7),
      ];
      if (widget.canViewDepartmentBreakdown) {
        futures.add(EmployeeService.fetchDepartmentBreakdown());
      }

      final results = await Future.wait(futures);

      final name = results[0] as String;
      final dashboard = results[1] as Map<String, dynamic>;
      final trend = results[2] as List<Map<String, dynamic>>;
      final dept = widget.canViewDepartmentBreakdown
          ? results[3] as List<Map<String, dynamic>>
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _adminName = name;
        totalEmployees = (dashboard['totalEmployees'] as num?)?.toInt() ?? 0;
        presentCount = (dashboard['present'] as num?)?.toInt() ?? 0;
        absentCount = (dashboard['absent'] as num?)?.toInt() ?? 0;
        lateEntryCount = (dashboard['lateEntry'] as num?)?.toInt() ?? 0;
        onSiteCount = (dashboard['activeSites'] as num?)?.toInt() ?? 0;
        hasSiteModule = dashboard['hasSiteModule'] == true;
        pendingLeaveCount = (dashboard['pendingLeave'] as num?)?.toInt() ?? 0;
        pendingProfileCount =
            (dashboard['pendingProfile'] as num?)?.toInt() ?? 0;
        _trend = trend;
        _deptBreakdown = dept;
        _isLoading = false;
        _isRefreshing = false;
        _lastFetched = DateTime.now();
      });
    } catch (e) {
      // Fall back to a safe "Admin" label so the UI doesn't get stuck
      // on the loading spinner indefinitely
      debugPrint('AdminHome _fetchAll error: $e');
      if (!mounted) return;
      setState(() {
        _adminName = _adminName.isEmpty ? 'Admin' : _adminName;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // Human-readable "updated Xm ago" label shown next to the section header
  String get _lastFetchedLabel {
    if (_lastFetched == null) return '';
    final diff = DateTime.now().difference(_lastFetched!);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _primary,
                  strokeWidth: 2.5,
                ),
              )
            : RefreshIndicator(
                color: _primary,
                onRefresh: () => _fetchAll(isRefresh: true),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),

                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        label: "Today's overview",
                        trailing: _isRefreshing
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: _textLight,
                                ),
                              )
                            : _lastFetched != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: _success,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Updated $_lastFetchedLabel',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textLight,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    // Stat cards grid — 2 columns portrait, 3 on wide screens,
                    // taller aspect ratio in landscape to avoid cramped cards
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio:
                              MediaQuery.of(context).orientation ==
                                  Orientation.landscape
                              ? 2.0
                              : 1.45,
                        ),
                        delegate: SliverChildListDelegate([
                          _StatCard(
                            icon: Icons.people_outline_rounded,
                            iconBg: _primaryLight,
                            iconColor: _primary,
                            value: totalEmployees.toString(),
                            label: 'Total employees',
                          ),
                          _StatCard(
                            icon: Icons.check_circle_outline_rounded,
                            iconBg: _successLight,
                            iconColor: _success,
                            value: presentCount.toString(),
                            label: 'Present today',
                            valueColor: _success,
                          ),
                          _StatCard(
                            icon: Icons.cancel_outlined,
                            iconBg: _dangerLight,
                            iconColor: _danger,
                            value: absentCount.toString(),
                            label: 'Absent today',
                            valueColor: _danger,
                          ),
                          _StatCard(
                            icon: Icons.watch_later_outlined,
                            iconBg: _warningLight,
                            iconColor: _warning,
                            value: lateEntryCount.toString(),
                            label: 'Late entry',
                            valueColor: _warning,
                          ),
                          // Show on-site count if the org has the site module
                          // enabled, otherwise fall back to attendance rate
                          if (hasSiteModule)
                            _StatCard(
                              icon: Icons.location_on_outlined,
                              iconBg: _indigoLight,
                              iconColor: _indigo,
                              value: onSiteCount.toString(),
                              label: 'On-site today',
                              valueColor: _indigo,
                            )
                          else
                            _StatCard(
                              icon: Icons.insights_outlined,
                              iconBg: _indigoLight,
                              iconColor: _indigo,
                              value: totalEmployees > 0
                                  ? '${((presentCount / totalEmployees) * 100).round()}%'
                                  : '0%',
                              label: 'Attendance rate',
                              valueColor: _indigo,
                            ),
                          _StatCard(
                            icon: Icons.beach_access_outlined,
                            iconBg: _purpleLight,
                            iconColor: _purple,
                            value: (pendingLeaveCount + pendingProfileCount)
                                .toString(),
                            label: 'Pending requests',
                            valueColor: _purple,
                          ),
                        ]),
                      ),
                    ),

                    // ── Attendance trend chart ──────────────────────────────
                    SliverToBoxAdapter(
                      child: _SectionHeader(label: 'Attendance trend · 7 days'),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: _TrendCard(trend: _trend),
                      ),
                    ),

                    // ── Pending approvals ───────────────────────────────────
                    // Hidden entirely if the role can't view it, rather than
                    // shown disabled/greyed out
                    if (widget.canViewApprovals) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          label: 'Pending approvals',
                          trailing: GestureDetector(
                            onTap: () => widget.onNavigate?.call(4),
                            child: const Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 12,
                                color: _primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Column(
                            children: [
                              _ApprovalRow(
                                icon: Icons.beach_access_outlined,
                                label: 'Leave requests',
                                count: pendingLeaveCount,
                                onTap: () => widget.onNavigate?.call(4),
                              ),
                              const SizedBox(height: 8),
                              _ApprovalRow(
                                icon: Icons.person_search_outlined,
                                label: 'Profile update requests',
                                count: pendingProfileCount,
                                onTap: () => widget.onNavigate?.call(5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Department breakdown ────────────────────────────────
                    // Only rendered when permitted AND there's actual data
                    if (widget.canViewDepartmentBreakdown &&
                        _deptBreakdown.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(label: 'Department breakdown'),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: _DeptBreakdownCard(rows: _deptBreakdown),
                        ),
                      ),
                    ],

                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Top bar widget ─────────────────────────────────────────────────────────
  // Greeting + admin name. Trailing empty SizedBox reserves space for a
  // future notification/menu icon — currently unused.
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getGreeting(),
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome back, $_adminName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textLight,
              letterSpacing: 0.8,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: _textLight,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? _textDark,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: _textMid),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending approval row ───────────────────────────────────────────────────
class _ApprovalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;

  const _ApprovalRow({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: _textMid),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    '$count awaiting review',
                    style: const TextStyle(fontSize: 11, color: _textMid),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _textLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Attendance trend mini bar chart (no extra package needed) ──────────────
// Lightweight bar chart built with plain Containers — avoids pulling in
// a charting package for a simple 7-bar trend view
class _TrendCard extends StatelessWidget {
  final List<Map<String, dynamic>> trend;
  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text(
          'No attendance data yet',
          style: TextStyle(fontSize: 12, color: _textLight),
        ),
      );
    }

    final maxVal = trend
        .map((e) => (e['present'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: trend.map((e) {
            final present = (e['present'] as num?)?.toInt() ?? 0;
            final dateStr = e['date']?.toString() ?? '';
            final dayLabel = _shortDay(dateStr);
            final barHeight = 96 * (present / safeMax);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      present.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: _textMid,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: barHeight.clamp(4, 96),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dayLabel,
                      style: const TextStyle(fontSize: 10, color: _textLight),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _shortDay(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[d.weekday - 1];
    } catch (_) {
      return '';
    }
  }
}

// ── Department breakdown progress list ──────────────────────────────────────
class _DeptBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _DeptBreakdownCard({required this.rows});

  // Color-codes department attendance %: green ≥90, blue ≥75, amber below
  Color _colorFor(int pct) {
    if (pct >= 90) return _success;
    if (pct >= 75) return _primary;
    return _warning;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        children: rows.map((r) {
          final name = r['departmentName']?.toString() ?? 'Unknown';
          final pct = (r['percentage'] as num?)?.toInt() ?? 0;
          final color = _colorFor(pct);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: _surface,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
