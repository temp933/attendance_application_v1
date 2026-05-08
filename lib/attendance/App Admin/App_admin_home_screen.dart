import 'package:flutter/material.dart';
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
    _loadDummyData();
  }

  void _loadDummyData() async {
    await Future.delayed(const Duration(milliseconds: 800)); // fake delay

    setState(() {
      AdminName = "Kavidhan"; // dummy admin name

      totalEmployees = 48;
      presentCount = 38;
      absentCount = 6;
      lateEntryCount = 4;
      onSiteCount = 5;
      pendingCount = 3;

      leaveChartData = [
        LeaveData("Approved", 12, Colors.green),
        LeaveData("Pending", 5, Colors.orange),
        LeaveData("Rejected", 2, Colors.red),
      ];

      isLoading = false;
      isLeaveLoading = false;
    });
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
                        title: "Total Companies",
                        value: totalEmployees.toString(),
                        icon: Icons.people_outline,
                        gradient: const [Colors.blue, Colors.lightBlueAccent],
                        onTap: () => widget.onNavigate?.call(
                          5,
                        ), // ✅ index 9 = Manage Users
                      ),

                      _DashboardCard(
                        title: "Active",
                        value: presentCount.toString(),
                        icon: Icons.check_circle_outline,
                        gradient: [Colors.green, Colors.lightGreenAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "Trial",
                        value: absentCount.toString(),
                        icon: Icons.cancel_outlined,
                        gradient: [Colors.red, Colors.redAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "Revenue",
                        value: lateEntryCount.toString(),
                        icon: Icons.watch_later_outlined,
                        gradient: [Colors.orange, Colors.deepOrangeAccent],
                        onTap: () => widget.onNavigate?.call(
                          2,
                        ), // ✅ index 2 = Manage Attendance
                      ),

                      _DashboardCard(
                        title: "Expiry",
                        value: onSiteCount.toString(),
                        icon: Icons.work_outline,
                        gradient: [Colors.indigo, Colors.indigoAccent],
                        onTap: () => widget.onNavigate?.call(7),
                      ),

                      _DashboardCard(
                        title: "Alerts",
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
                    children: [],
                  );

                  if (isWide) {
                    // ✅ Desktop / Tablet → side by side
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leaveChart),
                        SizedBox(width: spacing),
                      ],
                    );
                  } else {
                    // ✅ Mobile → stacked
                    return Column(
                      children: [
                        leaveChart,
                        SizedBox(height: spacing),
                      ],
                    );
                  }
                },
              ),

              /// RECENT ACTIVITIES
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
