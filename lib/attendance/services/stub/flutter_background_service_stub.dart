// lib/attendance/services/stub/flutter_background_service_stub.dart
//
// Empty stub so the web build doesn't try to import the real package.
// The real package is only used on Android/iOS via conditional import.

class FlutterBackgroundService {
  Future<bool> isRunning() async => false;
  Future<void> startService() async {}
  void invoke(String method, [Map<String, dynamic>? args]) {}
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
}

abstract class ServiceInstance {
  void invoke(String method, [Map<String, dynamic>? args]);
  Stream<Map<String, dynamic>?> on(String method);
  void stopSelf();
}

class AndroidServiceInstance extends ServiceInstance {
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}
  @override
  Stream<Map<String, dynamic>?> on(String method) => const Stream.empty();
  @override
  void stopSelf() {}
  void setAsForegroundService() {}
  void setForegroundNotificationInfo({String? title, String? content}) {}
}

class AndroidConfiguration {
  const AndroidConfiguration({
    required dynamic onStart,
    bool autoStart = false,
    bool isForegroundMode = false,
    String? notificationChannelId,
    String? initialNotificationTitle,
    String? initialNotificationContent,
    int? foregroundServiceNotificationId,
    bool? autoStartOnBoot,
  });
}

class IosConfiguration {
  const IosConfiguration({
    bool autoStart = false,
    dynamic onForeground,
    dynamic onBackground,
  });
}
