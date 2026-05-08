import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../common/utils/greeting_util.dart';
import '../services/employee_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final String employeeId;
  final void Function(int index)? onNavigate; // ✅ ADD THIS

  const AdminHomeScreen({
    super.key,
    required this.employeeId,
    this.onNavigate, // ✅ ADD THIS
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String AdminName = ""; // admin's name to display
  bool isLoading = true; // Loading state
  int totalEmployees = 0;
  List<LeaveData> leaveChartData = [];
  bool isLeaveLoading = true;
  int presentCount = 0;
  int absentCount = 0;
  int lateEntryCount = 0;
  int onSiteCount = 0;
  int pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _fetchLeaveData();
  }

  Future<void> _fetchAdminData() async {
    try {
      final employee = await EmployeeService.fetchEmployee(
        int.parse(widget.employeeId),
      );

      final dashboard = await EmployeeService.fetchDashboardData();
      final onSite = await EmployeeService.fetchOnSiteToday();
      print("ON SITE VALUE FROM API: $onSite");

      String fullName = employee.firstName ?? "";

      if ((employee.midName ?? "").isNotEmpty) {
        fullName += " ${employee.midName}";
      }

      if ((employee.lastName ?? "").isNotEmpty) {
        fullName += " ${employee.lastName}";
      }

      setState(() {
        AdminName = fullName;
        totalEmployees = (dashboard['totalEmployees'] as num?)?.toInt() ?? 0;
        presentCount = (dashboard['present'] as num?)?.toInt() ?? 0;
        absentCount = (dashboard['absent'] as num?)?.toInt() ?? 0;
        lateEntryCount = (dashboard['lateEntry'] as num?)?.toInt() ?? 0;
        onSiteCount =
            (dashboard['activeSites'] as num?)?.toInt() ??
            0; // ← was 'onSite', API sends 'activeSites'
        pendingCount = (dashboard['pendingRequests'] as num?)?.toInt() ?? 0;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching Admin data: $e");
      setState(() {
        AdminName = "Admin";
        isLoading = false;
      });
    }
  }

  Future<void> _fetchLeaveData() async {
    setState(() => isLeaveLoading = true);

    try {
      final dataFromService = await EmployeeService.fetchLeaveStatusSummary();

      final filteredData = dataFromService
          .where((e) => e.status.toLowerCase() != "cancelled")
          .toList();

      setState(() {
        leaveChartData = filteredData;
        isLeaveLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching leave chart: $e");
      setState(() {
        leaveChartData = [];
        isLeaveLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.08 : 16;
    final double spacing = isDesktop ? 24 : 16;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: spacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// GREETING
              Text(
                getGreeting(),
                style: TextStyle(
                  fontSize: isDesktop ? 28 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              /// SHOW HR NAME OR LOADING
              isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      "Welcome back Admin, $AdminName",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),

              SizedBox(height: spacing),

              /// DASHBOARD CARDS GRID
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 2; // Mobile default
                  double childAspectRatio = 2.5; // Mobile default
                  if (constraints.maxWidth >= 900) {
                    crossAxisCount = 3;
                    childAspectRatio = 2.2; // Desktop
                  } else if (constraints.maxWidth >= 600) {
                    // Tablet
                    crossAxisCount = 2;
                    childAspectRatio = 2.0; // Slightly taller
                  } else {
                    // Small mobile
                    crossAxisCount = 2;
                    childAspectRatio = 1.8; // Increase height
                  }

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio, // Adjusted height
                    children: [
                      _DashboardCard(
                        title: "Total Employees",
                        value: totalEmployees.toString(),
                        icon: Icons.people_outline,
                        gradient: const [Colors.blue, Colors.lightBlueAccent],
                        onTap: () => widget.onNavigate?.call(
                          5,
                        ), // ✅ index 9 = Manage Users
                      ),

                      _DashboardCard(
                        title: "Present",
                        value: presentCount.toString(),
                        icon: Icons.check_circle_outline,
                        gradient: [Colors.green, Colors.lightGreenAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "Absent",
                        value: absentCount.toString(),
                        icon: Icons.cancel_outlined,
                        gradient: [Colors.red, Colors.redAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "Late Entry",
                        value: lateEntryCount.toString(),
                        icon: Icons.watch_later_outlined,
                        gradient: [Colors.orange, Colors.deepOrangeAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "On-Site Today",
                        value: onSiteCount.toString(),
                        icon: Icons.work_outline,
                        gradient: [Colors.indigo, Colors.indigoAccent],
                        onTap: () => widget.onNavigate?.call(7),
                      ),

                      _DashboardCard(
                        title: "Pending Requests",
                        value: pendingCount.toString(),
                        icon: Icons.beach_access_outlined,
                        gradient: [Colors.purple, Colors.purpleAccent],
                        // no onTap — keep as is
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: spacing),

              LayoutBuilder(
                builder: (context, constraints) {
                  bool isWide = constraints.maxWidth >= 700; // breakpoint

                  Widget leaveChart = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Leave Approval Status",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing / 2),
                      SizedBox(
                        height: isDesktop ? 300 : 220,
                        child: isLeaveLoading
                            ? const Center(child: CircularProgressIndicator())
                            : leaveChartData.isEmpty
                            ? const Center(
                                child: Text("No leave data available"),
                              )
                            : SfCircularChart(
                                legend: const Legend(
                                  isVisible: true,
                                  position: LegendPosition.bottom,
                                  overflowMode: LegendItemOverflowMode.wrap,
                                ),
                                series: <CircularSeries<LeaveData, String>>[
                                  PieSeries<LeaveData, String>(
                                    dataSource: leaveChartData,
                                    xValueMapper: (d, _) => d.status,
                                    yValueMapper: (d, _) => d.count,
                                    pointColorMapper: (d, _) => d.color,
                                    dataLabelSettings: const DataLabelSettings(
                                      isVisible: true,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );

                  Widget employeeChart = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Employee Status",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: spacing / 2),
                      SizedBox(
                        height: isDesktop ? 300 : 220,
                        child: SfCircularChart(
                          legend: const Legend(
                            isVisible: true,
                            position: LegendPosition.bottom,
                            overflowMode: LegendItemOverflowMode.wrap,
                          ),
                          series: <CircularSeries<LeaveData, String>>[
                            PieSeries<LeaveData, String>(
                              dataSource: const [
                                LeaveData("On-Site", 4, Colors.green),
                                LeaveData(
                                  "Office",
                                  38,
                                  Color.fromARGB(255, 7, 243, 172),
                                ),
                                LeaveData("Travel", 6, Colors.red),
                              ],
                              xValueMapper: (d, _) => d.status,
                              yValueMapper: (d, _) => d.count,
                              pointColorMapper: (d, _) => d.color,
                              dataLabelMapper: (d, _) =>
                                  "${d.status} (${d.count})",
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                labelPosition: ChartDataLabelPosition.outside,
                                connectorLineSettings: ConnectorLineSettings(
                                  type: ConnectorType.curve,
                                ),
                                textStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (isWide) {
                    // ✅ Desktop / Tablet → side by side
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leaveChart),
                        SizedBox(width: spacing),
                        Expanded(child: employeeChart),
                      ],
                    );
                  } else {
                    // ✅ Mobile → stacked
                    return Column(
                      children: [
                        leaveChart,
                        SizedBox(height: spacing),
                        employeeChart,
                      ],
                    );
                  }
                },
              ),

              /// RECENT ACTIVITIES
              const Text(
                "Recent Activities",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: spacing / 2),
              const _ActivityCard(
                employee: "John Doe",
                action: "Applied for leave",
                time: "Today, 9:30 AM",
              ),
              const _ActivityCard(
                employee: "Sara Smith",
                action: "Checked-in",
                time: "Today, 9:00 AM",
              ),
              const _ActivityCard(
                employee: "David Lee",
                action: "Submitted expense report",
                time: "Yesterday, 5:00 PM",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap; // ✅ ADD THIS

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap, // ✅ ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          // ✅ WRAP WITH GestureDetector
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: isDesktop ? 32 : 26),
                SizedBox(height: isDesktop ? 12 : 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isDesktop ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// RECENT ACTIVITY CARD
class _ActivityCard extends StatelessWidget {
  final String employee;
  final String action;
  final String time;

  const _ActivityCard({
    required this.employee,
    required this.action,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Card(
      margin: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: isDesktop ? 28 : 24,
          ),
        ),
        title: Text(
          "$employee $action",
          style: TextStyle(fontSize: isDesktop ? 16 : 14),
        ),
        subtitle: Text(time, style: TextStyle(fontSize: isDesktop ? 14 : 12)),
      ),
    );
  }
}
