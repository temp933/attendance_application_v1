// class AssignLocationModel {
//   final int assignId;
//   final int empId;
//   final String empName;
//   final String? locationName;
//   final DateTime? startDate;
//   final DateTime? endDate;
//   final String? aboutWork;
//   final String status; // Active, Completed, Extended, Relieved
//   final String? assignBy; // Admin / HR / Employee
//   final String? extendReason;

//   AssignLocationModel({
//     required this.assignId,
//     required this.empId,
//     required this.empName,
//     this.locationName,
//     this.startDate,
//     this.endDate,
//     this.aboutWork,
//     required this.status,
//     this.assignBy,
//     this.extendReason,
//   });

//   factory AssignLocationModel.fromJson(Map<String, dynamic> json) {
//     return AssignLocationModel(
//       assignId: json['assign_id'],
//       empId: json['emp_id'],
//       empName: json['emp_name'],
//       locationName: json['location_name'],
//       startDate: json['start_date'] == null
//           ? null
//           : DateTime.parse(json['start_date']),
//       endDate: json['end_date'] == null
//           ? null
//           : DateTime.parse(json['end_date']),
//       aboutWork: json['about_work'],
//       status: json['status'],
//       assignBy: json['assign_by'],
//       extendReason: json['extend_reason'],
//     );
//   }

//   int get daysCount {
//     if (startDate == null || endDate == null) return 0;
//     return endDate!.difference(startDate!).inDays + 1;
//   }

//   bool get isExpired {
//     if (endDate == null) return false;
//     return DateTime.now().isAfter(endDate!);
//   }

//   bool get isExtended => status == "Extended";
//   bool get isRelieved => status == "Relieved";
//   bool get isCompleted => status == "Completed";
//   bool get isActive => status == "Active";
// }
// D:\Kavidhan Global tech\Employee Attendance System\employee_attendance_system\lib\attendance\models\asign_location.dart

class AssignLocationModel {
  final int assignId;
  final int empId;
  final String empName;
  final String? locationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? aboutWork;
  final String status; // Raw DB status: Active, Completed, Extended, Relieved
  final String
  workStatus; // Computed by backend: Working, Future, Not Completed, etc.
  final String? doneBy;
  final String? extendReason;

  AssignLocationModel({
    required this.assignId,
    required this.empId,
    required this.empName,
    this.locationName,
    this.startDate,
    this.endDate,
    this.aboutWork,
    required this.status,
    required this.workStatus,
    this.doneBy,
    this.extendReason,
  });

  factory AssignLocationModel.fromJson(Map<String, dynamic> json) {
    return AssignLocationModel(
      assignId: json['assign_id'] as int,
      empId: json['emp_id'] as int,
      empName: json['emp_name'] as String,
      locationName: json['location_name'] as String?,
      // Backend now returns plain DATE strings ("2026-02-20"), no timezone shift needed
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      aboutWork: json['about_work'] as String?,
      status: json['status'] as String,
      workStatus: json['work_status'] as String? ?? json['status'] as String,
      doneBy: json['done_by'] as String?,
      extendReason: json['extend_reason'] as String?,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Total days inclusive (e.g. Feb 20 – Feb 22 = 3 days)
  int get daysCount {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  /// True if end date is in the past (date-only comparison)
  bool get isExpired {
    if (endDate == null) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final endOnly = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return endOnly.isBefore(todayOnly);
  }

  bool get isExtended => status == "Extended";
  bool get isRelieved => status == "Relieved";
  bool get isCompleted => status == "Completed";
  bool get isActive => status == "Active";

  // Use workStatus (computed by backend) as the single source of truth for display
  String get displayStatus => workStatus;
}
