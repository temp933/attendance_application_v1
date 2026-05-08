import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'login.dart';

class EmployeeHome extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  const EmployeeHome({
    super.key,
    required this.employeeId,
    this.employeeName = '',
  });

  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  final _service = FlutterBackgroundService();

  String status = "Initializing...";
  String? currentSiteName;
  LatLng? currentPosition;
  double? currentAccuracy;
  bool isGoodAccuracy = true;
  DateTime? startTime;
  DateTime? endTime;

  bool isRunning = false;
  bool isDoneForDay = false;
  bool isLoading = true;

  // Site visit log — each row = one visit to one site
  List<Map<String, dynamic>> todayLogs = [];
  Timer? _logsRefreshTimer;

  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _locationSub?.cancel();
    _logsRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _requestPermissions();

    try {
      final data = await ApiService.getTodayStatus(widget.employeeId);

      if (data["status"] == "completed") {
        await _fetchTodayLogs();
        setState(() {
          isDoneForDay = true;
          isRunning = false;
          status = "✅ Work Done for Today";
          isLoading = false;
        });
        return;
      }

      if (data["status"] == "in_progress") {
        try {
          final List<dynamic> logs = await ApiService.getTodayLogs(
            widget.employeeId,
          );
          if (logs.isNotEmpty) {
            final String? firstInStr = logs.first["in_time"] as String?;
            if (firstInStr != null) {
              startTime = DateTime.tryParse(firstInStr);
            }
          }
        } catch (_) {
          startTime = DateTime.now();
        }
        isRunning = true;
        status = "Resuming tracking...";
      }
    } catch (e) {
      debugPrint("Status check error: $e");
    }

    final running = await _service.isRunning();
    if (!running && isRunning) await _service.startService();

    await _fetchTodayLogs();

    // Refresh logs every 10 seconds while working to show live out_time updates
    _logsRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (isRunning && !isDoneForDay) await _fetchTodayLogs();
    });

    // Listen: site in/out changes
    _statusSub = _service.on("status_update").listen((event) {
      if (!mounted || event == null) return;
      setState(() {
        final s = event["status"] as String;
        if (s == "IN") {
          status = "IN: ${event["site_name"]}";
          currentSiteName = event["site_name"] as String?;
        } else {
          status = "Tracking... (outside sites)";
          currentSiteName = null;
        }
        if (event["lat"] != null) {
          currentPosition = LatLng(
            event["lat"] as double,
            event["lng"] as double,
          );
          currentAccuracy = (event["accuracy"] as num).toDouble();
          isGoodAccuracy = true;
        }
      });
      // Refresh logs when site changes so the new row appears immediately
      _fetchTodayLogs();
    });

    // Listen: every GPS tick — updates coordinates only
    _locationSub = _service.on("location_update").listen((event) {
      if (!mounted || event == null) return;
      setState(() {
        currentPosition = LatLng(
          event["lat"] as double,
          event["lng"] as double,
        );
        currentAccuracy = (event["accuracy"] as num).toDouble();
        isGoodAccuracy = event["good"] as bool? ?? true;
      });
    });

    setState(() => isLoading = false);
  }

  Future<void> _fetchTodayLogs() async {
    try {
      final List<dynamic> logs = await ApiService.getTodayLogs(
        widget.employeeId,
      );
      if (mounted) {
        setState(() {
          todayLogs = logs.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint("Logs fetch error: $e");
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Geolocator.requestPermission();
  }

  Future<void> startWork() async {
    setState(() {
      isLoading = true;
      status = "Starting...";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("employee_id", widget.employeeId);
      await prefs.setBool("is_done_for_day_${widget.employeeId}", false);

      startTime = DateTime.now();
      isRunning = true;

      await _service.startService();

      setState(() {
        status = "Tracking...";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        status = "Error starting: $e";
        isRunning = false;
        isLoading = false;
      });
    }
  }

  Future<void> endWork() async {
    setState(() => isLoading = true);

    try {
      final Completer<void> endConfirmed = Completer<void>();
      StreamSubscription? confirmSub;

      confirmSub = _service.on("end_day_done").listen((_) {
        if (!endConfirmed.isCompleted) endConfirmed.complete();
        confirmSub?.cancel();
      });

      _service.invoke("end_day");

      await endConfirmed.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => confirmSub?.cancel(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("is_done_for_day_${widget.employeeId}", true);

      endTime = DateTime.now();
      isRunning = false;
      isDoneForDay = true;
      _logsRefreshTimer?.cancel();

      await _fetchTodayLogs(); // Final refresh to show real out_time

      setState(() {
        status = "✅ Work Done for Today";
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        status = "Error ending work";
        isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  String _calcWorkingHours() {
    if (startTime == null) return "--";
    final end = endTime ?? DateTime.now();
    final diff = end.difference(startTime!);
    return "${diff.inHours}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m";
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return "--";
    if (minutes < 60) return "${minutes}m";
    return "${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m";
  }

  String _accuracyLabel() {
    if (currentAccuracy == null) return "Acquiring...";
    final a = currentAccuracy!;
    if (a <= 10) return "±${a.toStringAsFixed(0)}m (Excellent)";
    if (a <= 20) return "±${a.toStringAsFixed(0)}m (Good)";
    if (a <= 40) return "±${a.toStringAsFixed(0)}m (Fair)";
    return "±${a.toStringAsFixed(0)}m (Poor)";
  }

  Color _accuracyColor() {
    if (currentAccuracy == null) return Colors.grey;
    if (!isGoodAccuracy) return Colors.orange;
    if (currentAccuracy! <= 10) return Colors.green;
    if (currentAccuracy! <= 20) return Colors.lightGreen;
    if (currentAccuracy! <= 40) return Colors.orange;
    return Colors.red;
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: Text(
          isRunning
              ? "Tracking is active. End work and logout?"
              : "Are you sure you want to logout?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (isRunning) {
                await endWork();
              } else {
                _service.invoke("stop");
              }
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = isDoneForDay
        ? Colors.teal
        : status.startsWith("IN")
        ? Colors.green
        : status.startsWith("❌")
        ? Colors.red
        : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employeeName.isNotEmpty
              ? "Hi, ${widget.employeeName}"
              : "Employee Attendance",
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── STATUS CARD ──────────────────────────────────────────────────
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (isLoading)
                      const CircularProgressIndicator()
                    else
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                    const SizedBox(height: 10),

                    // Live coordinates
                    if (currentPosition != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 13,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${currentPosition!.latitude.toStringAsFixed(6)},  "
                            "${currentPosition!.longitude.toStringAsFixed(6)}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isGoodAccuracy
                                ? Icons.gps_fixed
                                : Icons.gps_not_fixed,
                            size: 13,
                            color: _accuracyColor(),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _accuracyLabel(),
                            style: TextStyle(
                              fontSize: 11,
                              color: _accuracyColor(),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else if (isRunning)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Acquiring GPS...",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),

                    if (isRunning && !isDoneForDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "Working: ${_calcWorkingHours()}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                    if (isDoneForDay)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "Total: ${_calcWorkingHours()}  👋 Come back tomorrow!",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── TODAY'S SITE VISITS ──────────────────────────────────────────
            // Shows each site visit as a row with in/out time and duration.
            // Updates every 10 seconds while working.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        "Today's Site Visits",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const Spacer(),
                      if (isRunning && !isDoneForDay)
                        GestureDetector(
                          onTap: _fetchTodayLogs,
                          child: Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: todayLogs.isEmpty
                        ? Center(
                            child: Text(
                              isRunning
                                  ? "No site visits yet today"
                                  : "No attendance recorded today",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: todayLogs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final log = todayLogs[index];
                              final String siteName =
                                  log["site_name"] as String? ?? "Unknown";
                              final String inTime =
                                  log["in_time"] as String? ?? "--";
                              final String? outTime =
                                  log["out_time"] as String?;
                              final int? durationMin =
                                  log["duration_minutes"] as int?;
                              final bool isOpen = outTime == null;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isOpen
                                        ? Colors.green.shade200
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Site indicator dot
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isOpen
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Site name + times
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            siteName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.login,
                                                size: 12,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                inTime,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.logout,
                                                size: 12,
                                                color: isOpen
                                                    ? Colors.orange
                                                    : Colors.red,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                isOpen
                                                    ? "Active now"
                                                    : (outTime ?? "--"),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isOpen
                                                      ? Colors.orange
                                                      : Colors.red,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Duration badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOpen
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _formatDuration(durationMin),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOpen
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── START / END BUTTONS ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("START"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (isRunning || isDoneForDay || isLoading)
                        ? null
                        : startWork,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text("END"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (isRunning && !isLoading) ? endWork : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
