// lib/services/comp_off_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum CompOffStatus { earned, used, expired }

extension CompOffStatusExt on CompOffStatus {
  String get value => name; // 'earned' | 'used' | 'expired'

  static CompOffStatus fromString(String s) {
    switch (s) {
      case 'used':
        return CompOffStatus.used;
      case 'expired':
        return CompOffStatus.expired;
      default:
        return CompOffStatus.earned;
    }
  }
}

class CompOffRecord {
  final int id;
  final int? attendanceId;
  final int? leaveId;
  final DateTime earnedDate;
  final DateTime? expiryDate;
  final CompOffStatus status;
  final String? remarks;
  final DateTime? createdAt;
  final String? workedTime; // "HH:MM:SS"

  const CompOffRecord({
    required this.id,
    this.attendanceId,
    this.leaveId,
    required this.earnedDate,
    this.expiryDate,
    required this.status,
    this.remarks,
    this.createdAt,
    this.workedTime,
  });

  factory CompOffRecord.fromJson(Map<String, dynamic> j) => CompOffRecord(
    id: int.tryParse('${j['id']}') ?? 0,
    attendanceId: j['attendance_id'] != null
        ? int.tryParse('${j['attendance_id']}')
        : null,
    leaveId: j['leave_id'] != null ? int.tryParse('${j['leave_id']}') : null,
    earnedDate: DateTime.parse(j['earned_date'] as String),
    expiryDate: j['expiry_date'] != null
        ? DateTime.tryParse(j['expiry_date'] as String)
        : null,
    status: CompOffStatusExt.fromString(j['status'] as String? ?? 'earned'),
    remarks: j['remarks'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'] as String)
        : null,
    workedTime: j['worked_time'] as String?,
  );

  bool get isExpired => status == CompOffStatus.expired;
  bool get isUsed => status == CompOffStatus.used;
  bool get isEarned => status == CompOffStatus.earned;

  bool get isExpiringSoon {
    if (expiryDate == null || !isEarned) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 7;
  }
}

class CompOffSummary {
  final int total;
  final int earned;
  final int used;
  final int expired;

  const CompOffSummary({
    required this.total,
    required this.earned,
    required this.used,
    required this.expired,
  });

  factory CompOffSummary.fromJson(Map<String, dynamic> j) => CompOffSummary(
    total: int.tryParse('${j['total'] ?? 0}') ?? 0,
    earned: int.tryParse('${j['earned'] ?? 0}') ?? 0,
    used: int.tryParse('${j['used'] ?? 0}') ?? 0,
    expired: int.tryParse('${j['expired'] ?? 0}') ?? 0,
  );
  factory CompOffSummary.empty() =>
      const CompOffSummary(total: 0, earned: 0, used: 0, expired: 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class CompOffService {
  static const String _base = '/comp-off';

  // ── GET /comp-off?status=earned|used|expired&limit=50&offset=0 ────────────
  static Future<({List<CompOffRecord> records, CompOffSummary summary})>
  getCompOffs({String? status, int limit = 50, int offset = 0}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$_base').replace(
      queryParameters: {
        if (status != null) 'status': status,
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final res = await http.get(uri, headers: ApiConfig.headers);
    _check(res);

    final body = _decode(res);
    if (body['success'] != true)
      throw body['message'] ?? 'Failed to load comp-offs.';

    final records = (body['records'] as List)
        .map((e) => CompOffRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    final summary = body['summary'] != null
        ? CompOffSummary.fromJson(body['summary'] as Map<String, dynamic>)
        : CompOffSummary.empty();

    return (records: records, summary: summary);
  }

  // ── GET /comp-off/eligibility/:attendanceId ───────────────────────────────
  static Future<Map<String, dynamic>> checkEligibility(int attendanceId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$_base/eligibility/$attendanceId'),
      headers: ApiConfig.headers,
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true)
      throw body['message'] ?? 'Eligibility check failed.';
    return body;
  }

  // ── POST /comp-off/generate ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateCompOff(int attendanceId) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$_base/generate'),
      headers: ApiConfig.headers,
      body: jsonEncode({'attendance_id': attendanceId}),
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true) throw body['message'] ?? 'Generation failed.';
    return body;
  }

  // ── PATCH /comp-off/:id/use ───────────────────────────────────────────────
  static Future<void> markUsed(int compOffId, {int? leaveId}) async {
    final res = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}$_base/$compOffId/use'),
      headers: ApiConfig.headers,
      body: jsonEncode({if (leaveId != null) 'leave_id': leaveId}),
    );
    _check(res);
    final body = _decode(res);
    if (body['success'] != true)
      throw body['message'] ?? 'Failed to mark as used.';
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  static Map<String, dynamic> _decode(http.Response res) =>
      jsonDecode(res.body) as Map<String, dynamic>;

  static void _check(http.Response res) {
    if (res.statusCode == 401) throw 'Session expired. Please log in again.';
    if (res.statusCode == 404) {
      throw (_decode(res)['message'] ?? 'Not found.');
    }
    if (res.statusCode == 409) {
      throw (_decode(res)['message'] ?? 'Conflict.');
    }
    if (res.statusCode >= 500) throw 'Server error. Please try again.';
  }
}
