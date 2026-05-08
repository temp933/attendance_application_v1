// -------------------- Attendance Report --------------------
class AttendanceReport {
  final String employeeId;
  final String employeeName;
  final String department;
  final DateTime date;
  final String checkIn;
  final String checkOut;
  final String status; // Present / Absent / Late

  AttendanceReport({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
  });
}

// -------------------- Task / Work Allotment Report --------------------
class TaskReport {
  final String employeeName;
  final String department;
  final String taskName;
  final DateTime assignedDate;
  final DateTime? completedDate;
  final String status; // Pending / Completed / In Progress

  TaskReport({
    required this.employeeName,
    required this.department,
    required this.taskName,
    required this.assignedDate,
    this.completedDate,
    required this.status,
  });
}

// -------------------- Leave / Approval Report --------------------
class LeaveReport {
  final String employeeName;
  final String department;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final String approvalStatus; // Pending / Approved / Rejected
  final String reason;

  LeaveReport({
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.approvalStatus,
    required this.reason,
  });
}

// -------------------- Holiday Report --------------------
class HolidayReport {
  final String holidayName;
  final DateTime date;
  final String? department; // null = common holiday

  HolidayReport({
    required this.holidayName,
    required this.date,
    this.department,
  });
}

// -------------------- Employee Master Report --------------------
class EmployeeReport {
  final String employeeId;
  final String employeeName;
  final String department;
  final String role;
  final String email;
  final String phone;
  final DateTime dateOfJoining;
  final String status; // Active / Inactive

  EmployeeReport({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.role,
    required this.email,
    required this.phone,
    required this.dateOfJoining,
    required this.status,
  });
}

// -------------------- Department Master Report --------------------
class DepartmentReport {
  final String departmentId;
  final String departmentName;
  final String managerName;
  final int totalEmployees;

  DepartmentReport({
    required this.departmentId,
    required this.departmentName,
    required this.managerName,
    required this.totalEmployees,
  });
}
