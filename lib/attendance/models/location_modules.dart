// class LocationManager {
//   final int locationId;
//   final String nickName;
//   final double latitude;
//   final double longitude;
//   final DateTime startDate;
//   final DateTime? endDate;
//   final String? contactPersonName;
//   final String? contactPersonNumber;

//   LocationManager({
//     required this.locationId,
//     required this.nickName,
//     required this.latitude,
//     required this.longitude,
//     required this.startDate,
//     this.endDate,
//     this.contactPersonName,
//     this.contactPersonNumber,
//   });

//   factory LocationManager.fromJson(Map<String, dynamic> json) {
//     return LocationManager(
//       locationId: json['location_id'],
//       nickName: json['location_nick_name'],
//       latitude: double.parse(json['latitude'].toString()),
//       longitude: double.parse(json['longitude'].toString()),
//       startDate: DateTime.parse(json['start_date']),
//       endDate: json['end_date'] == null
//           ? null
//           : DateTime.parse(json['end_date']),
//       contactPersonName: json['contact_person_name'],
//       contactPersonNumber: json['contact_person_number'],
//     );
//   }
// }

class LocationManager {
  final int locationId;
  final String nickName;
  final double latitude;
  final double longitude;
  final DateTime startDate;
  final DateTime? endDate;
  final String? contactPersonName;
  final String? contactPersonNumber;

  LocationManager({
    required this.locationId,
    required this.nickName,
    required this.latitude,
    required this.longitude,
    required this.startDate,
    this.endDate,
    this.contactPersonName,
    this.contactPersonNumber,
  });

  factory LocationManager.fromJson(Map<String, dynamic> json) {
    return LocationManager(
      locationId: json['location_id'],
      nickName: json['location_nick_name'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date']),
      contactPersonName: json['contact_person_name'],
      contactPersonNumber: json['contact_person_number'],
    );
  }

  // ✅ FIX: Without these, List.contains() compares object identity (always false).
  //         DropdownButtonFormField needs value == one of items to show selection.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationManager &&
          runtimeType == other.runtimeType &&
          locationId == other.locationId;

  @override
  int get hashCode => locationId.hashCode;
}