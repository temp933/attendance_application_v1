import '../models/travel_onsite_model.dart';

class TravelService {
  // Current assigned travel
  Future<TravelOnsiteModel?> getCurrentTravel() async {
    // TODO: Replace with API / Database
    await Future.delayed(const Duration(seconds: 1));

    return TravelOnsiteModel(
      location: "Bangalore Office",
      duration: "12 Mar 2025 - 20 Mar 2025",
      purpose: "Client Project Deployment",
      status: "Approved",
    );
  }

  // Travel history
  Future<List<TravelOnsiteModel>> getTravelHistory() async {
    // TODO: Replace with API / Database
    await Future.delayed(const Duration(seconds: 1));

    return [
      TravelOnsiteModel(
        location: "Hyderabad",
        duration: "05 Jan 2025 - 10 Jan 2025",
        purpose: "Internal Training",
        status: "Completed",
      ),
      TravelOnsiteModel(
        location: "Chennai",
        duration: "18 Feb 2026 - 22 Feb 2026",
        purpose: "Client Meeting",
        status: "Approved",
      ),
    ];
  }
}
