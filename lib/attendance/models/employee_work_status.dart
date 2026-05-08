class EmployeeWorkStatus {
  final int empId;
  final String empName;
  final String? locationName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String workStatus;
  final String? extendReason;
  final String? doneBy;

  EmployeeWorkStatus({
    required this.empId,
    required this.empName,
    this.locationName,
    this.startDate,
    this.endDate,
    required this.workStatus,
    this.extendReason,
    this.doneBy,
  });

  factory EmployeeWorkStatus.fromJson(Map<String, dynamic> json) {
    return EmployeeWorkStatus(
      empId: json['emp_id'],
      empName: json['emp_name'],
      locationName: json['location_name'],
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date']),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date']),
      workStatus: json['work_status'],
      extendReason: json['extend_reason'],
      doneBy: json['done_by'],
    );
  }
}


