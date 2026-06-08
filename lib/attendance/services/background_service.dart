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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';
import 'site_cache.dart';

const String kChannelId = 'attendance_tracking';
const String kNotifTitle = 'Attendance Tracking';
const int kNotifId = 888;

// Keys used across the background isolate
const String _kSiteEntryActiveKey = 'site_entry_has_active_session';
const String _kSiteEntryLastPingKey = 'site_entry_last_ping_ms';

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
    debugPrint(
      '[LocalDB] $type emp=$employeeId site=$siteId session=$sessionId',
    );
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
    debugPrint('[LocalDB] Cleared all events');
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
      debugPrint('[Sync] flushing ${events.length} event(s)');

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
        debugPrint('[Sync] batch synced ${events.length}');
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
            debugPrint('[Sync] event ${e['id']} failed: $err');
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
  final prefs = await SharedPreferences.getInstance();
  final int? empId =
      prefs.getInt('employee_id') ??
      int.tryParse(prefs.getString('employeeId') ?? '');
  if (empId == null) {
    debugPrint('[BGService] No session — skipping init');
    return;
  }

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
// All timers are declared at function scope so shutdown() can cancel them.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final int? empId =
      prefs.getInt('employee_id') ??
      int.tryParse(prefs.getString('employeeId') ?? '');
  final int? sessionId =
      prefs.getInt('session_id_$empId') ?? prefs.getInt('session_id');

  debugPrint('[Service] STARTED emp=$empId session=$sessionId');

  if (empId == null) {
    debugPrint('[Service] No employee_id — stopping');
    service.stopSelf();
    return;
  }

  // ── Heavy plugin init (only after session confirmed) ───────────────────
  final notifPlugin = FlutterLocalNotificationsPlugin();
  if (defaultTargetPlatform == TargetPlatform.android) {
    await notifPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
  }

  void updateNotif(String body) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    notifPlugin.show(
      id: kNotifId,
      title: kNotifTitle,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kChannelId,
          'Attendance Tracking',
          ongoing: true,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
        ),
      ),
    );
  }

  int? currentSiteId;

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

  // ── Timers — declared at function scope so shutdown() can reach them ────
  final syncTimer = Timer.periodic(
    const Duration(minutes: 1),
    (_) => _fire(SyncWorker.flush()),
  );
  final siteRefreshTimer = Timer.periodic(
    const Duration(minutes: 30),
    (_) => _fire(SiteCache.sync()),
  );

  // ── GPS-face attendance location update (every 2 min) ──────────────────
  // FIX: declared here at function scope (was local inside the block before)
  final Timer gpsAttendanceTimer = Timer.periodic(
    const Duration(minutes: 2),
    (_) => _fire(_runGpsFaceUpdate(prefs, updateNotif)),
  );

  // ── Site-entry location update (every 2 min, offset by 60 s) ───────────
  // Uses a 60-second initial delay so the two pings don't fire simultaneously.
  Timer? siteEntryTimer;
  Future<void> startSiteEntryTimer() async {
    await Future.delayed(const Duration(seconds: 60));
    siteEntryTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _fire(_runSiteEntryUpdate(prefs, updateNotif, service)),
    );
  }

  _fire(startSiteEntryTimer());

  // ── 1-min location logger ───────────────────────────────────────────────
  final locationLogTimer = Timer.periodic(const Duration(minutes: 1), (
    _,
  ) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      debugPrint(
        '[Location] ${DateTime.now().toIso8601String()} '
        '| lat=${pos.latitude.toStringAsFixed(6)} '
        'lng=${pos.longitude.toStringAsFixed(6)} '
        'acc=${pos.accuracy.toStringAsFixed(1)}m',
      );
    } catch (e) {
      debugPrint('[Location] Failed: $e');
    }
  });

  // ── Shutdown helper ────────────────────────────────────────────────────
  Future<void> shutdown({
    required bool writeEndSession,
    required String endReason,
    required bool clearAllData,
    required String doneEvent,
  }) async {
    debugPrint('[Service] shutdown: $endReason');

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

    if (writeEndSession && endReason != 'not_in_range') {
      await LocalDB.writeEvent(
        type: endReason == 'logout' ? 'force_end_session' : 'end_session',
        employeeId: empId,
        sessionId: sessionId,
      );
    }

    await SyncWorker.flush();

    await prefs.remove('employee_id');
    await prefs.remove('current_site_id_$empId');
    await prefs.remove('tracking_active_$empId');
    await prefs.remove('session_id_$empId');
    // Clear site_entry active flag
    await prefs.remove(_kSiteEntryActiveKey);

    if (clearAllData) {
      await SiteCache.clear();
      await LocalDB.clearAll();
    }

    // Cancel ALL timers — now possible because all are in scope
    syncTimer.cancel();
    siteRefreshTimer.cancel();
    gpsAttendanceTimer.cancel();
    siteEntryTimer?.cancel();
    locationLogTimer.cancel();
    SiteCache.dispose();
    await notifPlugin.cancel(id: kNotifId);
    service.invoke(doneEvent, {});
    service.stopSelf();
    debugPrint('[Service] STOPPED');
  }

  // ── END SESSION ────────────────────────────────────────────────────────
  service.on('end_session').listen((_) async {
    await shutdown(
      writeEndSession: true,
      endReason: 'manual_end',
      clearAllData: false,
      doneEvent: 'end_session_done',
    );
  });

  // ── FORCE STOP (logout) ───────────────────────────────────────────────
  service.on('force_stop').listen((_) async {
    await shutdown(
      writeEndSession: true,
      endReason: 'not_in_range',
      clearAllData: true,
      doneEvent: 'force_stop_done',
    );
  });

  // ── GPS smoothing ──────────────────────────────────────────────────────
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

  // ── Location settings ──────────────────────────────────────────────────
  final LocationSettings locationSettings;
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

  // ── GPS stream ─────────────────────────────────────────────────────────
  Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position pos) async {
      if (pos.accuracy > 150) return;

      final s = smooth(pos);

      // Midnight rollover
      final today = _todayStr();
      if (today != workDate) {
        debugPrint('[Service] Midnight rollover');
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
      debugPrint('[Service] GPS error: $err');
      updateNotif('GPS unavailable — check permissions');
      service.invoke('service_error', {
        'reason': 'gps_error',
        'detail': err.toString(),
      });
    },
    onDone: () {
      debugPrint('[Service] GPS stream closed');
      updateNotif('GPS stopped — please restart the app');
      service.invoke('service_error', {'reason': 'gps_stream_closed'});
    },
  );

  debugPrint('[Service] GPS running | ${SiteCache.siteCount} site(s)');
}

// ─────────────────────────────────────────────────────────────────────────────
// GPS-face background ping (every 2 min)
// Extracted to a top-level function so it is not a closure capturing the
// local Timer variable — this was the original scoping bug.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runGpsFaceUpdate(
  SharedPreferences prefs,
  void Function(String) updateNotif,
) async {
  final attendanceId = prefs.getInt('gps_active_attendance_id');
  if (attendanceId == null) return;

  try {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 15));

    final token = prefs.getString('session_token') ?? '';
    final tenantId = prefs.getString('tenantId') ?? '';
    final baseUrl = prefs.getString('bg_base_url') ?? '';

    debugPrint(
      '[GPS-face] baseUrl=$baseUrl token=${token.isNotEmpty ? "SET" : "EMPTY"}',
    );

    if (baseUrl.isEmpty || token.isEmpty) return;

    final mode = prefs.getString('gps_active_attendance_mode') ?? 'face';
    final endpoint = mode == 'gps' ? 'gps' : 'face';
    final baseUrlFull = '$baseUrl/$endpoint/update-location';

    final response = await http
        .patch(
          Uri.parse(baseUrlFull),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-tenant-id': tenantId,
          },
          body: jsonEncode({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final isActive = body['active'] as bool? ?? true;
      if (!isActive) {
        await prefs.remove('gps_active_attendance_id');
        await prefs.remove('gps_checkin_time');
        await prefs.remove('gps_active_attendance_mode');
        debugPrint('[$endpoint BG] Session ended server-side');
      } else {
        debugPrint('[$endpoint BG] Updated: ${pos.latitude}, ${pos.longitude}');
      }
    }
  } catch (e) {
    debugPrint('[GPS-face] Update failed: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Site-entry background ping (every 2 min)
// Calls /api/site-entry/update-location and handles the action response.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _runSiteEntryUpdate(
  SharedPreferences prefs,
  void Function(String) updateNotif,
  ServiceInstance service,
) async {
  // Throttle: skip if last ping was less than 110 seconds ago
  final lastPing = prefs.getInt(_kSiteEntryLastPingKey) ?? 0;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (nowMs - lastPing < 110 * 1000) return;

  try {
    final bool svcEnabled = await Geolocator.isLocationServiceEnabled();
    if (!svcEnabled) return;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return; // GPS timeout — skip this cycle
    }

    final token = prefs.getString('session_token') ?? '';
    final tenantId = prefs.getString('tenantId') ?? '';
    final baseUrl = prefs.getString('bg_base_url') ?? '';

    if (baseUrl.isEmpty || token.isEmpty) return;

    final res = await http
        .patch(
          Uri.parse('$baseUrl/site-entry/update-location'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-tenant-id': tenantId,
          },
          body: jsonEncode({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          }),
        )
        .timeout(const Duration(seconds: 10));

    await prefs.setInt(_kSiteEntryLastPingKey, nowMs);

    if (res.statusCode != 200) return;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final action = body['action'] as String? ?? '';

    debugPrint('[SiteEntry BG] action=$action');

    switch (action) {
      case 'location_updated':
        await prefs.setBool(_kSiteEntryActiveKey, true);
        break;

      case 'paused':
      case 'still_paused':
        await prefs.setBool(_kSiteEntryActiveKey, true);
        final remaining = body['remaining_grace'] as int?;
        if (remaining != null) {
          updateNotif('Site attendance paused — ${remaining}m grace remaining');
        }
        break;

      case 'auto_checked_out':
        await prefs.setBool(_kSiteEntryActiveKey, false);
        updateNotif('Auto checked-out: absent from site >10 min');
        service.invoke('site_entry_auto_checkout', {
          'attendance_id': body['attendance_id'],
          'reason': body['reason'],
        });
        break;

      case 'site_switched':
        await prefs.setBool(_kSiteEntryActiveKey, true);
        final newSite =
            (body['new_session'] as Map<String, dynamic>?)?['site_name']
                as String? ??
            'new site';
        updateNotif('Moved to $newSite — new session started');
        service.invoke('site_entry_switched', {
          'new_site_id':
              (body['new_session'] as Map<String, dynamic>?)?['site_id'],
          'new_site_name': newSite,
        });
        break;

      case 'no_active_session':
        await prefs.setBool(_kSiteEntryActiveKey, false);
        break;
    }
  } catch (e) {
    debugPrint('[SiteEntry BG] ping failed: $e');
    // Never throw — background tasks must not crash the isolate
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────
String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

void _fire(Future<void> f) =>
    f.catchError((e) => debugPrint('[Service] async err: $e'));

// ── START ──────────────────────────────────────────────────────────────────
Future<void> startBackgroundTracking(int employeeId, {int? sessionId}) async {
  if (kIsWeb) return;

  final svc = FlutterBackgroundService();
  final prefs = await SharedPreferences.getInstance();

  if (await svc.isRunning()) {
    svc.invoke('force_stop');
    await Future.delayed(const Duration(milliseconds: 800));
  }

  await prefs.setInt('employee_id', employeeId);
  await prefs.setString('employeeId', employeeId.toString());
  await prefs.setBool('tracking_active_$employeeId', true);
  await prefs.remove('current_site_id_$employeeId');
  if (sessionId != null) {
    await prefs.setInt('session_id_$employeeId', sessionId);
    await prefs.setInt('session_id', sessionId);
  }

  await SiteCache.init();

  debugPrint('[startBackgroundTracking] emp=$employeeId session=$sessionId');
  await svc.startService();
}

// ── END SESSION ────────────────────────────────────────────────────────────
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
