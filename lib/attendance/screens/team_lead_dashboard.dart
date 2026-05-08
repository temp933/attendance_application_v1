// // import '../services/auth_service.dart';
// // import 'package:provider/provider.dart';
// // import '../providers/attendance_provider.dart';
// // import 'package:flutter/material.dart';
// // import 'hr_home_screen.dart';
// // import 'emp_attendance_screen.dart';
// // import 'admin_hr_attendance_screen.dart';
// // import 'tl_leave_screen.dart';
// // import 'login_screen.dart';
// // import '../services/location_services.dart';
// // import 'emp_profile_screen.dart';
// // import 'emp_leave_screen.dart';

// // class TLDashboardScreen extends StatefulWidget {
// //   final String employeeId; // Employee ID from login
// //   final String role; // "HR"
// //   final int initialIndex; // optional: which page to open first
// //   final int loginId;

// //   const TLDashboardScreen({
// //     super.key,
// //     required this.loginId,
// //     required this.employeeId,
// //     required this.role,
// //     this.initialIndex = 0,
// //   });

// //   @override
// //   State<TLDashboardScreen> createState() => _TLDashboardScreenState();
// // }

// // class _TLDashboardScreenState extends State<TLDashboardScreen> {
// //   late int selectedIndex;
// //   bool isExpanded = false;
// //   late LocationService locationService;
// //   double? distance;

// //   /// 🔔 Notification index (NOT in menu)
// //   static const int notificationIndex = 12;

// //   @override
// //   void initState() {
// //     super.initState();
// //     selectedIndex = widget.initialIndex;
// //     locationService = LocationService();
// //   }

// //   // ================= PAGES =================

// //   List<Widget> get pages => [
// //     HrHomeScreen(employeeId: widget.employeeId), // 0
// //     AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
// //     AdminHrAttendanceScreen(), // 2
// //     TLLeaveScreen(loginId: widget.loginId), // 3
// //     LeaveScreen(employeeId: widget.employeeId),

// //     EmployeeProfileScreen(employeeId: widget.employeeId.toString()),
// //     const Center(
// //       child: Text(
// //         "Notifications",
// //         style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// //       ),
// //     ),
// //   ];

// //   final List<String> titles = [
// //     "Dashboard",
// //     "Mark Attendance",
// //     "Manage Attendance",
// //     "Leave Approval",
// //     "Leave"
// //         "Profile",
// //     "Notifications",
// //   ];

// //   /// SET MENU WITH ICONS
// //   /// This list defines all sidebar menu options
// //   final List<NavigationRailDestination> railItems = const [
// //     NavigationRailDestination(
// //       icon: Icon(Icons.dashboard_outlined),
// //       selectedIcon: Icon(Icons.dashboard),
// //       label: Text("Dashboard"),
// //     ),

// //     NavigationRailDestination(
// //       icon: Icon(Icons.login_outlined),
// //       selectedIcon: Icon(Icons.login),
// //       label: Text("Mark Attendance"),
// //     ),

// //     NavigationRailDestination(
// //       icon: Icon(Icons.manage_accounts_outlined),
// //       selectedIcon: Icon(Icons.manage_accounts),
// //       label: Text("Manage Attendance"),
// //     ),

// //     NavigationRailDestination(
// //       icon: Icon(Icons.event_busy_outlined),
// //       selectedIcon: Icon(Icons.event_busy),
// //       label: Text("Leave Approval"),
// //     ),

// //     NavigationRailDestination(
// //       icon: Icon(Icons.event_busy_outlined),
// //       selectedIcon: Icon(Icons.event_busy),
// //       label: Text("Leave Apply"),
// //     ),
// //     NavigationRailDestination(
// //       icon: Icon(Icons.person_rounded),
// //       selectedIcon: Icon(Icons.person),
// //       label: Text("Profile"),
// //     ),
// //   ];

// //   @override
// //   Widget build(BuildContext context) {
// //     final bool isDesktop = MediaQuery.of(context).size.width >= 900;

// //     return ChangeNotifierProvider(
// //       create: (_) => AttendanceProvider(empId: widget.employeeId),
// //       child: Scaffold(
// //         backgroundColor: Colors.grey.shade100,

// //         appBar: AppBar(
// //           elevation: 1,
// //           backgroundColor: Colors.white,
// //           iconTheme: const IconThemeData(color: Colors.black87),
// //           title: Text(
// //             titles[selectedIndex],
// //             style: const TextStyle(
// //               color: Colors.black87,
// //               fontWeight: FontWeight.w600,
// //             ),
// //           ),
// //           actions: [
// //             IconButton(
// //               tooltip: "Notifications",
// //               icon: const Icon(Icons.notifications_outlined),
// //               onPressed: () {
// //                 setState(() => selectedIndex = notificationIndex);
// //               },
// //             ),
// //             IconButton(
// //               tooltip: "Logout",
// //               icon: const Icon(Icons.logout, color: Colors.red),
// //               onPressed: _logout,
// //             ),
// //             const SizedBox(width: 8),
// //           ],
// //         ),

// //         drawer: isDesktop ? null : _mobileDrawer(),

// //         body: Row(
// //           children: [
// //             if (isDesktop) _desktopSidebar(),
// //             Expanded(
// //               child: AnimatedSwitcher(
// //                 duration: const Duration(milliseconds: 250),
// //                 child: pages[selectedIndex],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   //  DESKTOP SIDEBAR
// //   Widget _desktopSidebar() {
// //     return MouseRegion(
// //       onEnter: (_) => setState(() => isExpanded = true),
// //       onExit: (_) => setState(() => isExpanded = false),
// //       child: AnimatedContainer(
// //         duration: const Duration(milliseconds: 250),
// //         width: isExpanded ? 230 : 72,
// //         color: Colors.white,
// //         child: ListView.builder(
// //           itemCount: railItems.length,
// //           itemBuilder: (context, index) {
// //             final item = railItems[index];
// //             final bool selected = selectedIndex == index;

// //             return InkWell(
// //               onTap: () => setState(() => selectedIndex = index),
// //               child: Container(
// //                 margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
// //                 padding: const EdgeInsets.symmetric(
// //                   vertical: 12,
// //                   horizontal: 12,
// //                 ),
// //                 decoration: selected
// //                     ? BoxDecoration(
// //                         color: Colors.indigo.shade50,
// //                         borderRadius: BorderRadius.circular(10),
// //                       )
// //                     : null,
// //                 child: Row(
// //                   children: [
// //                     IconTheme(
// //                       data: IconThemeData(
// //                         color: selected ? Colors.indigo : Colors.grey,
// //                       ),
// //                       child: selected ? item.selectedIcon : item.icon,
// //                     ),
// //                     if (isExpanded)
// //                       Expanded(
// //                         child: Padding(
// //                           padding: const EdgeInsets.only(left: 14),
// //                           child: Text(
// //                             (item.label as Text).data!,
// //                             overflow: TextOverflow.ellipsis,
// //                             style: TextStyle(
// //                               fontWeight: selected
// //                                   ? FontWeight.w600
// //                                   : FontWeight.normal,
// //                             ),
// //                           ),
// //                         ),
// //                       ),
// //                   ],
// //                 ),
// //               ),
// //             );
// //           },
// //         ),
// //       ),
// //     );
// //   }

// //   //  MOBILE DRAWER OR MENU BAR
// //   Widget _mobileDrawer() {
// //     return Drawer(
// //       child: ListView(
// //         children: [
// //           const DrawerHeader(
// //             decoration: BoxDecoration(color: Colors.indigo),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               mainAxisAlignment: MainAxisAlignment.end,
// //               children: [
// //                 Icon(Icons.badge, color: Colors.white, size: 40),
// //                 SizedBox(height: 12),
// //                 Text(
// //                   "HR Panel",
// //                   style: TextStyle(
// //                     color: Colors.white,
// //                     fontSize: 18,
// //                     fontWeight: FontWeight.bold,
// //                   ),
// //                 ),
// //                 Text(
// //                   "Employee Attendance System",
// //                   style: TextStyle(color: Colors.white70),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           ...List.generate(railItems.length, (index) {
// //             final bool selected = selectedIndex == index;
// //             return ListTile(
// //               leading: IconTheme(
// //                 data: IconThemeData(
// //                   color: selected ? Colors.indigo : Colors.grey,
// //                 ),
// //                 child: railItems[index].icon,
// //               ),
// //               title: Text((railItems[index].label as Text).data!),
// //               selected: selected,
// //               selectedTileColor: Colors.indigo.shade50,
// //               onTap: () {
// //                 setState(() => selectedIndex = index);
// //                 Navigator.pop(context);
// //               },
// //             );
// //           }),
// //         ],
// //       ),
// //     );
// //   }

// //   // LOGOUT
// //   Future<void> _logout() async {
// //     try {
// //       await AuthService.clearSession(); // clears DB session fields
// //     } catch (_) {}

// //     if (!mounted) return;

// //     Navigator.of(context).pushAndRemoveUntil(
// //       MaterialPageRoute(builder: (_) => const LoginScreen()),
// //       (route) => false,
// //     );
// //   }
// // }
// import '../services/auth_service.dart';
// import 'package:provider/provider.dart';
// import '../providers/attendance_provider.dart';
// import 'package:flutter/material.dart';
// import 'hr_home_screen.dart';
// import 'emp_attendance_screen.dart';
// import 'admin_hr_attendance_screen.dart';
// import 'tl_leave_screen.dart';
// import 'login_screen.dart';
// import '../services/location_services.dart';
// import 'emp_profile_screen.dart';
// import 'tl_hr_leave_screen.dart';

// class TLDashboardScreen extends StatefulWidget {
//   final String employeeId;
//   final String role;
//   final int initialIndex;
//   final int loginId;

//   const TLDashboardScreen({
//     super.key,
//     required this.loginId,
//     required this.employeeId,
//     required this.role,
//     this.initialIndex = 0,
//   });

//   @override
//   State<TLDashboardScreen> createState() => _TLDashboardScreenState();
// }

// class _TLDashboardScreenState extends State<TLDashboardScreen> {
//   // ── Design tokens (identical to AdminDashboardScreen) ──────────────────────
//   static const Color _primary = Color(0xFF1A56DB);
//   static const Color _surface = Color(0xFFF0F4FF);
//   static const Color _border = Color(0xFFE2E8F0);
//   static const Color _textDark = Color(0xFF0F172A);
//   static const Color _textMid = Color(0xFF64748B);
//   static const Color _selectedBg = Color(0xFFEEF2FF);

//   static const double _expandThreshold = 120.0;

//   late int selectedIndex;
//   bool isExpanded = false;
//   late LocationService locationService;

//   static const int notificationIndex = 12; // kept for future use

//   @override
//   void initState() {
//     super.initState();
//     selectedIndex = widget.initialIndex;
//     locationService = LocationService();
//   }

//   // ── Pages ──────────────────────────────────────────────────────────────────
//   List<Widget> get pages => [
//     HrHomeScreen(employeeId: widget.employeeId), // 0
//     AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
//     AdminHrAttendanceScreen(), // 2
//     TLLeaveScreen(loginId: widget.loginId), // 3
//     TL_HR_LeaveScreen(employeeId: widget.employeeId), // 4
//     EmployeeProfileScreen(employeeId: widget.employeeId.toString()), // 5
//   ];

//   // ── Titles ─────────────────────────────────────────────────────────────────
//   final List<String> titles = [
//     'Dashboard',
//     'Mark Attendance',
//     'Manage Attendance',
//     'Leave Approval',
//     'Apply Leave',
//     'Profile',
//   ];

//   // ── Rail items ─────────────────────────────────────────────────────────────
//   final List<NavigationRailDestination> railItems = const [
//     NavigationRailDestination(
//       icon: Icon(Icons.dashboard_outlined),
//       selectedIcon: Icon(Icons.dashboard),
//       label: Text('Dashboard'),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.fingerprint_outlined),
//       selectedIcon: Icon(Icons.fingerprint),
//       label: Text('Mark Attendance'),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.fact_check_outlined),
//       selectedIcon: Icon(Icons.fact_check),
//       label: Text('Manage Attendance'),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.event_busy_outlined),
//       selectedIcon: Icon(Icons.event_busy),
//       label: Text('Leave Approval'),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.beach_access_outlined),
//       selectedIcon: Icon(Icons.beach_access),
//       label: Text('Apply Leave'),
//     ),
//     NavigationRailDestination(
//       icon: Icon(Icons.person_outline),
//       selectedIcon: Icon(Icons.person),
//       label: Text('Profile'),
//     ),
//   ];

//   // ── Build ──────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final bool isDesktop = MediaQuery.of(context).size.width >= 900;

//     return ChangeNotifierProvider(
//       create: (_) => AttendanceProvider(empId: widget.employeeId),
//       child: Scaffold(
//         backgroundColor: _surface,
//         appBar: AppBar(
//           backgroundColor: _primary,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           title: Text(
//             titles[selectedIndex],
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w700,
//               fontSize: 17,
//             ),
//           ),
//           iconTheme: const IconThemeData(color: Colors.white),
//           actions: [
//             IconButton(
//               tooltip: 'Notifications',
//               icon: const Icon(
//                 Icons.notifications_outlined,
//                 color: Colors.white,
//               ),
//               onPressed: () =>
//                   setState(() => selectedIndex = notificationIndex),
//             ),
//             const SizedBox(width: 4),
//           ],
//         ),
//         drawer: isDesktop ? null : _mobileDrawer(),
//         body: Row(
//           children: [
//             if (isDesktop) _desktopSidebar(),
//             Expanded(
//               child: AnimatedSwitcher(
//                 duration: const Duration(milliseconds: 250),
//                 child: pages[selectedIndex],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Desktop sidebar ────────────────────────────────────────────────────────
//   Widget _desktopSidebar() {
//     return MouseRegion(
//       onEnter: (_) => setState(() => isExpanded = true),
//       onExit: (_) => setState(() => isExpanded = false),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         curve: Curves.easeInOut,
//         width: isExpanded ? 232 : 72,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           border: Border(right: BorderSide(color: _border, width: 1)),
//         ),
//         child: ClipRect(
//           child: LayoutBuilder(
//             builder: (context, constraints) {
//               final bool wide = constraints.maxWidth >= _expandThreshold;

//               return Column(
//                 children: [
//                   // ── Header ─────────────────────────────────────────────
//                   SizedBox(
//                     height: 56,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       child: Row(
//                         children: [
//                           const Icon(
//                             Icons.supervised_user_circle_rounded,
//                             size: 24,
//                           ),
//                           if (wide) ...[
//                             const SizedBox(width: 10),
//                             const Expanded(
//                               child: Text(
//                                 'TL Panel',
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ),

//                   // ── Nav items ───────────────────────────────────────────
//                   Expanded(
//                     child: ListView.builder(
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                       itemCount: railItems.length,
//                       itemBuilder: (context, index) {
//                         final item = railItems[index];
//                         final selected = selectedIndex == index;
//                         final label = (item.label as Text).data!;

//                         return Tooltip(
//                           message: wide ? '' : label,
//                           preferBelow: false,
//                           child: InkWell(
//                             onTap: () => setState(() => selectedIndex = index),
//                             borderRadius: BorderRadius.circular(10),
//                             child: Container(
//                               margin: const EdgeInsets.symmetric(
//                                 horizontal: 6,
//                                 vertical: 2,
//                               ),
//                               padding: wide
//                                   ? const EdgeInsets.only(
//                                       top: 11,
//                                       bottom: 11,
//                                       left: 10,
//                                       right: 8,
//                                     )
//                                   : const EdgeInsets.symmetric(vertical: 11),
//                               decoration: BoxDecoration(
//                                 color: selected
//                                     ? _selectedBg
//                                     : Colors.transparent,
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: selected
//                                     ? Border.all(
//                                         color: _primary.withOpacity(0.15),
//                                         width: 1,
//                                       )
//                                     : null,
//                               ),
//                               child: wide
//                                   ? Row(
//                                       children: [
//                                         // Icon
//                                         IconTheme(
//                                           data: IconThemeData(
//                                             color: selected
//                                                 ? _primary
//                                                 : _textMid,
//                                             size: 20,
//                                           ),
//                                           child: selected
//                                               ? item.selectedIcon
//                                               : item.icon,
//                                         ),
//                                         const SizedBox(width: 10),
//                                         // Label
//                                         Expanded(
//                                           child: Text(
//                                             label,
//                                             maxLines: 1,
//                                             overflow: TextOverflow.ellipsis,
//                                             style: TextStyle(
//                                               fontSize: 13,
//                                               fontWeight: selected
//                                                   ? FontWeight.w600
//                                                   : FontWeight.w400,
//                                               color: selected
//                                                   ? _primary
//                                                   : _textDark,
//                                             ),
//                                           ),
//                                         ),
//                                         // Active dot
//                                         SizedBox(
//                                           width: 10,
//                                           child: selected
//                                               ? Center(
//                                                   child: Container(
//                                                     width: 6,
//                                                     height: 6,
//                                                     decoration: BoxDecoration(
//                                                       color: _primary,
//                                                       shape: BoxShape.circle,
//                                                     ),
//                                                   ),
//                                                 )
//                                               : const SizedBox.shrink(),
//                                         ),
//                                       ],
//                                     )
//                                   : Center(
//                                       child: IconTheme(
//                                         data: IconThemeData(
//                                           color: selected ? _primary : _textMid,
//                                           size: 20,
//                                         ),
//                                         child: selected
//                                             ? item.selectedIcon
//                                             : item.icon,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),

//                   // ── Footer logout ───────────────────────────────────────
//                   Container(
//                     decoration: BoxDecoration(
//                       border: Border(top: BorderSide(color: _border, width: 1)),
//                     ),
//                     child: InkWell(
//                       onTap: _logout,
//                       borderRadius: BorderRadius.circular(10),
//                       child: Container(
//                         margin: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 8,
//                         ),
//                         padding: wide
//                             ? const EdgeInsets.only(
//                                 top: 11,
//                                 bottom: 11,
//                                 left: 10,
//                                 right: 8,
//                               )
//                             : const EdgeInsets.symmetric(vertical: 11),
//                         child: wide
//                             ? Row(
//                                 children: const [
//                                   Icon(
//                                     Icons.logout_rounded,
//                                     color: Color(0xFFEF4444),
//                                     size: 20,
//                                   ),
//                                   SizedBox(width: 10),
//                                   Expanded(
//                                     child: Text(
//                                       'Logout',
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                       style: TextStyle(
//                                         fontSize: 13,
//                                         fontWeight: FontWeight.w500,
//                                         color: Color(0xFFEF4444),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               )
//                             : const Center(
//                                 child: Icon(
//                                   Icons.logout_rounded,
//                                   color: Color(0xFFEF4444),
//                                   size: 20,
//                                 ),
//                               ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Mobile drawer ──────────────────────────────────────────────────────────
//   Widget _mobileDrawer() {
//     return Drawer(
//       backgroundColor: Colors.white,
//       child: Column(
//         children: [
//           // Header gradient — matches Admin dashboard style
//           Container(
//             width: double.infinity,
//             padding: EdgeInsets.only(
//               top: MediaQuery.of(context).padding.top + 20,
//               left: 20,
//               right: 20,
//               bottom: 20,
//             ),
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Color(0xFF1A56DB),
//                   Color(0xFF1E3A8A),
//                   Color(0xFF1e1b4b),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.15),
//                     borderRadius: BorderRadius.circular(14),
//                     border: Border.all(
//                       color: Colors.white.withOpacity(0.25),
//                       width: 1.5,
//                     ),
//                   ),
//                   child: const Icon(
//                     Icons.supervised_user_circle_rounded,
//                     color: Colors.white,
//                     size: 26,
//                   ),
//                 ),
//                 const SizedBox(height: 14),
//                 const Text(
//                   'TL Panel',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 18,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: 0.2,
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Text(
//                   'Employee Attendance System',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.6),
//                     fontSize: 12,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Nav items
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.symmetric(vertical: 8),
//               itemCount: railItems.length,
//               itemBuilder: (context, index) {
//                 final selected = selectedIndex == index;
//                 final label = (railItems[index].label as Text).data!;
//                 return ListTile(
//                   dense: true,
//                   contentPadding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 1,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   leading: IconTheme(
//                     data: IconThemeData(
//                       color: selected ? _primary : _textMid,
//                       size: 20,
//                     ),
//                     child: selected
//                         ? railItems[index].selectedIcon
//                         : railItems[index].icon,
//                   ),
//                   title: Text(
//                     label,
//                     style: TextStyle(
//                       fontSize: 13,
//                       fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
//                       color: selected ? _primary : _textDark,
//                     ),
//                   ),
//                   selected: selected,
//                   selectedTileColor: _selectedBg,
//                   onTap: () {
//                     setState(() => selectedIndex = index);
//                     Navigator.pop(context);
//                   },
//                 );
//               },
//             ),
//           ),

//           // Footer logout
//           Container(
//             decoration: BoxDecoration(
//               border: Border(top: BorderSide(color: _border, width: 1)),
//             ),
//             child: ListTile(
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 4,
//               ),
//               leading: const Icon(
//                 Icons.logout_rounded,
//                 color: Color(0xFFEF4444),
//                 size: 20,
//               ),
//               title: const Text(
//                 'Logout',
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w500,
//                   color: Color(0xFFEF4444),
//                 ),
//               ),
//               onTap: () {
//                 Navigator.pop(context);
//                 _logout();
//               },
//             ),
//           ),

//           SafeArea(top: false, child: const SizedBox(height: 5)),
//         ],
//       ),
//     );
//   }

//   // ── Logout ─────────────────────────────────────────────────────────────────
//   Future<void> _logout() async {
//     try {
//       await AuthService.clearSession();
//     } catch (_) {}
//     if (!mounted) return;
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => const LoginScreen()),
//       (route) => false,
//     );
//   }
// }
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'tl_home_screen.dart';
import 'emp_attendance_screen.dart';
import 'tl_att_screen.dart';
import 'tl_leave_approval_screen.dart';
import 'login_screen.dart';
import '../services/location_services.dart';
import 'emp_profile_screen.dart';
import 'tl_hr_leave_screen.dart';
import 'session_guard_mixin.dart';
import 'emp_work_location.dart';
import '../services/attendance_state.dart';
import '../services/api_service.dart';
import '../services/site_cache.dart';

class TLDashboardScreen extends StatefulWidget {
  final String employeeId;
  final String role;
  final int initialIndex;
  final int loginId;

  const TLDashboardScreen({
    super.key,
    required this.loginId,
    required this.employeeId,
    required this.role,
    this.initialIndex = 0,
  });

  @override
  State<TLDashboardScreen> createState() => _TLDashboardScreenState();
}

class _TLDashboardScreenState extends State<TLDashboardScreen>
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
  late LocationService locationService;

  // static const int notificationIndex = 12;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    locationService = LocationService();
    startSessionGuard();
  }

  // ── Pages ──────────────────────────────────────────────────────────────────
  List<Widget> get pages => [
    TlHomeScreen(
      employeeId: widget.employeeId.toString(),
      loginId: widget.loginId.toString(), // ← add this
      onNavigate: (index) => setState(() => selectedIndex = index),
    ), // 0
    AttendanceScreen(employeeId: int.parse(widget.employeeId)), // 1
    TLAttendanceScreen(loginId: widget.loginId), // 2
    TLLeaveScreen(loginId: widget.loginId), // 3
    TL_HR_LeaveScreen(employeeId: widget.employeeId), // 4
    EmployeeAssignmentsScreen(),
    EmployeeProfileScreen(employeeId: widget.employeeId.toString()), // 5
  ];

  // ── Titles ─────────────────────────────────────────────────────────────────
  final List<String> titles = [
    'Dashboard',
    'Mark Attendance',
    'Manage Attendance',
    'Leave Approval',
    'Apply Leave',
    "Sites",
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
    final double width = MediaQuery.of(context).size.width;

    // Three-tier breakpoints
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 900;
    final bool isDesktop = width >= 900;

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
        ),
        // Only mobile gets a hamburger drawer
        drawer: isMobile ? _mobileDrawer(width) : null,
        body: Row(
          children: [
            if (isDesktop) _desktopSidebar(),
            if (isTablet) _tabletRail(), // ← new tablet rail
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

  // ── Desktop sidebar (hover-expand) ─────────────────────────────────────────
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
                  // Header
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
                                'TL Panel',
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

                  // Nav items
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

  // ── Tablet rail (icon-only, fixed 72 px) ───────────────────────────────────
  Widget _tabletRail() {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        children: [
          // Header icon
          const SizedBox(
            height: 56,
            child: Center(
              child: Icon(
                Icons.supervised_user_circle_rounded,
                size: 24,
                color: _textMid,
              ),
            ),
          ),

          // Nav icons
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: railItems.length,
              itemBuilder: (context, index) {
                final item = railItems[index];
                final selected = selectedIndex == index;
                final label = (item.label as Text).data!;

                return Tooltip(
                  message: label,
                  preferBelow: false,
                  child: InkWell(
                    onTap: () => setState(() => selectedIndex = index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: selected ? _selectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(
                                color: _primary.withOpacity(0.15),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(
                            color: selected ? _primary : _textMid,
                            size: 20,
                          ),
                          child: selected ? item.selectedIcon : item.icon,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Logout icon
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: _border, width: 1)),
            ),
            child: InkWell(
              onTap: _logout,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: const Center(
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
      ),
    );
  }

  // ── Mobile drawer (fully responsive) ──────────────────────────────────────
  Widget _mobileDrawer(double width) {
    // Size helpers
    final bool isSmall = width < 360;
    final bool isLarge = width > 500;

    return SizedBox(
      width: width * 0.75, // responsive drawer width (75 % of screen)
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // ── Gradient header ──────────────────────────────────────────
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
                      Icons.supervised_user_circle_rounded,
                      color: Colors.white,
                      size: isSmall
                          ? 22
                          : isLarge
                          ? 28
                          : 26, // responsive
                    ),
                  ),
                  SizedBox(height: isSmall ? 10 : 14),
                  Text(
                    'TL Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall
                          ? 16
                          : isLarge
                          ? 20
                          : 18, // responsive
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Employee Attendance System',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: isSmall ? 10 : 12, // responsive
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // ── Nav items ────────────────────────────────────────────────
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
                      horizontal: width * 0.04, // responsive horizontal pad
                      vertical: width * 0.01, // responsive vertical pad
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

            // ── Logout footer ─────────────────────────────────────────────
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

  // ── Logout ─────────────────────────────────────────────────────────────────
  // Future<void> _logout() async {
  //   try {
  //     await AuthService.clearSession();
  //   } catch (_) {}
  //   if (!mounted) return;
  //   Navigator.of(context).pushAndRemoveUntil(
  //     MaterialPageRoute(builder: (_) => const LoginScreen()),
  //     (route) => false,
  //   );
  // }

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
