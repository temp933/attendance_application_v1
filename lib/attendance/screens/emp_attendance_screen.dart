import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart'
    if (dart.library.html) '../services/stub/flutter_background_service_stub.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/attendance_state.dart';
import '../services/background_service.dart';
import 'attendance_history_screen.dart';
import 'face_verify_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final int employeeId;
  const AttendanceScreen({super.key, required this.employeeId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _service = FlutterBackgroundService();
  final _state = AttendanceState.instance;
  bool _verifyingLocation = false;
  int _verifyCountdown = 120;
  Timer? _verifyTimer;
  StreamSubscription? _verifySub;
  bool _acquiringGPS = false;
  final int _gpsTimeout = 30;
  int _gpsCountdown = 30;
  Timer? _gpsTimer;
  StreamSubscription? _gpsAcquiredSub;
  LatLng? _position;
  double? _accuracy;
  bool _goodAccuracy = true;
  bool _isLoading = true;
  bool _listenersAttached = false;
  bool _faceVerifyPending = false;
  List<Map<String, dynamic>> _logs = [];

  Timer? _statusTimer;
  Timer? _logsTimer;
  Timer? _clockTimer;

  StreamSubscription? _statusSub;
  StreamSubscription? _locationSub;
  StreamSubscription? _errorSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _init();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusSub?.cancel();
    _locationSub?.cancel();
    _errorSub?.cancel();
    _statusTimer?.cancel();
    _logsTimer?.cancel();
    _clockTimer?.cancel();
    _verifyTimer?.cancel();
    _verifySub?.cancel();
    _gpsTimer?.cancel();
    _gpsAcquiredSub?.cancel();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await _state.checkStatus(widget.employeeId);

    if (_state.dayStatus == DayStatus.inProgress) {
      if (!_state.locationVerified) {
        await _state.cancelStart(widget.employeeId);
        await _fetchLogs();
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack(
            'Previous session had no location. Please tap START again.',
            isError: true,
          );
        }
        return;
      }

      _attachListeners();
      _startTimers();
    }

    await _fetchLogs();
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Timers ────────────────────────────────────────────────────────────────

  void _startTimers() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _state.checkStatus(widget.employeeId);
      if (mounted) setState(() {});
    });
    _logsTimer?.cancel();
    _logsTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchLogs(),
    );
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _statusTimer = null;
    _logsTimer?.cancel();
    _logsTimer = null;
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  // ── Stream listeners ──────────────────────────────────────────────────────

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    Stream<Map<String, dynamic>?> statusStream;
    Stream<Map<String, dynamic>?> locationStream;
    Stream<Map<String, dynamic>?> errorStream;

    if (kIsWeb) {
      statusStream = webOn('status_update');
      locationStream = webOn('location_update');
      errorStream = webOn('service_error');
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      statusStream = _service.on('status_update');
      locationStream = _service.on('location_update');
      errorStream = _service.on('service_error');
    } else {
      statusStream = desktopOn('status_update');
      locationStream = desktopOn('location_update');
      errorStream = desktopOn('service_error');
    }

    _statusSub = statusStream.listen((e) {
      if (!mounted || e == null) return;
      _state.updateSiteStatus(
        e['status'] == 'IN',
        e['site_name'] as String? ?? '',
      );
      setState(() {
        if (e['lat'] != null) {
          _position = LatLng(e['lat'] as double, e['lng'] as double);
          _accuracy = (e['accuracy'] as num).toDouble();
          _goodAccuracy = true;
        }
      });
      _fetchLogs();
    });

    _locationSub = locationStream.listen((e) {
      if (!mounted || e == null) return;
      setState(() {
        _position = LatLng(e['lat'] as double, e['lng'] as double);
        _accuracy = (e['accuracy'] as num).toDouble();
        _goodAccuracy = e['good'] as bool? ?? true;
      });
    });

    _errorSub = errorStream.listen((e) {
      if (!mounted || e == null) return;
      final reason = e['reason'] as String? ?? 'unknown';
      final msg = switch (reason) {
        'no_background_location' =>
          'Background location permission required. Enable in Settings.',
        'location_permission_denied' => 'Location permission denied.',
        'gps_error' => 'GPS error: ${e['detail'] ?? 'unknown'}',
        'gps_stream_closed' => 'GPS stopped unexpectedly. Restart the app.',
        _ => 'Tracking error: $reason',
      };
      _showSnack(msg, isError: true);
    });
  }

  void _detachListeners() {
    _statusSub?.cancel();
    _statusSub = null;
    _locationSub?.cancel();
    _locationSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _listenersAttached = false;
  }

  // ── Fetch logs ────────────────────────────────────────────────────────────

  Future<void> _fetchLogs() async {
    try {
      final logs = await ApiService.getTodayLogs(widget.employeeId);
      if (mounted) setState(() => _logs = logs.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  // ── START ─────────────────────────────────────────────────────────────────

  Future<void> _startWork() async {
    if (_isLoading || _verifyingLocation || _acquiringGPS) return;
    setState(() => _isLoading = true);

    await _state.checkStatus(widget.employeeId);

    if (!mounted) return;

    if (_state.dayStatus == DayStatus.inProgress) {
      setState(() => _isLoading = false);
      _showSnack('Tracking is already active.');
      if (!_listenersAttached) {
        _attachListeners();
        _startTimers();
        setState(() {});
      }
      return;
    }

    // ── Permission flow ─────────────────────────────────────────────
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      if (!await Permission.locationWhenInUse.isGranted) {
        final s = await Permission.locationWhenInUse.request();
        if (!s.isGranted) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          _showSnack('Location permission is required.');
          return;
        }
      }

      if (!mounted) return;

      if (!await Permission.locationAlways.isGranted) {
        final label = defaultTargetPlatform == TargetPlatform.iOS
            ? "'Always'"
            : "'Allow all the time'";

        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.location_on, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Background Location Required'),
              ],
            ),
            content: Text(
              'This app needs $label location permission to track '
              'attendance in background.\n\n'
              'Please select $label on next screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }

        final bgStatus = await Permission.locationAlways.request();
        if (!mounted) return;

        if (!bgStatus.isGranted) {
          setState(() => _isLoading = false);
          _showSnack('Background location denied.');
          return;
        }
      }
    }

    // ── Face Verification (ONLY ONCE) ──────────────────────────────
    if (!mounted) return;
    setState(() => _isLoading = false);

    final verifyResult = await Navigator.push<FaceVerifyResult>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            FaceVerifyScreen(employeeId: widget.employeeId),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (!mounted) return;

    if (verifyResult == null || !verifyResult.match) {
      if (verifyResult != null && !verifyResult.match) {
        _showSnack(
          'Face verification failed. Please try again.',
          isError: true,
        );
      }
      return;
    }

    // ── Start Session ─────────────────────────────────────────────
    setState(() => _isLoading = true);

    try {
      await _state.start(widget.employeeId);
      if (!mounted) return;

      await startBackgroundTracking(
        widget.employeeId,
        sessionId: _state.currentSessionId,
      );
      if (!mounted) return;

      _attachListeners();

      setState(() {
        _isLoading = false;
        _acquiringGPS = true;
        _gpsCountdown = _gpsTimeout;
      });

      // ── GPS Timer ───────────────────────────────────────────────
      _gpsTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) {
          t.cancel();
          return;
        }

        setState(() => _gpsCountdown--);

        if (_gpsCountdown <= 0) {
          t.cancel();
          if (!mounted) return;

          await _cancelVerification();

          if (!mounted) return;

          _showSnack('Could not acquire GPS signal.', isError: true);
        }
      });

      // ── FIRST LOCATION UPDATE ───────────────────────────────────
      _gpsAcquiredSub = _service.on('location_update').listen((e) async {
        if (!mounted || e == null || !_acquiringGPS) return;

        _gpsTimer?.cancel();
        _gpsTimer = null;

        _gpsAcquiredSub?.cancel();
        _gpsAcquiredSub = null;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          setState(() {
            _acquiringGPS = false;
            _verifyingLocation = true;
            _verifyCountdown = 120;
          });

          // ── Site Verification Timer ───────────────────────────
          _verifyTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
            if (!mounted) {
              t.cancel();
              return;
            }

            setState(() => _verifyCountdown--);

            if (_verifyCountdown <= 0) {
              t.cancel();
              if (!mounted) return;
              await _cancelVerification();
            }
          });

          // ── Status Listener ───────────────────────────────────
          _verifySub = _service.on('status_update').listen((e) async {
            if (!mounted || e == null) return;

            if (e['status'] == 'IN') {
              await _confirmVerification();
            }
          });
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showSnack('Failed to start tracking: $e', isError: true);
    }
  }

  // ── Confirm verification ──────────────────────────────────────────────────

  Future<void> _confirmVerification() async {
    _verifyTimer?.cancel();
    _verifySub?.cancel();
    _verifyTimer = null;
    _verifySub = null;

    await ApiService.confirmLocation(
      widget.employeeId,
      _state.currentSessionId,
    );
    _state.locationVerified = true;
    _state.confirmStart();

    if (!mounted) return;
    setState(() => _verifyingLocation = false);

    // ── Show comp-off toast if auto-granted ───────────────────────────────
    if (_state.compoffGranted) {
      final workType = _state.compoffWorkType ?? 'Holiday / Weekend';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comp-Off Credited! 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You worked on $workType. 1 day added to your comp-off balance.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    _startTimers();
  }

  // ── Cancel verification ───────────────────────────────────────────────────

  Future<void> _cancelVerification() async {
    _verifyTimer?.cancel();
    _verifySub?.cancel();
    _gpsTimer?.cancel();
    _gpsAcquiredSub?.cancel();
    _verifyTimer = null;
    _verifySub = null;
    _gpsTimer = null;
    _gpsAcquiredSub = null;
    _faceVerifyPending = false;

    final svc = FlutterBackgroundService();
    if (await svc.isRunning()) {
      svc.invoke('force_stop');
      await Future.delayed(const Duration(milliseconds: 800));
    }

    await _state.cancelStart(widget.employeeId);
    _detachListeners();

    if (!mounted) return;
    setState(() {
      _verifyingLocation = false;
      _acquiringGPS = false;
    });

    _showSnack('You are not near any site. Session cancelled.', isError: true);
  }

  // ── GPS Acquiring card ────────────────────────────────────────────────────

  Widget _buildAcquiringGPSCard() {
    final minutes = (_gpsCountdown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_gpsCountdown % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acquiring GPS Signal...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Waiting for location lock',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Make sure GPS is enabled and you have a clear view of the sky.\n'
            'This may take a few moments...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _cancelVerification,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Verifying card ────────────────────────────────────────────────────────

  Widget _buildVerifyingCard() {
    final minutes = (_verifyCountdown ~/ 60).toString().padLeft(2, '0');
    final seconds = (_verifyCountdown % 60).toString().padLeft(2, '0');
    final progress = _verifyCountdown / 120.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verifying Location...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Please stay near your site',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Session will be cancelled if you are not detected\nat a site within $minutes:$seconds',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _cancelVerification,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── END ───────────────────────────────────────────────────────────────────

  Future<void> _endWork() async {
    if (_state.dayStatus != DayStatus.inProgress || _isLoading) return;

    bool? stillOnSite;

    if (_state.isInsideSite) {
      stillOnSite = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Still on site?', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
          content: Text(
            'You are currently at ${_state.currentSiteName}.\n\n'
            'Are you still physically at this location?',
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.directions_walk_rounded, size: 16),
              label: const Text("No, I've left"),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.home_work_rounded, size: 16),
              label: const Text('Yes, still here'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (stillOnSite == null) return;
    } else {
      stillOnSite = false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('End Session?'),
          ],
        ),
        content: Text(
          stillOnSite == true
              ? 'GPS tracking will stop.\n\n'
                    'Your site visit will continue being recorded '
                    'until you start a new session.'
              : 'GPS tracking will stop and your site visit '
                    'will be marked complete.\n\n'
                    'You can start a new session anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'End Session',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // ── Face Verification Step ──────────────────────────────────────────────
    final verifyResult = await Navigator.push<FaceVerifyResult>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            FaceVerifyScreen(employeeId: widget.employeeId),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // ✅ Face matched — proceed to end session ──────────────────────────────
    setState(() => _isLoading = true);

    final ok = await sendEndSession(stillOnSite: stillOnSite);

    if (!ok) {
      try {
        final data = await ApiService.getTodayStatus(widget.employeeId);
        if ((data['status'] as String?) == 'in_progress') {
          setState(() => _isLoading = false);
          _showSnack('Could not end session. Please try again.', isError: true);
          return;
        }
      } catch (_) {}
    }

    await _state.end();
    _stopTimers();
    _detachListeners();
    _position = null;
    _accuracy = null;
    _goodAccuracy = true;

    setState(() => _isLoading = false);
    _fetchLogs();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : null,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  String _fmtDuration(int? m) {
    if (m == null) return '--';
    return m < 60
        ? '${m}m'
        : '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }

  String _accuracyLabel() {
    if (_accuracy == null) return 'Acquiring GPS...';
    final a = _accuracy!;
    if (a <= 10) return '±${a.toStringAsFixed(0)}m · Excellent';
    if (a <= 20) return '±${a.toStringAsFixed(0)}m · Good';
    if (a <= 40) return '±${a.toStringAsFixed(0)}m · Fair';
    return '±${a.toStringAsFixed(0)}m · Poor';
  }

  Color _accuracyColor() {
    if (_accuracy == null) return Colors.grey;
    if (!_goodAccuracy) return Colors.orange;
    if (_accuracy! <= 10) return Colors.green;
    if (_accuracy! <= 20) return Colors.lightGreen;
    if (_accuracy! <= 40) return Colors.orange;
    return Colors.red;
  }

  int get _totalWorkedMinutes {
    int total = 0;
    for (final log in _logs) {
      final m = log['duration_minutes'];
      if (m != null) total += (m as num).toInt();
    }
    return total;
  }

  String get _totalWorkedLabel {
    final m = _totalWorkedMinutes;
    if (m == 0) return '--';
    final h = m ~/ 60;
    final min = (m % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h ${min}m' : '${min}m';
  }

  _StatusConfig get _statusConfig {
    final hasPrior = _state.hasActivityToday || _logs.isNotEmpty;
    switch (_state.dayStatus) {
      case DayStatus.inProgress:
        if (_state.isInsideSite) {
          return _StatusConfig(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.location_on_rounded,
            label: "You're On Site",
            sublabel: _state.currentSiteName,
            dotColor: const Color(0xFFA5D6A7),
            showPulse: true,
          );
        }
        return _StatusConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.radar_rounded,
          label: 'Tracking Active',
          sublabel: 'Moving between sites',
          dotColor: const Color(0xFF90CAF9),
          showPulse: true,
        );
      case DayStatus.notStarted:
        if (hasPrior) {
          return _StatusConfig(
            gradient: const LinearGradient(
              colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.play_circle_outline_rounded,
            label: 'Session Paused',
            sublabel:
                'Session ${_state.sessionCountToday} ended · Tap START to resume',
            dotColor: const Color(0xFFCE93D8),
            showPulse: false,
          );
        }
        return _StatusConfig(
          gradient: const LinearGradient(
            colors: [Color(0xFF455A64), Color(0xFF607D8B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.fingerprint_rounded,
          label: 'Not Started',
          sublabel: 'Tap START when you arrive',
          dotColor: const Color(0xFFB0BEC5),
          showPulse: false,
        );
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final isSmall = sw < 360;
    final isCompact = sh < 680;
    final safeBot = mq.padding.bottom;
    final isRunning = _state.dayStatus == DayStatus.inProgress;
    final notStarted = _state.dayStatus == DayStatus.notStarted;

    final hPad = isSmall ? 12.0 : 16.0;
    final cardPad = isSmall ? 14.0 : 20.0;
    final gap = isCompact ? 10.0 : 16.0;
    final btnH = isSmall ? 48.0 : 54.0;
    final btnR = isSmall ? 12.0 : 16.0;
    final btnFs = isSmall ? 13.0 : 15.0;
    final btnIs = isSmall ? 19.0 : 22.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 0),
          child: Column(
            children: [
              _acquiringGPS
                  ? _buildAcquiringGPSCard()
                  : _verifyingLocation
                  ? _buildVerifyingCard()
                  : _buildStatusCard(cardPad: cardPad, isCompact: isCompact),
              SizedBox(height: gap),
              _buildLogHeader(isSmall: isSmall),
              SizedBox(height: isSmall ? 6 : 8),
              Expanded(child: _buildLogList(isRunning, isSmall: isSmall)),
              Padding(
                padding: EdgeInsets.only(
                  top: gap,
                  bottom: safeBot + (isSmall ? 8 : 12),
                ),
                child: _buildButtons(
                  isRunning: isRunning,
                  notStarted: notStarted,
                  height: btnH,
                  radius: btnR,
                  fontSize: btnFs,
                  iconSize: btnIs,
                  isSmall: isSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard({required double cardPad, required bool isCompact}) {
    if (_isLoading) {
      return Container(
        height: isCompact ? 130 : 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final cfg = _statusConfig;
    final isRunning = _state.dayStatus == DayStatus.inProgress;

    return Container(
      decoration: BoxDecoration(
        gradient: cfg.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cfg.gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: isCompact ? 38 : 46,
                  height: isCompact ? 38 : 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    cfg.icon,
                    color: Colors.white,
                    size: isCompact ? 22 : 26,
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cfg.sublabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: isCompact ? 11 : 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cfg.showPulse)
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, _) => Transform.scale(
                      scale: _pulseAnim.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cfg.dotColor,
                          boxShadow: [
                            BoxShadow(
                              color: cfg.dotColor.withValues(alpha: 0.7),
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
                      color: cfg.dotColor.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
            if (!isCompact) ...[
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 14),
              _buildCardBottom(isRunning: isRunning, isCompact: false),
            ] else ...[
              const SizedBox(height: 10),
              _buildCardBottom(isRunning: isRunning, isCompact: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardBottom({required bool isRunning, required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_logs.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total On-Site',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.timelapse_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _totalWorkedLabel,
                        style: TextStyle(
                          fontSize: isCompact ? 13 : 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_logs.length > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_logs.length} visits',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 16),
            ],
            if (!isRunning && _state.hasActivityToday) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sessions Today',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_state.sessionCountToday}',
                        style: TextStyle(
                          fontSize: isCompact ? 13 : 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
            ],
            if (isRunning)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GPS Signal',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _position == null
                        ? _infoChip(
                            icon: Icons.gps_not_fixed,
                            label: 'Acquiring...',
                            spinning: true,
                          )
                        : _infoChipColor(
                            icon: _goodAccuracy
                                ? Icons.gps_fixed
                                : Icons.gps_not_fixed,
                            label: _accuracyLabel(),
                            color: _accuracyColor(),
                          ),
                  ],
                ),
              )
            else
              const Spacer(),
          ],
        ),
        if (isRunning && _state.isLate && _state.lateText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  'Late by ${_state.lateText}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool spinning = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinning
            ? SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              )
            : Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _infoChipColor({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Log header ────────────────────────────────────────────────────────────

  Widget _buildLogHeader({required bool isSmall}) {
    return Row(
      children: [
        Icon(
          Icons.list_alt_rounded,
          size: isSmall ? 15 : 17,
          color: Colors.indigo,
        ),
        SizedBox(width: isSmall ? 5 : 7),
        Text(
          "Today's Site Visits",
          style: TextStyle(
            fontSize: isSmall ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey[800],
            letterSpacing: 0.2,
          ),
        ),
        if (_state.sessionCountToday > 1) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo.shade200, width: 1),
            ),
            child: Text(
              '${_state.sessionCountToday} sessions',
              style: TextStyle(
                fontSize: 10,
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AttendanceHistoryScreen(employeeId: widget.employeeId),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 13,
                  color: Colors.indigo.shade600,
                ),
                const SizedBox(width: 5),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.indigo.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _fetchLogs,
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
    );
  }

  // ── Log list ──────────────────────────────────────────────────────────────

  Widget _buildLogList(bool isRunning, {required bool isSmall}) {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              isRunning ? 'No site visits yet' : 'No attendance today',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _logs.length,
      separatorBuilder: (_, _) => SizedBox(height: isSmall ? 6 : 8),
      itemBuilder: (_, i) {
        final log = _logs[i];
        final isOpen = log['out_time'] == null;
        final duration = log['duration_minutes'] as int?;
        final sessionNum = log['session_number'] as int?;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 10 : 14,
            vertical: isSmall ? 9 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOpen ? Colors.green.shade200 : Colors.grey.shade200,
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
              Container(
                width: isSmall ? 30 : 36,
                height: isSmall ? 30 : 36,
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOpen
                      ? Icons.radio_button_on_rounded
                      : Icons.check_circle_outline_rounded,
                  size: isSmall ? 15 : 18,
                  color: isOpen ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(width: isSmall ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log['site_name'] as String? ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isSmall ? 12 : 13.5,
                              color: const Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (sessionNum != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'S$sessionNum',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.indigo.shade400,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _timeTag(
                          icon: Icons.login_rounded,
                          time: log['in_time'] as String? ?? '--',
                          color: Colors.green.shade700,
                          bg: Colors.green.shade50,
                        ),
                        _timeTag(
                          icon: Icons.logout_rounded,
                          time: isOpen
                              ? 'Active'
                              : (log['out_time'] as String? ?? '--'),
                          color: isOpen
                              ? Colors.orange.shade700
                              : Colors.red.shade400,
                          bg: isOpen
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 7 : 10,
                  vertical: isSmall ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  gradient: isOpen
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                        )
                      : LinearGradient(
                          colors: [Colors.grey.shade300, Colors.grey.shade400],
                        ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _fmtDuration(duration),
                  style: TextStyle(
                    fontSize: isSmall ? 10 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timeTag({
    required IconData icon,
    required String time,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildButtons({
    required bool isRunning,
    required bool notStarted,
    required double height,
    required double radius,
    required double fontSize,
    required double iconSize,
    required bool isSmall,
  }) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'START',
            icon: Icons.play_arrow_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            onPressed: (notStarted && !_isLoading && !_verifyingLocation)
                ? _startWork
                : null,
            height: height,
            radius: radius,
            fontSize: fontSize,
            iconSize: iconSize,
          ),
        ),
        SizedBox(width: isSmall ? 10 : 14),
        Expanded(
          child: _ActionButton(
            label: 'END',
            icon: Icons.pause_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
            ),
            onPressed: (isRunning && !_isLoading && !_verifyingLocation)
                ? _endWork
                : null,
            height: height,
            radius: radius,
            fontSize: fontSize,
            iconSize: iconSize,
          ),
        ),
      ],
    );
  }
}

// ─── StatusConfig ─────────────────────────────────────────────────────────────

class _StatusConfig {
  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color dotColor;
  final bool showPulse;
  const _StatusConfig({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.dotColor,
    required this.showPulse,
  });
}

// ─── ActionButton ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled ? Colors.white : Colors.grey.shade500,
              size: iconSize,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey.shade500,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
