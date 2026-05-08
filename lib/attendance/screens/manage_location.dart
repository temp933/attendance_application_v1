import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'add_location_dialog.dart';
import '../providers/api_client.dart';

class ManageLocationPage extends StatefulWidget {
  const ManageLocationPage({super.key});

  @override
  State<ManageLocationPage> createState() => _ManageLocationPageState();
}

class _ManageLocationPageState extends State<ManageLocationPage> {
  List<Map<String, dynamic>> sites = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  // ─────────────────────────────
  // Load Sites
  // ─────────────────────────────
  Future<void> loadSites() async {
    try {
      final res = await ApiClient.get('/sites');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          sites = List<Map<String, dynamic>>.from(data);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  // ─────────────────────────────
  // Add Site
  // ─────────────────────────────
  Future<void> saveSite(
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closedPoints = [...points];

    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    final body = jsonEncode({
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });

    await ApiClient.post('/sites', {
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });

    loadSites();
  }

  // ─────────────────────────────
  // Update Site
  // ─────────────────────────────
  Future<void> updateSite(
    int id,
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closedPoints = [...points];

    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    final body = jsonEncode({
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });

    await ApiClient.put('/sites/$id', {
      "site_name": name,
      "polygon_json": closedPoints
          .map((e) => {"lat": e.latitude, "lng": e.longitude})
          .toList(),
      "start_date": start.toIso8601String().split("T")[0],
      "end_date": end.toIso8601String().split("T")[0],
    });
    loadSites();
  }

  // ─────────────────────────────
  void openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(onSave: saveSite),
    );
  }

  void openEditDialog(Map site) {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(
        existingSite: site,
        onSave: (name, points, start, end) {
          updateSite(site["id"], name, points, start, end);
        },
      ),
    );
  }

  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Locations"),
      //   backgroundColor: Colors.teal,
      // ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sites.isEmpty
          ? const Center(child: Text("No locations available"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sites.length,
              itemBuilder: (context, i) {
                final s = sites[i];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(s["site_name"]),
                    subtitle: Text(
                      "From ${s["start_date"]} → ${s["end_date"]}",
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => openEditDialog(s),
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
