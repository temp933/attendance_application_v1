import 'package:flutter/material.dart';
import '../models/travel_onsite_model.dart';
import '../services/travel_service.dart';

class TravelOnsiteScreen extends StatelessWidget {
  const TravelOnsiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final travelService = TravelService();
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel / Onsite"),
        backgroundColor: Colors.indigo,
      ),

      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder(
        future: Future.wait([
          travelService.getCurrentTravel(),
          travelService.getTravelHistory(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("Something went wrong"));
          }

          final TravelOnsiteModel? currentTravel =
              snapshot.data![0] as TravelOnsiteModel?;

          final List<TravelOnsiteModel> history =
              snapshot.data![1] as List<TravelOnsiteModel>;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? size.width * 0.15 : 16,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //  CURRENT TRAVEL 
                Text(
                  "Assigned Travel / Onsite Details",
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                currentTravel == null
                    ? const Text("No active travel assigned")
                    : _currentTravelCard(currentTravel, isDesktop),

                const SizedBox(height: 32),

                //  HISTORY 
                Text(
                  "Travel / Onsite History",
                  style: TextStyle(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                history.isEmpty
                    ? const Text("No travel history found")
                    : Column(
                        children: history
                            .map((travel) => _historyCard(travel, isDesktop))
                            .toList(),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // CURRENT CARD 
  Widget _currentTravelCard(TravelOnsiteModel travel, bool isDesktop) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          children: [
            _infoRow(Icons.location_on, "Location", travel.location, isDesktop),
            const Divider(),
            _infoRow(Icons.date_range, "Duration", travel.duration, isDesktop),
            const Divider(),
            _infoRow(Icons.work_outline, "Purpose", travel.purpose, isDesktop),
          ],
        ),
      ),
    );
  }

  // ================= HISTORY CARD =================
  Widget _historyCard(TravelOnsiteModel travel, bool isDesktop) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: isDesktop ? 12 : 8,
        ),
        leading: const Icon(
          Icons.directions_car_outlined,
          color: Colors.indigo,
          size: 28,
        ),
        title: Text(
          travel.location,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(travel.duration),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor(travel.status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            travel.status,
            style: TextStyle(
              color: _statusColor(travel.status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ================= COMMON INFO ROW =================
  Widget _infoRow(IconData icon, String label, String value, bool isDesktop) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo, size: isDesktop ? 28 : 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isDesktop ? 14 : 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= STATUS COLOR =================
  static Color _statusColor(String status) {
    switch (status) {
      case "Completed":
        return Colors.green;
      case "Approved":
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}
