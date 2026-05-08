// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart' as p;
// import 'package:flutter/foundation.dart';
// import 'api_service.dart';
// import 'site_cache.dart';

// const String kChannelId = 'attendance_tracking';
// const String kNotifTitle = 'Attendance Tracking';
// const int kNotifId = 888;

// // ─────────────────────────────────────────────────────────────────────────────
// // LocalDB — SQLite event queue
// //
// // Every geofence transition is written here first, then flushed to server.
// // Survives network outages and process kills.
// // ─────────────────────────────────────────────────────────────────────────────
// class LocalDB {
//   static Database? _db;

//   static Future<Database> get db async {
//     _db ??= await openDatabase(
//       p.join(await getDatabasesPath(), 'attendance_local.db'),
//       version: 2,
//       onCreate: (db, _) async {
//         await db.execute('''
//           CREATE TABLE attendance_events (
//             id          INTEGER PRIMARY KEY AUTOINCREMENT,
//             type        TEXT    NOT NULL,
//             employee_id INTEGER NOT NULL,
//             site_id     INTEGER,
//             session_id  INTEGER,
//             timestamp   TEXT    NOT NULL,
//             synced      INTEGER NOT NULL DEFAULT 0
//           )
//         ''');
//       },
//       onUpgrade: (db, oldV, newV) async {
//         if (oldV < 2) {
//           // Add session_id column if upgrading from v1
//           await db.execute(
//             'ALTER TABLE attendance_events ADD COLUMN session_id INTEGER',
//           );
//         }
//       },
//     );
//     return _db!;
//   }

//   static Future<void> writeEvent({
//     required String type,
//     required int employeeId,
//     int? siteId,
//     int? sessionId,
//   }) async {
//     final ts = DateTime.now().toIso8601String();
//     await (await db).insert('attendance_events', {
//       'type': type,
//       'employee_id': employeeId,
//       'site_id': siteId,
//       'session_id': sessionId,
//       'timestamp': ts,
//       'synced': 0,
//     });
//     print('[LocalDB] ✍ $type emp=$employeeId site=$siteId session=$sessionId');
//   }

//   static Future<List<Map<String, dynamic>>> pendingEvents() async => (await db)
//       .query('attendance_events', where: 'synced = 0', orderBy: 'id ASC');

//   static Future<void> markSynced(List<int> ids) async {
//     if (ids.isEmpty) return;
//     await (await db).update(
//       'attendance_events',
//       {'synced': 1},
//       where: 'id IN (${List.filled(ids.length, '?').join(',')})',
//       whereArgs: ids,
//     );
//   }

//   static Future<void> cleanup() async {
//     final cutoff = DateTime.now()
//         .subtract(const Duration(days: 3))
//         .toIso8601String();
//     await (await db).delete(
//       'attendance_events',
//       where: 'synced = 1 AND timestamp < ?',
//       whereArgs: [cutoff],
//     );
//   }

//   static Future<void> clearAll() async {
//     await (await db).delete('attendance_events');
//     print('[LocalDB] 🗑 Cleared all events');
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SyncWorker — flush pending events to server
// // ─────────────────────────────────────────────────────────────────────────────
// class SyncWorker {
//   static bool _running = false;

//   static Future<void> flush() async {
//     if (_running) return;
//     _running = true;
//     try {
//       final events = await LocalDB.pendingEvents();
//       if (events.isEmpty) return;
//       print('[Sync] flushing ${events.length} event(s)');

//       final payload = events
//           .map(
//             (e) => {
//               'type': e['type'],
//               'employee_id': e['employee_id'],
//               'site_id': e['site_id'],
//               'session_id': e['session_id'],
//               'timestamp': e['timestamp'],
//             },
//           )
//           .toList();

//       try {
//         await ApiService.batchSync(payload);
//         await LocalDB.markSynced(events.map((e) => e['id'] as int).toList());
//         await LocalDB.cleanup();
//         print('[Sync] ✅ batch synced ${events.length}');
//       } catch (_) {
//         // Fallback: one by one
//         final synced = <int>[];
//         for (final e in events) {
//           try {
//             switch (e['type'] as String) {
//               case 'mark_in':
//                 await ApiService.markIn(
//                   e['employee_id'] as int,
//                   e['site_id'] as int,
//                   sessionId: e['session_id'] as int?,
//                 );
//                 break;
//               case 'mark_out':
//                 await ApiService.markOut(
//                   e['employee_id'] as int,
//                   sessionId: e['session_id'] as int?,
//                 );
//                 break;
//               case 'end_session':
//               case 'force_end_session':
//                 await ApiService.endSession(
//                   e['employee_id'] as int,
//                   e['session_id'] as int?,
//                   reason: e['type'] == 'force_end_session'
//                       ? 'logout'
//                       : 'manual_end',
//                 );
//                 break;
//             }
//             synced.add(e['id'] as int);
//           } catch (err) {
//             print('[Sync] ⚠ event ${e['id']} failed: $err');
//           }
//         }
//         await LocalDB.markSynced(synced);
//         if (synced.isNotEmpty) await LocalDB.cleanup();
//         print('[Sync] fallback: ${synced.length}/${events.length}');
//       }
//     } finally {
//       _running = false;
//     }
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // initBackgroundService
// // ─────────────────────────────────────────────────────────────────────────────
// Future<void> initBackgroundService() async {
//   final service = FlutterBackgroundService();
//   final notifPlugin = FlutterLocalNotificationsPlugin();

//   await notifPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(
//         const AndroidNotificationChannel(
//           kChannelId,
//           'Attendance Tracking',
//           description: 'Keeps GPS tracking running in the background',
//           importance: Importance.low,
//         ),
//       );

//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onServiceStart,
//       isForegroundMode: true,
//       autoStartOnBoot: false,
//       notificationChannelId: kChannelId,
//       initialNotificationTitle: kNotifTitle,
//       initialNotificationContent: 'Tracking active — tap to open',
//       foregroundServiceNotificationId: kNotifId,
//       foregroundServiceTypes: [AndroidForegroundType.location],
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: false,
//       onForeground: onServiceStart,
//       onBackground: onIosBackground,
//     ),
//   );
// }

// // ── iOS background handler ────────────────────────────────────────────────────
// // iOS calls this periodically (~15 min). We use it to flush any pending syncs.
// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();
//   try {
//     await SyncWorker.flush();
//   } catch (_) {}
//   return true;
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // onServiceStart — main service entry point (Android foreground + iOS foreground)
// // ─────────────────────────────────────────────────────────────────────────────
// @pragma('vm:entry-point')
// void onServiceStart(ServiceInstance service) async {
//   DartPluginRegistrant.ensureInitialized();

//   // ── Notification helper (Android only) ───────────────────────────────────
//   final notifPlugin = FlutterLocalNotificationsPlugin();
//   if (defaultTargetPlatform == TargetPlatform.android) {
//     await notifPlugin.initialize(
//       const InitializationSettings(
//         android: AndroidInitializationSettings('@mipmap/ic_launcher'),
//       ),
//     );
//   }

//   void updateNotif(String body) {
//     if (defaultTargetPlatform != TargetPlatform.android) return;
//     notifPlugin.show(
//       kNotifId,
//       kNotifTitle,
//       body,
//       const NotificationDetails(
//         android: AndroidNotificationDetails(
//           kChannelId,
//           kNotifTitle,
//           ongoing: true,
//           importance: Importance.low,
//           priority: Priority.low,
//           playSound: false,
//         ),
//       ),
//     );
//   }

//   print('[Service] ▶ STARTED');

//   final prefs = await SharedPreferences.getInstance();
//   final int? empId = prefs.getInt('employee_id');
//   int? sessionId = prefs.getInt('session_id_$empId');
//   bool _forceNextCheck = true; // force geofence check on fresh service start
//   print('[Service] BOOT empId=$empId sessionId=$sessionId');

//   if (empId == null) {
//     print('[Service] No employee_id — stopping');
//     service.stopSelf();
//     return;
//   }

//   // ── Background location guard (Android only) ──────────────────────────────
//   if (defaultTargetPlatform == TargetPlatform.android) {
//     if (!await Permission.locationAlways.isGranted) {
//       updateNotif('Background location permission required');
//       service.invoke('service_error', {'reason': 'no_background_location'});
//       service.stopSelf();
//       return;
//     }
//   }

//   await SiteCache.init();
//   int? currentSiteId = prefs.getInt('current_site_id_$empId');
//   String _workDate = _todayStr();
//   _fire(SyncWorker.flush());

//   // ── Timers ─────────────────────────────────────────────────────────────────
//   final syncTimer = Timer.periodic(
//     const Duration(minutes: 1),
//     (_) => _fire(SyncWorker.flush()),
//   );
//   final siteRefreshTimer = Timer.periodic(
//     const Duration(minutes: 30),
//     (_) => _fire(SiteCache.sync()),
//   );

//   // ── Clean shutdown helper ─────────────────────────────────────────────────
//   service.on('set_session').listen((e) async {
//     if (e == null) return;
//     final newId = e['session_id'] as int?;
//     if (newId != null) {
//       sessionId = newId;
//       currentSiteId = null;
//       _forceNextCheck = true;
//       await prefs.setInt('session_id_$empId', newId);
//       await prefs.remove('current_site_id_$empId');
//       print('[Service] 🔑 session_id updated → $newId, forceNextCheck=true');
//     }
//   });
//   Future<void> shutdown({
//     required bool writeEndSession,
//     required String endReason, // 'manual_end' | 'logout'
//     required bool clearAllData,
//     required String doneEvent,
//   }) async {
//     print('[Service] 🛑 shutdown: $endReason clearAll=$clearAllData');

//     // 1. Close open site visit
//     if (currentSiteId != null) {
//       await LocalDB.writeEvent(
//         type: 'mark_out',
//         employeeId: empId,
//         siteId: currentSiteId,
//         sessionId: sessionId,
//       );
//       currentSiteId = null;
//       await prefs.remove('current_site_id_$empId');
//     }

//     // 2. Close the tracking session on server
//     if (writeEndSession) {
//       await LocalDB.writeEvent(
//         type: endReason == 'logout' ? 'force_end_session' : 'end_session',
//         employeeId: empId,
//         sessionId: sessionId,
//       );
//     }

//     // 3. Final sync attempt
//     await SyncWorker.flush();

//     // 4. Optionally wipe all local data (on logout)
//     if (clearAllData) {
//       await SiteCache.clear();
//       await LocalDB.clearAll();
//       await prefs.remove('employee_id');
//       await prefs.remove('current_site_id_$empId');
//       await prefs.remove('tracking_active_$empId');
//       await prefs.remove('session_id_$empId');
//       await prefs.remove('session_start_$empId');
//       await prefs.remove('session_count_$empId');
//     } else {
//       await prefs.setBool('tracking_active_$empId', false);
//     }

//     syncTimer.cancel();
//     siteRefreshTimer.cancel();
//     SiteCache.dispose();
//     await notifPlugin.cancel(kNotifId);
//     service.invoke(doneEvent, {});
//     service.stopSelf();
//     print('[Service] ■ STOPPED ($endReason)');
//   }

//   // ── END SESSION event (employee pressed END) ──────────────────────────────
//   // Includes the "still on site?" answer from the UI dialog
//   service.on('end_session').listen((e) async {
//     final stillOnSite = e?['still_on_site'] as bool? ?? false;

//     if (stillOnSite && currentSiteId != null) {
//       // Employee said they're still physically on site.
//       // Don't mark_out yet — the row stays open.
//       // It will be closed by the next START's first GPS fix or by a future mark_out.
//       print('[Service] Still on site — keeping row open, stopping GPS only');
//       await LocalDB.writeEvent(
//         type: 'end_session',
//         employeeId: empId,
//         sessionId: sessionId,
//       );
//       await SyncWorker.flush();
//       await prefs.setBool('tracking_active_$empId', false);
//       // Keep current_site_id so next session knows it was open
//       syncTimer.cancel();
//       siteRefreshTimer.cancel();
//       SiteCache.dispose();
//       await notifPlugin.cancel(kNotifId);
//       service.invoke('end_session_done', {});
//       service.stopSelf();
//     } else {
//       // Employee left the site (or wasn't on one) — mark OUT before stopping
//       await shutdown(
//         writeEndSession: true,
//         endReason: 'manual_end',
//         clearAllData: false,
//         doneEvent: 'end_session_done',
//       );
//     }
//   });

//   // ── FORCE STOP event (logout — admin or user) ─────────────────────────────
//   service.on('force_stop').listen((_) async {
//     await shutdown(
//       writeEndSession: true,
//       endReason: 'logout',
//       clearAllData: true, // full wipe on logout
//       doneEvent: 'force_stop_done',
//     );
//   });

//   // ── Legacy stop_service ───────────────────────────────────────────────────
//   service.on('stop_service').listen((_) async {
//     await shutdown(
//       writeEndSession: false,
//       endReason: 'manual_end',
//       clearAllData: false,
//       doneEvent: 'stop_service_done',
//     );
//   });

//   // ── GPS smoothing (weighted moving average, window = 3) ───────────────────
//   final List<({double lat, double lng})> _hist = [];

//   ({double lat, double lng}) _smooth(Position pos) {
//     _hist.add((lat: pos.latitude, lng: pos.longitude));
//     if (_hist.length > 3) _hist.removeAt(0);
//     double ls = 0, ns = 0, ws = 0;
//     for (int i = 0; i < _hist.length; i++) {
//       final w = (i + 1).toDouble();
//       ls += _hist[i].lat * w;
//       ns += _hist[i].lng * w;
//       ws += w;
//     }
//     return (lat: ls / ws, lng: ns / ws);
//   }

//   double? _lastLat, _lastLng;
//   bool _movedEnough(double lat, double lng) {
//     if (_lastLat == null) return true;
//     return Geolocator.distanceBetween(_lastLat!, _lastLng!, lat, lng) > 8;
//   }

//   // Warm-up with last known position
//   try {
//     final last = await Geolocator.getLastKnownPosition();
//     if (last != null) {
//       service.invoke('location_update', {
//         'lat': last.latitude,
//         'lng': last.longitude,
//         'accuracy': last.accuracy,
//         'good': last.accuracy <= 80,
//       });
//     }
//   } catch (_) {}

//   // On resume — if there was an open site row from previous session,
//   // check if we're still inside. If not, mark_out immediately.
//   if (currentSiteId != null) {
//     print('[Service] Resuming — checking if still inside site $currentSiteId');
//     // Will be resolved on first GPS fix below
//   }

//   // ── Location settings (platform-specific) ─────────────────────────────────
//   LocationSettings locationSettings;
//   if (defaultTargetPlatform == TargetPlatform.iOS) {
//     locationSettings = AppleSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       activityType: ActivityType.otherNavigation,
//       distanceFilter: 0,
//       pauseLocationUpdatesAutomatically: false,
//       showBackgroundLocationIndicator: true,
//       allowBackgroundLocationUpdates: true,
//     );
//   } else {
//     locationSettings = AndroidSettings(
//       accuracy: LocationAccuracy.bestForNavigation,
//       distanceFilter: 0,
//       intervalDuration: const Duration(seconds: 3),
//       foregroundNotificationConfig: const ForegroundNotificationConfig(
//         notificationChannelName: 'Attendance Tracking',
//         notificationText: 'Location tracking active',
//         notificationTitle: kNotifTitle,
//         enableWakeLock: true,
//         setOngoing: true,
//       ),
//     );
//   }

//   // ── GPS stream ────────────────────────────────────────────────────────────
//   Geolocator.getPositionStream(locationSettings: locationSettings).listen(
//     (Position pos) async {
//       if (pos.accuracy > 150) return; // discard very noisy fixes

//       final s = _smooth(pos);

//       // ── Midnight rollover ─────────────────────────────────────────────────
//       final today = _todayStr();
//       if (today != _workDate) {
//         print('[Service] 🕛 Midnight rollover');
//         if (currentSiteId != null) {
//           await LocalDB.writeEvent(
//             type: 'mark_out',
//             employeeId: empId,
//             siteId: currentSiteId,
//             sessionId: sessionId,
//           );
//           currentSiteId = null;
//           await prefs.remove('current_site_id_$empId');
//         }
//         await LocalDB.writeEvent(
//           type: 'end_session',
//           employeeId: empId,
//           sessionId: sessionId,
//         );
//         _hist.clear();
//         _lastLat = null;
//         _lastLng = null;
//         _workDate = today;
//         _fire(SiteCache.sync());
//         _fire(SyncWorker.flush());
//       }

//       // Always push UI update
//       service.invoke('location_update', {
//         'lat': s.lat,
//         'lng': s.lng,
//         'accuracy': pos.accuracy,
//         'good': pos.accuracy <= 50,
//       });

//       if (!_movedEnough(s.lat, s.lng) && !_forceNextCheck) return;
//       _lastLat = s.lat;
//       _lastLng = s.lng;
//       _forceNextCheck = false;

//       // Check if session was killed externally (admin force-logout)
//       final stillActive = prefs.getBool('tracking_active_$empId') ?? true;
//       if (!stillActive) {
//         print('[Service] Prefs say inactive — shutting down');
//         await shutdown(
//           writeEndSession: false,
//           endReason: 'logout',
//           clearAllData: false,
//           doneEvent: 'force_stop_done',
//         );
//         return;
//       }

//       // ── Geofence check ───────────────────────────────────────────────────
//       final result = SiteCache.checkLocation(s.lat, s.lng);

//       if (result.inside) {
//         final siteId = result.siteId!;
//         final siteName = result.siteName!;

//         if (currentSiteId != siteId) {
//           // Transition: left previous site or entering for first time this session
//           if (currentSiteId != null) {
//             await LocalDB.writeEvent(
//               type: 'mark_out',
//               employeeId: empId,
//               siteId: currentSiteId,
//               sessionId: sessionId,
//             );
//           }
//           await LocalDB.writeEvent(
//             type: 'mark_in',
//             employeeId: empId,
//             siteId: siteId,
//             sessionId: sessionId,
//           );
//           currentSiteId = siteId;
//           await prefs.setInt('current_site_id_$empId', siteId);
//           updateNotif('IN: $siteName');
//           _fire(SyncWorker.flush()); // eager flush on transitions
//         }

//         service.invoke('status_update', {
//           'status': 'IN',
//           'site_name': siteName,
//           'lat': s.lat,
//           'lng': s.lng,
//           'accuracy': pos.accuracy,
//         });
//       } else {
//         if (currentSiteId != null) {
//           await LocalDB.writeEvent(
//             type: 'mark_out',
//             employeeId: empId,
//             siteId: currentSiteId,
//             sessionId: sessionId,
//           );
//           currentSiteId = null;
//           await prefs.remove('current_site_id_$empId');
//           updateNotif('Tracking — outside all sites');
//           _fire(SyncWorker.flush());
//         }
//         service.invoke('status_update', {
//           'status': 'OUTSIDE',
//           'lat': s.lat,
//           'lng': s.lng,
//           'accuracy': pos.accuracy,
//         });
//       }
//     },
//     onError: (Object err) {
//       print('[Service] GPS error: $err');
//       updateNotif('GPS unavailable — check permissions');
//       service.invoke('service_error', {
//         'reason': 'gps_error',
//         'detail': err.toString(),
//       });
//     },
//     onDone: () {
//       print('[Service] GPS stream closed');
//       updateNotif('GPS stopped — please restart the app');
//       service.invoke('service_error', {'reason': 'gps_stream_closed'});
//     },
//   );

//   print('[Service] ✅ GPS stream running | ${SiteCache.siteCount} site(s)');
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // Public API used by AttendanceScreen / AttendanceState
// // ─────────────────────────────────────────────────────────────────────────────

// String _todayStr() {
//   final n = DateTime.now();
//   return '${n.year}-${n.month.toString().padLeft(2, '0')}'
//       '-${n.day.toString().padLeft(2, '0')}';
// }

// void _fire(Future<void> f) =>
//     f.catchError((e) => print('[Service] async err: $e'));

// // Platform stubs
// Stream<Map<String, dynamic>?> webOn(String e) => const Stream.empty();
// Stream<Map<String, dynamic>?> desktopOn(String e) => const Stream.empty();

// Future<void> startBackgroundTracking(int employeeId, {int? sessionId}) async {
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.setInt('employee_id', employeeId);
//   await prefs.setBool('tracking_active_$employeeId', true);
//   if (sessionId != null) {
//     await prefs.setInt('session_id_$employeeId', sessionId);
//   }
//   if (kIsWeb) return;
//   await SiteCache.init();
//   final svc = FlutterBackgroundService();
//   if (!await svc.isRunning()) {
//     await svc.startService();
//     await Future.delayed(const Duration(milliseconds: 1500));
//   } else {
//     // Service already running — small delay before pushing new session
//     await Future.delayed(const Duration(milliseconds: 300));
//   }
//   // Push new session_id into the running service
//   // This handles sessions 2, 3, 4... where service is already running
//   if (sessionId != null) {
//     svc.invoke('set_session', {'session_id': sessionId});
//     print('[startBackgroundTracking] 🔑 pushed session_id=$sessionId');
//   }
// }

// // ── sendEndSession ─────────────────────────────────────────────────────────────
// // Called by END button. Passes 'still_on_site' so service handles mark_out correctly.
// Future<bool> sendEndSession({required bool stillOnSite}) async {
//   if (kIsWeb) return true;
//   final svc = FlutterBackgroundService();
//   if (!await svc.isRunning()) return true;

//   final completer = Completer<bool>();
//   StreamSubscription? sub;
//   sub = svc.on('end_session_done').listen((_) {
//     if (!completer.isCompleted) completer.complete(true);
//     sub?.cancel();
//   });
//   svc.invoke('end_session', {'still_on_site': stillOnSite});
//   return completer.future.timeout(
//     const Duration(seconds: 12),
//     onTimeout: () {
//       sub?.cancel();
//       return false;
//     },
//   );
// }

// // ── sendForceStop ──────────────────────────────────────────────────────────────
// // Called by LogoutService. Full wipe.
// Future<bool> sendForceStop() async {
//   if (kIsWeb) return true;
//   final svc = FlutterBackgroundService();
//   if (!await svc.isRunning()) return true;

//   final completer = Completer<bool>();
//   StreamSubscription? sub;
//   sub = svc.on('force_stop_done').listen((_) {
//     if (!completer.isCompleted) completer.complete(true);
//     sub?.cancel();
//   });
//   svc.invoke('force_stop');
//   return completer.future.timeout(
//     const Duration(seconds: 15),
//     onTimeout: () {
//       sub?.cancel();
//       return false;
//     },
//   );
// }

import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'site_cache.dart';

const String kChannelId = 'attendance_tracking';
const String kNotifTitle = 'Attendance Tracking';
const int kNotifId = 888;

// ─────────────────────────────────────────────────────────────────────────────
// LocalDB
// ─────────────────────────────────────────────────────────────────────────────
class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'attendance_local.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE attendance_events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            type        TEXT    NOT NULL,
            employee_id INTEGER NOT NULL,
            site_id     INTEGER,
            session_id  INTEGER,
            timestamp   TEXT    NOT NULL,
            synced      INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute(
            'ALTER TABLE attendance_events ADD COLUMN session_id INTEGER',
          );
        }
      },
    );
    return _db!;
  }

  static Future<void> writeEvent({
    required String type,
    required int employeeId,
    int? siteId,
    int? sessionId,
  }) async {
    final ts = DateTime.now().toIso8601String();
    await (await db).insert('attendance_events', {
      'type': type,
      'employee_id': employeeId,
      'site_id': siteId,
      'session_id': sessionId,
      'timestamp': ts,
      'synced': 0,
    });
    print('[LocalDB] $type emp=$employeeId site=$siteId session=$sessionId');
  }

  static Future<List<Map<String, dynamic>>> pendingEvents() async => (await db)
      .query('attendance_events', where: 'synced = 0', orderBy: 'id ASC');

  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    await (await db).update(
      'attendance_events',
      {'synced': 1},
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  static Future<void> cleanup() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String();
    await (await db).delete(
      'attendance_events',
      where: 'synced = 1 AND timestamp < ?',
      whereArgs: [cutoff],
    );
  }

  static Future<void> clearAll() async {
    await (await db).delete('attendance_events');
    print('[LocalDB] Cleared all events');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SyncWorker
// ─────────────────────────────────────────────────────────────────────────────
class SyncWorker {
  static bool _running = false;

  static Future<void> flush() async {
    if (_running) return;
    _running = true;
    try {
      final events = await LocalDB.pendingEvents();
      if (events.isEmpty) return;
      print('[Sync] flushing ${events.length} event(s)');

      final payload = events
          .map(
            (e) => {
              'type': e['type'],
              'employee_id': e['employee_id'],
              'site_id': e['site_id'],
              'session_id': e['session_id'],
              'timestamp': e['timestamp'],
            },
          )
          .toList();

      try {
        await ApiService.batchSync(payload);
        await LocalDB.markSynced(events.map((e) => e['id'] as int).toList());
        await LocalDB.cleanup();
        print('[Sync] batch synced ${events.length}');
      } catch (_) {
        final synced = <int>[];
        for (final e in events) {
          try {
            switch (e['type'] as String) {
              case 'mark_in':
                await ApiService.markIn(
                  e['employee_id'] as int,
                  e['site_id'] as int,
                  sessionId: e['session_id'] as int?,
                );
                break;
              case 'mark_out':
                await ApiService.markOut(
                  e['employee_id'] as int,
                  sessionId: e['session_id'] as int?,
                );
                break;
              case 'end_session':
              case 'force_end_session':
                await ApiService.endSession(
                  e['employee_id'] as int,
                  e['session_id'] as int?,
                  reason: e['type'] == 'force_end_session'
                      ? 'logout'
                      : 'manual_end',
                );
                break;
            }
            synced.add(e['id'] as int);
          } catch (err) {
            print('[Sync] event ${e['id']} failed: $err');
          }
        }
        await LocalDB.markSynced(synced);
        if (synced.isNotEmpty) await LocalDB.cleanup();
      }
    } finally {
      _running = false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// initBackgroundService
// ─────────────────────────────────────────────────────────────────────────────
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  final notifPlugin = FlutterLocalNotificationsPlugin();

  await notifPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          'Attendance Tracking',
          description: 'Keeps GPS tracking running in the background',
          importance: Importance.low,
        ),
      );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      isForegroundMode: true,
      autoStartOnBoot: false,
      notificationChannelId: kChannelId,
      initialNotificationTitle: kNotifTitle,
      initialNotificationContent: 'Tracking active — tap to open',
      foregroundServiceNotificationId: kNotifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

// ── iOS background handler ─────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    await SyncWorker.flush();
  } catch (_) {}
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// onServiceStart
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notifPlugin = FlutterLocalNotificationsPlugin();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await notifPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  void updateNotif(String body) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    notifPlugin.show(
      kNotifId,
      kNotifTitle,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kChannelId,
          kNotifTitle,
          ongoing: true,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
      ),
    );
  }

  // ── Read everything from prefs at boot ────────────────────────────────────
  // session_id and employee_id are always written BEFORE service starts
  final prefs = await SharedPreferences.getInstance();
  final int? empId = prefs.getInt('employee_id');
  final int? sessionId = prefs.getInt('session_id_$empId');
  int? currentSiteId; // always start fresh — no leftover site state

  print('[Service] STARTED emp=$empId session=$sessionId');

  if (empId == null) {
    print('[Service] No employee_id — stopping');
    service.stopSelf();
    return;
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    if (!await Permission.locationAlways.isGranted) {
      updateNotif('Background location permission required');
      service.invoke('service_error', {'reason': 'no_background_location'});
      service.stopSelf();
      return;
    }
  }

  await SiteCache.init();
  String workDate = _todayStr();
  _fire(SyncWorker.flush());

  final syncTimer = Timer.periodic(
    const Duration(minutes: 1),
    (_) => _fire(SyncWorker.flush()),
  );
  final siteRefreshTimer = Timer.periodic(
    const Duration(minutes: 30),
    (_) => _fire(SiteCache.sync()),
  );

  // ── Shutdown helper ────────────────────────────────────────────────────────
  Future<void> shutdown({
    required bool writeEndSession,
    required String endReason,
    required bool clearAllData,
    required String doneEvent,
  }) async {
    print('[Service] shutdown: $endReason');

    // Close open site visit
    if (currentSiteId != null) {
      await LocalDB.writeEvent(
        type: 'mark_out',
        employeeId: empId,
        siteId: currentSiteId,
        sessionId: sessionId,
      );
      currentSiteId = null;
      await prefs.remove('current_site_id_$empId');
    }

    // Close session
    if (writeEndSession && endReason != 'not_in_range') {
      await LocalDB.writeEvent(
        type: endReason == 'logout' ? 'force_end_session' : 'end_session',
        employeeId: empId,
        sessionId: sessionId,
      );
    }

    // Sync before exit
    await SyncWorker.flush();

    // Always fully clear prefs — next START always writes fresh
    await prefs.remove('employee_id');
    await prefs.remove('current_site_id_$empId');
    await prefs.remove('tracking_active_$empId');
    await prefs.remove('session_id_$empId');

    if (clearAllData) {
      await SiteCache.clear();
      await LocalDB.clearAll();
    }

    syncTimer.cancel();
    siteRefreshTimer.cancel();
    SiteCache.dispose();
    await notifPlugin.cancel(kNotifId);
    service.invoke(doneEvent, {});
    service.stopSelf();
    print('[Service] STOPPED');
  }

  // ── END SESSION ────────────────────────────────────────────────────────────
  service.on('end_session').listen((e) async {
    await shutdown(
      writeEndSession: true,
      endReason: 'manual_end',
      clearAllData: false,
      doneEvent: 'end_session_done',
    );
  });

  // ── FORCE STOP (logout) ────────────────────────────────────────────────────
  service.on('force_stop').listen((_) async {
    await shutdown(
      writeEndSession: true,
      endReason: 'not_in_range',
      clearAllData: true,
      doneEvent: 'force_stop_done',
    );
  });

  // ── GPS smoothing ──────────────────────────────────────────────────────────
  final List<({double lat, double lng})> hist = [];

  ({double lat, double lng}) smooth(Position pos) {
    hist.add((lat: pos.latitude, lng: pos.longitude));
    if (hist.length > 3) hist.removeAt(0);
    double ls = 0, ns = 0, ws = 0;
    for (int i = 0; i < hist.length; i++) {
      final w = (i + 1).toDouble();
      ls += hist[i].lat * w;
      ns += hist[i].lng * w;
      ws += w;
    }
    return (lat: ls / ws, lng: ns / ws);
  }

  double? lastLat, lastLng;
  bool movedEnough(double lat, double lng) {
    if (lastLat == null) return true;
    return Geolocator.distanceBetween(lastLat!, lastLng!, lat, lng) > 8;
  }

  // ── Location settings ──────────────────────────────────────────────────────
  LocationSettings locationSettings;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    locationSettings = AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      activityType: ActivityType.otherNavigation,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  } else {
    locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationChannelName: 'Attendance Tracking',
        notificationText: 'Location tracking active',
        notificationTitle: kNotifTitle,
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  // ── GPS stream ─────────────────────────────────────────────────────────────
  Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position pos) async {
      if (pos.accuracy > 150) return;

      final s = smooth(pos);

      // Midnight rollover
      final today = _todayStr();
      if (today != workDate) {
        print('[Service] Midnight rollover');
        if (currentSiteId != null) {
          await LocalDB.writeEvent(
            type: 'mark_out',
            employeeId: empId,
            siteId: currentSiteId,
            sessionId: sessionId,
          );
          currentSiteId = null;
          await prefs.remove('current_site_id_$empId');
        }
        await LocalDB.writeEvent(
          type: 'end_session',
          employeeId: empId,
          sessionId: sessionId,
        );
        hist.clear();
        lastLat = null;
        lastLng = null;
        workDate = today;
        _fire(SiteCache.sync());
        _fire(SyncWorker.flush());
      }

      service.invoke('location_update', {
        'lat': s.lat,
        'lng': s.lng,
        'accuracy': pos.accuracy,
        'good': pos.accuracy <= 50,
      });

      if (!movedEnough(s.lat, s.lng)) return;
      lastLat = s.lat;
      lastLng = s.lng;

      // Geofence check
      final result = SiteCache.checkLocation(s.lat, s.lng);

      if (result.inside) {
        final siteId = result.siteId!;
        final siteName = result.siteName!;

        if (currentSiteId != siteId) {
          if (currentSiteId != null) {
            await LocalDB.writeEvent(
              type: 'mark_out',
              employeeId: empId,
              siteId: currentSiteId,
              sessionId: sessionId,
            );
          }
          await LocalDB.writeEvent(
            type: 'mark_in',
            employeeId: empId,
            siteId: siteId,
            sessionId: sessionId,
          );
          currentSiteId = siteId;
          await prefs.setInt('current_site_id_$empId', siteId);
          updateNotif('IN: $siteName');
          _fire(SyncWorker.flush());
        }

        service.invoke('status_update', {
          'status': 'IN',
          'site_name': siteName,
          'lat': s.lat,
          'lng': s.lng,
          'accuracy': pos.accuracy,
        });
      } else {
        if (currentSiteId != null) {
          await LocalDB.writeEvent(
            type: 'mark_out',
            employeeId: empId,
            siteId: currentSiteId,
            sessionId: sessionId,
          );
          currentSiteId = null;
          await prefs.remove('current_site_id_$empId');
          updateNotif('Tracking — outside all sites');
          _fire(SyncWorker.flush());
        }
        service.invoke('status_update', {
          'status': 'OUTSIDE',
          'lat': s.lat,
          'lng': s.lng,
          'accuracy': pos.accuracy,
        });
      }
    },
    onError: (Object err) {
      print('[Service] GPS error: $err');
      updateNotif('GPS unavailable — check permissions');
      service.invoke('service_error', {
        'reason': 'gps_error',
        'detail': err.toString(),
      });
    },
    onDone: () {
      print('[Service] GPS stream closed');
      updateNotif('GPS stopped — please restart the app');
      service.invoke('service_error', {'reason': 'gps_stream_closed'});
    },
  );

  print('[Service] GPS running | ${SiteCache.siteCount} site(s)');
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}'
      '-${n.day.toString().padLeft(2, '0')}';
}

void _fire(Future<void> f) =>
    f.catchError((e) => print('[Service] async err: $e'));

Stream<Map<String, dynamic>?> webOn(String e) => const Stream.empty();
Stream<Map<String, dynamic>?> desktopOn(String e) => const Stream.empty();

// ── START — kill any existing, write prefs, start fresh ───────────────────
Future<void> startBackgroundTracking(int employeeId, {int? sessionId}) async {
  if (kIsWeb) return;

  final svc = FlutterBackgroundService();
  final prefs = await SharedPreferences.getInstance();

  // Kill existing service if running
  if (await svc.isRunning()) {
    svc.invoke('force_stop');
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // Write fresh prefs before starting — service reads these at boot
  await prefs.setInt('employee_id', employeeId);
  await prefs.setBool('tracking_active_$employeeId', true);
  await prefs.remove('current_site_id_$employeeId'); // always fresh site state
  if (sessionId != null) {
    await prefs.setInt('session_id_$employeeId', sessionId);
  }

  await SiteCache.init();
  await svc.startService();

  print(
    '[startBackgroundTracking] fresh start emp=$employeeId session=$sessionId',
  );
}

// ── END — send signal, service handles everything and kills itself ─────────
Future<bool> sendEndSession({required bool stillOnSite}) async {
  if (kIsWeb) return true;

  final svc = FlutterBackgroundService();
  if (!await svc.isRunning()) return true;

  final completer = Completer<bool>();
  StreamSubscription? sub;
  sub = svc.on('end_session_done').listen((_) {
    if (!completer.isCompleted) completer.complete(true);
    sub?.cancel();
  });

  svc.invoke('end_session', {'still_on_site': stillOnSite});

  return completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      sub?.cancel();
      return false;
    },
  );
}

// ── FORCE STOP (logout) ────────────────────────────────────────────────────
Future<bool> sendForceStop() async {
  if (kIsWeb) return true;

  final svc = FlutterBackgroundService();
  if (!await svc.isRunning()) return true;

  final completer = Completer<bool>();
  StreamSubscription? sub;
  sub = svc.on('force_stop_done').listen((_) {
    if (!completer.isCompleted) completer.complete(true);
    sub?.cancel();
  });

  svc.invoke('force_stop');

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () {
      sub?.cancel();
      return false;
    },
  );
}

Future<bool> sendEndDay() => sendEndSession(stillOnSite: false);
