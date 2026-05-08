// class ApiConfig {
//   static const String baseUrl =
//       "https://unrivaled-headset-unmanaged.ngrok-free.dev";

//   static const Map<String, String> headers = {
//     'Content-Type': 'application/json',
//     'ngrok-skip-browser-warning': 'true',
//   };
// }
class ApiConfig {
  static const String baseUrl = 'http://192.168.29.104:5000';

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };
}
