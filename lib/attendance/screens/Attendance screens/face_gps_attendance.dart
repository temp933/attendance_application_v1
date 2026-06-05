import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/api_config.dart';
import 'face_verify_screen.dart';
import 'att_history.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const String _kAttendanceIdKey = 'gps_active_attendance_id';
const String _kCheckinTimeKey = 'gps_checkin_time';

/// Minimum confidence (%) from face verification required to proceed.
/// Your Python service already accepts distance < 0.45 (~55% confidence),
/// but we gate the UI at 50% to allow a small buffer.
const int _kMinFaceConfidence = 50;

// ─────────────────────────────────────────────────────────────────────────────
// Helper — MySQL DECIMAL columns come back as strings over the wire
// ─────────────────────────────────────────────────────────────────────────────
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceRecord {
  final int attendanceId;
  final String status;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final double? checkinLat;
  final double? checkinLng;
  final double? checkoutLat;
  final double? checkoutLng;
  final bool isLate;
  final int lateMinutes;
  final String? totalWorkTime;
  final String? remarks;

  const _AttendanceRecord({
    required this.attendanceId,
    required this.status,
    this.checkinTime,
    this.checkoutTime,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    this.isLate = false,
    this.lateMinutes = 0,
    this.totalWorkTime,
    this.remarks,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory _AttendanceRecord.fromJson(Map<String, dynamic> j) =>
      _AttendanceRecord(
        attendanceId: (j['attendance_id'] as num).toInt(),
        status: j['status'] as String? ?? 'active',
        checkinTime: j['checkin_time'] != null
            ? DateTime.tryParse(j['checkin_time'] as String)
            : null,
        checkoutTime: j['checkout_time'] != null
            ? DateTime.tryParse(j['checkout_time'] as String)
            : null,
        checkinLat: _toDouble(j['checkin_latitude']),
        checkinLng: _toDouble(j['checkin_longitude']),
        checkoutLat: _toDouble(j['checkout_latitude']),
        checkoutLng: _toDouble(j['checkout_longitude']),
        isLate: (j['is_late'] as num?)?.toInt() == 1,
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
        totalWorkTime: j['total_work_time'] as String?,
        remarks: j['remarks'] as String?,
      );
}

class _Policy {
  final String? officeInTime;
  final String? officeOutTime;
  final int lateAfterMinutes;

  const _Policy({
    this.officeInTime,
    this.officeOutTime,
    this.lateAfterMinutes = 0,
  });

  factory _Policy.fromJson(Map<String, dynamic> j) => _Policy(
    officeInTime: j['office_in_time'] as String?,
    officeOutTime: j['office_out_time'] as String?,
    lateAfterMinutes: (j['late_after_minutes'] as num?)?.toInt() ?? 0,
  );

  String? get inDisplay => _fmt(officeInTime);
  String? get outDisplay => _fmt(officeOutTime);

  static String? _fmt(String? t) {
    if (t == null) return null;
    final p = t.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, h, m));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class FaceGpsAttendanceScreen extends StatefulWidget {
  /// Pass the logged-in employee's ID so we can send it to the face-verify API.
  final int employeeId;

  const FaceGpsAttendanceScreen({super.key, required this.employeeId});

  @override
  State<FaceGpsAttendanceScreen> createState() =>
      _FaceGpsAttendanceScreenState();
}

class _FaceGpsAttendanceScreenState extends State<FaceGpsAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _actionLoading = false;

  _AttendanceRecord? _record;
  _Policy? _policy;

  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;

  // Live clock
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  // Pulse animation for active state
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _fetchToday();
    _fetchHistory();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Network ────────────────────────────────────────────────────────────────
  Future<void> _fetchToday() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/face/today'),
        headers: ApiConfig.headers,
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        setState(() {
          _record = body['record'] != null
              ? _AttendanceRecord.fromJson(
                  body['record'] as Map<String, dynamic>,
                )
              : null;
          _policy = body['policy'] != null
              ? _Policy.fromJson(body['policy'] as Map<String, dynamic>)
              : null;
        });
      }
    } catch (e) {
      _showSnack('Failed to load: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchHistory() async {
    if (mounted) setState(() => _historyLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/face/history?limit=7'),
        headers: ApiConfig.headers,
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true && mounted) {
        setState(() {
          _history = (body['records'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _historyLoading = false);
  }

  // ── Face verification gate ─────────────────────────────────────────────────
  /// Opens [FaceVerifyScreen] and returns true only when the face is matched
  /// with at least [_kMinFaceConfidence]% confidence.
  Future<bool> _verifyFace() async {
    final result = await Navigator.push<FaceVerifyResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceVerifyScreen(employeeId: widget.employeeId),
      ),
    );

    if (result == null) {
      // User cancelled / dismissed
      return false;
    }

    if (!result.match || result.confidence < _kMinFaceConfidence) {
      _showSnack(
        'Face verification failed (${result.confidence}% confidence). '
        'Please try again in good lighting.',
        isError: true,
      );
      return false;
    }

    return true;
  }

  // ── GPS helpers ────────────────────────────────────────────────────────────
  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('Location services are disabled.', isError: true);
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Location permission denied.', isError: true);
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack(
        'Location permission permanently denied. Enable it in Settings.',
        isError: true,
      );
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      _showSnack('Could not get location. Try again.', isError: true);
      return null;
    }
  }

  // ── Check In  (face → GPS) ─────────────────────────────────────────────────
  Future<void> _checkIn() async {
    // ── Step 1: Face verification ──────────────────────────────────────────
    final faceOk = await _verifyFace();
    if (!faceOk) return; // verification failed / cancelled

    // ── Step 2: GPS check-in ───────────────────────────────────────────────
    setState(() => _actionLoading = true);
    try {
      final position = await _getLocation();
      if (position == null) return;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/face/checkin'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 409) {
        _showSnack(body['message'] ?? 'Already checked in.', isError: true);
        return;
      }
      if (body['success'] != true) {
        _showSnack(body['message'] ?? 'Check-in failed.', isError: true);
        return;
      }

      final record = _AttendanceRecord.fromJson(
        body['record'] as Map<String, dynamic>,
      );
      setState(() => _record = record);

      // Persist attendance_id for background service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kAttendanceIdKey, record.attendanceId);
      await prefs.setString(_kCheckinTimeKey, DateTime.now().toIso8601String());

     
      if (record.isLate && record.lateMinutes > 0) {
        _showSnack(
          'Checked in — ${_fmtDuration(record.lateMinutes)} late 🕐',
          isError: false,
          color: Colors.orange.shade700,
        );
      } else {
        _showSnack('Checked in! Location captured ✅', isError: false);
      }
      await _fetchHistory();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Check Out  (face → GPS) ────────────────────────────────────────────────
  Future<void> _checkOut() async {
    // ── Step 1: Confirm dialog ─────────────────────────────────────────────
    final confirm = await _showConfirmDialog();
    if (confirm != true) return;

    // ── Step 2: Face verification ──────────────────────────────────────────
    final faceOk = await _verifyFace();
    if (!faceOk) return;

    // ── Step 3: GPS check-out ──────────────────────────────────────────────
    setState(() => _actionLoading = true);
    try {
      final position = await _getLocation();
      if (position == null) return;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/face/checkout'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (body['success'] != true) {
        _showSnack(body['message'] ?? 'Check-out failed.', isError: true);
        return;
      }

      setState(() {
        _record = _AttendanceRecord.fromJson(
          body['record'] as Map<String, dynamic>,
        );
      });

      // Stop background service
      final service = FlutterBackgroundService();
      final prefs = await SharedPreferences.getInstance();
       await prefs.remove(_kAttendanceIdKey);
      await prefs.remove(_kCheckinTimeKey);

      _showSnack('Checked out. Have a great day! ✅', isError: false);
      await _fetchHistory();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(DateTime? dt) =>
      dt == null ? '--:--' : DateFormat('hh:mm a').format(dt);

  String _fmtCoord(double? v) => v == null ? '--' : v.toStringAsFixed(6);

  String _fmtDuration(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String _elapsed(DateTime from) {
    final d = _now.difference(from);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _parseTotalWork(String? t) {
    if (t == null || t.trim().isEmpty) return '--';
    try {
      final parts = t.split(':').map((p) => int.parse(p.trim())).toList();
      final h = parts.isNotEmpty ? parts[0] : 0;
      final m = parts.length > 1 ? parts[1] : 0;
      if (h == 0 && m == 0) return '--';
      return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
    } catch (_) {
      return '--';
    }
  }

  void _showSnack(String msg, {required bool isError, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            color ?? (isError ? Colors.red.shade700 : const Color(0xFF2E7D32)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<bool?> _showConfirmDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: Color(0xFFE65100)),
          SizedBox(width: 10),
          Text('Check Out', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: const Text('Your current location will be saved. Are you sure?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE65100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Check Out', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  Future<void> _openMap({
    required double checkinLat,
    required double checkinLng,
    double? checkoutLat,
    double? checkoutLng,
  }) async {
    final Uri uri;
    if (checkoutLat != null && checkoutLng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/$checkinLat,$checkinLng/$checkoutLat,$checkoutLng',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$checkinLat,$checkinLng',
      );
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open map.', isError: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([_fetchToday(), _fetchHistory()]);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader(),
                          const SizedBox(height: 14),
                          if (_policy != null) ...[
                            _buildPolicyBanner(),
                            const SizedBox(height: 14),
                          ],
                          _buildStatusCard(),
                          const SizedBox(height: 14),
                          _buildTimingsRow(),
                          const SizedBox(height: 14),
                          _buildLocationCard(),
                          const SizedBox(height: 14),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildHistorySection(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  // Widget _buildHeader() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             DateFormat('EEE, d MMM yyyy').format(_now),
  //             style: TextStyle(
  //               fontSize: 12,
  //               color: Colors.grey.shade500,
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //           const SizedBox(height: 2),
  //           const Text(
  //             'GPS Attendance',
  //             style: TextStyle(
  //               fontSize: 22,
  //               fontWeight: FontWeight.w800,
  //               color: Color(0xFF1A1A2E),
  //               letterSpacing: -0.3,
  //             ),
  //           ),
  //         ],
  //       ),
  //       Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(14),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withValues(alpha: 0.06),
  //               blurRadius: 12,
  //               offset: const Offset(0, 3),
  //             ),
  //           ],
  //         ),
  //         child: Row(
  //           children: [
  //             const Icon(
  //               Icons.access_time_rounded,
  //               size: 15,
  //               color: Color(0xFF5C6BC0),
  //             ),
  //             const SizedBox(width: 6),
  //             Text(
  //               DateFormat('hh:mm:ss a').format(_now),
  //               style: const TextStyle(
  //                 fontFeatures: [FontFeature.tabularFigures()],
  //                 fontSize: 13,
  //                 fontWeight: FontWeight.w700,
  //                 color: Color(0xFF1A1A2E),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }
  Widget _buildHeader() {
    return Row(
      children: [
        // Title (takes all remaining space)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE, d MMM yyyy').format(_now),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'GPS Attendance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        // Clock
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 15,
                color: Color(0xFF5C6BC0),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('hh:mm:ss a').format(_now),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // History button
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AttendanceHistoryScreen(mode: 'gps_face'),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 20,
              color: Color(0xFF5C6BC0),
            ),
          ),
        ),
      ],
    );
  }

  // ── Policy banner ──────────────────────────────────────────────────────────
  Widget _buildPolicyBanner() {
    final p = _policy!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.gps_fixed_rounded,
            size: 16,
            color: Colors.indigo.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            'GPS Mode',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.indigo.shade400,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: Colors.grey.shade300),
          const SizedBox(width: 10),
          Icon(Icons.login_rounded, size: 13, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            p.inDisplay ?? '--',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.logout_rounded, size: 13, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text(
            p.outDisplay ?? '--',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          if (p.lateAfterMinutes > 0) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Grace ${p.lateAfterMinutes}m',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final isActive = _record?.isActive ?? false;
    final isCompleted = _record?.isCompleted ?? false;

    final LinearGradient gradient;
    final IconData icon;
    final String label;
    final String sublabel;

    if (isActive) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.gps_fixed_rounded;
      label = 'Currently Tracked';
      sublabel = _elapsed(_record!.checkinTime!);
    } else if (isCompleted) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.check_circle_rounded;
      label = 'Day Complete';
      sublabel = 'Worked ${_parseTotalWork(_record!.totalWorkTime)} today';
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFF37474F), Color(0xFF607D8B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.gps_off_rounded;
      label = 'Not Checked In';
      sublabel = 'Tap CHECK IN to verify face & start GPS';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFA5D6A7),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFA5D6A7,
                            ).withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),

          // Late badge
          if (_record != null &&
              _record!.isLate &&
              _record!.lateMinutes > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_fmtDuration(_record!.lateMinutes)} late',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_policy?.inDisplay != null)
                    Text(
                      'Expected ${_policy!.inDisplay}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Live location-update indicator
          if (isActive) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Location updating every 02 minutes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Face-verify hint when not yet checked in
          if (!isActive && !isCompleted) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Face verification required to check in',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Timings row ────────────────────────────────────────────────────────────
  Widget _buildTimingsRow() {
    final isActive = _record?.isActive ?? false;
    final totalLabel = isActive
        ? _elapsed(_record!.checkinTime!)
        : _parseTotalWork(_record?.totalWorkTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _timingBlock(
              icon: Icons.login_rounded,
              iconBg: Colors.green.shade50,
              iconColor: Colors.green.shade700,
              label: 'Check In',
              value: _fmtTime(_record?.checkinTime),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _timingBlock(
              icon: Icons.logout_rounded,
              iconBg: Colors.red.shade50,
              iconColor: Colors.red.shade400,
              label: 'Check Out',
              value: _fmtTime(_record?.checkoutTime),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _timingBlock(
              icon: Icons.timelapse_rounded,
              iconBg: Colors.indigo.shade50,
              iconColor: Colors.indigo.shade500,
              label: 'Total Work',
              value: totalLabel,
              valueColor: isActive ? Colors.indigo.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 44, color: Colors.grey.shade200);

  Widget _timingBlock({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF1A1A2E),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Location card ──────────────────────────────────────────────────────────
  Widget _buildLocationCard() {
    final hasCheckin = _record?.checkinLat != null;
    final hasCheckout = _record?.checkoutLat != null;
    if (!hasCheckin && !hasCheckout) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: Colors.indigo.shade500,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Location Snapshot',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasCheckin)
            _locationRow(
              label: 'Check-in',
              lat: _record!.checkinLat!,
              lng: _record!.checkinLng!,
              color: Colors.green,
              icon: Icons.login_rounded,
              isLive: _record!.isActive,
            ),
          if (hasCheckin && hasCheckout) const SizedBox(height: 10),
          if (hasCheckout)
            _locationRow(
              label: 'Check-out',
              lat: _record!.checkoutLat!,
              lng: _record!.checkoutLng!,
              color: Colors.red,
              icon: Icons.logout_rounded,
              isLive: false,
            ),
        ],
      ),
    );
  }

  Widget _locationRow({
    required String label,
    required double lat,
    required double lng,
    required MaterialColor color,
    required IconData icon,
    required bool isLive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.shade600),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.shade700,
            ),
          ),
          if (isLive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '${_fmtCoord(lat)}, ${_fmtCoord(lng)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.shade700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    final canCheckIn = _record == null || _record!.isCompleted;
    final canCheckOut = _record?.isActive == true;

    return Column(
      children: [
        // Face-verify hint strip above buttons
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.face_retouching_natural,
                size: 14,
                color: Colors.indigo.shade400,
              ),
              const SizedBox(width: 7),
              Text(
                'Face verification → GPS capture',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade500,
                ),
              ),
            ],
          ),
        ),

        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'CHECK IN',
                icon: Icons.face_retouching_natural,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                ),
                enabled: canCheckIn && !_actionLoading,
                loading: _actionLoading && canCheckIn,
                onTap: _checkIn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'CHECK OUT',
                icon: Icons.face_retouching_natural,
                gradient: const LinearGradient(
                  colors: [Color(0xFFBF360C), Color(0xFFE64A19)],
                ),
                enabled: canCheckOut && !_actionLoading,
                loading: _actionLoading && canCheckOut,
                onTap: _checkOut,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── History section ────────────────────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 17,
                  color: Colors.indigo.shade400,
                ),
                const SizedBox(width: 7),
                Text(
                  'Recent GPS Attendance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _fetchHistory,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Colors.indigo.shade300,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_historyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_history.isEmpty)
          _buildEmptyHistory()
        else
          Builder(
            builder: (_) {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              final todayRecords = _history
                  .where(
                    (r) => (r['work_date'] as String? ?? '').startsWith(today),
                  )
                  .toList();
              if (todayRecords.isEmpty) return _buildEmptyHistory();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todayRecords.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildHistoryRow(todayRecords[i]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyHistory() => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(Icons.gps_off_rounded, size: 36, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(
          'No GPS history yet',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildHistoryRow(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'completed';
    final isActive = status == 'active';
    final isLate = (row['is_late'] as num?)?.toInt() == 1;
    final lateMin = (row['late_minutes'] as num?)?.toInt() ?? 0;
    final workDate = row['work_date'] as String? ?? '';
    final checkin = row['checkin_time'] != null
        ? DateTime.tryParse(row['checkin_time'] as String)
        : null;
    final checkout = row['checkout_time'] != null
        ? DateTime.tryParse(row['checkout_time'] as String)
        : null;
    final totalWork = row['total_work_time'] as String?;
    final hasLat = _toDouble(row['checkin_latitude']) != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.green.shade200
              : isLate
              ? Colors.orange.shade200
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date block
          SizedBox(
            width: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workDate.isNotEmpty
                      ? DateFormat('EEE').format(DateTime.parse(workDate))
                      : '--',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  workDate.isNotEmpty
                      ? DateFormat('d MMM').format(DateTime.parse(workDate))
                      : '--',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Times + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _historyTag(
                      icon: Icons.login_rounded,
                      label: _fmtTime(checkin),
                      color: Colors.green.shade700,
                      bg: Colors.green.shade50,
                    ),
                    _historyTag(
                      icon: Icons.logout_rounded,
                      label: isActive ? 'Active' : _fmtTime(checkout),
                      color: isActive
                          ? Colors.orange.shade700
                          : Colors.red.shade400,
                      bg: isActive ? Colors.orange.shade50 : Colors.red.shade50,
                    ),
                    if (hasLat)
                      _historyTag(
                        icon: Icons.gps_fixed_rounded,
                        label: 'GPS',
                        color: Colors.indigo.shade600,
                        bg: Colors.indigo.shade50,
                      ),
                  ],
                ),
                if (isLate && lateMin > 0) ...[
                  const SizedBox(height: 5),
                  _historyTag(
                    icon: Icons.schedule_rounded,
                    label: '${_fmtDuration(lateMin)} late',
                    color: Colors.orange.shade800,
                    bg: Colors.orange.shade50,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Duration + Map
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade200, Colors.grey.shade300],
                        ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _parseTotalWork(totalWork),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
              if (hasLat) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    final lat = _toDouble(row['checkin_latitude'])!;
                    final lng = _toDouble(row['checkin_longitude'])!;
                    final outLat = _toDouble(row['checkout_latitude']);
                    final outLng = _toDouble(row['checkout_longitude']);
                    _openMap(
                      checkinLat: lat,
                      checkinLng: lng,
                      checkoutLat: outLat,
                      checkoutLng: outLng,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 12,
                          color: Colors.indigo.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Map',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyTag({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button widget
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gradient.colors.last.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
