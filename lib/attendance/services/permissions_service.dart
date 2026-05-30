import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

class PermissionsService {
  static Future<List<Map<String, dynamic>>> getMyPermissions() async {
    try {
      final res = await ApiClient.get('/role-permissions/my-permissions');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return List<Map<String, dynamic>>.from(body['permissions'] as List);
        }
      }
    } catch (e) {
      debugPrint('[PermissionsService] error: $e');
    }
    return [];
  }
}
