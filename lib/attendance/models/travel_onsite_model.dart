class TravelOnsiteModel {
  final String location;
  final String duration;
  final String purpose;
  final String status;

  TravelOnsiteModel({
    required this.location,
    required this.duration,
    required this.purpose,
    required this.status,
  });

  factory TravelOnsiteModel.fromJson(Map<String, dynamic> json) {
    return TravelOnsiteModel(
      location: json['location'] ?? '',
      duration: json['duration'] ?? '',
      purpose: json['purpose'] ?? '',
      status: json['status'] ?? '',
    );
  }
}
