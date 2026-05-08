import 'dart:convert';
import '../models/employee_location_model.dart';
import '../providers/api_client.dart';

class EmployeeLocationService {
  Future<EmployeeLocationAssignment?> fetchEmployeeLocation(int empId) async {
    final response = await ApiClient.get('/employee-location/$empId');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["assigned"] == false) {
        return null;
      }
      return EmployeeLocationAssignment.fromJson(data);
    } else {
      throw Exception("Failed to fetch employee location");
    }
  }
}
