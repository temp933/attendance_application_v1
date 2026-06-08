int parseInt(dynamic v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

double parseDouble(dynamic v) => v == null
    ? 0.0
    : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

String parseString(dynamic v) => v?.toString() ?? '';

// ─────────────────────────────────────────────────────────────────────────────
// Department
// ─────────────────────────────────────────────────────────────────────────────

class DepartmentModel {
  final int id;
  final String name;
  final String status;

  const DepartmentModel({
    required this.id,
    required this.name,
    required this.status,
  });
  @override
  bool operator ==(Object other) => other is DepartmentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory DepartmentModel.fromJson(Map<String, dynamic> j) => DepartmentModel(
    id: parseInt(j['department_id'] ?? j['id']),
    name: parseString(j['department_name'] ?? j['name']),
    status: parseString(j['status'] ?? 'Active'),
  );
}

const DepartmentModel kAllDepartments = DepartmentModel(
  id: -1,
  name: 'All Departments',
  status: 'Active',
);

// ─────────────────────────────────────────────────────────────────────────────
// Matrix (monthly grid)
// ─────────────────────────────────────────────────────────────────────────────

class MatrixDate {
  final String date;
  final int day;
  final bool isHoliday;
  final bool isWeekend;
  final String? holidayName;

  const MatrixDate({
    required this.date,
    required this.day,
    required this.isHoliday,
    required this.isWeekend,
    this.holidayName,
  });

  factory MatrixDate.fromJson(Map<String, dynamic> j) => MatrixDate(
    date: parseString(j['date']),
    day: parseInt(j['day']),
    isHoliday: j['is_holiday'] == true,
    isWeekend: j['is_weekend'] == true,
    holidayName: j['holiday_name']?.toString(),
  );

  String get dayLabel => const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][day];
  int get dayOfMonth => int.parse(date.split('-')[2]);
}

class MatrixEmp {
  final int empId;
  final String name;
  final String department;
  final List<String> days;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int compOffDays;
  final int totalWorkingDays;
  final double percentage;
  // ── new summary fields ──────────────────────────────────────────────────
  final int compOffEarned;
  final int compOffUsed;
  final int compOffExpired;
  final int leaveApproved;
  final int leaveRejected;

  const MatrixEmp({
    required this.empId,
    required this.name,
    required this.department,
    required this.days,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.compOffDays,
    required this.totalWorkingDays,
    required this.percentage,
    required this.compOffEarned,
    required this.compOffUsed,
    required this.compOffExpired,
    required this.leaveApproved,
    required this.leaveRejected,
  });

  factory MatrixEmp.fromJson(Map<String, dynamic> j) => MatrixEmp(
    empId: parseInt(j['emp_id']),
    name: parseString(j['name']),
    department: parseString(j['department']),
    days: List<String>.from(j['days'] ?? []),
    presentDays: parseInt(j['present_days']),
    absentDays: parseInt(j['absent_days']),
    leaveDays: parseInt(j['leave_days']),
    compOffDays: parseInt(j['comp_off_days']),
    totalWorkingDays: parseInt(j['total_working_days']),
    percentage: parseDouble(j['percentage']),
    compOffEarned: parseInt(j['comp_off_earned']),
    compOffUsed: parseInt(j['comp_off_used']),
    compOffExpired: parseInt(j['comp_off_expired']),
    leaveApproved: parseInt(j['leave_approved']),
    leaveRejected: parseInt(j['leave_rejected']),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily
// ─────────────────────────────────────────────────────────────────────────────

class EmpDaily {
  final int empId;
  final String name;
  final String department;
  final String? checkIn;
  final String? checkOut;
  final int workedMinutes;
  final String status;
  final bool isLate;
  final int lateMinutes;
  final bool compOffEarned;
  final String? holidayName;
  final int totalCompOffEarned;
  final int totalCompOffUsed;
  final int totalCompOffExpired;
  final int totalLeaveApproved;
  final int totalLeaveRejected;
  final List<SiteSession> siteSessions; // ← moved up, before constructor

  const EmpDaily({
    required this.empId,
    required this.name,
    required this.department,
    this.checkIn,
    this.checkOut,
    required this.workedMinutes,
    required this.status,
    required this.isLate,
    required this.lateMinutes,
    required this.compOffEarned,
    this.holidayName,
    required this.totalCompOffEarned,
    required this.totalCompOffUsed,
    required this.totalCompOffExpired,
    required this.totalLeaveApproved,
    required this.totalLeaveRejected,
    this.siteSessions = const [], // ← default empty, const-safe
  });

  factory EmpDaily.fromJson(Map<String, dynamic> j) => EmpDaily(
    empId: parseInt(j['emp_id']),
    name: parseString(j['name']),
    department: parseString(j['department']),
    checkIn: j['check_in']?.toString(),
    checkOut: j['check_out']?.toString(),
    workedMinutes: j['worked_seconds'] != null
        ? (parseInt(j['worked_seconds']) ~/ 60)
        : parseInt(j['worked_minutes']),
    status: parseString(j['status']).isEmpty
        ? 'Absent'
        : parseString(j['status']),
    isLate: j['is_late'] == true,
    lateMinutes: parseInt(j['late_minutes']),
    compOffEarned: j['comp_off_earned'] == true,
    holidayName: j['holiday_name']?.toString(),
    totalCompOffEarned: parseInt(j['total_comp_off_earned']),
    totalCompOffUsed: parseInt(j['total_comp_off_used']),
    totalCompOffExpired: parseInt(j['total_comp_off_expired']),
    totalLeaveApproved: parseInt(j['total_leave_approved']),
    totalLeaveRejected: parseInt(j['total_leave_rejected']),
    siteSessions: (j['sessions'] as List? ?? [])
        .map((s) => SiteSession.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

 String get workedFormatted {
    if (workedMinutes <= 0) return '-';
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get lateFormatted {
    if (lateMinutes <= 0) return '-';
    final h = lateMinutes ~/ 60;
    final m = lateMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Status constants
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceStatus {
  static const present = 'P';
  static const absent = 'A';
  static const leave = 'L';
  static const holiday = 'H';
  static const weekend = 'W';
  static const compOff = 'C';
}

class SiteSession {
  final String? siteName;
  final String? checkIn;
  final String? checkOut;
  final String? totalWorkTime;
  final String status; // 'active' | 'completed'
  final int totalPauseSecs;

  SiteSession({
    this.siteName,
    this.checkIn,
    this.checkOut,
    this.totalWorkTime,
    this.status = 'completed',
    this.totalPauseSecs = 0,
  });

  factory SiteSession.fromJson(Map<String, dynamic> j) => SiteSession(
    siteName: j['site_name'],
    checkIn: j['checkin_time'],
    checkOut: j['checkout_time'],
    totalWorkTime: j['total_work_time'],
    status: j['status'] ?? 'completed',
    totalPauseSecs: int.tryParse(j['total_pause_secs']?.toString() ?? '0') ?? 0,
  );
}
