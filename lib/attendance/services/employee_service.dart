import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee.dart';
import 'package:flutter/material.dart';
import '../models/employee_work_status.dart';
import '../providers/api_config.dart';
import '../providers/api_client.dart';

const String baseUrl = ApiConfig.baseUrl;

class EmployeeService {
  // ================= LOGIN =================
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String deviceId = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'device_id': deviceId,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 403) {
      throw Exception('Already logged in on another device. Logout first.');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? error['error'] ?? 'Login failed');
    }
  }

  // ================= GET EMPLOYEE BY ID =================
  static Future<Employee> fetchEmployee(int empId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/employees/$empId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      return Employee.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch employee');
    }
  }

  // ================= DASHBOARD DATA =================
  static Future<Map<String, dynamic>> fetchDashboardData() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: ApiConfig.headers, // ← ADDED
    );
    // debugPrint('🌐 Fetching dashboard data...');
    // debugPrint('   URL    : ${ApiConfig.baseUrl}/your-endpoint');
    // debugPrint('   token  : ${ApiConfig.headers['Authorization']}');
    // debugPrint('   tenant : ${ApiConfig.headers['x-tenant-id']}');
    // debugPrint('   empId  : ${ApiConfig.headers['x-employee-id']}');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch dashboard data');
    }
  }

  // ================= GET ALL PENDING REQUESTS =================
  // In employee_service.dart
  static Future<List<Employee>> fetchPendingRequests() async {
    // Only fetch PENDING and REJECTED — never APPROVED (those are in master)
    final res = await ApiClient.get('/pending-request?status=PENDING');
    // Also fetch REJECTED separately and merge
    final res2 = await ApiClient.get('/pending-request?status=REJECTED');

    final List pending = jsonDecode(res.body)['data'] ?? [];
    final List rejected = jsonDecode(res2.body)['data'] ?? [];

    return [...pending, ...rejected].map((e) => Employee.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchTlDashboardData(
    String loginId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/tl/$loginId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch TL dashboard data');
    }
  }

  // ================= LEAVE STATUS SUMMARY =================
  static Future<List<LeaveData>> fetchLeaveStatusSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave-status-summary'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) {
        Color color;
        switch (e['status']) {
          case 'Approved':
            color = Colors.green;
            break;
          case 'Pending':
            color = Colors.orange;
            break;
          case 'Rejected':
            color = Colors.red;
            break;
          case 'Not_Recommended_By_TL':
            color = const Color.fromARGB(167, 228, 10, 10);
            break;
          default:
            color = Colors.grey;
        }
        return LeaveData(e['status'], e['count'], color);
      }).toList();
    } else {
      throw Exception('Failed to fetch leave status summary');
    }
  }

  // ================= LEAVE TYPE SUMMARY =================
  static List<LeaveData> getLeaveChartData(Map<String, dynamic> json) {
    return [
      LeaveData('Sick', json['sick'] ?? 0, Colors.red),
      LeaveData('Casual', json['casual'] ?? 0, Colors.blue),
      LeaveData('Paid', json['paid'] ?? 0, Colors.green),
      LeaveData('Unpaid', json['unpaid'] ?? 0, Colors.orange),
    ];
  }

  // ================= GET ALL REQUESTS =================
  static Future<List<Employee>> fetchAllRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/requests'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body)['data'];
      return list.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch requests');
    }
  }

  // ================= GET ALL EMPLOYEES =================
  static Future<List<Employee>> fetchAllEmployees() async {
    final response = await http.get(
      Uri.parse('$baseUrl/employees'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body)['data'];
      return list.map((e) => Employee.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch employees');
    }
  }

  // ================= EMPLOYEES WITH WORK =================
  static Future<List<EmployeeWorkStatus>> fetchEmployeesWithWork() async {
    final response = await http.get(
      Uri.parse('$baseUrl/employees-with-work'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => EmployeeWorkStatus.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load employees with work");
    }
  }

  // ================= GET EMPLOYEE WORK HOURS =================
  static Future<Map<String, String>> fetchEmployeeWorkHours(int empId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/employee-work-hours/$empId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        "today": data["today"]?.toString() ?? "0h 0m",
        "week": data["week"]?.toString() ?? "0h 0m",
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to fetch work hours');
    }
  }

  // ================= ASSIGN LOCATION =================
  static Future<void> assignLocation({
    required int empId,
    required int locationId,
    required String aboutWork,
    required String startDate,
    required String endDate,
    required String doneBy,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assign-location'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        "emp_id": empId,
        "location_id": locationId,
        "about_work": aboutWork,
        "start_date": startDate,
        "end_date": endDate,
        "done_by": doneBy,
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to assign location');
    }
  }

  // ================= GET DEPARTMENTS =================
  static Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/departments'),
      headers: ApiConfig.headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final raw = data['data'];
      if (raw is! List) return [];
      return (raw as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['id'] ??= m['department_id'];
        m['name'] ??= m['department_name'];
        return m;
      }).toList();
    } else {
      throw Exception("Failed to load departments");
    }
  }

  // ================= GET ROLES =================
  // Fetch designations — optionally filtered by department
  static Future<List<Map<String, dynamic>>> fetchDesignations({
    int? deptId,
  }) async {
    try {
      final url = deptId != null
          ? '$baseUrl/designations?department_id=$deptId'
          : '$baseUrl/designations';
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'];
        if (raw is! List) return [];
        // Normalise: add 'id' key so FormDropdownMap works (backend returns designation_id)
        return (raw as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['id'] ??= m['designation_id'];
          m['name'] ??= m['designation_name'];
          return m;
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // Fetch all roles (flat list — no dept filter needed)
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/roles'),
        headers: ApiConfig.headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['data'];
        if (raw is! List) return [];
        // Normalise: backend returns role_id / role_name
        return (raw as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['id'] ??= m['role_id'];
          m['name'] ??= m['role_name'];
          return m;
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ================= EDUCATION =================
  static Future<List<Education>> fetchEducation(int empId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/employees/$empId/education'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body)['data'];
      return list.map((e) => Education.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch education records');
  }

  static Future<void> addEducation(int empId, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/employees/$empId/education'),
      headers: ApiConfig.headers,
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return addPendingEducation(requestId, data);
    }
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to add education');
    }
  }

  static Future<void> updateEducation(
    int eduId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/education/$eduId'),
      headers: ApiConfig.headers,
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return updatePendingEducation(eduId, data);
    }
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update education');
    }
  }

  static Future<void> deleteEducation(int eduId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/education/$eduId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 403 && body['pending'] == true) {
      final requestId = body['request_id'];
      if (requestId == null) throw Exception('Pending request ID missing');
      return deletePendingEducation(eduId);
    }
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to delete education');
    }
  }

  // ================= PENDING EDUCATION =================
  static Future<List<Education>> fetchPendingEducation(int requestId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/requests/$requestId/education'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body)['data'];
      return list.map((e) => Education.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch pending education');
  }

  static Future<void> addPendingEducation(
    int requestId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/requests/$requestId/education"),
      headers: ApiConfig.headers, // ← FIXED (was hardcoded)
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to add pending education");
    }
  }

  static Future<void> updatePendingEducation(
    int eduReqId,
    Map<String, dynamic> data,
  ) async {
    final res = await http.put(
      Uri.parse("$baseUrl/requests/education/$eduReqId"),
      headers: ApiConfig.headers, // ← FIXED (was hardcoded)
      body: jsonEncode(data),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to update pending education");
    }
  }

  static Future<void> deletePendingEducation(int eduReqId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/requests/education/$eduReqId"),
      headers: ApiConfig.headers, // ← FIXED (was hardcoded)
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? "Failed to delete pending education");
    }
  }

  // ================= PENDING REQUEST ID =================
  static Future<int?> getPendingRequestId(int empId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/employees/$empId/pending-request"),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['pending'] == true) return body['request_id'];
    }
    return null;
  }

  // ================= LEAVE HISTORY =================
  static Future<List<Map<String, dynamic>>> fetchLeaveHistory(int empId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave-history?emp_id=$empId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch leave history');
      }
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to fetch leave history');
    }
  }

  // ================= PENDING TL LEAVES =================
  static Future<List<Map<String, dynamic>>> fetchPendingTLLeaves() async {
    final response = await http.get(
      Uri.parse('$baseUrl/leaves/pending-tl'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data']);
      } else {
        throw Exception(body['message'] ?? 'Failed to fetch pending TL leaves');
      }
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to fetch pending TL leaves');
    }
  }

  // ================= HR ACTION =================
  static Future<void> hrAction(
    int leaveId,
    String status,
    int loginId, {
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leave/$leaveId/hr-action'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'status': status,
        'login_id': loginId,
        'rejection_reason': rejectionReason,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to update leave status');
    }
  }

  // ================= TL ACTION =================
  static Future<void> tlAction(
    int leaveId,
    String action,
    int loginId, {
    String? rejectionReason,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/leave/$leaveId/tl-action'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        'action': action,
        'login_id': loginId,
        'rejection_reason': rejectionReason,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Failed to perform TL action');
    }
  }

  // ================= ON SITE TODAY =================
  static Future<int> fetchOnSiteToday() async {
    final response = await http.get(
      Uri.parse("$baseUrl/on-site-today"),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['onSiteToday'] ?? 0;
    } else {
      throw Exception("Failed to load on-site data");
    }
  }

  // ================= TODAY ATTENDANCE SUMMARY =================
  static Future<Map<String, dynamic>> fetchTodayAttendanceSummary(
    int empId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/today-summary/$empId'),
      headers: ApiConfig.headers, // ← ADDED
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data;
      throw Exception(data['message'] ?? 'Failed to fetch attendance summary');
    }
    throw Exception('Failed to fetch attendance summary');
  }
}

class LeaveData {
  final String status;
  final int count;
  final Color color;
  const LeaveData(this.status, this.count, this.color);
}
