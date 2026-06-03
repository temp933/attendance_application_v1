import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../providers/api_config.dart';
import '../providers/attendance_provider.dart';
import '../services/auth_service.dart';
import '../services/attendance_state.dart';
import '../services/api_service.dart';
import '../services/site_cache.dart';
import 'session_guard_mixin.dart';
import 'login_screen.dart';
import 'notification.dart';

// ── Admin screens ─────────────────────────────────────────────────────────────
import 'emp_profile_screen.dart';
import 'admin_hr_leave_approval.dart';
import 'admin_manage_user.dart';
import 'admin_approval.dart';
import 'admin_face_approval.dart';
import 'admin_session_management_screen.dart';
import 'dept_role_desg_screen.dart';
import './Attendance screens/normal_attendance_management_screen.dart';
import './Attendance screens/gps_attendance_management_screen.dart';
import './Attendance screens/face_gps_attendance_management_screen.dart';
import './policy_management_screen.dart';
import './report_management_screen.dart';
import './holiday_management_screen.dart';
// ── Employee screens ──────────────────────────────────────────────────────────
import 'emp_home_screen.dart';
import 'emp_leave_screen.dart';
import 'emp_work_location.dart';
import 'comp_off_screen.dart';
import './Attendance screens/normal_in_out.dart';
import './Attendance screens/attendance_gps.dart';
import './Attendance screens/face_gps_attendance.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Module definition
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleDef {
  final String key;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final String navLabel;
  final Widget Function({
    required String employeeId,
    required String roleId,
    required String tenantId,
    required String authToken,
    required bool canEdit,
  })
  builder;

  const _ModuleDef({
    required this.key,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.navLabel,
    required this.builder,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// All 19 modules — admin decides who sees what
// ─────────────────────────────────────────────────────────────────────────────
final List<_ModuleDef> _allModules = [
  // ── Employee-facing ────────────────────────────────────────────────────────
  _ModuleDef(
    key: 'emp_dashboard',
    title: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    navLabel: 'Dashboard',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => EmployeeHomeScreen(
          empId: int.tryParse(employeeId) ?? 0,
          role: roleId,
        ),
  ),
  _ModuleDef(
    key: 'emp_attendance_normal',
    title: 'Attendance',
    icon: Icons.fingerprint_outlined,
    selectedIcon: Icons.fingerprint,
    navLabel: 'Attendance',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => NormalAttendanceScreen(),
  ),
  _ModuleDef(
    key: 'emp_attendance_gps',
    title: 'GPS Attendance',
    icon: Icons.gps_fixed_outlined,
    selectedIcon: Icons.gps_fixed,
    navLabel: 'GPS',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => GpsAttendanceScreen(),
  ),
  _ModuleDef(
    key: 'emp_attendance_face',
    title: 'Face Attendance',
    icon: Icons.face_outlined,
    selectedIcon: Icons.face,
    navLabel: 'Face',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) =>
            FaceGpsAttendanceScreen(employeeId: int.tryParse(employeeId) ?? 0),
  ),
  _ModuleDef(
    key: 'emp_leave',
    title: 'My Leave',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
    navLabel: 'Leave',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => LeaveScreen(),
  ),
  _ModuleDef(
    key: 'emp_profile',
    title: 'My Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    navLabel: 'Profile',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => EmployeeProfileScreen(employeeId: employeeId),
  ),
  _ModuleDef(
    key: 'emp_site',
    title: 'Site',
    icon: Icons.place_outlined,
    selectedIcon: Icons.place,
    navLabel: 'Site',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => EmployeeAssignmentsScreen(),
  ),
  _ModuleDef(
    key: 'comp_off',
    title: 'Comp-Off',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    navLabel: 'Comp-Off',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => CompOffScreen(),
  ),

  // ── Admin/HR-facing ────────────────────────────────────────────────────────
  _ModuleDef(
    key: 'admin_attendance_normal',
    title: 'Normal Attendance',
    icon: Icons.access_time_outlined,
    selectedIcon: Icons.access_time,
    navLabel: 'Normal Att.',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => NormalAttendanceManagementScreen(
          tenantId: tenantId,
          authToken: authToken,
        ),
  ),
  _ModuleDef(
    key: 'admin_attendance_gps',
    title: 'GPS Attendance',
    icon: Icons.location_on_outlined,
    selectedIcon: Icons.location_on,
    navLabel: 'GPS Att.',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => GpsAttendanceManagementScreen(
          tenantId: tenantId,
          authToken: authToken,
        ),
  ),
  _ModuleDef(
    key: 'admin_attendance_face',
    title: 'Face Attendance',
    icon: Icons.face_retouching_natural_outlined,
    selectedIcon: Icons.face_retouching_natural,
    navLabel: 'Face Att.',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => FaceGpsAttendanceManagementScreen(
          tenantId: tenantId,
          authToken: authToken,
        ),
  ),
  _ModuleDef(
    key: 'dept_management',
    title: 'Departments & Roles',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    navLabel: 'Departments',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => DeptRoleDesgScreen(),
  ),
  _ModuleDef(
    key: 'manage_user',
    title: 'Manage Users',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    navLabel: 'Users',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => ManageUserScreen(roleId: roleId, tenantId: tenantId),
  ),

  _ModuleDef(
    key: 'approval',
    title: 'Approvals',
    icon: Icons.check_circle_outline,
    selectedIcon: Icons.check_circle,
    navLabel: 'Approvals',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => AdminApprovalPage(),
  ),
  _ModuleDef(
    key: 'face_approval',
    title: 'Face Approval',
    icon: Icons.how_to_reg_outlined,
    selectedIcon: Icons.how_to_reg,
    navLabel: 'Face Approval',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => AdminFaceApprovalPage(),
  ),
  _ModuleDef(
    key: 'leave_approval',
    title: 'Leave Approval',
    icon: Icons.leave_bags_at_home_outlined,
    selectedIcon: Icons.leave_bags_at_home,
    navLabel: 'Leave',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => LeaveApprovalScreen(),
  ),

  _ModuleDef(
    key: 'holiday_management',
    title: 'Holiday Management',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    navLabel: 'Holidays',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => HolidayManagementScreen(),
  ),

  _ModuleDef(
    key: 'session_management',
    title: 'Session Management',
    icon: Icons.lock_clock_outlined,
    selectedIcon: Icons.lock_clock,
    navLabel: 'Sessions',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => AdminSessionManagementScreen(),
  ),
  _ModuleDef(
    key: 'report',
    title: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    navLabel: 'Reports',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => ReportManagementScreen(authToken: authToken, tenantId: tenantId),
  ),
  _ModuleDef(
    key: 'policy_management',
    title: 'Policy Management',
    icon: Icons.policy_outlined,
    selectedIcon: Icons.policy,
    navLabel: 'Policy',
    builder:
        ({
          required employeeId,
          required roleId,
          required tenantId,
          required authToken,
          required canEdit,
        }) => PolicyManagementScreen(authToken: authToken, tenantId: tenantId),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// UserDashboardScreen
// org_admin  → permissions = null → sees ALL modules
// everyone else → sees only what admin granted via role_permissions
// ─────────────────────────────────────────────────────────────────────────────
class UserDashboardScreen extends StatefulWidget {
  final int loginId;
  final String employeeId;
  final String roleId;
  final String tenantId;
  final String userType;
  final List<Map<String, dynamic>>? permissions; // null = full access (admin)

  const UserDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.roleId,
    required this.tenantId,
    required this.userType,
    this.permissions,
  });

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen>
    with SessionGuardMixin {
  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _selectedBg = Color(0xFFEEF2FF);
  static const double _expandThreshold = 120.0;

  late int _selectedIndex;
  bool _isExpanded = false;

  late final List<_ModuleDef> _visibleModules;
  late final Map<String, bool> _canEditMap;
  late List<Widget> _pages;
  late final String _authToken;

  bool get _isAdmin => widget.userType == 'org_admin';

  @override
  void initState() {
    super.initState();
    _selectedIndex = 0;
    startSessionGuard();
    ApiConfig.tenantId = widget.tenantId;
    ApiConfig.employeeId = widget.employeeId;

    _authToken = ApiConfig.getToken();

    _resolvePermissions();
    _buildPages();
  }

  // ── Resolve visible modules ───────────────────────────────────────────────
  void _resolvePermissions() {
    // org_admin → full access
    if (_isAdmin || widget.permissions == null) {
      _visibleModules = List.from(_allModules);
      _canEditMap = {for (final m in _allModules) m.key: true};
      return;
    }

    final permMap = <String, Map<String, dynamic>>{
      for (final p in widget.permissions!) p['module_key'] as String: p,
    };

    _visibleModules = [];
    _canEditMap = {};

    for (final module in _allModules) {
      final perm = permMap[module.key];
      if (perm != null && (perm['can_view'] == 1 || perm['can_view'] == true)) {
        _visibleModules.add(module);
        _canEditMap[module.key] =
            perm['can_edit'] == 1 || perm['can_edit'] == true;
      }
    }
  }

  // ── Build pages ───────────────────────────────────────────────────────────
  void _buildPages() {
    _pages = _visibleModules
        .map(
          (m) => m.builder(
            employeeId: widget.employeeId,
            roleId: widget.roleId,
            tenantId: widget.tenantId,
            authToken: _authToken,
            canEdit: _canEditMap[m.key] ?? false,
          ),
        )
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _currentTitle => _visibleModules.isNotEmpty
      ? _visibleModules[_selectedIndex].title
      : 'Dashboard';

  String get _panelTitle {
    switch (widget.userType) {
      case 'org_admin':
        return 'Admin Panel';
      case 'org_hr':
        return 'HR Panel';
      default:
        return 'My Panel';
    }
  }

  IconData get _panelIcon {
    switch (widget.userType) {
      case 'org_admin':
        return Icons.admin_panel_settings_rounded;
      case 'org_hr':
        return Icons.people_alt_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  bool get _hasNoAccess => !_isAdmin && _visibleModules.isEmpty;

  // ─────────────────────────────────────────────────────────────────────────
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
            _currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                // Force rebuild of current page by bumping a key
                setState(() {
                  _pages[_selectedIndex] = _visibleModules[_selectedIndex]
                      .builder(
                        employeeId: widget.employeeId,
                        roleId: widget.roleId,
                        tenantId: widget.tenantId,
                        authToken: _authToken,
                        canEdit:
                            _canEditMap[_visibleModules[_selectedIndex].key] ??
                            false,
                      );
                });
              },
            ),
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS))
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationScreen()),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: isDesktop
            ? null
            : _mobileDrawer(MediaQuery.of(context).size.width),
        body: _hasNoAccess
            ? _noAccessView()
            : Row(
                children: [
                  if (isDesktop) _desktopSidebar(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(
                          '${_selectedIndex}_${_pages[_selectedIndex].hashCode}',
                        ),
                        child: _pages[_selectedIndex],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── No access ─────────────────────────────────────────────────────────────
  Widget _noAccessView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text(
          'No modules assigned',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Contact your administrator to get access.',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Logout'),
        ),
      ],
    ),
  );

  // ── Desktop sidebar ───────────────────────────────────────────────────────
  Widget _desktopSidebar() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isExpanded = true),
      onExit: (_) => setState(() => _isExpanded = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _isExpanded ? 232 : 72,
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
                  // Header
                  SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(_panelIcon, size: 24),
                          if (wide) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _panelTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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

                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visibleModules.length,
                      itemBuilder: (context, index) {
                        final m = _visibleModules[index];
                        final selected = _selectedIndex == index;
                        return Tooltip(
                          message: wide ? '' : m.navLabel,
                          preferBelow: false,
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
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
                                        IconTheme(
                                          data: IconThemeData(
                                            color: selected
                                                ? _primary
                                                : _textMid,
                                            size: 20,
                                          ),
                                          child: Icon(
                                            selected ? m.selectedIcon : m.icon,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            m.navLabel,
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
                                        child: Icon(
                                          selected ? m.selectedIcon : m.icon,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Logout footer
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

  // ── Mobile drawer ─────────────────────────────────────────────────────────
  Widget _mobileDrawer(double width) {
    final bool isSmall = width < 360;
    final bool isLarge = width > 500;
    return SizedBox(
      width: width * 0.75,
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
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
                      _panelIcon,
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
                    _panelTitle,
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

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _visibleModules.length,
                itemBuilder: (context, index) {
                  final m = _visibleModules[index];
                  final selected = _selectedIndex == index;
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
                      child: Icon(selected ? m.selectedIcon : m.icon),
                    ),
                    title: Text(
                      m.navLabel,
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
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),

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
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    try {
      final state = AttendanceState.instance;
      if (state.dayStatus == DayStatus.inProgress) {
        await ApiService.endSession(
          int.parse(widget.employeeId),
          state.currentSessionId,
          reason: 'logout',
        );
      }
    } catch (_) {}
    try {
      await AttendanceState.instance.forceStop();
    } catch (_) {}
    try {
      SiteCache.dispose();
    } catch (_) {}
    await AuthService.clearSession();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
