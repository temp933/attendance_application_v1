// lib/attendance/services/stub/flutter_local_notifications_stub.dart
//
// Empty stub so the web build doesn't try to import the real package.

class FlutterLocalNotificationsPlugin {
  T? resolvePlatformSpecificImplementation<T>() => null;
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(dynamic channel) async {}
}

class AndroidNotificationChannel {
  final String id;
  final String name;
  final String? description;
  final dynamic importance;
  final bool playSound;
  final bool enableVibration;
  const AndroidNotificationChannel(
    this.id,
    this.name, {
    this.description,
    this.importance,
    this.playSound = true,
    this.enableVibration = true,
  });
}

class Importance {
  static const Importance low = Importance._('low');
  final String _value;
  const Importance._(this._value);
}
