import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../providers/api_config.dart';

// ─── Background message handler ───────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[notify] Background message: ${message.messageId}');
}

// ─── Notification Model ───────────────────────────────────────────────────────
class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String reminderType;
  final bool isRead;
  final DateTime? readAt;
  final String sentStatus;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.reminderType,
    required this.isRead,
    this.readAt,
    required this.sentStatus,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      reminderType: json['reminder_type'] as String,
      isRead: (json['is_read'] as int) == 1,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      sentStatus: json['sent_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NotificationItem copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      reminderType: reminderType,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      sentStatus: sentStatus,
      createdAt: createdAt,
    );
  }
}

// ─── NotifyService ────────────────────────────────────────────────────────────
class NotifyService {
  NotifyService._();

  // ── Singleton — lazy, never created on web ────────────────────────────────
  static NotifyService? _instance;
  static NotifyService get instance {
    assert(!kIsWeb, 'NotifyService is not supported on web.');
    return _instance ??= NotifyService._();
  }

  // ── Lazy fields — not initialized until initializeFCM() is called ─────────
  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotif;

  bool _initialized = false;

  static const _androidChannel = AndroidNotificationChannel(
    'attendance_reminders',
    'Attendance Reminders',
    description: 'Reminders to mark your attendance before shift starts.',
    importance: Importance.high,
    playSound: true,
  );

  final _backgroundTapController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _backgroundTapController.stream;

  // ─────────────────────────────────────────────────────────────────────────
  // 1. initializeFCM
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> initializeFCM() async {
    if (_initialized) return;

    // Initialize lazy fields here — safe because we only reach this on mobile
    _fcm = FirebaseMessaging.instance;
    _localNotif = FlutterLocalNotificationsPlugin();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif!.initialize(
      settings: const InitializationSettings(
        android: initAndroid,
        iOS: initIOS,
      ),
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );
    await _localNotif!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    await _fcm!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(handleForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(handleBackgroundNotification);

    final initial = await _fcm!.getInitialMessage();
    if (initial != null) handleBackgroundNotification(initial);

    _fcm!.onTokenRefresh.listen((newToken) async {
      debugPrint('[notify] FCM token refreshed.');
      await saveFcmToken(newToken);
    });

    _initialized = true;
    debugPrint('[notify] FCM initialized.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. requestNotificationPermission
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> requestNotificationPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('[notify] Permission: ${settings.authorizationStatus}');
    return granted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. saveFcmToken
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveFcmToken([String? tokenOverride]) async {
    if (_fcm == null) return;
    try {
      final token = tokenOverride ?? await _fcm!.getToken();
      if (token == null) return;

      // Safe platform check — only runs on mobile so dart:io is fine
      String platform = 'android';
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        platform = 'ios';
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/fcm-token'),
        headers: {...ApiConfig.headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        debugPrint('[notify] FCM token saved.');
      } else {
        debugPrint('[notify] Failed to save FCM token: ${response.body}');
      }
    } catch (e) {
      debugPrint('[notify] saveFcmToken error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. syncDeviceSession
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> syncDeviceSession() async {
    await saveFcmToken();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. handleForegroundNotification
  // ─────────────────────────────────────────────────────────────────────────
  void handleForegroundNotification(RemoteMessage message) {
    debugPrint('[notify] Foreground: ${message.notification?.title}');
    showLocalNotification(message);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 6. handleBackgroundNotification
  // ─────────────────────────────────────────────────────────────────────────
  void handleBackgroundNotification(RemoteMessage message) {
    debugPrint('[notify] Background tap: ${message.data}');
    _backgroundTapController.add(message.data);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 7. showLocalNotification
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> showLocalNotification(RemoteMessage message) async {
    if (_localNotif == null) return;
    final notif = message.notification;
    if (notif == null) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotif!.show(
      id: message.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotifTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _backgroundTapController.add(data);
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 8. fetchNotificationHistory
  // ─────────────────────────────────────────────────────────────────────────
  Future<({List<NotificationItem> items, int unreadCount})>
  fetchNotificationHistory({int page = 1, int limit = 20}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications/history?page=$page&limit=$limit',
    );
    final response = await http.get(uri, headers: ApiConfig.headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['data'] as List<dynamic>)
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return (items: list, unreadCount: (json['unread_count'] as int));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 9. markNotificationRead
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> markNotificationRead(int id) async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
      headers: ApiConfig.headers,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 10. markAllNotificationsRead
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> markAllNotificationsRead() async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
      headers: ApiConfig.headers,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 11. removeDeviceToken
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> removeDeviceToken() async {
    if (_fcm == null) return;
    try {
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications/fcm-token'),
        headers: ApiConfig.headers,
      );
      await _fcm!.deleteToken();
      debugPrint('[notify] FCM token removed on logout.');
    } catch (e) {
      debugPrint('[notify] removeDeviceToken error: $e');
    }
  }
}
