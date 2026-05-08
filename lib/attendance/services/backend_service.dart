// // import 'dart:convert';
// // import 'package:http/http.dart' as http;

// // class BackendService {
// //   static const String baseUrl = "http://192.168.29.216:3000";

// //   // Get all users
// //   static Future<List<Map<String, dynamic>>> getUsers() async {
// //     final url = Uri.parse("$baseUrl/users");
// //     final response = await http.get(url);
// //     if (response.statusCode == 200) {
// //       return List<Map<String, dynamic>>.from(jsonDecode(response.body));
// //     }
// //     return [];
// //   }

// //   // Approve/reject user
// //   static Future<bool> updateApproval(
// //     String employeeId,
// //     bool approved, [
// //     String? reason,
// //   ]) async {
// //     final url = Uri.parse("$baseUrl/users/$employeeId/approval");
// //     final response = await http.post(
// //       url,
// //       headers: {"Content-Type": "application/json"},
// //       body: jsonEncode({"approved": approved, "reason": reason ?? ""}),
// //     );
// //     return response.statusCode == 200;
// //   }

// //   // Add a user
// //   static Future<bool> addUser(Map<String, dynamic> user) async {
// //     final url = Uri.parse("$baseUrl/users");
// //     final response = await http.post(
// //       url,
// //       headers: {"Content-Type": "application/json"},
// //       body: jsonEncode(user),
// //     );
// //     return response.statusCode == 200;
// //   }
// // }

// import 'dart:async';
// import 'dart:io';
// import 'dart:ui';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/widgets.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'offline_queue.dart';
// import 'site_cache.dart';

// // ─── Public initializer — call once in main() BEFORE runApp() ─────────────────

// Future<void> initBackgroundService() async {
//   final service = FlutterBackgroundService();

//   const AndroidNotificationChannel channel = AndroidNotificationChannel(
//     'attendance_fg_channel',
//     'Attendance Tracking',
//     description: 'Keeps location tracking active in the background',
//     importance: Importance.low,
//     playSound: false,
//     enableVibration: false,
//   );

//   final FlutterLocalNotificationsPlugin notificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   await notificationsPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(channel);

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       autoStart: false,
//       isForegroundMode: true,
//       notificationChannelId: 'attendance_fg_channel',
//       initialNotificationTitle: 'Attendance Active',
//       initialNotificationContent: 'Location tracking is running…',
//       foregroundServiceNotificationId: 888,
//       autoStartOnBoot: false,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//   );
// }

// // ─── iOS background handler ────────────────────────────────────────────────────

// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   return true;
// }

// // ─── Background isolate entry point ───────────────────────────────────────────

// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   if (service is AndroidServiceInstance) {
//     service.setAsForegroundService();
//     service.setForegroundNotificationInfo(
//       title: 'Attendance Active',
//       content: 'Tracking your location…',
//     );
//   }

//   // ── Read employee id ────────────────────────────────────────────────────────
//   final prefs = await SharedPreferences.getInstance();
//   final empId = prefs.getInt('employee_id') ?? -1;
//   if (empId == -1) {
//     debugPrint('[BG] No employee_id — stopping.');
//     service.stopSelf();
//     return;
//   }

//   // ── Site cache ──────────────────────────────────────────────────────────────
//   await SiteCache.init();

//   // ── Isolate-local mutable state ─────────────────────────────────────────────
//   int? currentSiteId;
//   bool dayEnded = false;
//   DateTime lastDrain = DateTime.now().subtract(const Duration(minutes: 6));

//   // ── Helpers ────────────────────────────────────────────────────────────────

//   void updateNotification(String content) {
//     if (service is AndroidServiceInstance) {
//       service.setForegroundNotificationInfo(
//         title: 'Attendance Active',
//         content: content,
//       );
//     }
//   }

//   /// Raw TCP check — no connectivity_plus needed.
//   Future<bool> isOnline() async {
//     try {
//       final sock = await Socket.connect(
//         '8.8.8.8',
//         53,
//         timeout: const Duration(seconds: 3),
//       );
//       sock.destroy();
//       return true;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> maybeDrain({bool force = false}) async {
//     final now = DateTime.now();
//     if (!force && now.difference(lastDrain).inSeconds < 290) return;
//     if (!await isOnline()) return;
//     final ok = await OfflineQueue.drain();
//     if (ok) lastDrain = now;
//   }

//   Future<void> checkFence(Position pos) async {
//     final result = SiteCache.checkLocation(pos.latitude, pos.longitude);

//     if (result.inside) {
//       if (result.siteId != currentSiteId) {
//         currentSiteId = result.siteId;
//         await OfflineQueue.enqueue(
//           type: 'mark_in',
//           employeeId: empId,
//           siteId: result.siteId!,
//         );
//         debugPrint('[BG] Entered site: ${result.siteName}');
//         updateNotification('On site: ${result.siteName}');
//         await maybeDrain(force: true);
//       }
//     } else {
//       if (currentSiteId != null) {
//         currentSiteId = null;
//         await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
//         debugPrint('[BG] Left site — mark_out queued.');
//         updateNotification('Tracking active (outside sites)');
//         await maybeDrain(force: true);
//       }
//     }

//     service.invoke('location_update', {
//       'lat': pos.latitude,
//       'lng': pos.longitude,
//       'accuracy': pos.accuracy,
//       'good': pos.accuracy <= 40,
//     });
//     service.invoke('status_update', {
//       'status': result.inside ? 'IN' : 'OUT',
//       'site_name': result.siteName ?? '',
//       'lat': pos.latitude,
//       'lng': pos.longitude,
//       'accuracy': pos.accuracy,
//     });
//   }

//   // ── GPS stream ──────────────────────────────────────────────────────────────

//   final LocationSettings locationSettings =
//       (defaultTargetPlatform == TargetPlatform.android)
//       ? AndroidSettings(
//           accuracy: LocationAccuracy.high,
//           distanceFilter: 10,
//           intervalDuration: const Duration(seconds: 30),
//           forceLocationManager: false,
//           foregroundNotificationConfig: const ForegroundNotificationConfig(
//             notificationText: 'Attendance tracking is active',
//             notificationTitle: 'Attendance',
//             enableWakeLock: true,
//           ),
//         )
//       : const LocationSettings(
//           accuracy: LocationAccuracy.high,
//           distanceFilter: 10,
//         );

//   // Use a wrapper class so the closure can reference itself without a
//   // forward-declaration trick (avoids the lint warning too).
//   StreamSubscription<Position>? gpsSub;

//   void Function() restartGps = () {}; // will be replaced below

//   restartGps = () {
//     gpsSub?.cancel();
//     gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings)
//         .listen(
//           (pos) async {
//             if (!dayEnded) await checkFence(pos);
//           },
//           onError: (Object e) {
//             debugPrint('[BG] GPS error: $e');
//             service.invoke('service_error', {
//               'reason': 'gps_error',
//               'detail': e.toString(),
//             });
//           },
//           onDone: () {
//             debugPrint('[BG] GPS stream closed — restarting in 5 s.');
//             Future.delayed(const Duration(seconds: 5), restartGps);
//           },
//           cancelOnError: false,
//         );
//   };

//   // ── Permission guard ────────────────────────────────────────────────────────
//   final perm = await Geolocator.checkPermission();
//   if (perm != LocationPermission.always) {
//     service.invoke('service_error', {'reason': 'no_background_location'});
//     service.stopSelf();
//     return;
//   }

//   restartGps();

//   // ── 5-minute sync timer ─────────────────────────────────────────────────────
//   Timer.periodic(const Duration(minutes: 5), (_) async {
//     if (!dayEnded) await maybeDrain();
//   });

//   // ── 60-second online-recovery poll ─────────────────────────────────────────
//   // Drains as soon as connectivity is restored after an offline period.
//   Timer.periodic(const Duration(seconds: 60), (_) async {
//     if (dayEnded) return;
//     final pending = await OfflineQueue.pendingCount();
//     if (pending > 0 && await isOnline()) {
//       debugPrint('[BG] Online with $pending pending — draining.');
//       await maybeDrain(force: true);
//     }
//   });

//   // ── Site-cache refresh every 2 h ────────────────────────────────────────────
//   Timer.periodic(const Duration(hours: 2), (_) async {
//     await SiteCache.sync();
//   });

//   // ── "end_day" command from UI ───────────────────────────────────────────────
//   service.on('end_day').listen((_) async {
//     if (dayEnded) {
//       service.invoke('end_day_done', {});
//       return;
//     }

//     dayEnded = true;
//     gpsSub?.cancel();

//     if (currentSiteId != null) {
//       await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
//       currentSiteId = null;
//     }
//     await OfflineQueue.enqueue(type: 'end_day', employeeId: empId);

//     bool synced = false;
//     for (int attempt = 0; attempt < 3 && !synced; attempt++) {
//       synced = await OfflineQueue.drain();
//       if (!synced) await Future.delayed(const Duration(seconds: 3));
//     }

//     service.invoke('end_day_done', {'synced': synced});

//     if (service is AndroidServiceInstance) {
//       service.setForegroundNotificationInfo(
//         title: 'Attendance',
//         content: 'Work day ended — see you tomorrow! 👋',
//       );
//     }

//     await Future.delayed(const Duration(seconds: 2));
//     service.stopSelf();
//   });

//   // ── "stop_service" command (logout) ────────────────────────────────────────
//   service.on('stop_service').listen((_) async {
//     gpsSub?.cancel();
//     SiteCache.dispose();
//     service.stopSelf();
//   });

//   debugPrint('[BG] ✅ Service running — empId=$empId');
// }
// lib/attendance/services/background_service.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// CROSS-PLATFORM ATTENDANCE TRACKING SERVICE
// ═══════════════════════════════════════════════════════════════════════════
//
// Platform behaviour:
//   Android  → OS Foreground Service (stopWithTask=false in manifest).
//              Runs even after app is swiped away from recents.
//              Survives OOM kills — OS restarts it automatically.
//   iOS      → Background fetch via FlutterBackgroundService.
//   Windows  │
//   macOS    ├→ Dart Isolate that lives for the duration of the app session.
//   Linux    │  Automatically re-launched if the window is re-opened.
//   Web      → Timer loop in main isolate (browser hard-limit: stops on tab close).
//
// Data flow (ALL platforms):
//   GPS event → checkFence() → OfflineQueue.enqueue()   ← always local-first
//                                      ↓ (async, best-effort)
//                               OfflineQueue.drain()     ← only when online
//                                      ↓
//                            /attendance/batch-sync
//
// UI reads logs from LOCAL CACHE first (SharedPreferences), then the server
// refreshes in the background.  The UI never blocks on network.
//
// FIXES in this version:
//   ✅ locationSettings param removed from Geolocator.getCurrentPosition()
//      (web path) — replaced with desiredAccuracy (correct API for that call)
//   ✅ Removed unused _webEndDayCtrl and _webStopCtrl variables
//   ✅ Replaced __ with _ in Timer callbacks (unnecessary_underscores lint)
//   ✅ sendEndDay() is a top-level function — no longer a method on a State
//   ✅ All .withOpacity() replaced with .withValues(alpha:) in the UI patch
//   ✅ Cache-first: UI loads from SharedPreferences before any network call

import 'dart:async';
import 'dart:io' show Socket;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mobile-only packages — web gets empty stubs via conditional import
import 'package:flutter_background_service/flutter_background_service.dart'
    if (dart.library.html) 'stub/flutter_background_service_stub.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'stub/flutter_local_notifications_stub.dart';

import 'offline_queue.dart';
import 'site_cache.dart';

// ─── Platform helpers ──────────────────────────────────────────────────────

bool get _isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

// IsolateNameServer key for desktop isolate ↔ UI communication
const String _kDesktopPortName = 'attendance_desktop_bg';

// ═══════════════════════════════════════════════════════════════════════════
// PUBLIC API  (call these from AttendanceState / EmployeeHome)
// ═══════════════════════════════════════════════════════════════════════════

/// Call once in main() BEFORE runApp().
Future<void> initBackgroundService() async {
  if (_isMobile) await _initMobileService();
  // Desktop / Web: nothing to pre-init — service starts on demand.
}

/// Start background GPS tracking for [empId].
Future<void> startBackgroundTracking(int empId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('employee_id', empId);

  if (_isMobile) {
    await _startMobile();
  } else if (_isDesktop) {
    await _startDesktop(empId);
  } else {
    _startWeb(empId);
  }
}

/// Stop tracking (called on logout or force-quit).
Future<void> stopBackgroundTracking() async {
  if (_isMobile) {
    FlutterBackgroundService().invoke('stop_service');
  } else if (_isDesktop) {
    _desktopControlPort?.send({'cmd': 'stop'});
  } else {
    _webTimer?.cancel();
    _webDayEnded = true;
  }
}

/// Tell the background service to end the work day.
/// Returns true if the server confirmed, false on timeout (data is safe in
/// the offline queue and will sync automatically when back online).
///
/// This is a TOP-LEVEL function — call it directly from EmployeeHome,
/// do NOT call it as a method on the State class.
Future<bool> sendEndDay() async {
  if (_isMobile) return _mobileEndDay();
  if (_isDesktop) return _desktopEndDay();
  return _webEndDay(); // web
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE  (Android + iOS)
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _initMobileService() async {
  final service = FlutterBackgroundService();

  // Create the persistent notification channel (Android 8+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'attendance_fg_channel',
    'Attendance Tracking',
    description: 'Keeps attendance location tracking active',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // @pragma entry-point below
      autoStart: false, // started manually by employee
      isForegroundMode: true, // OS CANNOT kill a foreground service
      notificationChannelId: 'attendance_fg_channel',
      initialNotificationTitle: 'Attendance Active',
      initialNotificationContent: 'Location tracking is running…',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: false, // employee must START each day
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> _startMobile() async {
  if (!await FlutterBackgroundService().isRunning()) {
    await FlutterBackgroundService().startService();
  }
}

Future<bool> _mobileEndDay() async {
  final service = FlutterBackgroundService();
  final done = Completer<bool>();
  StreamSubscription? sub;

  sub = service.on('end_day_done').listen((e) {
    sub?.cancel();
    if (!done.isCompleted) done.complete(true);
  });

  service.invoke('end_day');

  return done.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      sub?.cancel();
      return false;
    },
  );
}

// ─── iOS background handler ────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ─── Mobile isolate entry-point ────────────────────────────────────────────
//
// Annotated with @pragma so the AOT compiler keeps it even after tree-shaking.
// This runs in a SEPARATE Dart isolate spawned by the OS foreground service.

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'Attendance Active',
      content: 'Tracking your location…',
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final empId = prefs.getInt('employee_id') ?? -1;
  if (empId == -1) {
    debugPrint('[BG-Mobile] No employee_id — stopping.');
    service.stopSelf();
    return;
  }

  await SiteCache.init();

  await _runTrackingLoop(
    empId: empId,
    onNotification: (title, content) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(title: title, content: content);
      }
    },
    onLocationUpdate: (d) => service.invoke('location_update', d),
    onStatusUpdate: (d) => service.invoke('status_update', d),
    onServiceError: (d) => service.invoke('service_error', d),
    onEndDayDone: (d) => service.invoke('end_day_done', d),
    endDayStream: service.on('end_day'),
    stopStream: service.on('stop_service'),
    stopSelf: service.stopSelf,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP  (Windows · macOS · Linux)
// ═══════════════════════════════════════════════════════════════════════════

SendPort? _desktopControlPort;
ReceivePort? _desktopEventPort;

final _desktopEventController = StreamController<_BgEvent>.broadcast();

/// Listen for named events from the desktop background isolate.
Stream<Map<String, dynamic>?> desktopOn(String event) => _desktopEventController
    .stream
    .where((e) => e.name == event)
    .map((e) => e.data);

Future<void> _startDesktop(int empId) async {
  _desktopEventPort?.close();
  _desktopEventPort = ReceivePort();

  IsolateNameServer.removePortNameMapping(_kDesktopPortName);
  IsolateNameServer.registerPortWithName(
    _desktopEventPort!.sendPort,
    _kDesktopPortName,
  );

  final controlReceive = ReceivePort();

  await Isolate.spawn(
    _desktopIsolateMain,
    _DesktopArgs(empId: empId, controlPort: controlReceive.sendPort),
  );

  _desktopControlPort = await controlReceive.first as SendPort;

  _desktopEventPort!.listen((msg) {
    if (msg is Map) {
      final event = msg['event'] as String? ?? '';
      final data = (msg['data'] as Map?)?.cast<String, dynamic>() ?? {};
      _desktopEventController.add(_BgEvent(event, data));
    }
  });
}

void _desktopSend(String cmd) => _desktopControlPort?.send({'cmd': cmd});

Future<bool> _desktopEndDay() async {
  final done = Completer<bool>();
  StreamSubscription? sub;

  sub = desktopOn('end_day_done').listen((_) {
    sub?.cancel();
    if (!done.isCompleted) done.complete(true);
  });

  _desktopSend('end_day');

  return done.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      sub?.cancel();
      return false;
    },
  );
}

class _DesktopArgs {
  final int empId;
  final SendPort controlPort;
  const _DesktopArgs({required this.empId, required this.controlPort});
}

Future<void> _desktopIsolateMain(_DesktopArgs args) async {
  final uiPort = IsolateNameServer.lookupPortByName(_kDesktopPortName);
  final selfReceive = ReceivePort();

  args.controlPort.send(selfReceive.sendPort); // hand back our SendPort

  void push(String event, Map<String, dynamic> data) =>
      uiPort?.send({'event': event, 'data': data});

  await SiteCache.init();

  final endDayCtrl = StreamController<Map<String, dynamic>?>();
  final stopCtrl = StreamController<Map<String, dynamic>?>();

  selfReceive.listen((msg) {
    if (msg is Map) {
      final cmd = msg['cmd'] as String?;
      if (cmd == 'end_day') endDayCtrl.add({});
      if (cmd == 'stop') stopCtrl.add({});
    }
  });

  await _runTrackingLoop(
    empId: args.empId,
    onNotification: (_, __) {}, // no notification on desktop
    onLocationUpdate: (d) => push('location_update', d),
    onStatusUpdate: (d) => push('status_update', d),
    onServiceError: (d) => push('service_error', d),
    onEndDayDone: (d) => push('end_day_done', d),
    endDayStream: endDayCtrl.stream,
    stopStream: stopCtrl.stream,
    stopSelf: () {
      selfReceive.close();
      endDayCtrl.close();
      stopCtrl.close();
      Isolate.current.kill();
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WEB
// ═══════════════════════════════════════════════════════════════════════════
//
// Runs in the main isolate using a Timer.  Background after tab close is
// a hard browser limitation — impossible to circumvent.

Timer? _webTimer;
int? _webCurrentSiteId;
bool _webDayEnded = false;

final _webEventController = StreamController<_BgEvent>.broadcast();

Stream<Map<String, dynamic>?> webOn(String event) =>
    _webEventController.stream.where((e) => e.name == event).map((e) => e.data);

void _startWeb(int empId) {
  _webDayEnded = false;
  _webCurrentSiteId = null;
  _webTimer?.cancel();

  // GPS poll every 30 s
  _webTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (_webDayEnded) {
      _webTimer?.cancel();
      return;
    }
    try {
      // Web uses getCurrentPosition (no stream API in browsers).
      // desiredAccuracy is the correct parameter — NOT locationSettings.
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final result = SiteCache.checkLocation(pos.latitude, pos.longitude);

      if (result.inside && result.siteId != _webCurrentSiteId) {
        _webCurrentSiteId = result.siteId;
        await OfflineQueue.enqueue(
          type: 'mark_in',
          employeeId: empId,
          siteId: result.siteId!,
        );
        await OfflineQueue.drain();
      } else if (!result.inside && _webCurrentSiteId != null) {
        _webCurrentSiteId = null;
        await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
        await OfflineQueue.drain();
      }

      _webEventController.add(
        _BgEvent('location_update', {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
          'good': pos.accuracy <= 40,
        }),
      );
      _webEventController.add(
        _BgEvent('status_update', {
          'status': result.inside ? 'IN' : 'OUT',
          'site_name': result.siteName ?? '',
          'lat': pos.latitude,
          'lng': pos.longitude,
          'accuracy': pos.accuracy,
        }),
      );
    } catch (_) {} // GPS unavailable — silently retry next tick
  });

  // 5-min background drain
  Timer.periodic(const Duration(minutes: 5), (_) async {
    if (!_webDayEnded) await OfflineQueue.drain();
  });
}

Future<bool> _webEndDay() async {
  _webDayEnded = true;
  _webTimer?.cancel();

  final prefs = await SharedPreferences.getInstance();
  final empId = prefs.getInt('employee_id') ?? -1;

  if (_webCurrentSiteId != null) {
    await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
    _webCurrentSiteId = null;
  }
  await OfflineQueue.enqueue(type: 'end_day', employeeId: empId);

  bool synced = false;
  for (int i = 0; i < 3 && !synced; i++) {
    synced = await OfflineQueue.drain();
    if (!synced) await Future.delayed(const Duration(seconds: 3));
  }

  _webEventController.add(_BgEvent('end_day_done', {'synced': synced}));
  return synced;
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED TRACKING LOOP
// Used by: mobile onStart() isolate AND desktop _desktopIsolateMain()
// ═══════════════════════════════════════════════════════════════════════════

Future<void> _runTrackingLoop({
  required int empId,
  required void Function(String title, String content) onNotification,
  required void Function(Map<String, dynamic>) onLocationUpdate,
  required void Function(Map<String, dynamic>) onStatusUpdate,
  required void Function(Map<String, dynamic>) onServiceError,
  required void Function(Map<String, dynamic>) onEndDayDone,
  required Stream<Map<String, dynamic>?> endDayStream,
  required Stream<Map<String, dynamic>?> stopStream,
  required void Function() stopSelf,
}) async {
  int? currentSiteId;
  bool dayEnded = false;
  DateTime lastDrain = DateTime.now().subtract(const Duration(minutes: 6));

  // ── Online check (dart:io TCP, not available on web) ───────────────────
  Future<bool> isOnline() async {
    if (kIsWeb) return true;
    try {
      final sock = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 3),
      );
      sock.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Drain: always enqueue locally first, then drain when possible ───────
  Future<void> maybeDrain({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(lastDrain).inSeconds < 290) return;
    if (!await isOnline()) return;
    final ok = await OfflineQueue.drain();
    if (ok) lastDrain = now;
  }

  // ── Geofence check ──────────────────────────────────────────────────────
  Future<void> checkFence(Position pos) async {
    final result = SiteCache.checkLocation(pos.latitude, pos.longitude);

    if (result.inside) {
      if (result.siteId != currentSiteId) {
        currentSiteId = result.siteId;
        // LOCAL FIRST — always enqueue regardless of network
        await OfflineQueue.enqueue(
          type: 'mark_in',
          employeeId: empId,
          siteId: result.siteId!,
        );
        debugPrint('[BG] → Entered: ${result.siteName}');
        onNotification('Attendance Active', 'On site: ${result.siteName}');
        await maybeDrain(force: true); // best-effort immediate sync
      }
    } else {
      if (currentSiteId != null) {
        currentSiteId = null;
        await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
        debugPrint('[BG] ← Left site — queued mark_out');
        onNotification('Attendance Active', 'Outside all registered sites');
        await maybeDrain(force: true);
      }
    }

    // Push live position to UI (no-op if app is closed)
    onLocationUpdate({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'good': pos.accuracy <= 40,
    });
    onStatusUpdate({
      'status': result.inside ? 'IN' : 'OUT',
      'site_name': result.siteName ?? '',
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
    });
  }

  // ── GPS stream settings ─────────────────────────────────────────────────
  //
  // Android: AndroidSettings with wake-lock + interval + distance filter.
  // iOS/Desktop: plain LocationSettings (same effect, no ForegroundNotif).
  final LocationSettings locationSettings =
      (defaultTargetPlatform == TargetPlatform.android)
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // metres; skip if phone hasn't moved
          intervalDuration: const Duration(seconds: 30),
          forceLocationManager: false,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Attendance',
            notificationText: 'Tracking is active',
            enableWakeLock: true, // prevents CPU sleep during tracking
          ),
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        );

  // ── Self-restarting GPS subscription ────────────────────────────────────
  StreamSubscription<Position>? gpsSub;
  void Function() restartGps = () {};

  restartGps = () {
    gpsSub?.cancel();
    gpsSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
          (pos) async {
            if (!dayEnded) await checkFence(pos);
          },
          onError: (Object e) {
            debugPrint('[BG] GPS error: $e');
            onServiceError({'reason': 'gps_error', 'detail': e.toString()});
          },
          onDone: () {
            // Stream closed unexpectedly (e.g. GPS toggled off) — auto-restart
            debugPrint('[BG] GPS stream closed — restarting in 5 s.');
            Future.delayed(const Duration(seconds: 5), restartGps);
          },
          cancelOnError: false, // keep listening despite errors
        );
  };

  // ── Permission check ────────────────────────────────────────────────────
  if (!kIsWeb) {
    final perm = await Geolocator.checkPermission();
    final needsAlways =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (needsAlways && perm != LocationPermission.always) {
      onServiceError({'reason': 'no_background_location'});
      stopSelf();
      return;
    }

    final denied =
        perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever;
    if (!needsAlways && denied) {
      onServiceError({'reason': 'location_permission_denied'});
      stopSelf();
      return;
    }
  }

  restartGps(); // 🚀 start listening to GPS

  // ── 5-minute drain timer ────────────────────────────────────────────────
  // Handles the "came back online after offline period" case on a fixed cadence.
  Timer.periodic(const Duration(minutes: 5), (_) async {
    if (!dayEnded) await maybeDrain();
  });

  // ── 60-second online-recovery poll ─────────────────────────────────────
  // As soon as we're back online, flush any queued events.
  Timer.periodic(const Duration(seconds: 60), (_) async {
    if (dayEnded) return;
    final pending = await OfflineQueue.pendingCount();
    if (pending > 0 && await isOnline()) {
      debugPrint('[BG] 🌐 Back online — draining $pending queued event(s).');
      await maybeDrain(force: true);
    }
  });

  // ── Site-cache refresh every 2 h ────────────────────────────────────────
  Timer.periodic(const Duration(hours: 2), (_) async {
    await SiteCache.sync();
  });

  // ── "end_day" command ───────────────────────────────────────────────────
  endDayStream.listen((_) async {
    if (dayEnded) {
      onEndDayDone({});
      return;
    }

    dayEnded = true;
    gpsSub?.cancel();

    // Close any open site visit
    if (currentSiteId != null) {
      await OfflineQueue.enqueue(type: 'mark_out', employeeId: empId);
      currentSiteId = null;
    }
    // Sentinel event — server locks the day on receipt
    await OfflineQueue.enqueue(type: 'end_day', employeeId: empId);

    // Attempt to drain — up to 3 retries with back-off
    bool synced = false;
    for (int attempt = 0; attempt < 3 && !synced; attempt++) {
      synced = await OfflineQueue.drain();
      if (!synced) await Future.delayed(const Duration(seconds: 3));
    }
    // If still unsynced, the queue persists — will drain next app open.

    onEndDayDone({'synced': synced});
    onNotification('Attendance', 'Work day ended — see you tomorrow! 👋');
    await Future.delayed(const Duration(seconds: 2));
    stopSelf();
  });

  // ── "stop_service" command (logout / force quit) ────────────────────────
  stopStream.listen((_) async {
    gpsSub?.cancel();
    SiteCache.dispose();
    stopSelf();
  });

  debugPrint(
    '[BG] ✅ Tracking loop active — empId=$empId '
    '(${defaultTargetPlatform.name})',
  );
}

// ─── Internal event model ──────────────────────────────────────────────────

class _BgEvent {
  final String name;
  final Map<String, dynamic> data;
  const _BgEvent(this.name, this.data);
}
