import 'dart:convert';
import '../providers/api_client.dart';
import '../models/dept_role_desg_models.dart';

Map<String, dynamic> _parseOrThrow(String responseBody) {
  final Map<String, dynamic> json = jsonDecode(responseBody);
  if (json['success'] != true) {
    throw Exception(json['message'] ?? 'Something went wrong.');
  }
  return json;
}

class DepartmentService {
  Future<List<DepartmentModel>> fetchAll() async {
    final res = await ApiClient.get('/departments');
    final json = _parseOrThrow(res.body);
    return (json['data'] as List<dynamic>)
        .map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DepartmentModel> create({
    required String departmentName,
    String status = 'Active',
  }) async {
    final res = await ApiClient.post('/departments', {
      'department_name': departmentName.trim(),
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return DepartmentModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<DepartmentModel> update({
    required int id,
    required String departmentName,
    required String status,
  }) async {
    final res = await ApiClient.put('/departments/$id', {
      'department_name': departmentName.trim(),
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return DepartmentModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await ApiClient.delete('/departments/$id');
    _parseOrThrow(res.body);
  }
}

class DesignationService {
  Future<List<DesignationModel>> fetchAll() async {
    final res = await ApiClient.get('/designations');
    final json = _parseOrThrow(res.body);
    return (json['data'] as List<dynamic>)
        .map((e) => DesignationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DesignationModel> create({
    required String designationName,
    required int departmentId,
    String status = 'Active',
  }) async {
    final res = await ApiClient.post('/designations', {
      'designation_name': designationName.trim(),
      'department_id': departmentId,
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return DesignationModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<DesignationModel> update({
    required int id,
    required String designationName,
    required int departmentId,
    required String status,
  }) async {
    final res = await ApiClient.put('/designations/$id', {
      'designation_name': designationName.trim(),
      'department_id': departmentId,
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return DesignationModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await ApiClient.delete('/designations/$id');
    _parseOrThrow(res.body);
  }
}

class RoleService {
  Future<List<RoleModel>> fetchAll() async {
    final res = await ApiClient.get('/roles');
    final json = _parseOrThrow(res.body);
    return (json['data'] as List<dynamic>)
        .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoleModel> create({
    required String roleName,
    String status = 'Active',
  }) async {
    final res = await ApiClient.post('/roles', {
      'role_name': roleName.trim(),
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return RoleModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<RoleModel> update({
    required int id,
    required String roleName,
    required String status,
  }) async {
    final res = await ApiClient.put('/roles/$id', {
      'role_name': roleName.trim(),
      'status': status,
    });
    final json = _parseOrThrow(res.body);
    return RoleModel.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await ApiClient.delete('/roles/$id');
    _parseOrThrow(res.body);
  }
}
