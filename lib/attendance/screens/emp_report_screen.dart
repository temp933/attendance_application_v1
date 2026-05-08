import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportService _reportService;

  late final Future<AttendanceReportModel> _weeklyReport;
  late final Future<AttendanceReportModel> _monthlyReport;
  late final Future<double> _workHoursSummary;

  @override
  void initState() {
    super.initState();
    _reportService = ReportService();

    _weeklyReport = _reportService.getWeeklyReport();
    _monthlyReport = _reportService.getMonthlyReport();
    _workHoursSummary = _reportService.getWorkHoursSummary();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? size.width * 0.18 : 16,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reportCard(
              title: "Weekly Attendance Report",
              future: _weeklyReport,
              isDesktop: isDesktop,
            ),
            _reportCard(
              title: "Monthly Attendance Report",
              future: _monthlyReport,
              isDesktop: isDesktop,
            ),
            _summaryCard(_workHoursSummary, isDesktop),
          ],
        ),
      ),
    );
  }

  // ================= REPORT CARD =================
  Widget _reportCard({
    required String title,
    required Future<AttendanceReportModel> future,
    required bool isDesktop,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: FutureBuilder<AttendanceReportModel>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData) {
              return const Text("No data available");
            }

            final report = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                _infoRow("Period", report.period),
                _infoRow("Present Days", report.presentDays.toString()),
                _infoRow("Absent Days", report.absentDays.toString()),
                _infoRow("Total Hours", "${report.totalHours} hrs"),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= SUMMARY CARD =================
  Widget _summaryCard(Future<double> future, bool isDesktop) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: FutureBuilder<double>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData) {
              return const Text("No data");
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Work Hours Summary",
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "${snapshot.data} Total Hours Worked",
                  style: TextStyle(
                    fontSize: isDesktop ? 26 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ================= INFO ROW =================
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
