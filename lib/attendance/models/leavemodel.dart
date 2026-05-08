class LeaveModel {
  final int? leaveId;
  final int empId;
  final String? employeeName;
  final String? departmentName;
  final String? roleName;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final int numberOfDays;
  final String? approvedBy;
  final int? takenDays;
  final int? remainingDays;
  String status;
  final String? reason;
  final String? rejectionReason;
  final String? cancelReason;
  final String? recommendedByName;
  final String? recommendedBy;
  final String? recommendedAt;
  final String? createdAt;
  final String? updatedAt;
  final bool isHalfDay;
  int get effectiveDays {
    if (numberOfDays > 0) return numberOfDays;

    final diff = toDate.difference(fromDate).inDays + 1;

    if (isHalfDay) return 1; // or 0.5 if using double

    return diff > 0 ? diff : 1;
  }

  final String? halfDayPeriod; // 'AM' | 'PM'
  final double? allocatedDays;
  final double? usedDays;
  final double? pendingDays;

  LeaveModel({
    this.leaveId,
    required this.empId,
    this.employeeName,
    this.departmentName,
    this.roleName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    this.approvedBy,
    this.reason,
    this.takenDays,
    this.remainingDays,
    required this.status,
    this.rejectionReason,
    this.cancelReason,
    this.recommendedByName,
    this.recommendedBy,
    this.recommendedAt,
    this.createdAt,
    this.updatedAt,
    this.isHalfDay = false,
    this.halfDayPeriod,
    this.allocatedDays,
    this.usedDays,
    this.pendingDays,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  static int? _parseInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  static int _parseIntRequired(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    return (double.tryParse(v.toString()) ?? fallback.toDouble()).toInt();
  }

  /// Parses both "yyyy-MM-dd" (server default) and "dd.MM.yyyy" (legacy format).
  /// FIX: previous dot-branch had day/month swapped — p[0] is day, p[1] is month.
  static DateTime _parseDate(String? s) {
    if (s == null || s.isEmpty) return DateTime.now();

    // "dd.MM.yyyy" branch
    if (s.contains('.')) {
      final p = s.split('.');
      if (p.length == 3) {
        final day = int.tryParse(p[0]);
        final month = int.tryParse(p[1]);
        final year = int.tryParse(p[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    // FIX: wrap DateTime.parse in a try-catch so a malformed string from the
    // server doesn't crash the whole list parse — fall back to today instead.
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory LeaveModel.fromPendingJson(Map<String, dynamic> json) {
    return LeaveModel(
      leaveId: _parseInt(json['leave_id']),
      empId: _parseIntRequired(json['emp_id']),
      employeeName: json['employee_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      roleName: json['role_name']?.toString(),
      leaveType: json['leave_type']?.toString() ?? '',
      fromDate: _parseDate(
        (json['from_date'] ?? json['leave_start_date'])?.toString(),
      ),
      toDate: _parseDate(
        (json['to_date'] ?? json['leave_end_date'])?.toString(),
      ),
      numberOfDays: _parseIntRequired(
        json['total_days'] ?? json['number_of_days'],
      ),
      approvedBy: json['approved_by']?.toString(),
      reason: json['reason']?.toString(),
      takenDays: _parseInt(json['taken_days']),
      remainingDays: _parseInt(json['remaining_days']),
      status: json['status']?.toString() ?? 'Pending',
      rejectionReason: json['rejection_reason']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      recommendedBy: json['recommended_by']?.toString(),
      recommendedAt: json['recommended_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      isHalfDay: (json['is_half_day'] == 1 || json['is_half_day'] == true),
      halfDayPeriod: json['half_day_period']?.toString(),
    );
  }
  // ── fromHistoryJson ───────────────────────────────────────────────────────
  // Used by: /leaves/all-history, /leave-history
  // These endpoints return dates as 'from_date' / 'to_date' keys.
  factory LeaveModel.fromHistoryJson(Map<String, dynamic> json) {
    final approvedByName = json['approved_by_name']?.toString();
    final recommendedByName = json['recommended_by_name']?.toString();

    return LeaveModel(
      leaveId: _parseInt(json['leave_id']),
      empId: _parseIntRequired(json['emp_id']),
      employeeName: json['employee_name']?.toString(),
      departmentName: json['department_name']?.toString(),
      roleName: json['role_name']?.toString(),
      leaveType: json['leave_type']?.toString() ?? '',
      // FIX: history endpoints use 'from_date' / 'to_date' — not leave_start/end_date
      fromDate: _parseDate(json['from_date']?.toString()),
      toDate: _parseDate(json['to_date']?.toString()),
      numberOfDays: _parseIntRequired(json['number_of_days']),
      // Use resolved name if available, raw id otherwise
      approvedBy: approvedByName ?? json['approved_by']?.toString(),
      status: json['status']?.toString() ?? '',
      reason: json['reason']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      cancelReason: json['cancel_reason']?.toString(),
      recommendedByName: recommendedByName,
      isHalfDay: (json['is_half_day'] == 1 || json['is_half_day'] == true),
      halfDayPeriod: json['half_day_period']?.toString(),
    );
  }
}
