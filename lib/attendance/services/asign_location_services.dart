import 'dart:convert';
import '../models/asign_location.dart';
import '../providers/api_client.dart';

class AssignLocationService {
  // ── ASSIGN LOCATION ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> assignLocation({
    required List<int> empIds,
    required int locationId,
    required String aboutWork,
    required String startDate,
    required String endDate,
    String assignBy = "Admin",
  }) async {
    try {
      final response = await ApiClient.post('/assign-location-and-get-list', {
        "emp_ids": empIds,
        "location_id": locationId,
        "about_work": aboutWork,
        "start_date": startDate,
        "end_date": endDate,
        "assign_by": assignBy,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          "Assign failed (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── WORKING + FUTURE EMPLOYEES ─────────────────────────────────────────────
  static Future<List<AssignLocationModel>> getCurrentWorkingEmployees() async {
    try {
      final response = await ApiClient.get('/working-today-and-future');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        return data
            .map((e) => AssignLocationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          "Failed to load employees (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── ALL EMPLOYEES ──────────────────────────────────────────────────────────
  static Future<List<AssignLocationModel>> getAllEmployees() async {
    return getCurrentWorkingEmployees();
  }

  // ── SINGLE EMPLOYEE ASSIGNMENTS ────────────────────────────────────────────
  static Future<List<AssignLocationModel>> getEmployeeAssignments(
    int empId,
  ) async {
    try {
      final response = await ApiClient.get('/employee-assignments/$empId');

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        return data
            .map((e) => AssignLocationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
          "Failed to load assignments (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }

  // ── UPDATE WORK STATUS ─────────────────────────────────────────────────────
  static Future<void> updateWorkStatus({
    required int empId,
    required String status,
    required String updatedBy,
    String? reason,
    String? endDate,
  }) async {
    try {
      final body = <String, dynamic>{
        "empId": empId,
        "status": status,
        "updatedBy": updatedBy,
        "reason": ?reason,
        "endDate": ?endDate,
      };

      final response = await ApiClient.post('/update-work-status', body);

      if (response.statusCode != 200) {
        throw Exception(
          "Update failed (${response.statusCode}): ${response.body}",
        );
      }
    } on Exception {
      rethrow;
    }
  }
}
