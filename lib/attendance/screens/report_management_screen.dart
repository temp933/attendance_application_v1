// import 'package:flutter/material.dart';
// import 'leave_policy_management.dart'; // adjust import paths
// import 'admin_leave_report.dart';
// import './Attendance screens/attendance_policy_screen.dart'; // adjust import paths

// const Color _primary = Color(0xFF1A56DB);

// class ReportManagementScreen extends StatefulWidget {
//   final String authToken;
//   final String tenantId;

//   const ReportManagementScreen({
//     super.key,
//     required this.authToken,
//     required this.tenantId,
//   });

//   @override
//   State<ReportManagementScreen> createState() => _ReportManagementScreenState();
// }

// class _ReportManagementScreenState extends State<ReportManagementScreen> {
//   static const _primary = Color(0xFF1A56DB);
//   int _refreshKey = 0;

//   void _refresh() => setState(() => _refreshKey++);

//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF0F4FF),
//         appBar: PreferredSize(
//           preferredSize: const Size.fromHeight(48),
//           child: Container(
//             color: const Color(0xFFF0F4FF),
//             child: SafeArea(
//               bottom: false,
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TabBar(
//                       indicatorColor: _primary,
//                       indicatorWeight: 3,
//                       labelColor: _primary,
//                       unselectedLabelColor: const Color.fromARGB(153, 35, 34, 34),
//                       labelStyle: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         fontSize: 13,
//                       ),
//                       unselectedLabelStyle: const TextStyle(
//                         fontWeight: FontWeight.w500,
//                         fontSize: 13,
//                       ),
//                       tabs: const [
//                         Tab(
//                           icon: Icon(Icons.policy_outlined, size: 18),
//                           text: 'Leave Report',
//                         ),
//                         Tab(
//                           icon: Icon(
//                             Icons.access_time_filled_rounded,
//                             size: 18,
//                           ),
//                           text: 'Attendance',
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                 ],
//               ),
//             ),
//           ),
//         ),
//         body: TabBarView(
//           children: [
//             _LeaveReportTab(key: ValueKey('leave_$_refreshKey')),

//             _AttendancePolicyTab(
//               key: ValueKey('attend_$_refreshKey'),
//               authToken: widget.authToken,
//               tenantId: widget.tenantId,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _LeaveReportTab extends StatelessWidget {
//   const _LeaveReportTab({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const LeaveReportScreen();
//   }
// }

// class _AttendancePolicyTab extends StatelessWidget {
//   final String authToken;
//   final String tenantId;
//   const _AttendancePolicyTab({
//     super.key,
//     required this.authToken,
//     required this.tenantId,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return AttendancePolicyScreen(
//       authToken: authToken,
//       tenantId: tenantId,
//       hideAppBar: true,
//     );
//   }
// }
