import 'dart:math';
import 'admin_profile_screen.dart';
import '../services/auth_service.dart';
import '../providers/attendance_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'admin_hr_attendance_screen.dart';
import 'login_screen.dart';
import 'admin_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'admin_hr_leave_approval.dart';
import 'admin_department_screen.dart';
import 'manage_location.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import 'admin_approval.dart';
import 'admin_manage_user.dart';
import 'admin_session_management_screen.dart';
import 'session_guard_mixin.dart';
import '../services/attendance_state.dart';
import '../services/api_service.dart';
import '../services/site_cache.dart';
import '../providers/api_config.dart';
import './Attendance screens/normal_attendance_management_screen.dart';
import './Attendance screens/gps_attendance_management_screen.dart';
import './Attendance screens/face_gps_attendance_management_screen.dart';
import 'admin_face_approval.dart';
import 'leave_policy_management.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;
  final String employeeId;
  final String roleId;
  final int loginId;
  final String tenantId;

  const AdminDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.roleId,
    required this.tenantId,
    this.initialIndex = 0,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SessionGuardMixin {
  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _selectedBg = Color(0xFFEEF2FF);

  static const double _expandThreshold = 120.0;

  late int selectedIndex;
  bool isExpanded = false;

  // static const int notificationIndex = 16;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    startSessionGuard();
    ApiConfig.tenantId = widget.tenantId;
    ApiConfig.employeeId = widget.employeeId;
  }

  // ── Pages ──────────────────────────────────────────────────────────────────
  late final LocationService locationService = LocationService();
  final List<Widget> pages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    pages.clear();

    print('DEBUG AdminDashboard widget.tenantId: "${widget.tenantId}"');
    print('DEBUG AdminDashboard widget.employeeId: "${widget.employeeId}"');

    pages.addAll([
      AdminHomeScreen(
        employeeId: widget.employeeId,
        onNavigate: (index) => setState(() => selectedIndex = index),
      ), // 0

      NormalAttendanceManagementScreen(
        tenantId: widget.tenantId,
        authToken:
            ApiConfig.headers['Authorization']?.replaceFirst('Bearer ', '') ??
            '',
      ), // 2
      GpsAttendanceManagementScreen(
        tenantId: widget.tenantId,
        authToken:
            ApiConfig.headers['Authorization']?.replaceFirst('Bearer ', '') ??
            '',
      ),
      FaceGpsAttendanceManagementScreen(
        tenantId: widget.tenantId,
        authToken:
            ApiConfig.headers['Authorization']?.replaceFirst('Bearer ', '') ??
            '',
      ),

      AdminDepartmentsScreen(tenantId: widget.tenantId), // 4
      ManageUserScreen(roleId: widget.roleId, tenantId: widget.tenantId), // 5
      AdminApprovalPage(),
      AdminFaceApprovalPage(),
      AdminProfileScreen(employeeId: widget.employeeId), // 6

      LeavePolicyManagementScreen(), // 7
      LeaveApprovalScreen(), // 8
    ]);
    print(
      'DEBUG AdminDepartmentsScreen receiving tenantId: "${widget.tenantId}"',
    );
  }

  // ── Titles ─────────────────────────────────────────────────────────────────
  final List<String> titles = [
    'Dashboard',
    'Normal Attendance',
    'GPS Attendance',
    'Face & GPS Attendance',
    'Departments',
    'Manage Users',
    'Approvals',
    'Face Approval',
    'Profile',
    'Leave Policy Management',
    'Leave Management',
  ];

  // ── Rail items ─────────────────────────────────────────────────────────────
  final List<NavigationRailDestination> railItems = const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.access_time_outlined),
      selectedIcon: Icon(Icons.access_time),
      label: Text('Normal Attendance'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.location_on_outlined),
      selectedIcon: Icon(Icons.location_on),
      label: Text('GPS Attendance'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.face_outlined),
      selectedIcon: Icon(Icons.face),
      label: Text('Face & GPS Attendance'),
    ),

    NavigationRailDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment),
      label: Text('Departments'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people),
      selectedIcon: Icon(Icons.people),
      label: Text('Manage Users'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.check_circle_outline),
      selectedIcon: Icon(Icons.check_circle),
      label: Text('Approvals'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.face_outlined),
      selectedIcon: Icon(Icons.face),
      label: Text('Face Approval'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person),
      selectedIcon: Icon(Icons.person),
      label: Text('Profile'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.policy_outlined),
      selectedIcon: Icon(Icons.policy),
      label: Text('Leave Policy'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.leave_bags_at_home_outlined),
      selectedIcon: Icon(Icons.leave_bags_at_home),
      label: Text('Leave Management'),
    ),
  ];

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(empId: widget.employeeId.toString()),
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
        drawer: isDesktop
            ? null
            : _mobileDrawer(MediaQuery.of(context).size.width),
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
        // ClipRect prevents children from painting outside the animated bounds.
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Drive layout from actual width, not from the boolean.
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
                            Icons.admin_panel_settings_rounded,
                            size: 24,
                          ),
                          if (wide) ...[
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Admin Panel',
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
                                        // Icon — always 20 px wide
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
                                        // Label — takes all remaining space
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
                                        // Dot — fixed 10 px slot, always
                                        // reserved so layout is predictable
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
  Widget _mobileDrawer(double width) {
    final bool isSmall = width < 360;
    final bool isLarge = width > 500;
    return SizedBox(
      width: width * 0.75,
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Header gradient
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + (width * 0.04),
                left: width * 0.05,
                right: width * 0.05,
                bottom: width * 0.04,
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
                    padding: EdgeInsets.all(isSmall ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: isSmall
                          ? 22
                          : isLarge
                          ? 28
                          : 26,
                    ),
                  ),
                  SizedBox(height: isSmall ? 10 : 14),
                  Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall
                          ? 16
                          : isLarge
                          ? 20
                          : 18,

                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Employee Attendance System',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: isSmall ? 10 : 12,
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: width * 0.04,
                      vertical: width * 0.01,
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: width * 0.04,
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

            SafeArea(top: false, child: const SizedBox(height: 5)),
          ],
        ),
      ), // ← closes Drawer
    ); // ← closes SizedBox
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
