import 'package:flutter/material.dart';
import 'leave_policy_management.dart'; // adjust import paths
import './Attendance screens/attendance_policy_screen.dart'; // adjust import paths

const Color _primary = Color(0xFF1A56DB);

class PolicyManagementScreen extends StatefulWidget {
  final String authToken;
  final String tenantId;

  const PolicyManagementScreen({
    super.key,
    required this.authToken,
    required this.tenantId,
  });

  @override
  State<PolicyManagementScreen> createState() => _PolicyManagementScreenState();
}

class _PolicyManagementScreenState extends State<PolicyManagementScreen> {
  static const _primary = Color(0xFF1A56DB);
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _primary,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.policy_outlined, size: 18),
                          text: 'Leave Policies',
                        ),
                        Tab(
                          icon: Icon(
                            Icons.access_time_filled_rounded,
                            size: 18,
                          ),
                          text: 'Attendance',
                        ),
                      ],
                    ),
                  ),
                  
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _LeavePolicyTab(key: ValueKey('leave_$_refreshKey')),

            _AttendancePolicyTab(
              key: ValueKey('attend_$_refreshKey'),
              authToken: widget.authToken,
              tenantId: widget.tenantId,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeavePolicyTab extends StatelessWidget {
  const _LeavePolicyTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const LeavePolicyManagementScreen(hideAppBar: true);
  }
}

class _AttendancePolicyTab extends StatelessWidget {
  final String authToken;
  final String tenantId;
  const _AttendancePolicyTab({
    super.key,
    required this.authToken,
    required this.tenantId,
  });

  @override
  Widget build(BuildContext context) {
    return AttendancePolicyScreen(
      authToken: authToken,
      tenantId: tenantId,
      hideAppBar: true,
    );
  }
}
