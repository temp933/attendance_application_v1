// // import 'package:flutter/material.dart';

// // class AttendanceProvider extends ChangeNotifier {
// //   final int empId; // Employee ID added here

// //   bool isCheckedIn = false;
// //   DateTime? checkInTime;
// //   DateTime? checkOutTime;
// //   String status = "Not Checked In";

// //   AttendanceProvider({required this.empId});

// //   /// CHECK IN
// //   void checkIn() {
// //     isCheckedIn = true;
// //     checkInTime = DateTime.now();

// //     // Clear old check-out time if any
// //     checkOutTime = null;

// //     status = "Checked In";
// //     notifyListeners();
// //   }

// //   /// CHECK OUT
// //   void checkOut() {
// //     isCheckedIn = false;
// //     checkOutTime = DateTime.now();
// //     status = "Checked Out";
// //     notifyListeners();
// //   }

// //   /// OPTIONAL RESET (Next Day)
// //   void reset() {
// //     isCheckedIn = false;
// //     checkInTime = null;
// //     checkOutTime = null;
// //     status = "Not Checked In";
// //     notifyListeners();
// //   }
// // }

// // import 'package:flutter/material.dart';

// // class AttendanceProvider extends ChangeNotifier {
// //   final String empId; // Add empId here

// //   bool _isCheckedIn = false;
// //   bool get isCheckedIn => _isCheckedIn;

// //   DateTime? _checkInTime;
// //   DateTime? get checkInTime => _checkInTime;

// //   DateTime? _checkOutTime;
// //   DateTime? get checkOutTime => _checkOutTime;

// //   String get status => _isCheckedIn ? "Checked In" : "Checked Out";

// //   AttendanceProvider({required this.empId}); // require empId in constructor

// //   void checkIn() {
// //     _isCheckedIn = true;
// //     _checkInTime = DateTime.now();
// //     notifyListeners();
// //   }

// //   void checkOut() {
// //     _isCheckedIn = false;
// //     _checkOutTime = DateTime.now();
// //     notifyListeners();
// //   }
// // }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class AttendanceProvider extends ChangeNotifier {
//   final String empId; // Employee ID

//   bool _isCheckedIn = false;
//   bool get isCheckedIn => _isCheckedIn;

//   DateTime? _checkInTime;
//   DateTime? get checkInTime => _checkInTime;

//   DateTime? _checkOutTime;
//   DateTime? get checkOutTime => _checkOutTime;

//   String get status => _isCheckedIn ? "Checked In" : "Checked Out";

//   AttendanceProvider({required this.empId});

//   /// Mark check-in locally
//   void checkIn() {
//     _isCheckedIn = true;
//     _checkInTime = DateTime.now();
//     notifyListeners();
//   }

//   /// Mark check-out locally
//   void checkOut() {
//     _isCheckedIn = false;
//     _checkOutTime = DateTime.now();
//     notifyListeners();
//   }

//   /// Fetch last attendance from backend
//   Future<void> fetchAttendanceStatus() async {
//     try {
//       final url = Uri.parse("http://localhost:3000/attendance/status/$empId");
//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         _isCheckedIn = data['isCheckedIn'] ?? false;

//         _checkInTime = data['checkInTime'] != null
//             ? DateTime.parse(data['checkInTime'])
//             : null;

//         _checkOutTime = data['checkOutTime'] != null
//             ? DateTime.parse(data['checkOutTime'])
//             : null;

//         notifyListeners();
//       } else {
//         print("Failed to fetch attendance status: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("Error fetching attendance status: $e");
//     }
//   }

//   /// Reset provider (optional, for logout)
//   void reset() {
//     _isCheckedIn = false;
//     _checkInTime = null;
//     _checkOutTime = null;
//     notifyListeners();
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Mirrors the backend tables:
///   employee_site_attendance  (id, employee_id, site_id, in_time, out_time,
///                              total_time_in_site, work_date, status, updated_at)
///   sites                     (id, site_name, polygon_json, start_date,
///                              end_date, created_at)
///
/// Backend status values: 'not_started' | 'in_progress' | 'completed'
///   • not_started  → no row in employee_site_attendance today
///   • in_progress  → at least one row with status = 'active' (out_time IS NULL)
///   • completed    → all rows closed  (status = 'completed' or 'ended_manually')
class AttendanceProvider extends ChangeNotifier {
  // ── Set once at login, never changes within the session ──────────────────
  final String
  empId; // stored as String to match login response; cast to int for API calls

  // ── Day status ────────────────────────────────────────────────────────────
  // Values: 'not_started' | 'in_progress' | 'completed'
  String _dayStatus = 'not_started';
  String get dayStatus => _dayStatus;

  bool get isNotStarted => _dayStatus == 'not_started';
  bool get isInProgress => _dayStatus == 'in_progress';
  bool get isCompleted => _dayStatus == 'completed';

  // ── Active site (populated while isInProgress = true) ─────────────────────
  // Derived from the open row (out_time IS NULL, status = 'active') in today's logs
  int? _activeSiteId;
  String? _activeSiteName;
  int? get activeSiteId => _activeSiteId;
  String? get activeSiteName => _activeSiteName;

  // ── Today's site-visit rows ───────────────────────────────────────────────
  // Each item mirrors the JOIN of employee_site_attendance + sites:
  //   { id, site_id, site_name, in_time, out_time, work_date,
  //     status, total_time_in_site, duration_minutes }
  //
  //   • in_time / out_time come back as 'HH:mm:ss' strings (see server.js)
  //   • out_time is null when status = 'active'
  //   • duration_minutes is TIMESTAMPDIFF computed by the backend
  List<Map<String, dynamic>> _todayLogs = [];
  List<Map<String, dynamic>> get todayLogs => List.unmodifiable(_todayLogs);

  // ── Loading / error ───────────────────────────────────────────────────────
  bool _loading = false;
  bool get loading => _loading;
  String _error = '';
  String get error => _error;

  // ── HTTP ──────────────────────────────────────────────────────────────────
  static const _base = 'http://192.168.29.104:3000';
  final _client = http.Client();

  AttendanceProvider({required this.empId});

  // ══════════════════════════════════════════════════════════════════════════
  // INIT — call on screen load
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetches today's status + all site-visit logs in one shot.
  /// AttendanceScreen calls this from _init().
  Future<void> fetchAll() async {
    _setLoading(true);
    _error = '';
    try {
      await Future.wait([_fetchStatus(), _fetchLogs()]);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE ACTIONS — called by AttendanceScreen / background_service
  // ══════════════════════════════════════════════════════════════════════════

  /// POST /attendance/in  { employee_id, site_id }
  /// Backend rules (from server.js):
  ///   1. Same site, row open → already IN, no-op
  ///   2. Same site, row closed < 15 min ago → reopen row
  ///   3. Same site, row closed ≥ 15 min ago → new row
  ///   4. Different site open → close it first, then apply 1-3
  ///   5. No row today → new row
  Future<bool> markIn(int siteId, String siteName) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_base/attendance/in'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'employee_id': _empIdInt, 'site_id': siteId}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _dayStatus = 'in_progress';
        _activeSiteId = siteId;
        _activeSiteName = siteName;
        await _fetchLogs(); // refresh the visit list
        notifyListeners();
        return true;
      }
      _error = _extractMessage(res.body, 'Mark-in failed');
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// POST /attendance/out  { employee_id }
  /// Closes ALL open rows for today (sets out_time = NOW(), status = 'completed').
  Future<bool> markOut() async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_base/attendance/out'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'employee_id': _empIdInt}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _activeSiteId = null;
        _activeSiteName = null;
        // Re-fetch both — status might still be in_progress if
        // background service will mark IN again at a different site.
        await Future.wait([_fetchStatus(), _fetchLogs()]);
        notifyListeners();
        return true;
      }
      _error = _extractMessage(res.body, 'Mark-out failed');
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// PUT /attendance/heartbeat  { employee_id }
  /// Rolls out_time forward on the active row so the backend knows the
  /// employee is still on site.  Called every 5 minutes by background_service.
  Future<void> heartbeat() async {
    try {
      await _client
          .put(
            Uri.parse('$_base/attendance/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'employee_id': _empIdInt}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Heartbeat failures are non-fatal — just log them
      debugPrint('AttendanceProvider.heartbeat error: $e');
    }
  }

  /// POST /attendance/end-day  { employee_id }
  /// Closes all open rows with status = 'ended_manually'.
  /// Called when the employee taps END WORK for the day.
  Future<bool> endDay() async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_base/attendance/end-day'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'employee_id': _empIdInt}),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _dayStatus = 'completed';
        _activeSiteId = null;
        _activeSiteName = null;
        await _fetchLogs();
        notifyListeners();
        return true;
      }
      _error = _extractMessage(res.body, 'End-day failed');
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REFRESH HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Lightweight refresh — just today's log rows.
  /// AttendanceScreen calls this every 10 seconds via Timer.
  Future<void> refreshLogs() async {
    try {
      await _fetchLogs();
    } catch (e) {
      debugPrint('AttendanceProvider.refreshLogs error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════════════════════════

  void clearError() {
    _error = '';
    notifyListeners();
  }

  /// Call on logout to wipe all state.
  void reset() {
    _dayStatus = 'not_started';
    _activeSiteId = null;
    _activeSiteName = null;
    _todayLogs = [];
    _error = '';
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE — backend calls
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /attendance/status/:empId
  /// Response: { "status": "not_started" | "in_progress" | "completed" }
  Future<void> _fetchStatus() async {
    final res = await _client
        .get(Uri.parse('$_base/attendance/status/$empId'))
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _dayStatus = (data['status'] as String?) ?? 'not_started';
    }
  }

  /// GET /attendance/today/:empId
  /// Returns an array of rows from employee_site_attendance JOIN sites:
  ///   [
  ///     {
  ///       "id": 12,
  ///       "site_id": 3,
  ///       "site_name": "Main Gate",
  ///       "in_time": "09:05:00",          ← HH:mm:ss string from DATE_FORMAT
  ///       "out_time": "12:30:00" | null,  ← null when status = 'active'
  ///       "work_date": "2026-03-07",
  ///       "status": "active" | "completed" | "ended_manually",
  ///       "total_time_in_site": "03:25:00" | null,  ← STORED GENERATED column
  ///       "duration_minutes": 205         ← TIMESTAMPDIFF from backend
  ///     },
  ///     ...
  ///   ]
  Future<void> _fetchLogs() async {
    final res = await _client
        .get(Uri.parse('$_base/attendance/today/$empId'))
        .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      _todayLogs = list.cast<Map<String, dynamic>>();

      // Derive the active site from the open row
      // (out_time == null AND status == 'active')
      final openRow = _todayLogs.cast<Map<String, dynamic>?>().firstWhere(
        (r) => r != null && r['out_time'] == null && r['status'] == 'active',
        orElse: () => null,
      );

      if (openRow != null) {
        _activeSiteId = openRow['site_id'] as int?;
        _activeSiteName = openRow['site_name'] as String?;
        _dayStatus = 'in_progress';
      } else if (_todayLogs.isNotEmpty && _dayStatus != 'completed') {
        // All rows are closed → mark completed unless backend already said so
        final allClosed = _todayLogs.every(
          (r) => r['out_time'] != null || r['status'] != 'active',
        );
        if (allClosed) {
          _activeSiteId = null;
          _activeSiteName = null;
          // Don't override 'completed' set by endDay()
        }
      }

      notifyListeners();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  int get _empIdInt => int.tryParse(empId) ?? 0;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  String _extractMessage(String body, String fallback) {
    try {
      final d = jsonDecode(body) as Map<String, dynamic>;
      return (d['message'] ?? d['error'] ?? fallback).toString();
    } catch (_) {
      return fallback;
    }
  }
}
