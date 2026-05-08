import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_state.dart';
import 'background_service.dart';

/// LogoutService
///
/// Call from anywhere a logout is triggered:
///   - User taps logout
///   - Admin force-logouts via session management
///   - Session-validation poll returns force_logout: true
///
/// Sequence:
///   1. Sends 'force_stop' to background service
///      → service marks OUT from current site if inside one
///      → writes end_session event with reason='logout'
///      → final sync flush to server
///      → clears all SQLite events + site cache
///   2. AttendanceState.forceStop() — wipes in-memory state
///   3. SharedPreferences.clear() — removes all local keys
///   4. Calls onComplete (navigate to login)

class LogoutService {
  LogoutService._();

  static Future<void> logout({
    BuildContext? context,
    required VoidCallback onComplete,
  }) async {
    print('[LogoutService] 🚪 Logout initiated');

    OverlayEntry? overlay;
    if (context != null && context.mounted) {
      overlay = OverlayEntry(builder: (_) => const _LogoutOverlay());
      Overlay.of(context).insert(overlay);
    }

    // ── Safety net: write mark_out + force_end_session directly to SQLite ────
    // Handles the case where service already stopped (e.g. user pressed END
    // with "still on site = true" then immediately logs out).
    // If service IS running, force_stop will also do this — no harm in double.
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getInt('employee_id');
      if (empId != null) {
        final sessionId = prefs.getInt('session_id_$empId');
        final siteId = prefs.getInt('current_site_id_$empId');
        if (siteId != null) {
          await LocalDB.writeEvent(
            type: 'mark_out',
            employeeId: empId,
            siteId: siteId,
            sessionId: sessionId,
          );
        }
        await LocalDB.writeEvent(
          type: 'force_end_session',
          employeeId: empId,
          sessionId: sessionId,
        );
        await SyncWorker.flush();
        print('[LogoutService] ✅ Safety mark_out + end_session written');
      }
    } catch (e) {
      print('[LogoutService] ⚠ Safety write error: $e');
    }

    try {
      await sendForceStop();
      print('[LogoutService] ✅ Service stopped');
    } catch (e) {
      print('[LogoutService] ⚠ Service stop error: $e');
    }

    try {
      await AttendanceState.instance.forceStop();
      print('[LogoutService] ✅ State cleared');
    } catch (e) {
      print('[LogoutService] ⚠ State error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('[LogoutService] ✅ Prefs cleared');
    } catch (e) {
      print('[LogoutService] ⚠ Prefs error: $e');
    }

    overlay?.remove();
    print('[LogoutService] ✅ Done');
    onComplete();
  }

  /// For session-invalid cases — no overlay, immediate.
  static Future<void> forceLogout({required VoidCallback onComplete}) =>
      logout(onComplete: onComplete);
}

class _LogoutOverlay extends StatelessWidget {
  const _LogoutOverlay();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Signing out...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Saving attendance data',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
