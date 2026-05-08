class DepartmentModel {
  final int id;
  final String name;
  final String status; // optional, default to Active if not provided

  DepartmentModel({
    required this.id,
    required this.name,
    this.status = "Active",
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'], // matches your API
      name: json['name'], // matches your API
      status: json['status'] ?? "Active", // default if not in API
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'status': status};
  }
}
