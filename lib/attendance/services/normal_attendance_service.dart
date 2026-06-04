import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/api_config.dart';

/// Attendance Service
/// Matches routes in routes/attendance.js
class AttendanceService {
  // ─────────────────────────────────────────────────────────────
  // GET TODAY ATTENDANCE (returns only the record)
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getToday() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/today'),
      headers: ApiConfig.headers,
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Failed to fetch attendance';
    }
    return body['record'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getTodayFull() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/today'),
      headers: ApiConfig.headers,
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Failed to fetch attendance';
    }
    // Return the full map so the screen can read both 'record' and 'policy'
    return {
      'record': body['record'], // Map<String, dynamic>? — today's record
      'policy': body['policy'], // Map<String, dynamic>? — office policy
    };
  }

  // ─────────────────────────────────────────────────────────────
  // CHECK IN — returns the record map directly
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkIn({
    double? latitude,
    double? longitude,
    bool faceVerified = false,
    String? photo,
    String? notes,
    String mode = 'normal',
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/attendance/checkin'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'face_verified': faceVerified,
        if (photo != null) 'photo': photo,
        if (notes != null) 'notes': notes,
        'mode': mode,
      }),
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Check-in failed';
    }
    return body['record'] as Map<String, dynamic>;
  }

  // checkInFull is an alias — returns the record map directly (same as checkIn)
  static Future<Map<String, dynamic>> checkInFull({
    double? latitude,
    double? longitude,
    bool faceVerified = false,
    String? photo,
    String? notes,
    String mode = 'normal',
  }) async {
    return checkIn(
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      photo: photo,
      notes: notes,
      mode: mode,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHECK OUT — returns the record map directly
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkOut({
    double? latitude,
    double? longitude,
    bool faceVerified = false,
    String? photo,
    String? notes,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/attendance/checkout'),
      headers: ApiConfig.headers,
      body: jsonEncode({
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'face_verified': faceVerified,
        if (photo != null) 'photo': photo,
        if (notes != null) 'notes': notes,
      }),
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Check-out failed';
    }
    return body['record'] as Map<String, dynamic>;
  }

  // checkOutFull is an alias — returns the record map directly (same as checkOut)
  static Future<Map<String, dynamic>> checkOutFull({
    double? latitude,
    double? longitude,
    bool faceVerified = false,
    String? photo,
    String? notes,
  }) async {
    return checkOut(
      latitude: latitude,
      longitude: longitude,
      faceVerified: faceVerified,
      photo: photo,
      notes: notes,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ATTENDANCE HISTORY
  // ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/attendance/history').replace(
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
        'mode': 'normal',
      },
    );
    final res = await http.get(uri, headers: ApiConfig.headers);
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Failed';
    }
    return (body['records'] as List).cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────────────────────
  // ATTENDANCE SUMMARY
  // ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/attendance/summary'),
      headers: ApiConfig.headers,
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) {
      throw body['message'] ?? 'Failed';
    }
    return body['summary'] as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────
  static Map<String, dynamic> _decode(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  static void _check(http.Response res) {
    if (res.statusCode == 401) {
      throw 'Session expired. Please log in again.';
    }
    if (res.statusCode == 409) {
      final body = jsonDecode(res.body);
      throw body['message'] ?? 'Conflict.';
    }
    if (res.statusCode == 404) {
      final body = jsonDecode(res.body);
      throw body['message'] ?? 'Not found.';
    }
    if (res.statusCode >= 500) {
      throw 'Server error. Please try again.';
    }
  }
}
