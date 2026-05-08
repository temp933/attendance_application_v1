// class EmployeeLocationAssignment {
//   final bool assigned;
//   final String work;
//   final String status;
//   final DateTime startDate;
//   final DateTime endDate;

//   EmployeeLocationAssignment({
//     required this.assigned,
//     required this.work,
//     required this.status,
//     required this.startDate,
//     required this.endDate,
//   });

//   factory EmployeeLocationAssignment.fromJson(Map<String, dynamic> json) {
//     return EmployeeLocationAssignment(
//       assigned: json['assigned'],
//       work: json['work'],
//       status: json['status'],
//       startDate: DateTime.parse(json['startDate']),
//       endDate: DateTime.parse(json['endDate']),
//     );
//   }
// }

class EmployeeLocationAssignment {
  final bool assigned;
  final String work;
  final String locationName;
  final String status;
  final DateTime startDate;
  final DateTime endDate;

  EmployeeLocationAssignment({
    required this.assigned,
    required this.work,
    required this.locationName,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  factory EmployeeLocationAssignment.fromJson(Map<String, dynamic> json) {
    return EmployeeLocationAssignment(
      assigned: json['assigned'],
      work: json['work'],
      locationName: json['locationName'] ?? 'Not Assigned',
      status: json['status'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now(),
    );
  }
}
