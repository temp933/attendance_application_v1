import 'dart:convert';
import '../models/leavemodel.dart';
import '../providers/api_client.dart';

class LeaveService {
  // ── Employee leaves ────────────────────────────────────────────────────────
  Future<List<LeaveModel>> getEmployeeLeaves(int empId) async {
    final response = await ApiClient.get('/employees/$empId/leaves');
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  Future<List<LeaveModel>> getPendingTLLeaves(int loginId) async {
    final response = await ApiClient.get(
      '/leaves/pending-tl?login_id=$loginId',
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  Future<List<LeaveModel>> getPendingManagerLeaves() async {
    final response = await ApiClient.get('/leaves/pending-manager');
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  Future<List<LeaveModel>> getPendingHRLeaves() => getPendingManagerLeaves();

  Future<List<LeaveModel>> getAllPendingLeaves() async {
    final response = await ApiClient.get('/leaves/all-pending');
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromPendingJson(e)).toList();
      }
    }
    return [];
  }

  Future<bool> tlLeaveAction({
    required int leaveId,
    required String action,
    required int loginId,
    String? rejectionReason,
  }) async {
    final body = <String, dynamic>{'action': action, 'login_id': loginId};
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;
    final response = await ApiClient.put('/leave/$leaveId/tl-action', body);
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  Future<bool> managerLeaveAction({
    required int leaveId,
    required String status,
    required int loginId,
    String? rejectionReason,
  }) async {
    final body = <String, dynamic>{'status': status, 'login_id': loginId};
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;
    final response = await ApiClient.put(
      '/leave/$leaveId/manager-action',
      body,
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['success'] == true;
    }
    return false;
  }

  Future<List<LeaveModel>> getAllLeaveHistory(int empId) async {
    final response = await ApiClient.get('/leave-history?emp_id=$empId');
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      } else {
        throw Exception(decoded['message']);
      }
    } else {
      throw Exception('Failed to load leave history');
    }
  }

  Future<List<LeaveModel>> getAllLeavesHistory() async {
    final response = await ApiClient.get('/leaves/all-history');
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      }
    }
    return [];
  }

  Future<List<LeaveModel>> getTLLeavesHistory(int loginId) async {
    final response = await ApiClient.get(
      '/leaves/tl-history?login_id=$loginId',
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['success'] == true) {
        List data = decoded['data'];
        return data.map((e) => LeaveModel.fromHistoryJson(e)).toList();
      }
    }
    return [];
  }

  // ── Leave balance ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getLeaveBalance(
    int empId, {
    int? year,
  }) async {
    final y = year ?? DateTime.now().year;
    final res = await ApiClient.get('/employees/$empId/leave-balance?year=$y');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data']);
      }
    }
    return [];
  }

  // ── Comp-off eligibility ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCompoffEligibility(int empId) async {
    final res = await ApiClient.get('/employees/$empId/compoff-eligible');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        return {
          'eligible': data['eligible'] as bool,
          'available': (data['available'] as num).toDouble(),
        };
      }
    }
    return {'eligible': false, 'available': 0.0};
  }

  // ── Working days preview ───────────────────────────────────────────────────
  Future<int?> getWorkingDays(String from, String to) async {
    final res = await ApiClient.get('/working-days?from=$from&to=$to');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['working_days'] as int?;
    }
    return null;
  }

  // ── Submit leave (all types including Comp-Off) ────────────────────────────
  Future<Map<String, dynamic>> applyLeave({
    required int empId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    bool isHalfDay = false,
    String? halfDayPeriod,
  }) async {
    final body = <String, dynamic>{
      'leave_type': leaveType,
      'leave_start_date': startDate,
      'leave_end_date': endDate,
      'reason': reason,
      'is_half_day': isHalfDay,
    };
    if (isHalfDay && halfDayPeriod != null) {
      body['half_day_period'] = halfDayPeriod;
    }
    final res = await ApiClient.post('/employees/$empId/apply-leave', body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Regularization ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getMyRegularizations(int empId) async {
    final res = await ApiClient.get('/regularization?emp_id=$empId');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['data'] as List;
    }
    return [];
  }

  Future<bool> submitRegularization({
    required int empId,
    required String workDate,
    String? expectedIn,
    String? expectedOut,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'emp_id': empId,
      'work_date': workDate,
      'reason': reason,
    };
    if (expectedIn != null) body['expected_in'] = expectedIn;
    if (expectedOut != null) body['expected_out'] = expectedOut;
    final res = await ApiClient.post('/regularization', body);
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<bool> cancelRegularization(int regId, int empId) async {
    final res = await ApiClient.put('/regularization/$regId/cancel', {
      'emp_id': empId,
    });
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<List<dynamic>> getPendingRegularizationsTL(int loginId) async {
    final res = await ApiClient.get(
      '/regularization/pending-tl?login_id=$loginId',
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['data'] as List;
    }
    return [];
  }

  Future<bool> tlRegularizationAction({
    required int regId,
    required String action,
    required int loginId,
    String? remark,
  }) async {
    final body = <String, dynamic>{'action': action, 'login_id': loginId};
    if (remark != null) body['remark'] = remark;
    final res = await ApiClient.put('/regularization/$regId/tl-action', body);
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<List<dynamic>> getPendingRegularizationsManager() async {
    final res = await ApiClient.get('/regularization/pending-manager');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['data'] as List;
    }
    return [];
  }

  Future<bool> managerRegularizationAction({
    required int regId,
    required String action,
    required int loginId,
    String? remark,
  }) async {
    final body = <String, dynamic>{'action': action, 'login_id': loginId};
    if (remark != null) body['remark'] = remark;
    final res = await ApiClient.put(
      '/regularization/$regId/manager-action',
      body,
    );
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  // ── Comp-off ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getCompoffBalance(int empId) async {
    final res = await ApiClient.get('/employees/$empId/compoff-balance');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<dynamic>> getMyCompoffEarned(int empId) async {
    final res = await ApiClient.get('/compoff/earn?emp_id=$empId');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['data'] as List;
    }
    return [];
  }

  Future<bool> submitCompoffEarn({
    required int empId,
    required String workedDate,
    double? workedHours,
    required String reason,
  }) async {
    final body = <String, dynamic>{
      'emp_id': empId,
      'worked_date': workedDate,
      'reason': reason,
    };
    if (workedHours != null) body['worked_hours'] = workedHours;
    final res = await ApiClient.post('/compoff/earn', body);
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<bool> cancelCompoffEarn(int compoffId, int empId) async {
    final res = await ApiClient.put('/compoff/earn/$compoffId/cancel', {
      'emp_id': empId,
    });
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<List<dynamic>> getMyCompoffAvailed(int empId) async {
    final res = await ApiClient.get('/compoff/avail?emp_id=$empId');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) return data['data'] as List;
    }
    return [];
  }

  Future<bool> submitCompoffAvail({
    required int empId,
    required String availDate,
    double daysUsed = 1.0,
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'emp_id': empId,
      'avail_date': availDate,
      'days_used': daysUsed,
    };
    if (reason != null) body['reason'] = reason;
    final res = await ApiClient.post('/compoff/avail', body);
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  Future<bool> cancelCompoffAvail(int availId, int empId) async {
    final res = await ApiClient.put('/compoff/avail/$availId/cancel', {
      'emp_id': empId,
    });
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }
}
