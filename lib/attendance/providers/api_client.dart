import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // add to pubspec: http_parser: ^4.0.0
import 'api_config.dart';

class ApiClient {
  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    return http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {...ApiConfig.headers, ...?headers},
    );
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {...ApiConfig.headers, ...?headers},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    return http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {...ApiConfig.headers, ...?headers},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {...ApiConfig.headers, ...?headers},
    );
  }

  static Future<http.Response> patch(
    String path, {
    String? body,
    Map<String, String>? headers,
  }) async {
    return http.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {...ApiConfig.headers, ...?headers},
      body: body,
    );
  }

  /// Sends a multipart/form-data POST request.
  ///
  /// [path]       — API path, e.g. '/face_emb_vector'
  /// [fields]     — String key-value pairs sent as form fields
  /// [fileField]  — The form field name for the file, e.g. 'photo'
  /// [fileBytes]  — Raw bytes of the file
  /// [fileName]   — File name including extension, e.g. 'face.jpg'
  /// [mimeType]   — MIME type string, e.g. 'image/jpeg' or 'image/png'
  static Future<http.Response> multipartPost(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    // Auth + tenant headers (exclude Content-Type — multipart sets it automatically)
    final baseHeaders = Map<String, String>.from(ApiConfig.headers)
      ..remove('Content-Type');
    request.headers.addAll(baseHeaders);

    // Form fields
    request.fields.addAll(fields);

    // File
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }
}
