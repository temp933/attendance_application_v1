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
// }
class ApiConfig {
  static const String baseUrl = 'http://192.168.29.104:5000/api';

  /// Set this once at app startup (e.g. after login) so every request
  /// automatically carries the correct tenant header.
  static String tenantId = '';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    if (tenantId.isNotEmpty) 'x-tenant-id': tenantId,
  };
}
