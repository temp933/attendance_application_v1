import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/api_config.dart';
import 'face_verify_screen.dart';
import 'att_history.dart';
import 'normal_in_out.dart' show AttendancePolicy;

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const int _kMinFaceConfidence = 50;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
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
class _Site {
  final int id;
  final String name;
  const _Site({required this.id, required this.name});
  factory _Site.fromJson(Map<String, dynamic> j) => _Site(
    id: (j['id'] as num).toInt(),
    name: j['site_name'] as String? ?? '',
  );
}

class _Session {
  final int attendanceId;
  final int? siteId;
  final String siteName;
  final String status;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final String? totalWorkTime;
  final bool isLate;
  final int lateMinutes;
  final double? checkinLat;
  final double? checkinLng;
  final double? checkoutLat;
  final double? checkoutLng;
  final bool forceClosed;
  final String? forceCloseReason;

  const _Session({
    required this.attendanceId,
    this.siteId,
    required this.siteName,
    required this.status,
    this.checkinTime,
    this.checkoutTime,
    this.totalWorkTime,
    this.isLate = false,
    this.lateMinutes = 0,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    this.forceClosed = false,
    this.forceCloseReason,
  });

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory _Session.fromJson(Map<String, dynamic> j) => _Session(
    attendanceId: (j['attendance_id'] as num).toInt(),
    siteId: (j['site_id'] as num?)?.toInt(),
    siteName: j['site_name'] as String? ?? 'Unknown Site',
    status: j['status'] as String? ?? 'completed',
    checkinTime: j['checkin_time'] != null
        ? DateTime.tryParse(j['checkin_time'] as String)
        : null,
    checkoutTime: j['checkout_time'] != null
        ? DateTime.tryParse(j['checkout_time'] as String)
        : null,
    totalWorkTime: j['total_work_time'] as String?,
    isLate: (j['is_late'] as num?)?.toInt() == 1,
    lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
    checkinLat: _toDouble(j['checkin_latitude']),
    checkinLng: _toDouble(j['checkin_longitude']),
    checkoutLat: _toDouble(j['checkout_latitude']),
    checkoutLng: _toDouble(j['checkout_longitude']),
    forceClosed: (j['force_closed'] as num?)?.toInt() == 1,
    forceCloseReason: j['force_close_reason'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class SiteEntryAttendanceScreen extends StatefulWidget {
  final int employeeId;
  const SiteEntryAttendanceScreen({super.key, required this.employeeId});

  @override
  State<SiteEntryAttendanceScreen> createState() =>
      _SiteEntryAttendanceScreenState();
}

class _SiteEntryAttendanceScreenState extends State<SiteEntryAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _actionLoading = false;

  List<_Session> _todaySessions = [];
  AttendancePolicy? _policy;
  String? _dailyTotal;

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Active session (latest one that is active) ─────────────────────────────
  _Session? get _activeSession {
    try {
      return _todaySessions.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  // ── Network ────────────────────────────────────────────────────────────────
  Future<void> _fetchToday() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/site-entry/today'),
        headers: ApiConfig.headers,
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true && mounted) {
        setState(() {
          _todaySessions = (body['records'] as List)
              .map((e) => _Session.fromJson(e as Map<String, dynamic>))
              .toList();
          final rawPolicy = body['policy'];
          if (rawPolicy != null && rawPolicy is Map<String, dynamic>) {
            _policy = AttendancePolicy.fromJson(rawPolicy);
          } else {
            _policy = null;
          }
          _dailyTotal = body['daily_total'] as String?;
        });
      }
    } catch (e) {
      _showSnack('Failed to load: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Face verify ────────────────────────────────────────────────────────────
  Future<bool> _verifyFace() async {
    final result = await Navigator.push<FaceVerifyResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceVerifyScreen(employeeId: widget.employeeId),
      ),
    );
    if (result == null) return false;
    if (!result.match || result.confidence < _kMinFaceConfidence) {
      _showSnack(
        'Face verification failed (${result.confidence}% confidence). '
        'Try in better lighting.',
        isError: true,
      );
      return false;
    }
    return true;
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnack('Location services are disabled.', isError: true);
      return null;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        _showSnack('Location permission denied.', isError: true);
        return null;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      _showSnack(
        'Location permanently denied. Enable in Settings.',
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

  // ── Fetch nearby sites for given position ──────────────────────────────────
  Future<List<_Site>> _fetchNearbySites(Position pos) async {
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/site-entry/nearby-sites'
          '?lat=${pos.latitude}&lng=${pos.longitude}&radius=50',
        ),
        headers: ApiConfig.headers,
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return (body['sites'] as List)
            .map((e) => _Site.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Check In: face → GPS → detect site → post ─────────────────────────────
  Future<void> _checkIn() async {
    // Step 1: Face verify
    final faceOk = await _verifyFace();
    if (!faceOk) return;

    setState(() => _actionLoading = true);
    try {
      // Step 2: Get GPS
      final pos = await _getLocation();
      if (pos == null) return;

      // Step 3: Detect nearby sites
      final nearbySites = await _fetchNearbySites(pos);

      if (nearbySites.isEmpty) {
        _showSnack(
          'No site found within 50m of your location. Move closer to a site.',
          isError: true,
        );
        return;
      }

      // Step 4: If multiple sites nearby, let user pick; else auto-select
      _Site selectedSite;
      if (nearbySites.length == 1) {
        selectedSite = nearbySites.first;
      } else {
        final picked = await _showSitePickerDialog(nearbySites);
        if (picked == null) return;
        selectedSite = picked;
      }

      // Step 5: Post check-in
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/site-entry/checkin'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'site_id': selectedSite.id,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
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

      final record = _Session.fromJson(body['record'] as Map<String, dynamic>);
      _showSnack(
        record.isLate && record.lateMinutes > 0
            ? 'Checked in to ${selectedSite.name} — ${_fmtDuration(record.lateMinutes)} late 🕐'
            : 'Checked in to ${selectedSite.name} ✅',
        isError: false,
        color: record.isLate ? Colors.orange.shade700 : null,
      );
      await _fetchToday();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Check Out: confirm → face → GPS → post ────────────────────────────────
  Future<void> _checkOut() async {
    final active = _activeSession;
    if (active == null) return;

    // Step 1: Confirm
    final confirm = await _showConfirmDialog(active.siteName);
    if (confirm != true) return;

    // Step 2: Face verify
    final faceOk = await _verifyFace();
    if (!faceOk) return;

    setState(() => _actionLoading = true);
    try {
      // Step 3: GPS
      final pos = await _getLocation();
      if (pos == null) return;

      // Step 4: Post checkout
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/site-entry/checkout'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'attendance_id': active.attendanceId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        _showSnack(body['message'] ?? 'Check-out failed.', isError: true);
        return;
      }
      _showSnack(
        'Checked out from ${active.siteName}. Have a great day! ✅',
        isError: false,
      );
      await _fetchToday();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(DateTime? dt) =>
      dt == null ? '--:--' : DateFormat('hh:mm a').format(dt);

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

  Future<bool?> _showConfirmDialog(String siteName) => showDialog<bool>(
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
      content: Text(
        'Check out from $siteName? Your current location will be saved.',
      ),
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

  Future<_Site?> _showSitePickerDialog(List<_Site> sites) => showDialog<_Site>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.location_city_rounded, color: Colors.teal.shade600),
          const SizedBox(width: 10),
          const Text('Select Site', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: sites
            .map(
              (s) => ListTile(
                leading: Icon(Icons.place_rounded, color: Colors.teal.shade500),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, s),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
            .toList(),
      ),
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
                onRefresh: _fetchToday,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
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
          const SizedBox(width: 10),
          Icon(Icons.login_rounded, size: 13, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            p.officeInDisplay ?? '--',
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
            p.officeOutDisplay ?? '--',
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
    final active = _activeSession;
    final hasAnyCompleted = _todaySessions.any((s) => s.isCompleted);

    final LinearGradient gradient;
    final IconData icon;
    final String label;
    final String sublabel;

    if (active != null) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.location_city_rounded;
      label = active.siteName;
      sublabel = _elapsed(active.checkinTime!);
    } else if (hasAnyCompleted) {
      // Compute total sessions and sites today
      final siteCount = _todaySessions.map((s) => s.siteId).toSet().length;
      gradient = const LinearGradient(
        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.check_circle_rounded;
      label = 'Day Complete';
      sublabel =
          '${_todaySessions.length} session(s) across $siteCount site(s)';
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFF37474F), Color(0xFF607D8B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.location_city_outlined;
      label = 'Not Checked In';
      sublabel = 'Tap CHECK IN to verify face & detect site';
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
              if (active != null)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, _) => Transform.scale(
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
          if (active != null && active.isLate && active.lateMinutes > 0) ...[
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
                    '${_fmtDuration(active.lateMinutes)} late',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Live location hint
          if (active != null) ...[
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
                    'Location updating every 2 minutes',
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

          // Face-verify hint when not checked in
          if (active == null && !hasAnyCompleted) ...[
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
                    'Face verification required for each check-in/out',
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

  Widget _buildTimingsRow() {
    final active = _activeSession;
    final multiAllowed = _policy?.multipleInOutAllowed ?? true;

    final latestCheckin = _todaySessions.isNotEmpty
        ? _todaySessions.last.checkinTime
        : null;
    final latestCheckout = active == null && _todaySessions.isNotEmpty
        ? _todaySessions.last.checkoutTime
        : null;

    // Third block logic:
    // multi=false → single session only → show checkout time
    // multi=true  → show today's total worked hours across all sessions
    final String thirdLabel;
    final String thirdValue;
    final Color? thirdValueColor;
    final IconData thirdIcon;
    final Color thirdIconBg;
    final Color thirdIconColor;

    if (!multiAllowed) {
      // Single in/out: third block = Total Work
      thirdLabel = 'Total Work';
      thirdIcon = Icons.timelapse_rounded;
      thirdIconBg = Colors.indigo.shade50;
      thirdIconColor = Colors.indigo.shade500;
      if (active != null) {
        thirdValue = _elapsed(active.checkinTime!);
        thirdValueColor = Colors.indigo.shade700;
      } else if (_dailyTotal != null) {
        thirdValue = _parseTotalWork(_dailyTotal);
        thirdValueColor = null;
      } else if (_todaySessions.isNotEmpty) {
        thirdValue = _parseTotalWork(_todaySessions.last.totalWorkTime);
        thirdValueColor = null;
      } else {
        thirdValue = '--';
        thirdValueColor = null;
      }
    } else {
      // Multi in/out: third block = Today's total
      thirdLabel = 'Total Today';
      thirdIcon = Icons.timelapse_rounded;
      thirdIconBg = Colors.indigo.shade50;
      thirdIconColor = Colors.indigo.shade500;
      if (active != null) {
        thirdValue = _elapsed(active.checkinTime!);
        thirdValueColor = Colors.indigo.shade700;
      } else if (_dailyTotal != null) {
        thirdValue = _parseTotalWork(_dailyTotal);
        thirdValueColor = null;
      } else if (_todaySessions.isNotEmpty) {
        thirdValue = _parseTotalWork(_todaySessions.last.totalWorkTime);
        thirdValueColor = null;
      } else {
        thirdValue = '--';
        thirdValueColor = null;
      }
    }

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
              value: _fmtTime(latestCheckin),
            ),
          ),
          _vDivider(),
          // multi=false: show Check Out | Total Today (3 blocks)
          // multi=true:  show Total Today only (2 blocks — no Last Out)
          if (!multiAllowed) ...[
            Expanded(
              child: _timingBlock(
                icon: Icons.logout_rounded,
                iconBg: Colors.red.shade50,
                iconColor: Colors.red.shade400,
                label: 'Check Out',
                value: _fmtTime(latestCheckout),
              ),
            ),
            _vDivider(),
          ],
          Expanded(
            child: _timingBlock(
              icon: thirdIcon,
              iconBg: thirdIconBg,
              iconColor: thirdIconColor,
              label: thirdLabel,
              value: thirdValue,
              valueColor: thirdValueColor,
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
    final active = _activeSession;
    final latest = _todaySessions.isNotEmpty ? _todaySessions.last : null;
    final hasCheckin = active?.checkinLat != null || latest?.checkinLat != null;
    final hasCheckout = latest?.checkoutLat != null;
    if (!hasCheckin && !hasCheckout) return const SizedBox.shrink();

    final session = active ?? latest!;

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
          if (session.checkinLat != null)
            _locationRow(
              label: 'Check-in',
              lat: session.checkinLat!,
              lng: session.checkinLng!,
              color: Colors.green,
              icon: Icons.login_rounded,
              isLive: session.isActive,
            ),
          if (session.checkinLat != null && session.checkoutLat != null)
            const SizedBox(height: 10),
          if (session.checkoutLat != null)
            _locationRow(
              label: 'Check-out',
              lat: session.checkoutLat!,
              lng: session.checkoutLng!,
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
    return GestureDetector(
      onTap: () => _openMap(checkinLat: lat, checkinLng: lng),
      child: Container(
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
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.shade700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    final active = _activeSession;
    final multiAllowed = _policy?.multipleInOutAllowed ?? true;
    final hasAnySession = _todaySessions.isNotEmpty;

    // If multi=false and any session exists today (active or completed), block check-in
    final canCheckIn = active == null && (multiAllowed || !hasAnySession);
    final canCheckOut = active != null;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.face_retouching_natural,
                size: 14,
                color: Colors.teal.shade500,
              ),
              const SizedBox(width: 7),
              Text(
                'Face verification → GPS site detection',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal.shade600,
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
                  color: Colors.teal.shade400,
                ),
                const SizedBox(width: 7),
                Text(
                  "Today's Sessions",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AttendanceHistoryScreen(mode: 'site_entry'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: Colors.teal.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_todaySessions.isEmpty)
          _buildEmptyHistory()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todaySessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildSessionRow(_todaySessions[i]),
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
        Icon(
          Icons.location_city_outlined,
          size: 36,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 10),
        Text(
          'No sessions today',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildSessionRow(_Session s) {
    final isActive = s.isActive;
    final isLate = s.isLate && s.lateMinutes > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.green.shade200
              : s.forceClosed
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
          // Site icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isActive
                  ? Icons.location_city_rounded
                  : Icons.check_circle_rounded,
              size: 18,
              color: isActive ? Colors.green.shade600 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 10),
          // Site name + times
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.siteName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _historyTag(
                      icon: Icons.login_rounded,
                      label: _fmtTime(s.checkinTime),
                      color: Colors.green.shade700,
                      bg: Colors.green.shade50,
                    ),
                    _historyTag(
                      icon: Icons.logout_rounded,
                      label: isActive ? 'Active' : _fmtTime(s.checkoutTime),
                      color: isActive
                          ? Colors.orange.shade700
                          : Colors.red.shade400,
                      bg: isActive ? Colors.orange.shade50 : Colors.red.shade50,
                    ),
                    if (s.checkinLat != null)
                      _historyTag(
                        icon: Icons.gps_fixed_rounded,
                        label: 'GPS',
                        color: Colors.indigo.shade600,
                        bg: Colors.indigo.shade50,
                      ),
                    if (isLate)
                      _historyTag(
                        icon: Icons.schedule_rounded,
                        label: '${_fmtDuration(s.lateMinutes)} late',
                        color: Colors.orange.shade800,
                        bg: Colors.orange.shade50,
                      ),
                    if (s.forceClosed)
                      _historyTag(
                        icon: Icons.info_outline_rounded,
                        label: 'Auto',
                        color: Colors.orange.shade700,
                        bg: Colors.orange.shade50,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Duration + map
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
                  isActive
                      ? _elapsed(s.checkinTime!)
                      : _parseTotalWork(s.totalWorkTime),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
              if (s.checkinLat != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openMap(
                    checkinLat: s.checkinLat!,
                    checkinLng: s.checkinLng!,
                    checkoutLat: s.checkoutLat,
                    checkoutLng: s.checkoutLng,
                  ),
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
// Action Button widget (identical to FaceGpsAttendanceScreen)
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
