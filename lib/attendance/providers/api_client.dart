// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'api_config.dart';

// class ApiClient {
//   static final Map<String, String> _headers = ApiConfig.headers;

//   // ───────────────── GET ─────────────────
//   static Future<http.Response> get(String path) async {
//     return await http.get(
//       Uri.parse('${ApiConfig.baseUrl}$path'),
//       headers: _headers,
//     );
//   }

//   // ───────────────── POST ─────────────────
//   static Future<http.Response> post(
//     String path,
//     Map<String, dynamic> body,
//   ) async {
//     return await http.post(
//       Uri.parse('${ApiConfig.baseUrl}$path'),
//       headers: _headers,
//       body: jsonEncode(body),
//     );
//   }

//   // ───────────────── PUT ─────────────────
//   static Future<http.Response> put(
//     String path,
//     Map<String, dynamic> body,
//   ) async {
//     return await http.put(
//       Uri.parse('${ApiConfig.baseUrl}$path'),
//       headers: _headers,
//       body: jsonEncode(body),
//     );
//   }

//   // ───────────────── DELETE ─────────────────
//   static Future<http.Response> delete(String path) async {
//     return await http.delete(
//       Uri.parse('${ApiConfig.baseUrl}$path'),
//       headers: _headers,
//     );
//   }
// }
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  static final Map<String, String> _defaultHeaders = ApiConfig.headers;

  // ───────────────── GET ─────────────────
  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {..._defaultHeaders, ...?headers},
    );
  }

  // ───────────────── POST ─────────────────
  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {..._defaultHeaders, ...?headers},
      body: jsonEncode(body),
    );
  }

  // ───────────────── PUT ─────────────────
  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {..._defaultHeaders, ...?headers},
      body: jsonEncode(body),
    );
  }

  // ───────────────── DELETE ─────────────────
  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {..._defaultHeaders, ...?headers},
    );
  }
}
  