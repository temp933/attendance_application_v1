// class Employee {
//   final int empId;

//   final String? firstName;
//   final String? midName;
//   final String? lastName;
//   final String? email;
//   final String? phone;
//   final String? dob;
//   final String? gender;

//   final int? departmentId;
//   final String? departmentName;

//   final int? roleId;
//   final String? roleName;

//   final String? dateOfJoining;
//   final String? employmentType;
//   final String? reportingManager;

//   final String? address;
//   final String? city;
//   final String? state;
//   final String? country;
//   final String? pincode;

//   final String? emergencyContactName;
//   final String? emergencyContactNumber;

//   final String? adminApprove;

//   final DateTime? dateOfRelieving;
//   final String? workType;
//   final String? communicationAddress;
//   final String? aadharNumber;
//   final String? panNumber;
//   final String? passportNumber;
//   final String? status;

//   final int? requestId;

//   final String? fatherName;
//   final String? emergencyContact;
//   final String? pfNumber;
//   final String? esicNumber;
//   final int? yearsExperience;
//   final List<Education>? educationList;

//   Employee({
//     required this.empId,
//     this.firstName,
//     this.midName,
//     this.lastName,
//     this.email,
//     this.phone,
//     this.dob,
//     this.gender,
//     this.departmentId,
//     this.departmentName,
//     this.roleId,
//     this.roleName,
//     this.dateOfJoining,
//     this.employmentType,
//     this.reportingManager,
//     this.address,
//     this.city,
//     this.state,
//     this.country,
//     this.pincode,
//     this.emergencyContactName,
//     this.emergencyContactNumber,
//     this.adminApprove,
//     this.dateOfRelieving,
//     this.workType,
//     this.communicationAddress,
//     this.aadharNumber,
//     this.panNumber,
//     this.passportNumber,
//     this.status,
//     this.requestId,
//     this.fatherName,
//     this.emergencyContact,
//     this.pfNumber,
//     this.esicNumber,
//     this.yearsExperience,
//     this.educationList,
//   });

//   factory Employee.fromJson(Map<String, dynamic> json) {
//     String? val(String key) => json[key]?.toString();

//     List<Education>? eduList;
//     if (json['education'] != null && json['education'] is List) {
//       eduList = (json['education'] as List)
//           .map((e) => Education.fromJson(e))
//           .toList();
//     }

//     return Employee(
//       empId: json['emp_id'] ?? 0,
//       firstName: val('first_name'),
//       midName: val('mid_name'),
//       lastName: val('last_name'),
//       email: val('email_id') ?? val('email'),
//       phone: val('phone_number') ?? val('phone'),
//       dob: val('date_of_birth') ?? val('dob'),
//       gender: val('gender'),
//       departmentId: json['department_id'] == null
//           ? null
//           : int.tryParse(json['department_id'].toString()),
//       departmentName: json['department_name'],
//       roleId: json['role_id'] == null
//           ? null
//           : int.tryParse(json['role_id'].toString()),
//       roleName: json['role_name'],
//       dateOfJoining: val('date_of_joining'),
//       employmentType: val('employment_type'),
//       reportingManager: val('reporting_manager'),
//       address: val('permanent_address') ?? val('address'),
//       communicationAddress: val('communication_address'),
//       city: val('city'),
//       state: val('state'),
//       country: val('country'),
//       pincode: val('pincode'),
//       emergencyContactName: val('emergency_contact_name'),
//       emergencyContactNumber: val('emergency_contact_number'),
//       adminApprove: json['admin_approve'],
//       dateOfRelieving: json['date_of_relieving'] == null
//           ? null
//           : DateTime.tryParse(json['date_of_relieving'].toString()),
//       workType: val('work_type'),
//       aadharNumber: val('aadhar_number'),
//       panNumber: val('pan_number'),
//       passportNumber: val('passport_number'),
//       status: val('status'),
//       requestId: json['request_id'] == null
//           ? null
//           : int.tryParse(json['request_id'].toString()),
//       fatherName: val('father_name'),
//       emergencyContact: val('emergency_contact'),
//       pfNumber: val('pf_number'),
//       esicNumber: val('esic_number'),
//       yearsExperience: json['years_experience'] == null
//           ? null
//           : int.tryParse(json['years_experience'].toString()),
//       educationList: eduList,
//     );
//   }
// }

// class Education {
//   final int? eduId;
//   final int empId;
//   final String? educationLevel;
//   final String? stream;
//   final String? score;
//   final String? yearOfPassout;
//   final String? university;
//   final String? collegeName;

//   Education({
//     this.eduId,
//     required this.empId,
//     this.educationLevel,
//     this.stream,
//     this.score,
//     this.yearOfPassout,
//     this.university,
//     this.collegeName,
//   });

//   factory Education.fromJson(Map<String, dynamic> json) {
//     String? val(String key) => json[key]?.toString();

//     return Education(
//       eduId: json['edu_id'] == null
//           ? null
//           : int.tryParse(json['edu_id'].toString()),
//       empId: json['emp_id'] == null
//           ? 0
//           : int.parse(json['emp_id'].toString()), // ✅ ADD THIS
//       educationLevel: val('education_level'),
//       stream: val('stream'),
//       score: val('score'),
//       yearOfPassout: val('year_of_passout'),
//       university: val('university'),
//       collegeName: val('college_name'),
//     );
//   }

//   Map<String, dynamic> toJson() => {
//     'emp_id': empId,
//     'education_level': educationLevel,
//     'stream': stream,
//     'score': score,
//     'year_of_passout': yearOfPassout,
//     'university': university,
//     'college_name': collegeName,
//   };
// }
class Employee {
  final int empId;

  final String? firstName;
  final String? midName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? dob;
  final String? gender;

  final int? departmentId;
  final String? departmentName;

  final int? roleId;
  final String? roleName;

  final String? dateOfJoining;
  final String? employmentType;
  final String? reportingManager;

  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? pincode;

  final String? emergencyContactName;
  final String? emergencyContactNumber;

  final String? adminApprove;

  final DateTime? dateOfRelieving;
  final String? workType;
  final String? communicationAddress;
  final String? aadharNumber;
  final String? panNumber;
  final String? passportNumber;
  final String? status;

  final int? requestId;

  final String? fatherName;
  final String? emergencyContactRelation; // ← NEW
  final String? emergencyContact;
  final String? pfNumber;
  final String? esicNumber;
  final int? yearsExperience;
  final List<Education>? educationList;
  final int? tlId;

  Employee({
    required this.empId,
    this.firstName,
    this.midName,
    this.lastName,
    this.email,
    this.phone,
    this.dob,
    this.gender,
    this.departmentId,
    this.departmentName,
    this.roleId,
    this.roleName,
    this.dateOfJoining,
    this.employmentType,
    this.reportingManager,
    this.address,
    this.city,
    this.state,
    this.country,
    this.pincode,
    this.emergencyContactName,
    this.emergencyContactNumber,
    this.adminApprove,
    this.dateOfRelieving,
    this.workType,
    this.communicationAddress,
    this.aadharNumber,
    this.panNumber,
    this.passportNumber,
    this.status,
    this.requestId,
    this.fatherName,
    this.emergencyContactRelation, // ← NEW
    this.emergencyContact,
    this.pfNumber,
    this.esicNumber,
    this.yearsExperience,
    this.educationList,
    this.tlId,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    String? val(String key) => json[key]?.toString();

    List<Education>? eduList;
    if (json['education'] != null && json['education'] is List) {
      eduList = (json['education'] as List)
          .map((e) => Education.fromJson(e))
          .toList();
    }

    return Employee(
      empId: json['emp_id'] ?? 0,
      firstName: val('first_name'),
      midName: val('mid_name'),
      lastName: val('last_name'),
      email: val('email_id') ?? val('email'),
      phone: val('phone_number') ?? val('phone'),
      dob: val('date_of_birth') ?? val('dob'),
      gender: val('gender'),
      departmentId: json['department_id'] == null
          ? null
          : int.tryParse(json['department_id'].toString()),
      departmentName: json['department_name'],
      roleId: json['role_id'] == null
          ? null
          : int.tryParse(json['role_id'].toString()),
      roleName: json['role_name'],
      dateOfJoining: val('date_of_joining'),
      employmentType: val('employment_type'),
      reportingManager: val('reporting_manager'),
      address: val('permanent_address') ?? val('address'),
      communicationAddress: val('communication_address'),
      city: val('city'),
      state: val('state'),
      country: val('country'),
      pincode: val('pincode'),
      emergencyContactName: val('emergency_contact_name'),
      emergencyContactNumber: val('emergency_contact_number'),
      adminApprove: json['admin_approve'],
      dateOfRelieving: json['date_of_relieving'] == null
          ? null
          : DateTime.tryParse(json['date_of_relieving'].toString()),
      workType: val('work_type'),
      aadharNumber: val('aadhar_number'),
      panNumber: val('pan_number'),
      passportNumber: val('passport_number'),
      status: val('status'),
      requestId: json['request_id'] == null
          ? null
          : int.tryParse(json['request_id'].toString()),
      fatherName: val('father_name'),
      emergencyContactRelation: val('emergency_contact_relation'), // ← NEW
      emergencyContact: val('emergency_contact'),
      pfNumber: val('pf_number'),
      esicNumber: val('esic_number'),
      yearsExperience: json['years_experience'] == null
          ? null
          : int.tryParse(json['years_experience'].toString()),
      educationList: eduList,
      tlId: json['tl_id'] == null
          ? null
          : int.tryParse(json['tl_id'].toString()),
    );
  }
}

class Education {
  final int? eduId;
  final int empId;
  final String? educationLevel;
  final String? stream;
  final String? score;
  final String? yearOfPassout;
  final String? university;
  final String? collegeName;

  Education({
    this.eduId,
    required this.empId,
    this.educationLevel,
    this.stream,
    this.score,
    this.yearOfPassout,
    this.university,
    this.collegeName,
  });

  factory Education.fromJson(Map<String, dynamic> json) {
    String? val(String key) => json[key]?.toString();

    return Education(
      eduId: json['edu_id'] == null
          ? null
          : int.tryParse(json['edu_id'].toString()),
      empId: json['emp_id'] == null ? 0 : int.parse(json['emp_id'].toString()),
      educationLevel: val('education_level'),
      stream: val('stream'),
      score: val('score'),
      yearOfPassout: val('year_of_passout'),
      university: val('university'),
      collegeName: val('college_name'),
    );
  }

  Map<String, dynamic> toJson() => {
    'emp_id': empId,
    'education_level': educationLevel,
    'stream': stream,
    'score': score,
    'year_of_passout': yearOfPassout,
    'university': university,
    'college_name': collegeName,
  };
}
