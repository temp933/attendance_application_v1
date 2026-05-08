import 'admin_manage_user.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'hr_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'admin_hr_attendance_screen.dart';
import 'admin_hr_leave_approval.dart';
import 'login_screen.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import 'manager_leave.dart';
import 'session_guard_mixin.dart';
import 'emp_work_location.dart';
import '../services/attendance_state.dart';
import '../services/api_service.dart';
import '../services/site_cache.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final String employeeId;
  final String roleId;
  final int initialIndex;
  final int loginId;

  const ManagerDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.roleId,
    this.initialIndex = 0,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen>
    with SessionGuardMixin {
  // ── Design tokens (identical to AdminDashboardScreen) ──────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _selectedBg = Color(0xFFEEF2FF);

  static const double _expandThreshold = 120.0;

  late int selectedIndex;
  bool isExpanded = false;
  late LocationService locationService;

  // static const int notificationIndex = 12; // kept for future use

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    locationService = LocationService();
    startSessionGuard();
  }

  // ── Pages ──────────────────────────────────────────────────────────────────
  List<Widget> get pages => [
    HrHomeScreen(
      employeeId: widget.employeeId,
      onNavigate: (index) => setState(() => selectedIndex = index),
    ), // 0
    AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
    AdminHrAttendanceScreen(loginId: widget.loginId), // 2
    LeaveApprovalScreen(loginId: widget.loginId), // 3
    MGLeaveScreen(employeeId: widget.employeeId), // 4
    ManageUserScreen(roleId: widget.roleId), // 10
    EmployeeAssignmentsScreen(), //5

    EmployeeProfileScreen(employeeId: widget.employeeId.toString()), // 6
  ];

  // ── Titles ─────────────────────────────────────────────────────────────────
  final List<String> titles = [
    'Dashboard',
    'Mark Attendance',
    'Manage Attendance',
    'Leave Approval',
    'Apply Leave',
    "Manager User",
    "Site",
    'Profile',
  ];

  // ── Rail items ─────────────────────────────────────────────────────────────
  final List<NavigationRailDestination> railItems = const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fingerprint_outlined),
      selectedIcon: Icon(Icons.fingerprint),
      label: Text('Mark Attendance'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check),
      label: Text('Manage Attendance'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.event_busy_outlined),
      selectedIcon: Icon(Icons.event_busy),
      label: Text('Leave Approval'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.beach_access_outlined),
      selectedIcon: Icon(Icons.beach_access),
      label: Text('Apply Leave'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.manage_accounts_outlined),
      selectedIcon: Icon(Icons.manage_accounts),
      label: Text('Manage Users'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.place_outlined),
      selectedIcon: Icon(Icons.place),
      label: Text('Site'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profile'),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(empId: widget.employeeId),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            titles[selectedIndex],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          // actions: [
          //   IconButton(
          //     tooltip: 'Notifications',
          //     icon: const Icon(
          //       Icons.notifications_outlined,
          //       color: Colors.white,
          //     ),
          //     onPressed: () =>
          //         setState(() => selectedIndex = notificationIndex),
          //   ),
          //   const SizedBox(width: 4),
          // ],
        ),
        drawer: isDesktop ? null : _mobileDrawer(),
        body: Row(
          children: [
            if (isDesktop) _desktopSidebar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: pages[selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop sidebar ────────────────────────────────────────────────────────
  Widget _desktopSidebar() {
    return MouseRegion(
      onEnter: (_) => setState(() => isExpanded = true),
      onExit: (_) => setState(() => isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: isExpanded ? 232 : 72,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: _border, width: 1)),
        ),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide = constraints.maxWidth >= _expandThreshold;

              return Column(
                children: [
                  // ── Header ─────────────────────────────────────────────
                  SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.supervised_user_circle_rounded,
                            size: 24,
                          ),
                          if (wide) ...[
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Manager Panel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Nav items ───────────────────────────────────────────
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: railItems.length,
                      itemBuilder: (context, index) {
                        final item = railItems[index];
                        final selected = selectedIndex == index;
                        final label = (item.label as Text).data!;

                        return Tooltip(
                          message: wide ? '' : label,
                          preferBelow: false,
                          child: InkWell(
                            onTap: () => setState(() => selectedIndex = index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              padding: wide
                                  ? const EdgeInsets.only(
                                      top: 11,
                                      bottom: 11,
                                      left: 10,
                                      right: 8,
                                    )
                                  : const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _selectedBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: selected
                                    ? Border.all(
                                        color: _primary.withOpacity(0.15),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: wide
                                  ? Row(
                                      children: [
                                        // Icon
                                        IconTheme(
                                          data: IconThemeData(
                                            color: selected
                                                ? _primary
                                                : _textMid,
                                            size: 20,
                                          ),
                                          child: selected
                                              ? item.selectedIcon
                                              : item.icon,
                                        ),
                                        const SizedBox(width: 10),
                                        // Label
                                        Expanded(
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: selected
                                                  ? _primary
                                                  : _textDark,
                                            ),
                                          ),
                                        ),
                                        // Active dot
                                        SizedBox(
                                          width: 10,
                                          child: selected
                                              ? Center(
                                                  child: Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: _primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: IconTheme(
                                        data: IconThemeData(
                                          color: selected ? _primary : _textMid,
                                          size: 20,
                                        ),
                                        child: selected
                                            ? item.selectedIcon
                                            : item.icon,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Footer logout ───────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: _border, width: 1)),
                    ),
                    child: InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        padding: wide
                            ? const EdgeInsets.only(
                                top: 11,
                                bottom: 11,
                                left: 10,
                                right: 8,
                              )
                            : const EdgeInsets.symmetric(vertical: 11),
                        child: wide
                            ? Row(
                                children: const [
                                  Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Logout',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Mobile drawer ──────────────────────────────────────────────────────────
  Widget _mobileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header gradient — matches Admin dashboard style
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A56DB),
                  Color(0xFF1E3A8A),
                  Color(0xFF1e1b4b),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.supervised_user_circle_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Manager Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Employee Attendance System',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: railItems.length,
              itemBuilder: (context, index) {
                final selected = selectedIndex == index;
                final label = (railItems[index].label as Text).data!;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: IconTheme(
                    data: IconThemeData(
                      color: selected ? _primary : _textMid,
                      size: 20,
                    ),
                    child: selected
                        ? railItems[index].selectedIcon
                        : railItems[index].icon,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? _primary : _textDark,
                    ),
                  ),
                  selected: selected,
                  selectedTileColor: _selectedBg,
                  onTap: () {
                    setState(() => selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),

          // Footer logout
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFEF4444),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    // 1. End active tracking session on server (closes open site visits too)
    try {
      final state = AttendanceState.instance;
      if (state.dayStatus == DayStatus.inProgress) {
        await ApiService.endSession(
          int.parse(widget.employeeId),
          state.currentSessionId, // ← correct field name
          reason: 'logout',
        );
      }
    } catch (_) {
      // best-effort — don't block logout on API failure
    }

    // 2. forceStop handles: background service, SharedPrefs,
    //    and all AttendanceState fields in one call
    try {
      await AttendanceState.instance.forceStop();
    } catch (_) {}

    // 3. Stop site cache auto-sync timer
    try {
      SiteCache.dispose();
    } catch (_) {}

    // 4. Call server logout + clear SharedPreferences
    await AuthService.clearSession();

    // 5. Navigate to login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
