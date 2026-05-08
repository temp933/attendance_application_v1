// class User {
//   final String id;
//   String username;
//   String email;
//   String role;
//   bool isActive;
//   bool isEmailVerified;
//   String? deviceId;

//   // New fields
//   String fullName;
//   String employeeId;
//   String phone;
//   String department;
//   String designation;
//   String password;
//   bool deviceVerificationEnabled;

//   User({
//     required this.id,
//     required this.username,
//     required this.email,
//     required this.role,
//     this.isActive = false,
//     this.isEmailVerified = false,
//     this.deviceId,
//     required this.fullName,
//     required this.employeeId,
//     required this.phone,
//     required this.department,
//     required this.designation,
//     required this.password,
//     this.deviceVerificationEnabled = false,
//   });

//   factory User.fromJson(Map<String, dynamic> json) => User(
//     id: json['id'],
//     username: json['username'],
//     email: json['email'],
//     role: json['role'],
//     isActive: json['isActive'] ?? false,
//     isEmailVerified: json['isEmailVerified'] ?? false,
//     deviceId: json['deviceId'],
//     fullName: json['fullName'] ?? '',
//     employeeId: json['employeeId'] ?? '',
//     phone: json['phone'] ?? '',
//     department: json['department'] ?? '',
//     designation: json['designation'] ?? '',
//     password: json['password'] ?? '',
//     deviceVerificationEnabled: json['deviceVerificationEnabled'] ?? false,
//   );

//   Map<String, dynamic> toJson() => {
//     'id': id,
//     'username': username,
//     'email': email,
//     'role': role,
//     'isActive': isActive,
//     'isEmailVerified': isEmailVerified,
//     'deviceId': deviceId,
//     'fullName': fullName,
//     'employeeId': employeeId,
//     'phone': phone,
//     'department': department,
//     'designation': designation,
//     'password': password,
//     'deviceVerificationEnabled': deviceVerificationEnabled,
//   };
// }
/// user model.dart
class UserModel {
  // Core
  String employeeId;
  String firstName;
  String? middleName;
  String lastName;
  DateTime dob;
  DateTime doj;
  String roll;
  String department;
  String status;

  // Contact
  String phone;
  String personalEmail;
  String officialEmail;

  // Identity
  String aadhaar;
  String pan;

  // Bank
  String bankName;
  String bankBranch;
  String ifscCode;
  String accountType;
  String accountNumber;

  // Qualification
  List<Qualification> qualifications;

  // Address
  Address permanentAddress;
  Address communicationAddress;

  String submissionStatus;
  String? rejectionReason;

  UserModel({
    required this.employeeId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.dob,
    required this.doj,
    required this.roll,
    required this.department,
    required this.status,

    required this.phone,
    required this.personalEmail,
    required this.officialEmail,
    this.aadhaar = '',
    this.pan = '',
    this.bankName = '',
    this.bankBranch = '',
    this.ifscCode = '',
    this.accountType = '',
    this.accountNumber = '',
    required this.qualifications,
    required this.permanentAddress,
    required this.communicationAddress,
    required this.submissionStatus,
    
  });
}

/// =======================
/// QUALIFICATION
/// =======================
class Qualification {
  String type;
  String degree;

  Qualification({required this.type, required this.degree});
}

/// =======================
/// ADDRESS
/// =======================
class Address {
  String line1;
  String line2;
  String landmark;
  String state;
  String country;
  String pinCode;

  Address({
    required this.line1,
    required this.line2,
    required this.landmark,
    required this.state,
    required this.country,
    required this.pinCode,
  });

  factory Address.clone(Address a) {
    return Address(
      line1: a.line1,
      line2: a.line2,
      landmark: a.landmark,
      state: a.state,
      country: a.country,
      pinCode: a.pinCode,
    );
  }
}
