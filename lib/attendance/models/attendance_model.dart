class AttendanceModel {
  final int? attendanceId;
  final int empId;
  final DateTime? inTime;
  final DateTime? outTime;
  final String status; // IN / OUT
  final String isLate;
  final double? radius;
  final String? workedHrs;
  final String? inLast;
  final String? lateHrs;

  AttendanceModel({
    this.attendanceId,
    required this.empId,
    this.inTime,
    this.outTime,
    required this.status,
    required this.isLate,
    this.radius,
    this.workedHrs,
    this.inLast,
    this.lateHrs,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      attendanceId: json['attendance_id'],
      empId: json['emp_id'],
      inTime: json['in_time_date'] != null
          ? DateTime.parse(json['in_time_date'])
          : null,
      outTime: json['out_time_date'] != null
          ? DateTime.parse(json['out_time_date'])
          : null,
      status: json['status'],
      isLate: json['is_late'],
      radius: json['radius']?.toDouble(),
      workedHrs: json['worked_hrs']?.toString(),
      inLast: json['in_last'],
      lateHrs: json['late_hrs']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance_id': attendanceId,
      'emp_id': empId,
      'in_time_date': inTime?.toIso8601String(),
      'out_time_date': outTime?.toIso8601String(),
      'status': status,
      'is_late': isLate,
      'radius': radius,
      'worked_hrs': workedHrs,
      'in_last': inLast,
      'late_hrs': lateHrs,
    };
  }
}
