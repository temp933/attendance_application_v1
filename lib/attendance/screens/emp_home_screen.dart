import 'package:flutter/material.dart';
import 'dart:convert';
import '../../common/utils/greeting_util.dart';
import '../services/employee_location_service.dart';
import '../models/employee_location_model.dart';
import '../services/employee_service.dart';
import '../providers/api_client.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final int empId;
  final String role;

  const EmployeeHomeScreen({
    super.key,
    required this.empId,
    required this.role,
  });

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  String employeeName = "";
  bool isLoading = true;

  EmployeeLocationAssignment? locationData;
  bool isLocationLoading = true;

  final locationService = EmployeeLocationService();

  String todayHours = "0h 0m";
  String weekHours = "0h 0m";
  bool isHoursLoading = true;

  // ── Attendance summary ──────────────────────────────────────────────────────
  String attendanceStatus = "Not Checked In";
  String? currentSite;
  bool isAttendanceLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEmployeeName();
    fetchEmployeeLocation();
    fetchWorkHours();
    fetchTodayAttendance(); // ← new
  }

  // ── ACTIVE ASSIGNMENT CHECK ─────────────────────────────────────────────────
  bool get hasActiveAssignment {
    if (locationData == null) return false;
    final today = DateTime.now();
    final end = locationData!.endDate;
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(end.year, end.month, end.day);
    return !endDate.isBefore(todayDate);
  }

  // ── Attendance status color ─────────────────────────────────────────────────
  Color get attendanceColor {
    switch (attendanceStatus) {
      case "Checked In":
        return Colors.green;
      case "Checked Out":
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  // ── FETCH EMPLOYEE NAME ─────────────────────────────────────────────────────
  Future<void> fetchEmployeeName() async {
    try {
      final response = await ApiClient.get('/employees/${widget.empId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          employeeName =
              "${data['first_name'] ?? ''} ${data['middle_name'] ?? ''} ${data['last_name'] ?? ''}"
                  .trim();
          isLoading = false;
        });
      } else {
        setState(() {
          employeeName = "Unknown User";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching employee: $e");
      setState(() {
        employeeName = "Unknown User";
        isLoading = false;
      });
    }
  }

  // ── FETCH EMPLOYEE LOCATION ASSIGNMENT ──────────────────────────────────────
  Future<void> fetchEmployeeLocation() async {
    try {
      final result = await locationService.fetchEmployeeLocation(widget.empId);
      setState(() {
        locationData = result;
        isLocationLoading = false;
      });
    } catch (e) {
      debugPrint("Location fetch error: $e");
      setState(() => isLocationLoading = false);
    }
  }

  // ── FETCH WORK HOURS ────────────────────────────────────────────────────────
  Future<void> fetchWorkHours() async {
    try {
      final result = await EmployeeService.fetchEmployeeWorkHours(widget.empId);
      setState(() {
        todayHours = result["today"]!;
        weekHours = result["week"]!;
        isHoursLoading = false;
      });
    } catch (e) {
      debugPrint("Work hours error: $e");
      setState(() {
        isHoursLoading = false;
        todayHours = "0h 0m";
        weekHours = "0h 0m";
      });
    }
  }

  // ── FETCH TODAY ATTENDANCE SUMMARY ──────────────────────────────────────────
  Future<void> fetchTodayAttendance() async {
    try {
      final response = await ApiClient.get(
        '/attendance/today-summary/${widget.empId}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            attendanceStatus = data['attendanceStatus'] ?? 'Not Checked In';
            currentSite = data['currentSite'];
            // Also sync todayHours from the same response to avoid
            // two separate calls returning inconsistent values
            if (data['todayHours'] != null) {
              todayHours = data['todayHours'];
            }
            isAttendanceLoading = false;
          });
        } else {
          setState(() => isAttendanceLoading = false);
        }
      } else {
        setState(() => isAttendanceLoading = false);
      }
    } catch (e) {
      debugPrint("Attendance summary error: $e");
      setState(() => isAttendanceLoading = false);
    }
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.15 : 16;
    final double spacing = isDesktop ? 24 : 16;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GREETING
                  Text(
                    getGreeting(),
                    style: TextStyle(
                      fontSize: isDesktop ? 28 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Welcome back, $employeeName",
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: spacing),

                  // ATTENDANCE STATUS CARD
                  _infoCard(
                    icon: Icons.access_time,
                    title: "Attendance Status",
                    value: isAttendanceLoading
                        ? "Loading..."
                        : attendanceStatus,
                    color: isAttendanceLoading ? Colors.grey : attendanceColor,
                    isDesktop: isDesktop,
                  ),

                  SizedBox(height: spacing),

                  // WORK TYPE + CURRENT SITE
                  Row(
                    children: [
                      Expanded(
                        child: _SmallCard(
                          title: "Work Type",
                          value: isLocationLoading
                              ? "Loading..."
                              : hasActiveAssignment
                              ? (locationData!.locationName
                                            .trim()
                                            .toLowerCase() ==
                                        "office"
                                    ? "Work From Office"
                                    : "On-Site")
                              : "Work From Office",
                          icon: Icons.work_outline,
                          isDesktop: isDesktop,
                        ),
                      ),
                      SizedBox(width: spacing / 1.5),
                      Expanded(
                        child: _SmallCard(
                          title: "Current Site",
                          value: isAttendanceLoading
                              ? "Loading..."
                              : currentSite ?? "Not on site",
                          icon: Icons.location_on_outlined,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: spacing),

                  // WORK HOURS
                  Row(
                    children: [
                      Expanded(
                        child: _SmallCard(
                          title: "Today's Hours",
                          value: isHoursLoading ? "Loading..." : todayHours,
                          icon: Icons.timer_outlined,
                          isDesktop: isDesktop,
                        ),
                      ),
                      SizedBox(width: spacing / 1.5),
                      Expanded(
                        child: _SmallCard(
                          title: "Weekly Total",
                          value: isHoursLoading ? "Loading..." : weekHours,
                          icon: Icons.bar_chart_outlined,
                          isDesktop: isDesktop,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ── INFO CARD (large, single row) ───────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDesktop,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 16 : 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── SMALL CARD (icon + title + value, stacked) ──────────────────────────────
class _SmallCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isDesktop;

  const _SmallCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
