import 'api_service.dart';

class AttendanceService {
  /// Mark employee IN at a specific site.
  Future<void> checkIn({required int empId, required int siteId}) async {
    await ApiService.markIn(empId, siteId);
  }

  /// Mark employee OUT (close open row).
  Future<void> checkOut({required int empId}) async {
    await ApiService.markOut(empId);
  }

  /// End the whole work day — locks attendance for today.
  Future<void> endDay({required int empId}) async {
    await ApiService.endSession(empId, null, reason: 'manual_end');
  }
}
