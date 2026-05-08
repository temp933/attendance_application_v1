import 'dart:convert';
import '../models/location_modules.dart';
import '../providers/api_client.dart';

class LocationService {
  Future<List<LocationManager>> fetchLocations() async {
    final response = await ApiClient.get('/locations');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => LocationManager.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load locations");
    }
  }

  Future<void> addLocationToDb({
    required String nickName,
    required double latitude,
    required double longitude,
    required DateTime startDate,
    DateTime? endDate,
    String? contactPersonName,
    String? contactPersonNumber,
  }) async {
    final response = await ApiClient.post('/locations', {
      "nick_name": nickName,
      "latitude": latitude,
      "longitude": longitude,
      "start_date": startDate.toIso8601String(),
      "end_date": endDate?.toIso8601String(),
      "contact_person_name": contactPersonName ?? "",
      "contact_person_number": contactPersonNumber ?? "",
    });

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to add location: ${response.body}");
    }
  }
}
