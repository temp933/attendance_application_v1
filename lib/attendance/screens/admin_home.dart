import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_location_dialog.dart';
import 'login.dart'; // 👈 your login screen
import '../providers/api_config.dart';

const String _baseUrl = ApiConfig.baseUrl;

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  List<Map<String, dynamic>> sites = [];
  bool loading = true;

  final String baseUrl = "$_baseUrl/sites";

  @override
  void initState() {
    super.initState();
    loadSites();
  }

  // ─────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────
  void logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────
  Future<void> loadSites() async {
    try {
      final res = await http.get(Uri.parse(baseUrl));
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

  // In admin_home.dart — saveSite and updateSite
  Future<void> saveSite(
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    // ✅ Close the polygon by repeating first point at end
    final closedPoints = [...points];
    if (closedPoints.first.latitude != closedPoints.last.latitude ||
        closedPoints.first.longitude != closedPoints.last.longitude) {
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

    await http.post(
      Uri.parse(baseUrl),
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    loadSites();
  }

  // Same fix for updateSite
  Future<void> updateSite(
    int id,
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closedPoints = [...points];
    if (closedPoints.first.latitude != closedPoints.last.latitude ||
        closedPoints.first.longitude != closedPoints.last.longitude) {
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

    await http.put(
      Uri.parse("$baseUrl/$id"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    loadSites();
  }

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

  // ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin – Sites"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddDialog,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : sites.isEmpty
          ? const Center(child: Text("No sites added yet"))
          : ListView.builder(
              itemCount: sites.length,
              itemBuilder: (context, i) {
                final s = sites[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
    );
  }
}
