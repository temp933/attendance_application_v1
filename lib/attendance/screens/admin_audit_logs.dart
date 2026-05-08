// // // import 'package:flutter/material.dart';
// // // import '../services/audit_service.dart';

// // // class AdminAuditLogsScreen extends StatefulWidget {
// // //   const AdminAuditLogsScreen({super.key});

// // //   @override
// // //   State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
// // // }

// // // class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
// // //   final AuditService _auditService = AuditService();

// // //   @override
// // //   void initState() {
// // //     super.initState();

// // //     // Example dummy logs
// // //     _auditService.addLog(
// // //       userName: 'Admin1',
// // //       actionType: 'CREATE',
// // //       entity: 'Employee',
// // //       entityId: '101',
// // //       newValue: 'Name: John Doe, Salary: 50000',
// // //     );

// // //     _auditService.addLog(
// // //       userName: 'Admin2',
// // //       actionType: 'UPDATE',
// // //       entity: 'Employee',
// // //       entityId: '102',
// // //       oldValue: 'Salary: 40000',
// // //       newValue: 'Salary: 45000',
// // //     );
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final size = MediaQuery.of(context).size;
// // //     final bool isDesktop = size.width >= 900;
// // //     final double horizontalPadding = isDesktop ? size.width * 0.15 : 16;
// // //     final double spacing = isDesktop ? 20 : 12;

// // //     final logs = _auditService.logs.reversed.toList(); // newest first

// // //     return Scaffold(
// // //       appBar: AppBar(title: const Text('Admin Audit Logs')),
// // //       body: Padding(
// // //         padding: EdgeInsets.symmetric(
// // //           horizontal: horizontalPadding,
// // //           vertical: spacing,
// // //         ),
// // //         child: logs.isEmpty
// // //             ? const Center(child: Text('No audit logs yet'))
// // //             : ListView.builder(
// // //                 itemCount: logs.length,
// // //                 itemBuilder: (context, index) {
// // //                   final log = logs[index];
// // //                   Color iconColor;
// // //                   IconData iconData;

// // //                   switch (log.actionType) {
// // //                     case 'DELETE':
// // //                       iconData = Icons.delete;
// // //                       iconColor = Colors.red;
// // //                       break;
// // //                     case 'UPDATE':
// // //                       iconData = Icons.edit;
// // //                       iconColor = Colors.orange;
// // //                       break;
// // //                     case 'CREATE':
// // //                       iconData = Icons.add;
// // //                       iconColor = Colors.green;
// // //                       break;
// // //                     default:
// // //                       iconData = Icons.info;
// // //                       iconColor = Colors.blue;
// // //                   }

// // //                   return Card(
// // //                     margin: EdgeInsets.only(bottom: spacing),
// // //                     shape: RoundedRectangleBorder(
// // //                       borderRadius: BorderRadius.circular(16),
// // //                     ),
// // //                     elevation: 2,
// // //                     child: Padding(
// // //                       padding: EdgeInsets.all(isDesktop ? 20 : 12),
// // //                       child: Row(
// // //                         crossAxisAlignment: CrossAxisAlignment.start,
// // //                         children: [
// // //                           Icon(
// // //                             iconData,
// // //                             color: iconColor,
// // //                             size: isDesktop ? 32 : 24,
// // //                           ),
// // //                           SizedBox(width: spacing),
// // //                           Expanded(
// // //                             child: Column(
// // //                               crossAxisAlignment: CrossAxisAlignment.start,
// // //                               children: [
// // //                                 Text(
// // //                                   '${log.userName} performed ${log.actionType}',
// // //                                   style: TextStyle(
// // //                                     fontSize: isDesktop ? 18 : 14,
// // //                                     fontWeight: FontWeight.w600,
// // //                                   ),
// // //                                 ),
// // //                                 SizedBox(height: 4),
// // //                                 Text(
// // //                                   'Entity: ${log.entity} (ID: ${log.entityId})',
// // //                                   style: TextStyle(
// // //                                     fontSize: isDesktop ? 16 : 12,
// // //                                   ),
// // //                                 ),
// // //                                 if (log.oldValue.isNotEmpty)
// // //                                   Text(
// // //                                     'Old: ${log.oldValue}',
// // //                                     style: TextStyle(
// // //                                       fontSize: isDesktop ? 16 : 12,
// // //                                     ),
// // //                                   ),
// // //                                 if (log.newValue.isNotEmpty)
// // //                                   Text(
// // //                                     'New: ${log.newValue}',
// // //                                     style: TextStyle(
// // //                                       fontSize: isDesktop ? 16 : 12,
// // //                                     ),
// // //                                   ),
// // //                                 Text(
// // //                                   'Time: ${log.timestamp.toLocal()}',
// // //                                   style: TextStyle(
// // //                                     fontSize: isDesktop ? 14 : 12,
// // //                                     color: Colors.grey.shade600,
// // //                                   ),
// // //                                 ),
// // //                               ],
// // //                             ),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                   );
// // //                 },
// // //               ),
// // //       ),
// // //       floatingActionButton: FloatingActionButton(
// // //         onPressed: () {
// // //           setState(() {
// // //             _auditService.addLog(
// // //               userName: 'Admin3',
// // //               actionType: 'LOGIN',
// // //               entity: 'System',
// // //               entityId: '0',
// // //               notes: 'Logged in',
// // //             );
// // //           });
// // //         },
// // //         child: const Icon(Icons.add),
// // //       ),
// // //     );
// // //   }
// // // }
// // import 'package:flutter/material.dart';
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:latlong2/latlong.dart';

// // class DrawCampusOSM extends StatefulWidget {
// //   const DrawCampusOSM({super.key});

// //   @override
// //   State<DrawCampusOSM> createState() => _DrawCampusOSMState();
// // }

// // class _DrawCampusOSMState extends State<DrawCampusOSM> {
// //   final List<LatLng> points = [];

// //   void _onTap(TapPosition tapPosition, LatLng latlng) {
// //     setState(() {
// //       points.add(latlng);
// //     });

// //     // 🔥 Print to terminal
// //     print("New Point: ${latlng.latitude}, ${latlng.longitude}");
// //     print("All Points:");
// //     for (var p in points) {
// //       print("${p.latitude}, ${p.longitude}");
// //     }
// //     print("------------");
// //   }

// //   void _clear() {
// //     setState(() {
// //       points.clear();
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("Draw Campus (OpenStreetMap)"),
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.delete),
// //             onPressed: _clear,
// //           )
// //         ],
// //       ),
// //       body: FlutterMap(
// //         options: MapOptions(
// //           initialCenter: LatLng(13.0827, 80.2707), // Chennai
// //           initialZoom: 15,
// //           onTap: _onTap,
// //         ),
// //         children: [
// //           TileLayer(
// //             urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
// //             userAgentPackageName: "com.example.app",
// //           ),
// //           PolygonLayer(
// //             polygons: [
// //               if (points.length >= 3)
// //                 Polygon(
// //                   points: points,
// //                   color: Colors.blue.withOpacity(0.3),
// //                   borderColor: Colors.blue,
// //                   borderStrokeWidth: 3,
// //                 ),
// //             ],
// //           ),
// //           MarkerLayer(
// //             markers: points
// //                 .map(
// //                   (p) => Marker(
// //                     point: p,
// //                     width: 10,
// //                     height: 10,
// //                     child: const Icon(Icons.location_on, color: Colors.red),
// //                   ),
// //                 )
// //                 .toList(),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:http/http.dart' as http;
// import 'package:geolocator/geolocator.dart';

// class DrawCampusOSM extends StatefulWidget {
//   const DrawCampusOSM({super.key});

//   @override
//   State<DrawCampusOSM> createState() => _DrawCampusOSMState();
// }

// class _DrawCampusOSMState extends State<DrawCampusOSM> {
//   final List<LatLng> points = [];
//   final TextEditingController searchController = TextEditingController();
//   final MapController mapController = MapController();

//   // 🔍 Search place
//   Future<void> _searchPlace(String query) async {
//     if (query.isEmpty) return;

//     final url = Uri.parse(
//       "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1",
//     );

//     final response = await http.get(
//       url,
//       headers: {"User-Agent": "flutter_app"},
//     );

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       if (data.isNotEmpty) {
//         final lat = double.parse(data[0]["lat"]);
//         final lon = double.parse(data[0]["lon"]);
//         mapController.move(LatLng(lat, lon), 16);
//       } else {
//         _showMessage("Place not found");
//       }
//     }
//   }

//   // 📍 Move to current location
//   Future<void> _goToCurrentLocation() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       _showMessage("Location service is disabled");
//       return;
//     }

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//     }

//     if (permission == LocationPermission.deniedForever) {
//       _showMessage("Location permission permanently denied");
//       return;
//     }

//     final position = await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );

//     mapController.move(LatLng(position.latitude, position.longitude), 17);
//   }

//   // 🖱️ Tap to add point
//   void _onTap(TapPosition tapPosition, LatLng latlng) {
//     setState(() {
//       points.add(latlng);
//     });

//     print("New Point: ${latlng.latitude}, ${latlng.longitude}");
//     print("All Points:");
//     for (var p in points) {
//       print("${p.latitude}, ${p.longitude}");
//     }
//     print("------------");
//   }

//   void _clear() {
//     setState(() {
//       points.clear();
//     });
//   }

//   void _showMessage(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Draw Campus Boundary")),
//       body: Column(
//         children: [
//           // 🔍 Search + GPS Row
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: searchController,
//                     decoration: InputDecoration(
//                       hintText: "Search place (eg: IIT Madras)",
//                       prefixIcon: const Icon(Icons.search),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     onSubmitted: _searchPlace,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 IconButton(
//                   icon: const Icon(Icons.my_location, color: Colors.blue),
//                   onPressed: _goToCurrentLocation,
//                   tooltip: "Go to current location",
//                 ),
//               ],
//             ),
//           ),

//           // 🗺️ Map
//           Expanded(
//             child: FlutterMap(
//               mapController: mapController,
//               options: MapOptions(
//                 initialCenter: LatLng(13.0827, 80.2707),
//                 initialZoom: 15,
//                 onTap: _onTap,
//               ),
//               children: [
//                 TileLayer(
//                   urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
//                   userAgentPackageName: "com.example.app",
//                 ),
//                 PolygonLayer(
//                   polygons: [
//                     if (points.length >= 3)
//                       Polygon(
//                         points: points,
//                         color: Colors.blue.withOpacity(0.3),
//                         borderColor: Colors.blue,
//                         borderStrokeWidth: 3,
//                       ),
//                   ],
//                 ),
//                 MarkerLayer(
//                   markers: points
//                       .map(
//                         (p) => Marker(
//                           point: p,
//                           width: 10,
//                           height: 10,
//                           child: const Icon(
//                             Icons.location_on,
//                             color: Colors.red,
//                           ),
//                         ),
//                       )
//                       .toList(),
//                 ),
//               ],
//             ),
//           ),

//           // 🧹 Clear button
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: ElevatedButton.icon(
//               onPressed: _clear,
//               icon: const Icon(Icons.delete),
//               label: const Text("Clear Boundary"),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class DrawCampusOSM extends StatefulWidget {
  const DrawCampusOSM({super.key});

  @override
  State<DrawCampusOSM> createState() => _DrawCampusOSMState();
}

class _DrawCampusOSMState extends State<DrawCampusOSM> {
  final List<LatLng> points = [];
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool isFinished = false;

  LatLng center = LatLng(13.0827, 80.2707);

  void _onTap(TapPosition tapPosition, LatLng latlng) {
    if (isFinished) return; // ❌ stop adding after finish

    setState(() {
      points.add(latlng);
    });

    print("New Point: ${latlng.latitude}, ${latlng.longitude}");
  }

  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0;

    const double earthRadius = 6378137; // meters

    List<Offset> meters = points.map((p) {
      double x = _degToRad(p.longitude) * earthRadius;
      double y = _degToRad(p.latitude) * earthRadius;
      return Offset(x, y);
    }).toList();

    double area = 0;
    for (int i = 0; i < meters.length; i++) {
      int j = (i + 1) % meters.length;
      area += (meters[i].dx * meters[j].dy) - (meters[j].dx * meters[i].dy);
    }

    return area.abs() / 2;
  }

  void _clear() {
    setState(() {
      points.clear();
      isFinished = false;
    });
  }

  /// 📍 Current Location
  Future<void> _goToCurrentLocation() async {
    await Geolocator.requestPermission();
    Position pos = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(pos.latitude, pos.longitude), 17);
  }

  /// 🔍 Search place
  Future<void> _searchPlace(String place) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$place&format=json",
    );

    final response = await http.get(
      url,
      headers: {"User-Agent": "Flutter App"},
    );

    final data = jsonDecode(response.body);
    if (data.isNotEmpty) {
      double lat = double.parse(data[0]["lat"]);
      double lon = double.parse(data[0]["lon"]);
      _mapController.move(LatLng(lat, lon), 16);
    }
  }

  /// 📏 Distance between 2 points
  double _distance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000; // meters
    double dLat = _degToRad(p2.latitude - p1.latitude);
    double dLon = _degToRad(p2.longitude - p1.longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(p1.latitude)) *
            cos(_degToRad(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * pi / 180;

  /// ✅ Finish Drawing
  void _finishDrawing() {
    if (points.length < 3) {
      print("❌ Need at least 3 points to form campus");
      return;
    }

    setState(() {
      isFinished = true;
    });

    print("======== FINAL CAMPUS POINTS ========");
    for (var p in points) {
      print("${p.latitude}, ${p.longitude}");
    }

    double totalDistance = 0;

    for (int i = 0; i < points.length; i++) {
      LatLng p1 = points[i];
      LatLng p2 = (i == points.length - 1) ? points[0] : points[i + 1];
      totalDistance += _distance(p1, p2);
    }

    print("====================================");
    print("TOTAL CAMPUS BOUNDARY DISTANCE:");
    print("${totalDistance.toStringAsFixed(2)} meters");
    print("${(totalDistance / 1000).toStringAsFixed(2)} km");
    print("====================================");

    double area = _calculatePolygonArea(points);

    print("AREA:");
    print("${area.toStringAsFixed(2)} sq.m");
    print("${(area / 4046.86).toStringAsFixed(2)} acres");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Campus (OSM)"),
        actions: [
          IconButton(icon: const Icon(Icons.delete), onPressed: _clear),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          /// 🔍 Search
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search place...",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchPlace(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          /// 🗺️ Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.app",
                ),

                PolygonLayer(
                  polygons: [
                    if (points.length >= 3)
                      Polygon(
                        points: points,
                        color: Colors.blue.withOpacity(0.3),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 3,
                      ),
                  ],
                ),

                MarkerLayer(
                  markers: points
                      .map(
                        (p) => Marker(
                          point: p,
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          /// ✅ Finish Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text("FINISH MARKING"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _finishDrawing,
            ),
          ),
        ],
      ),
    );
  }
}
