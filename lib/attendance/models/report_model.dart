class AttendanceReportModel {
  final String period;
  final int presentDays;
  final int absentDays;
  final double totalHours;

  AttendanceReportModel({
    required this.period,
    required this.presentDays,
    required this.absentDays,
    required this.totalHours,
  });

  factory AttendanceReportModel.fromJson(Map<String, dynamic> json) {
    return AttendanceReportModel(
      period: json['period'] ?? '',
      presentDays: json['presentDays'] ?? 0,
      absentDays: json['absentDays'] ?? 0,
      totalHours: (json['totalHours'] ?? 0).toDouble(),
    );
  }
}
