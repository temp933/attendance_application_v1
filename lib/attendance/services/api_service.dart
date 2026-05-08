// import 'dart:convert';
// import 'package:http/http.dart' as http;

// import '../providers/api_config.dart';

// const String baseUrl = ApiConfig.baseUrl;

// class ApiService {
//   static const Duration _timeout = Duration(seconds: 10);
//   static const Duration _longTimeout = Duration(seconds: 20);

//   static final http.Client _client = http.Client();

//   // ── Auth ───────────────────────────────────────────────────────────────────

//   static Future<Map<String, dynamic>> login(
//     String loginId,
//     String password,
//   ) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/auth/login'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({'login_id': loginId, 'password': password}),
//         )
//         .timeout(_timeout);
//     final body = _decode(res.body);
//     if (res.statusCode == 200) return body;
//     throw ApiException(body['message'] ?? 'Login failed', res.statusCode);
//   }

//   // ── Attendance status & logs ───────────────────────────────────────────────

//   /// Returns:
//   ///   { status: 'in_progress', session_id: 42, session_number: 2 }
//   ///   { status: 'not_started', sessions_today: 1 }
//   static Future<Map<String, dynamic>> getTodayStatus(int employeeId) async {
//     final res = await _client
//         .get(Uri.parse('$baseUrl/attendance/status/$employeeId'))
//         .timeout(_timeout);
//     if (res.statusCode == 200) return _decode(res.body);
//     throw ApiException('Status check failed', res.statusCode);
//   }

//   /// Returns list of site visits today, each row includes session_number.
//   static Future<List<dynamic>> getTodayLogs(int employeeId) async {
//     final res = await _client
//         .get(Uri.parse('$baseUrl/attendance/today/$employeeId'))
//         .timeout(_timeout);
//     if (res.statusCode == 200) return jsonDecode(res.body) as List;
//     throw ApiException('Failed to fetch logs', res.statusCode);
//   }

//   // ── Session lifecycle ──────────────────────────────────────────────────────

//   /// Opens a new tracking_session row. Returns the new session_id (int).
//   /// Called when the employee presses START.
//   static Future<Map<String, dynamic>> startSession(int employeeId) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/attendance/start-session'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({'employee_id': employeeId}),
//         )
//         .timeout(_timeout);
//     if (res.statusCode == 200) return _decode(res.body);
//     throw ApiException('Start session failed: ${res.body}', res.statusCode);
//   }

//   /// Closes a tracking_session row with a reason.
//   /// Called when employee presses END or on logout.
//   static Future<void> endSession(
//     int employeeId,
//     int? sessionId, {
//     String reason = 'manual_end',
//   }) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/attendance/end-session'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({
//             'employee_id': employeeId,
//             'session_id': sessionId,
//             'reason': reason,
//           }),
//         )
//         .timeout(_timeout);
//     if (res.statusCode != 200) {
//       throw ApiException('End session failed: ${res.body}', res.statusCode);
//     }
//   }

//   // ── Site visits ────────────────────────────────────────────────────────────

//   static Future<void> markIn(
//     int employeeId,
//     int siteId, {
//     int? sessionId,
//   }) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/attendance/in'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({
//             'employee_id': employeeId,
//             'site_id': siteId,
//             'session_id': sessionId,
//           }),
//         )
//         .timeout(_timeout);
//     if (res.statusCode != 200) {
//       throw ApiException('Mark IN failed: ${res.body}', res.statusCode);
//     }
//   }

//   static Future<void> markOut(int employeeId, {int? sessionId}) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/attendance/out'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({
//             'employee_id': employeeId,
//             'session_id': sessionId,
//           }),
//         )
//         .timeout(_timeout);
//     if (res.statusCode != 200) {
//       throw ApiException('Mark OUT failed: ${res.body}', res.statusCode);
//     }
//   }

//   // ── Sites ──────────────────────────────────────────────────────────────────

//   static Future<List<dynamic>> getSites() async {
//     final res = await _client
//         .get(Uri.parse('$baseUrl/sites'))
//         .timeout(_longTimeout);
//     if (res.statusCode == 200) return jsonDecode(res.body) as List;
//     throw ApiException('Failed to fetch sites', res.statusCode);
//   }

//   // ── Batch sync ─────────────────────────────────────────────────────────────

//   static Future<Map<String, dynamic>> batchSync(
//     List<Map<String, dynamic>> events,
//   ) async {
//     final res = await _client
//         .post(
//           Uri.parse('$baseUrl/attendance/batch-sync'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({'events': events}),
//         )
//         .timeout(_longTimeout);
//     if (res.statusCode == 200) return _decode(res.body);
//     throw ApiException('Batch sync failed: ${res.statusCode}', res.statusCode);
//   }

//   // ── Health check ───────────────────────────────────────────────────────────

//   static Future<bool> pingServer() async {
//     try {
//       final res = await _client
//           .get(Uri.parse(baseUrl))
//           .timeout(const Duration(seconds: 5));
//       return res.statusCode == 200;
//     } catch (_) {
//       return false;
//     }
//   }

//   // ── Cancel Session (location not verified) ────────────────────────────────
//   static Future<void> cancelSession(int employeeId, int sessionId) async {
//     final res = await _delete('/attendance/cancel-session', {
//       'employee_id': employeeId,
//       'session_id': sessionId,
//     });
//     if (res.statusCode != 200) {
//       throw ApiException('Cancel session failed: ${res.body}', res.statusCode);
//     }
//   }

//   static Future<http.Response> _delete(
//     String path,
//     Map<String, dynamic> body,
//   ) async {
//     final request = http.Request('DELETE', Uri.parse('$baseUrl$path'));
//     request.headers['Content-Type'] = 'application/json';
//     request.body = jsonEncode(body);
//     final streamed = await _client.send(request).timeout(_timeout);
//     return http.Response.fromStream(streamed);
//   }
//   // ── Helpers ────────────────────────────────────────────────────────────────

//   static Map<String, dynamic> _decode(String body) {
//     try {
//       return jsonDecode(body) as Map<String, dynamic>;
//     } catch (_) {
//       return {'raw': body};
//     }
//   }
// }

// class ApiException implements Exception {
//   final String message;
//   final int statusCode;
//   const ApiException(this.message, this.statusCode);
//   @override
//   String toString() => 'ApiException($statusCode): $message';
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/api_config.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _longTimeout = Duration(seconds: 20);

  static final http.Client _client = http.Client();

  // ── shared headers ─────────────────────────────────────────────────────────
  static final Map<String, String> _headers = ApiConfig.headers;

  // ── Auth ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String loginId,
    String password,
  ) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/auth/login'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({'login_id': loginId, 'password': password}),
        )
        .timeout(_timeout);
    final body = _decode(res.body);
    if (res.statusCode == 200) return body;
    throw ApiException(body['message'] ?? 'Login failed', res.statusCode);
  }

  // ── Attendance status & logs ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTodayStatus(int employeeId) async {
    final res = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/attendance/status/$employeeId'),
          headers: _headers, // ← ADDED
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return _decode(res.body);
    throw ApiException('Status check failed', res.statusCode);
  }

  static Future<List<dynamic>> getTodayLogs(int employeeId) async {
    final res = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/attendance/today/$employeeId'),
          headers: _headers, // ← ADDED
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    throw ApiException('Failed to fetch logs', res.statusCode);
  }

  // ── Session lifecycle ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> startSession(int employeeId) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/start-session'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({'employee_id': employeeId}),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return _decode(res.body);
    throw ApiException('Start session failed: ${res.body}', res.statusCode);
  }

  static Future<void> endSession(
    int employeeId,
    int? sessionId, {
    String reason = 'manual_end',
  }) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/end-session'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({
            'employee_id': employeeId,
            'session_id': sessionId,
            'reason': reason,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException('End session failed: ${res.body}', res.statusCode);
    }
  }

  // ── Site visits ────────────────────────────────────────────────────────────
  static Future<void> markIn(
    int employeeId,
    int siteId, {
    int? sessionId,
  }) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/in'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({
            'employee_id': employeeId,
            'site_id': siteId,
            'session_id': sessionId,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException('Mark IN failed: ${res.body}', res.statusCode);
    }
  }

  static Future<void> markOut(int employeeId, {int? sessionId}) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/out'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({
            'employee_id': employeeId,
            'session_id': sessionId,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw ApiException('Mark OUT failed: ${res.body}', res.statusCode);
    }
  }

  // ── Sites ──────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getSites() async {
    final res = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/sites'),
          headers: _headers, // ← ADDED
        )
        .timeout(_longTimeout);
    if (res.statusCode == 200) return jsonDecode(res.body) as List;
    throw ApiException('Failed to fetch sites', res.statusCode);
  }

  // ── Batch sync ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> batchSync(
    List<Map<String, dynamic>> events,
  ) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/batch-sync'),
          headers: _headers, // ← CHANGED
          body: jsonEncode({'events': events}),
        )
        .timeout(_longTimeout);
    if (res.statusCode == 200) return _decode(res.body);
    throw ApiException('Batch sync failed: ${res.statusCode}', res.statusCode);
  }

  // ── Health check ───────────────────────────────────────────────────────────
  static Future<bool> pingServer() async {
    try {
      final res = await _client
          .get(
            Uri.parse(ApiConfig.baseUrl),
            headers: _headers, // ← ADDED
          )
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> confirmLocation(int employeeId, int? sessionId) async {
    if (sessionId == null) return;
    await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/attendance/confirm-location'),
          headers: _headers,
          body: jsonEncode({
            'employee_id': employeeId,
            'session_id': sessionId,
          }),
        )
        .timeout(_timeout);
  }

  // ── Cancel Session ────────────────────────────────────────────────────────
  static Future<void> cancelSession(int employeeId, int sessionId) async {
    final res = await _delete('/attendance/cancel-session', {
      'employee_id': employeeId,
      'session_id': sessionId,
    });
    if (res.statusCode != 200) {
      throw ApiException('Cancel session failed: ${res.body}', res.statusCode);
    }
  }

  static Future<http.Response> _delete(
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    );
    request.headers.addAll(
      _headers,
    ); // ← CHANGED (adds all headers including ngrok)
    request.body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': body};
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
