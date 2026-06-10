import 'package:flutter/material.dart';
import '../../common/utils/greeting_util.dart';
import '../services/employee_service.dart';
import 'admin_manage_user.dart';
import '../providers/api_config.dart';

// ── Design tokens (matches your existing screens) ─────────────────────────────
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
class AdminHomeScreen extends StatefulWidget {
  final String employeeId;
  final void Function(int index)? onNavigate;

  const AdminHomeScreen({super.key, required this.employeeId, this.onNavigate});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  String _adminName = '';
  bool _isLoading = true;
  bool _isRefreshing = false;

  int totalEmployees = 0;
  int presentCount = 0;
  int absentCount = 0;
  int lateEntryCount = 0;
  int onSiteCount = 0;
  int pendingCount = 0;

  DateTime? _lastFetched;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchAll({bool isRefresh = false}) async {
    if (isRefresh) setState(() => _isRefreshing = true);

    try {
      final results = await Future.wait([
        EmployeeService.fetchEmployeeName(int.parse(widget.employeeId)),
        EmployeeService.fetchDashboardData(),
      ]);

      final name = results[0] as String;
      final dashboard = results[1] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _adminName = name;
        totalEmployees = (dashboard['totalEmployees'] as num?)?.toInt() ?? 0;
        presentCount = (dashboard['present'] as num?)?.toInt() ?? 0;
        absentCount = (dashboard['absent'] as num?)?.toInt() ?? 0;
        lateEntryCount = (dashboard['lateEntry'] as num?)?.toInt() ?? 0;
        onSiteCount = (dashboard['activeSites'] as num?)?.toInt() ?? 0;
        pendingCount = (dashboard['pendingRequests'] as num?)?.toInt() ?? 0;
        _isLoading = false;
        _isRefreshing = false;
        _lastFetched = DateTime.now();
      });
    } catch (e) {
      debugPrint('AdminHome _fetchAll error: $e');
      if (!mounted) return;
      setState(() {
        _adminName = 'Admin';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

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
                    // ── Top bar ──────────────────────────────────────────────
                    SliverToBoxAdapter(child: _buildTopBar()),

                    // ── Stat cards ───────────────────────────────────────────
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
                          _StatCard(
                            icon: Icons.location_on_outlined,
                            iconBg: _indigoLight,
                            iconColor: _indigo,
                            value: onSiteCount.toString(),
                            label: 'On-site today',
                            valueColor: _indigo,
                          ),
                          _StatCard(
                            icon: Icons.beach_access_outlined,
                            iconBg: _purpleLight,
                            iconColor: _purple,
                            value: pendingCount.toString(),
                            label: 'Pending requests',
                            valueColor: _purple,
                          ),
                        ]),
                      ),
                    ),

                     SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Top bar widget ─────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    // REPLACE WITH:
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          // Greeting
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

          // Notification bell
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Section header ─────────────────────────────────────────────────────────────
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

// ── Stat card ──────────────────────────────────────────────────────────────────
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
            // Icon + arrow row
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
            // Value + label
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

// ── Quick nav tile ─────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback? onTap;

  const _NavTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sub,
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
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 10, color: _textLight),
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
