import 'dart:convert';
import '../models/departmentmodel.dart';
import '../providers/api_client.dart';

class DepartmentService {
  /// GET ALL DEPARTMENTS
  Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await ApiClient.get('/departments');

    if (res.statusCode == 200) {
      final Map<String, dynamic> json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        final List data = json['data'];
        return data.map((e) => DepartmentModel.fromJson(e)).toList();
      } else {
        return [];
      }
    } else {
      throw Exception("Failed to load departments");
    }
  }

  /// ADD DEPARTMENT
  Future<void> addDepartment(String name) async {
    final res = await ApiClient.post('/departments', {"department_name": name});
    if (res.statusCode != 200) {
      throw Exception("Failed to add department: ${res.body}");
    }
  }

  /// UPDATE STATUS
  Future<void> updateDepartmentStatus(int deptId, String status) async {
    final res = await ApiClient.put('/departments/$deptId/status', {
      "status": status,
    });
    if (res.statusCode != 200) {
      throw Exception("Failed to update department status: ${res.body}");
    }
  }

  /// TRANSFER EMPLOYEE
  Future<void> transferEmployee({
    required int empId,
    required int toDept,
    required String reason,
  }) async {
    final res = await ApiClient.put('/departments/$toDept/transfer-employee', {
      "emp_id": empId,
      "reason": reason,
    });
    if (res.statusCode != 200) {
      throw Exception("Employee transfer failed: ${res.body}");
    }
  }

  /// GET EMPLOYEES BY DEPARTMENT
  Future<List<Map<String, dynamic>>> fetchDeptEmployees(int deptId) async {
    final res = await ApiClient.get('/departments/$deptId/employees');

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to load employees: ${res.body}");
    }
  }
}
