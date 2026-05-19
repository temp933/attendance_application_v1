class LeaveModel {
  final int? leaveId;
  final int empId;
  final String? tenantId;
  final String? employeeName;

  final String leaveType;

  final DateTime fromDate;
  final DateTime toDate;

  final int numberOfDays;

  final bool isHalfDay;
  final String? halfDayPeriod;

  final String? reason;

  final String finalStatus;

  final int? currentApprovalLevel;
  final int? currentApproverEmployeeId;

  final String? currentApproverName;

  final String? createdAt;
  final String? updatedAt;

  List<LeaveTrailEntry> trail;

  LeaveModel({
    this.leaveId,
    required this.empId,
    this.tenantId,
    this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.numberOfDays,
    this.isHalfDay = false,
    this.halfDayPeriod,
    this.reason,
    required this.finalStatus,
    this.currentApprovalLevel,
    this.currentApproverEmployeeId,
    this.currentApproverName,
    this.createdAt,
    this.updatedAt,
    this.trail = const [],
  });

  // ─────────────────────────────────────
  // Computed
  // ─────────────────────────────────────

  double get effectiveDays {
    if (isHalfDay) return 0.5;

    if (numberOfDays > 0) {
      return numberOfDays.toDouble();
    }

    final diff = toDate.difference(fromDate).inDays + 1;

    return diff > 0 ? diff.toDouble() : 1;
  }

  bool get isPending => finalStatus == 'Pending';

  bool get isApproved => finalStatus == 'Approved';

  bool get isRejected => finalStatus == 'Rejected';

  // ─────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────

  static int _parseIntRequired(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;

    return int.tryParse(value.toString());
  }

  static DateTime _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return DateTime.now();
    }

    // Legacy format dd.MM.yyyy
    if (value.contains('.')) {
      final parts = value.split('.');

      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }

    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }

  // ─────────────────────────────────────
  // Main Generic Parser
  // ─────────────────────────────────────

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      leaveId: _parseInt(json['leave_id']),

      empId: _parseIntRequired(json['emp_id']),

      tenantId: json['tenant_id']?.toString(),

      employeeName: json['employee_name']?.toString(),

      leaveType: json['leave_type']?.toString() ?? '',

      fromDate: _parseDate(json['leave_start_date']?.toString()),

      toDate: _parseDate(json['leave_end_date']?.toString()),

      numberOfDays: _parseIntRequired(json['number_of_days']),

      isHalfDay: json['is_half_day'] == 1 || json['is_half_day'] == true,

      halfDayPeriod: json['half_day_period']?.toString(),

      reason: json['reason']?.toString(),

      finalStatus: json['final_status']?.toString() ?? 'Pending',

      currentApprovalLevel: _parseInt(json['current_approval_level']),

      currentApproverEmployeeId: _parseInt(
        json['current_approver_employee_id'],
      ),

      currentApproverName: json['current_approver_name']?.toString(),

      createdAt: json['created_at']?.toString(),

      updatedAt: json['updated_at']?.toString(),
    );
  }

  // ─────────────────────────────────────
  // Compatibility Parsers
  // ─────────────────────────────────────

  factory LeaveModel.fromPendingJson(Map<String, dynamic> json) {
    return LeaveModel.fromJson(json);
  }

  factory LeaveModel.fromHistoryJson(Map<String, dynamic> json) {
    return LeaveModel.fromJson(json);
  }

  factory LeaveModel.fromMyLeavesJson(Map<String, dynamic> json) {
    return LeaveModel.fromJson(json);
  }

  factory LeaveModel.fromApproverInboxJson(Map<String, dynamic> json) {
    return LeaveModel.fromJson(json);
  }
}

// ─────────────────────────────────────────
// Leave Trail Entry
// ─────────────────────────────────────────

class LeaveTrailEntry {
  final int? trailId;

  final int approvalLevel;

  final int approverEmployeeId;

  final String approverName;

  final String action;

  final String? comments;

  final String? actionAt;

  const LeaveTrailEntry({
    this.trailId,
    required this.approvalLevel,
    required this.approverEmployeeId,
    required this.approverName,
    required this.action,
    this.comments,
    this.actionAt,
  });

  factory LeaveTrailEntry.fromJson(Map<String, dynamic> json) {
    return LeaveTrailEntry(
      trailId: json['trail_id'] is num
          ? (json['trail_id'] as num).toInt()
          : null,

      approvalLevel: json['approval_level'] is num
          ? (json['approval_level'] as num).toInt()
          : 0,

      approverEmployeeId: json['approver_employee_id'] is num
          ? (json['approver_employee_id'] as num).toInt()
          : 0,

      approverName: json['approver_name']?.toString() ?? 'Unknown',

      action: json['action']?.toString() ?? '',

      comments: json['comments']?.toString(),

      actionAt: json['action_at']?.toString(),
    );
  }
}
