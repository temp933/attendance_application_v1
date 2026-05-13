import 'dart:convert';
import '../models/departmentmodel.dart';
import '../providers/api_client.dart';

class DepartmentService {
  final String tenantId;
  DepartmentService({required this.tenantId});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-tenant-id': tenantId,
  };

  Future<List<DepartmentModel>> fetchDepartments() async {
    print('DEBUG tenantId: "$tenantId"'); // ← add this
    final res = await ApiClient.get('/departments', headers: _headers);
    if (res.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(res.body);
      if (body['success'] == true && body['data'] != null) {
        return (body['data'] as List)
            .map((e) => DepartmentModel.fromJson(e))
            .toList();
      }
      return [];
    }
    throw Exception("Failed to load departments: ${res.statusCode}");
  }

  Future<void> addDepartment(String name) async {
    final res = await ApiClient.post('/departments', {
      "department_name": name,
    }, headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception("Failed to add department: ${res.body}");
    }
  }

  Future<void> updateDepartmentStatus(int deptId, String status) async {
    final res = await ApiClient.put('/departments/$deptId/status', {
      "status": status,
    }, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception("Failed to update status: ${res.body}");
    }
  }

  Future<void> deleteDepartment(int deptId) async {
    final res = await ApiClient.delete(
      '/departments/$deptId',
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception("Failed to delete department: ${res.body}");
    }
  }

  Future<void> transferEmployee({
    required int empId,
    required int toDept,
    required String reason,
  }) async {
    final res = await ApiClient.put('/departments/$toDept/transfer-employee', {
      "emp_id": empId,
      "reason": reason,
    }, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception("Transfer failed: ${res.body}");
    }
  }

  Future<List<Map<String, dynamic>>> fetchDeptEmployees(int deptId) async {
    final res = await ApiClient.get(
      '/departments/$deptId/employees',
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception("Failed to load employees: ${res.body}");
  }

  // Fetch roles for a specific department (not all roles globally)
  Future<List<Map<String, dynamic>>> fetchDeptRoles(int deptId) async {
    final res = await ApiClient.get(
      '/departments/$deptId/roles',
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true)
        return List<Map<String, dynamic>>.from(body['data']);
      return [];
    }
    throw Exception("Failed to load roles");
  }

  // Add role under a specific department (not hardcoded 0)
  Future<void> addRole(int deptId, String roleName) async {
    final res = await ApiClient.post('/departments/$deptId/roles', {
      "role_name": roleName,
    }, headers: _headers);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? "Failed to add role");
    }
  }

  // Toggle role status
  Future<void> updateRoleStatus(int deptId, int roleId, String status) async {
    final res = await ApiClient.put(
      '/departments/$deptId/roles/$roleId/status',
      {"status": status},
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception("Failed to update role status");
  }

  // Delete role
  Future<void> deleteRole(int deptId, int roleId) async {
    final res = await ApiClient.delete(
      '/departments/$deptId/roles/$roleId',
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? "Failed to delete role");
    }
  }

  // Edit department name
Future<void> updateDepartmentName(int deptId, String name) async {
  final res = await ApiClient.put('/departments/$deptId', {
    "department_name": name,
  }, headers: _headers);
  if (res.statusCode != 200) throw Exception("Failed to update department");
}

// Edit role name
Future<void> updateRoleName(int deptId, int roleId, String name) async {
  final res = await ApiClient.put('/departments/$deptId/roles/$roleId', {
    "role_name": name,
  }, headers: _headers);
  if (res.statusCode != 200) throw Exception("Failed to update role");
}
}
