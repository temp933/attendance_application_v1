// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/admin_hr_attendance_model.dart';
// import '../providers/api_config.dart';

// const String baseUrl = ApiConfig.baseUrl;

// class AdminHrAttendanceService {
//   static Future<List<AttendanceAdminModel>> fetchAttendance(String date) async {
//     final url = "$baseUrl/attendance/by-date-detail?date=$date";
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final body = json.decode(response.body);
//       final List data = body['data'];
//       return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load attendance");
//     }
//   }

//   static Future<List<AttendanceAdminModel>> fetchTLTeamAttendance(
//     String date,
//     int loginId,
//   ) async {
//     final url =
//         "$baseUrl/attendance/tl-team-by-date?date=$date&login_id=$loginId";
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final body = json.decode(response.body);
//       final List data = body['data'];
//       return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
//     } else {
//       throw Exception("Failed to load team attendance");
//     }
//   }

//   static Future<Map<String, double?>?> fetchSiteLocation(int siteId) async {
//     final url = "$baseUrl/sites/$siteId/location";
//     final response = await http.get(Uri.parse(url));
//     if (response.statusCode == 200) {
//       final body = json.decode(response.body);
//       return {
//         'lat': (body['lat'] as num?)?.toDouble(),
//         'lng': (body['lng'] as num?)?.toDouble(),
//       };
//     }
//     return null;
//   }
// }
import 'dart:convert';
import '../models/admin_hr_attendance_model.dart';
import '../providers/api_client.dart';

class AdminHrAttendanceService {
  static Future<List<AttendanceAdminModel>> fetchAttendance(String date) async {
    final response = await ApiClient.get(
      '/attendance/by-date-detail?date=$date',
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List data = body['data'];
      return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load attendance");
    }
  }

  static Future<List<AttendanceAdminModel>> fetchTLTeamAttendance(
    String date,
    int loginId,
  ) async {
    final response = await ApiClient.get(
      '/attendance/tl-team-by-date?date=$date&login_id=$loginId',
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List data = body['data'];
      return data.map((e) => AttendanceAdminModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load team attendance");
    }
  }

  static Future<Map<String, double?>?> fetchSiteLocation(int siteId) async {
    final response = await ApiClient.get('/sites/$siteId/location');
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      return {
        'lat': (body['lat'] as num?)?.toDouble(),
        'lng': (body['lng'] as num?)?.toDouble(),
      };
    }
    return null;
  }
}
