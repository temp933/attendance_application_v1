class LeaveModel {
  final String employeeName;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final String reason;

  String status; // Pending / Approved / Rejected
  String rejectionReason;

  LeaveModel({
    required this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = "Pending",
    this.rejectionReason = "",
  });
}
