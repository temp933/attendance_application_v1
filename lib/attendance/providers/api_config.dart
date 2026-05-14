// class ApiConfig {
//   static const String baseUrl =
//       "https://unrivaled-headset-unmanaged.ngrok-free.dev";

//   static const Map<String, String> headers = {
//     'Content-Type': 'application/json',
//     'ngrok-skip-browser-warning': 'true',
//   };
// // }
// class ApiConfig {
//   static const String baseUrl = 'http://192.168.29.104:5000/api';

//   static Map<String, String> get headers => {
//     'Content-Type': 'application/json',
//     'ngrok-skip-browser-warning': 'true',
//   };
// // }
// class ApiConfig {
//   // static const String baseUrl = 'http://192.168.29.104:5000/api';
//   static const String baseUrl = 'http://192.168.1.12:5000/api';

//   /// Set this once at app startup (e.g. after login) so every request
//   /// automatically carries the correct tenant header.
//   static String tenantId = '';

//   static Map<String, String> get headers => {
//     'Content-Type': 'application/json',
//     'ngrok-skip-browser-warning': 'true',
//     if (tenantId.isNotEmpty) 'x-tenant-id': tenantId,
//   };
// }
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String baseUrl = 'http://192.168.1.12:5000/api';
  static String tenantId = '';
  static String _token = '';

  static void setToken(String token) => _token = token;

  // Call this once at app startup (after splash/session restore)
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('session_token') ?? '';
    tenantId = prefs.getString('tenantId') ?? '';
  }

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (tenantId.isNotEmpty) 'x-tenant-id': tenantId,
    if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
  };
}
