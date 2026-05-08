import 'employee_model.dart';

class DepartmentModel {
  final String id;
  String name;
  String code;
  String head;
  bool isActive;
  List<EmployeeModel> employees; // This was missing

  DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    required this.head,
    this.isActive = true,
    List<EmployeeModel>? employees,
  }) : employees = employees ?? [];
}
