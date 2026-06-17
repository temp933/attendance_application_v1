import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../providers/api_config.dart';

// ─── Background message handler (top-level, required by Firebase) ─────────────
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[notify] Background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

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

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
    id: j['id'] as int,
    title: j['title'] as String,
    body: j['body'] as String,
    reminderType: j['reminder_type'] as String? ?? '',
    isRead: (j['is_read'] as int? ?? 0) == 1,
    readAt: j['read_at'] != null
        ? DateTime.tryParse(j['read_at'] as String)
        : null,
    sentStatus: j['sent_status'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  NotificationItem copyWith({bool? isRead, DateTime? readAt}) =>
      NotificationItem(
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

// Global notification (from App Admin broadcast)
class GlobalNotificationItem {
  final int notificationId;
  final String title;
  final String message;
  final String type;
  final bool isOpened;
  final DateTime receivedAt;

  GlobalNotificationItem({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.isOpened,
    required this.receivedAt,
  });

  factory GlobalNotificationItem.fromJson(Map<String, dynamic> j) =>
      GlobalNotificationItem(
        notificationId: j['notification_id'] as int,
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? j['body'] as String? ?? '',
        type: j['type'] as String? ?? 'general',
        isOpened: (j['is_opened'] as int? ?? 0) == 1,
        receivedAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  GlobalNotificationItem copyWith({bool? isOpened}) => GlobalNotificationItem(
    notificationId: notificationId,
    title: title,
    message: message,
    type: type,
    isOpened: isOpened ?? this.isOpened,
    receivedAt: receivedAt,
  );
}

// Unified inbox item — either attendance reminder or global broadcast
class InboxItem {
  final String kind; // 'reminder' | 'global'
  final NotificationItem? reminder;
  final GlobalNotificationItem? global;

  const InboxItem.reminder(this.reminder) : kind = 'reminder', global = null;

  const InboxItem.global(this.global) : kind = 'global', reminder = null;

  bool get isRead => kind == 'reminder'
      ? (reminder?.isRead ?? false)
      : (global?.isOpened ?? false);
  DateTime get date => kind == 'reminder'
      ? (reminder?.createdAt ?? DateTime.now())
      : (global?.receivedAt ?? DateTime.now());
  String get title =>
      kind == 'reminder' ? (reminder?.title ?? '') : (global?.title ?? '');
  String get body =>
      kind == 'reminder' ? (reminder?.body ?? '') : (global?.message ?? '');
}

// ─────────────────────────────────────────────────────────────────────────────
// NotifyService
// ─────────────────────────────────────────────────────────────────────────────

class NotifyService {
  NotifyService._();

  static NotifyService? _instance;
  static NotifyService get instance {
    assert(!kIsWeb, 'NotifyService is not supported on web.');
    return _instance ??= NotifyService._();
  }

  FirebaseMessaging? _fcm;
  FlutterLocalNotificationsPlugin? _localNotif;
  bool _initialized = false;

  // Navigator key — set this from main.dart so we can navigate on tap
  static GlobalKey<NavigatorState>? navigatorKey;

  // ── Channels ──────────────────────────────────────────────────────────────
  static const _reminderChannel = AndroidNotificationChannel(
    'attendance_reminders',
    'Attendance Reminders',
    description: 'Reminders to mark your attendance before shift starts.',
    importance: Importance.high,
    playSound: true,
  );

  static const _globalChannel = AndroidNotificationChannel(
    'global_alerts',
    'Global Alerts',
    description: 'Important announcements from your organization.',
    importance: Importance.max,
    playSound: true,
  );

  // Stream for in-app tap handling
  final _tapController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap => _tapController.stream;

  // ─────────────────────────────────────────────────────────────────────────
  // initializeFCM
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> initializeFCM() async {
    if (_initialized) return;

    _fcm = FirebaseMessaging.instance;
    _localNotif = FlutterLocalNotificationsPlugin();

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // Initialize local notifications
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

    // Create both channels
    final androidPlugin = _localNotif!
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_reminderChannel);
    await androidPlugin?.createNotificationChannel(_globalChannel);

    await _fcm!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for messages
    FirebaseMessaging.onMessage.listen(_handleForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // App opened from terminated state via notification tap
    final initial = await _fcm!.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Token refresh
    _fcm!.onTokenRefresh.listen((token) async {
      debugPrint('[notify] FCM token refreshed');
      await saveFcmToken(token);
    });

    _initialized = true;
    debugPrint('[notify] FCM initialized');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // requestNotificationPermission
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
  // saveFcmToken — saves to backend
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveFcmToken([String? tokenOverride]) async {
    if (_fcm == null) return;
    try {
      final token = tokenOverride ?? await _fcm!.getToken();
      if (token == null) return;

      final platform = defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/fcm-token'),
        headers: {...ApiConfig.headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token, 'platform': platform}),
      );

      debugPrint('[notify] FCM token save: ${res.statusCode}');
    } catch (e) {
      debugPrint('[notify] saveFcmToken error: $e');
    }
  }

  Future<void> syncDeviceSession() => saveFcmToken();

  // ─────────────────────────────────────────────────────────────────────────
  // removeDeviceToken — call on logout
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> removeDeviceToken() async {
    if (_fcm == null) return;
    try {
      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/notifications/fcm-token'),
        headers: ApiConfig.headers,
      );
      await _fcm!.deleteToken();
      debugPrint('[notify] FCM token removed');
    } catch (e) {
      debugPrint('[notify] removeDeviceToken error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Foreground — show local notification popup
  // ─────────────────────────────────────────────────────────────────────────
  void _handleForeground(RemoteMessage message) {
    debugPrint('[notify] Foreground: ${message.notification?.title}');
    _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    if (_localNotif == null) return;
    final notif = message.notification;
    if (notif == null) return;

    // Pick channel based on notification type
    final isGlobal = message.data['type'] == 'global_notification';
    final channel = isGlobal ? _globalChannel : _reminderChannel;

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notif.body ?? '',
        htmlFormatBigText: false,
        contentTitle: notif.title,
        htmlFormatContentTitle: false,
      ),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Tap handler — routes to inbox or marks global as opened
  // ─────────────────────────────────────────────────────────────────────────
  void _handleTap(RemoteMessage message) {
    debugPrint('[notify] Tapped: ${message.data}');
    _routeFromData(message.data);
  }

  void _onLocalNotifTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _routeFromData(data);
    } catch (_) {}
  }

  void _routeFromData(Map<String, dynamic> data) {
    _tapController.add(data);

    final type = data['type'] as String? ?? '';
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    if (type == 'global_notification') {
      final notifId = int.tryParse(data['notification_id']?.toString() ?? '');
      // Mark opened in background
      if (notifId != null) _markGlobalOpened(notifId);
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NotificationInboxScreen(initialTab: 1),
        ),
      );
    } else if (type == 'attendance_reminder') {
      navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder: (_) => NotificationInboxScreen(initialTab: 0),
        ),
      );
    }
  }

  Future<void> _markGlobalOpened(int notificationId) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notifications/mark-global-opened'),
        headers: {...ApiConfig.headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'notification_id': notificationId}),
      );
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API calls
  // ─────────────────────────────────────────────────────────────────────────
  Future<({List<NotificationItem> items, int unreadCount})>
  fetchNotificationHistory({int page = 1, int limit = 20}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications/history?page=$page&limit=$limit',
    );
    final res = await http.get(uri, headers: ApiConfig.headers);
    if (res.statusCode != 200) throw Exception('Failed: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (json['data'] as List)
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, unreadCount: json['unread_count'] as int? ?? 0);
  }

  Future<List<GlobalNotificationItem>> fetchGlobalNotificationHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/notifications/global-history?page=$page&limit=$limit',
    );
    final res = await http.get(uri, headers: ApiConfig.headers);
    if (res.statusCode != 200) throw Exception('Failed: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => GlobalNotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(int id) async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'),
      headers: ApiConfig.headers,
    );
  }

  Future<void> markAllNotificationsRead() async {
    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'),
      headers: ApiConfig.headers,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Expose foreground handler for testing
  // ─────────────────────────────────────────────────────────────────────────
  void handleForegroundNotification(RemoteMessage m) => _handleForeground(m);
  void handleBackgroundNotification(RemoteMessage m) => _handleTap(m);
  Future<void> showLocalNotification(RemoteMessage m) =>
      _showLocalNotification(m);
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION INBOX SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationInboxScreen extends StatefulWidget {
  final int initialTab;
  const NotificationInboxScreen({super.key, this.initialTab = 0});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Reminders
  List<NotificationItem> _reminders = [];
  int _reminderUnread = 0;
  bool _remindersLoading = true;
  String? _remindersError;

  // Global notifications (fetched from backend)
  List<GlobalNotificationItem> _globals = [];
  bool _globalsLoading = true;
  String? _globalsError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadReminders();
    _loadGlobals();

    // Listen for new notifications arriving while screen is open
    NotifyService.instance.onNotificationTap.listen((data) {
      if (data['type'] == 'attendance_reminder') _loadReminders();
      if (data['type'] == 'global_notification') _loadGlobals();
    });
  }

  Future<void> _loadGlobals() async {
    setState(() {
      _globalsLoading = true;
      _globalsError = null;
    });
    try {
      final items = await NotifyService.instance.fetchGlobalNotificationHistory();
      setState(() {
        _globals = items;
        _globalsLoading = false;
      });
    } catch (e) {
      setState(() {
        _globalsError = e.toString();
        _globalsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _remindersLoading = true;
      _remindersError = null;
    });
    try {
      final result = await NotifyService.instance.fetchNotificationHistory();
      setState(() {
        _reminders = result.items;
        _reminderUnread = result.unreadCount;
        _remindersLoading = false;
      });
    } catch (e) {
      setState(() {
        _remindersError = e.toString();
        _remindersLoading = false;
      });
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    await NotifyService.instance.markNotificationRead(item.id);
    setState(() {
      final idx = _reminders.indexWhere((r) => r.id == item.id);
      if (idx != -1) {
        _reminders[idx] = _reminders[idx].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
        if (_reminderUnread > 0) _reminderUnread--;
      }
    });
  }

  Future<void> _markAllRead() async {
    await NotifyService.instance.markAllNotificationsRead();
    setState(() {
      _reminders = _reminders.map((r) => r.copyWith(isRead: true)).toList();
      _reminderUnread = 0;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        // backgroundColor:Color(0xFF1A56DB),
        elevation: 0,
        surfaceTintColor: const Color.fromARGB(0, 254, 1, 1),
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: const Text(
          'Notifications',
          
          style: TextStyle(
            color: Color.fromARGB(255, 4, 4, 4),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_tab.index == 0 && _reminderUnread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF4361EE), fontSize: 13),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              Container(height: 1, color: const Color(0xFFE8EAED)),
              TabBar(
                controller: _tab,
                onTap: (i) => setState(() {}),
                labelColor: const Color(0xFF4361EE),
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: const Color(0xFF4361EE),
                indicatorWeight: 2,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Reminders'),
                        if (_reminderUnread > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(_reminderUnread),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Broadcasts'),
                        if (_globals.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _Badge(_globals.where((g) => !g.isOpened).length),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildRemindersTab(), _buildGlobalsTab()],
      ),
    );
  }

  // ── Reminders Tab ──────────────────────────────────────────────────────────
  Widget _buildRemindersTab() {
    if (_remindersLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4361EE),
          strokeWidth: 2,
        ),
      );
    }
    if (_remindersError != null) {
      return _ErrorView(message: _remindersError!, onRetry: _loadReminders);
    }
    if (_reminders.isEmpty) {
      return const _EmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'No reminders yet',
        subtitle: 'Attendance reminders will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: const Color(0xFF4361EE),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _reminders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ReminderTile(
          item: _reminders[i],
          onTap: () => _openReminder(_reminders[i]),
        ),
      ),
    );
  }

  void _openReminder(NotificationItem item) {
    _markRead(item);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifDetailSheet(
        title: item.title,
        body: item.body,
        time: item.createdAt,
        tag: _reminderTypeLabel(item.reminderType),
        tagColor: const Color(0xFF4361EE),
        icon: Icons.alarm_outlined,
      ),
    );
  }

  String _reminderTypeLabel(String type) {
    switch (type) {
      case 'before_30_min':
        return '30 min before shift';
      case 'before_10_min':
        return '10 min before shift';
      default:
        return 'Attendance Reminder';
    }
  }

  // ── Globals Tab ────────────────────────────────────────────────────────────
  Widget _buildGlobalsTab() {
    if (_globalsLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4361EE),
          strokeWidth: 2,
        ),
      );
    }
    if (_globalsError != null) {
      return _ErrorView(message: _globalsError!, onRetry: _loadGlobals);
    }
    if (_globals.isEmpty) {
      return const _EmptyState(
        icon: Icons.campaign_outlined,
        title: 'No broadcasts yet',
        subtitle: 'Organization-wide announcements will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadGlobals,
      color: const Color(0xFF4361EE),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _globals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _GlobalTile(
          item: _globals[i],
          onTap: () => _openGlobal(_globals[i]),
        ),
      ),
    );
  }

  void _openGlobal(GlobalNotificationItem item) {
    NotifyService.instance._markGlobalOpened(item.notificationId);
    // Mark as opened in local list
    final idx = _globals.indexOf(item);
    if (idx != -1) {
      setState(() {
        _globals[idx] = item.copyWith(isOpened: true);
      });
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifDetailSheet(
        title: item.title,
        body: item.message,
        time: item.receivedAt,
        tag: _globalTypeLabel(item.type),
        tagColor: _globalTypeColor(item.type),
        icon: _globalTypeIcon(item.type),
      ),
    );
  }

  String _globalTypeLabel(String type) {
    switch (type) {
      case 'maintenance':
        return 'Maintenance';
      case 'app_update':
        return 'App Update';
      case 'billing_reminder':
        return 'Billing';
      case 'emergency_alert':
        return 'Emergency';
      default:
        return 'General';
    }
  }

  Color _globalTypeColor(String type) {
    switch (type) {
      case 'maintenance':
        return const Color(0xFFFFB703);
      case 'app_update':
        return const Color(0xFF4CC9F0);
      case 'billing_reminder':
        return const Color(0xFF7209B7);
      case 'emergency_alert':
        return const Color(0xFFEF476F);
      default:
        return const Color(0xFF4361EE);
    }
  }

  IconData _globalTypeIcon(String type) {
    switch (type) {
      case 'maintenance':
        return Icons.build_outlined;
      case 'app_update':
        return Icons.system_update_alt_outlined;
      case 'billing_reminder':
        return Icons.receipt_long_outlined;
      case 'emergency_alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.campaign_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TILES
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _ReminderTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · h:mm a');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: item.isRead
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF4361EE),
              width: 3,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.isRead
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF4361EE).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.alarm_outlined,
                size: 18,
                color: item.isRead
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4361EE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4361EE),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fmt.format(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlobalTile extends StatelessWidget {
  final GlobalNotificationItem item;
  final VoidCallback onTap;
  const _GlobalTile({required this.item, required this.onTap});

  Color get _color {
    switch (item.type) {
      case 'maintenance':
        return const Color(0xFFFFB703);
      case 'emergency_alert':
        return const Color(0xFFEF476F);
      case 'app_update':
        return const Color(0xFF4CC9F0);
      case 'billing_reminder':
        return const Color(0xFF7209B7);
      default:
        return const Color(0xFF4361EE);
    }
  }

  IconData get _icon {
    switch (item.type) {
      case 'maintenance':
        return Icons.build_outlined;
      case 'emergency_alert':
        return Icons.warning_amber_rounded;
      case 'app_update':
        return Icons.system_update_alt_outlined;
      case 'billing_reminder':
        return Icons.receipt_long_outlined;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · h:mm a');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isOpened ? Colors.white : _color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _color, width: 3)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 18, color: _color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isOpened
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (!item.isOpened)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.type.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: _color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fmt.format(item.receivedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _NotifDetailSheet extends StatelessWidget {
  final String title;
  final String body;
  final DateTime time;
  final String tag;
  final Color tagColor;
  final IconData icon;

  const _NotifDetailSheet({
    required this.title,
    required this.body,
    required this.time,
    required this.tag,
    required this.tagColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM d, yyyy  h:mm a');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + tag row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tagColor, size: 22),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tagColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Body
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // Timestamp
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                size: 14,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 5),
              Text(
                fmt.format(time),
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Close button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEF476F),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361EE),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
