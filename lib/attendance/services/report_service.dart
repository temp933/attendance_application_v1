import '../models/report_model.dart';

class ReportService {
  // ---------------- EXISTING ----------------
  Future<AttendanceReportModel> getWeeklyReport() async {
    await Future.delayed(const Duration(seconds: 1));

    return AttendanceReportModel(
      period: "11 Mar - 17 Mar 2025",
      presentDays: 5,
      absentDays: 0,
      totalHours: 42.5,
    );
  }

  Future<AttendanceReportModel> getMonthlyReport() async {
    await Future.delayed(const Duration(seconds: 1));

    return AttendanceReportModel(
      period: "March 2025",
      presentDays: 22,
      absentDays: 2,
      totalHours: 176,
    );
  }

  Future<double> getWorkHoursSummary({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // TODO: Replace with actual API call using fromDate & toDate
    return 218.5;
  }

  // ---------------- NEW: Employee-wise report ----------------
  Future<AttendanceReportModel> getEmployeeReport({
    String? employee,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // TODO: Replace this dummy data with API call to fetch for the specific employee & date range
    final periodText = fromDate != null && toDate != null
        ? "${fromDate.day}-${fromDate.month}-${fromDate.year} to ${toDate.day}-${toDate.month}-${toDate.year}"
        : "All Time";

    return AttendanceReportModel(
      period: periodText,
      presentDays: 20,
      absentDays: 2,
      totalHours: 160,
    );
  }
}
