// main.dart

// import 'package:geolocator/geolocator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance/screens/login_screen.dart';
import 'attendance/screens/user_dashboard_screen.dart';
import 'attendance/services/location_services.dart';
import 'attendance/services/auth_service.dart';
import 'attendance/services/background_service.dart';
import 'attendance/services/notify.dart';
import 'attendance/App Admin/app_admin_maintenance_screen.dart';
import 'attendance/services/app_admin_provider.dart';
import 'attendance/providers/api_config.dart';
import 'attendance/services/permissions_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<AppAdminProvider>(
          create: (_) => AppAdminProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NotifyService.navigatorKey ??= GlobalKey<NavigatorState>(),
      home: const SplashRouter(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Module keys that require device permissions
// ─────────────────────────────────────────────────────────────────────────────
const _gpsModules = {
  'gps_attendance',
  'face_gps_attendance',
  'site_entry_attendance',
  'emp_gps_attendance',
  'emp_face_gps_attendance',
  'emp_site_entry_attendance',
};

const _cameraModules = {'face_gps_attendance', 'emp_face_gps_attendance'};

// ─────────────────────────────────────────────────────────────────────────────
// Permission need resolver — based on granted module keys
// ─────────────────────────────────────────────────────────────────────────────
class _PermNeeds {
  final bool location; // locationWhenInUse + locationAlways
  final bool camera; // camera
  final bool notification; // notifications (always true if location needed)

  const _PermNeeds({
    required this.location,
    required this.camera,
    required this.notification,
  });

  bool get hasAny => location || camera || notification;

  static _PermNeeds fromModules(List<Map<String, dynamic>>? permissions) {
    if (permissions == null || permissions.isEmpty) {
      return const _PermNeeds(
        location: false,
        camera: false,
        notification: false,
      );
    }

    final keys = permissions
        .map((p) => (p['module_key'] ?? '').toString())
        .toSet();

    final needsLocation = keys.intersection(_gpsModules).isNotEmpty;
    final needsCamera = keys.intersection(_cameraModules).isNotEmpty;

    return _PermNeeds(
      location: needsLocation,
      camera: needsCamera,
      notification: true, // always request — needed for FCM push notifications
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartPermissionGate — shown AFTER login, ONLY for first time, ONLY on mobile
// ─────────────────────────────────────────────────────────────────────────────
class SmartPermissionGate extends StatefulWidget {
  final int loginId;
  final List<Map<String, dynamic>>? permissions;
  final Widget destination;

  const SmartPermissionGate({
    super.key,
    required this.loginId,
    required this.permissions,
    required this.destination,
  });

  @override
  State<SmartPermissionGate> createState() => _SmartPermissionGateState();
}

class _SmartPermissionGateState extends State<SmartPermissionGate> {
  _GateStep _step = _GateStep.checking;
  String? _denyReason;
  late _PermNeeds _needs;

  @override
  void initState() {
    super.initState();
    _needs = _PermNeeds.fromModules(widget.permissions);
    _run();
  }

  Future<void> _run() async {
    // Non-mobile: skip straight through
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _advance();
      return;
    }

    // No permissions needed for this org's modules
    if (!_needs.hasAny) {
      await _markGranted();
      _advance();
      return;
    }

    // Already granted before for this user
    if (await _alreadyGranted()) {
      _advance();
      return;
    }

    // Check if OS-level permissions are already in place
    if (await _allOsGranted()) {
      await _markGranted();
      _advance();
      return;
    }

    // Show rationale
    if (mounted) setState(() => _step = _GateStep.rationale);
  }

  /// Per-user flag — safe for multi-account on same device
  Future<bool> _alreadyGranted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('permissions_granted_${widget.loginId}') ?? false;
  }

  Future<void> _markGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_granted_${widget.loginId}', true);
  }

  /// Check if every needed OS permission is already granted
  Future<bool> _allOsGranted() async {
    if (_needs.location) {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      if (!(await Permission.locationWhenInUse.status).isGranted) return false;
      if (!(await Permission.locationAlways.status).isGranted) return false;
    }

    if (_needs.camera) {
      if (!(await Permission.camera.status).isGranted) return false;
    }

    if (_needs.notification) {
      if (!(await Permission.notification.status).isGranted) return false;
    }

    return true;
  }

  /// Request only what the org's modules need
  Future<bool> _requestNeeded() async {
    // ── GPS ───────────────────────────────────────────────────────────────
    if (_needs.location) {
      // Step 1: GPS service ON
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return false;
        final open = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Turn On GPS'),
            content: const Text(
              'This app needs GPS to record your attendance.\n\n'
              'Please enable Location in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Exit'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (open == true) {
          await Geolocator.openLocationSettings();
          await Future.delayed(const Duration(seconds: 2));
        }
        if (!await Geolocator.isLocationServiceEnabled()) {
          _denyReason = 'GPS is disabled. Please enable it in Settings.';
          return false;
        }
      }

      // Step 2: Location when in use
      var whenInUse = await Permission.locationWhenInUse.status;
      if (!whenInUse.isGranted) {
        whenInUse = await Permission.locationWhenInUse.request();
      }
      if (!whenInUse.isGranted) {
        _denyReason = whenInUse.isPermanentlyDenied
            ? 'Location permission is permanently denied.\nOpen Settings → App → Permissions → Location.'
            : 'Location permission is required to record attendance.';
        return false;
      }

      // Step 3: Location always (background)
      var always = await Permission.locationAlways.status;
      if (!always.isGranted) {
        if (mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Color(0xFF1565C0)),
                  SizedBox(width: 10),
                  Text('Background Location', style: TextStyle(fontSize: 17)),
                ],
              ),
              content: const Text(
                'The app tracks your location in the background to record '
                'GPS attendance even when the screen is off.\n\n'
                'On the next screen, please choose "Allow all the time".',
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Got it',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        always = await Permission.locationAlways.request();
      }
      if (!always.isGranted) {
        _denyReason = always.isPermanentlyDenied
            ? 'Background location is permanently denied.\n\nOpen Settings → App → Permissions → Location → Allow all the time.'
            : 'Background location is required to track GPS attendance.';
        return false;
      }
    }

    // ── Camera ────────────────────────────────────────────────────────────
    if (_needs.camera) {
      var camera = await Permission.camera.status;
      if (!camera.isGranted) {
        camera = await Permission.camera.request();
      }
      if (!camera.isGranted) {
        _denyReason = camera.isPermanentlyDenied
            ? 'Camera permission is permanently denied.\nOpen Settings → App → Permissions → Camera.'
            : 'Camera permission is required for face attendance.';
        return false;
      }
    }

    // ── Notifications (optional — don't block) ────────────────────────────
    if (_needs.notification) {
      var notif = await Permission.notification.status;
      if (!notif.isGranted) {
        notif = await Permission.notification.request();
      }
      if (!notif.isGranted) {
        debugPrint(
          '[SmartPermissionGate] Notification denied — continuing anyway',
        );
      }
    }

    return true;
  }

  Future<void> _onContinue() async {
    if (mounted) setState(() => _step = _GateStep.requesting);
    final granted = await _requestNeeded();
    if (!mounted) return;
    if (granted) {
      await _markGranted();
      _advance();
    } else {
      setState(() => _step = _GateStep.denied);
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (!mounted) return;
    if (await _allOsGranted()) {
      await _markGranted();
      _advance();
    } else {
      setState(() => _step = _GateStep.rationale);
    }
  }

  void _advance() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _GateStep.checking:
        return const Center(child: CircularProgressIndicator());

      case _GateStep.requesting:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Requesting permissions…',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );

      case _GateStep.rationale:
        return _RationaleBody(needs: _needs, onContinue: _onContinue);

      case _GateStep.denied:
        return _DeniedBody(
          reason: _denyReason,
          onOpenSettings: _openSettings,
          onRetry: _onContinue,
        );
    }
  }
}

enum _GateStep { checking, rationale, requesting, denied }

// ── Rationale UI — shows only the permissions the org needs ──────────────────
class _RationaleBody extends StatelessWidget {
  final _PermNeeds needs;
  final VoidCallback onContinue;
  const _RationaleBody({required this.needs, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security_rounded,
                size: 48,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Permissions needed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'To record your attendance accurately, the app needs the following permissions:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Show only what's needed
          if (needs.location) ...[
            _permRow(
              icon: Icons.gps_fixed_rounded,
              color: Colors.green.shade600,
              title: 'Location — Always',
              desc:
                  'Tracks GPS check-ins and site presence even when the screen is off.',
            ),
            const SizedBox(height: 14),
          ],
          if (needs.camera) ...[
            _permRow(
              icon: Icons.camera_alt_rounded,
              color: Colors.orange.shade600,
              title: 'Camera',
              desc: 'Required for face recognition during attendance check-in.',
            ),
            const SizedBox(height: 14),
          ],
          if (needs.notification) ...[
            _permRow(
              icon: Icons.notifications_rounded,
              color: Colors.indigo.shade500,
              title: 'Notifications',
              desc: 'Shows background tracking status and attendance alerts.',
            ),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_rounded,
                  size: 18,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your data is only sent to your company\'s HR server '
                    'and is never shared with third parties.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: onContinue,
              child: const Text(
                'Grant Permissions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Denied / settings UI ──────────────────────────────────────────────────────
class _DeniedBody extends StatelessWidget {
  final String? reason;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;
  const _DeniedBody({
    this.reason,
    required this.onOpenSettings,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              size: 40,
              color: Colors.red.shade400,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Permission Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            reason ?? 'Required permissions are needed to use this app.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Open Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onOpenSettings,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SplashRouter — session check & routing
// ─────────────────────────────────────────────────────────────────────────────
class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // ── 1. Restore session ─────────────────────────────────────────────────
    await ApiConfig.loadFromPrefs();
    final session =
        await ApiConfig.getSession() ?? await AuthService.getSession();

    if (!mounted) return;
    if (session == null) {
      _go(const LoginScreen());
      return;
    }

    ApiConfig.setToken(session['sessionToken'] ?? '');
    ApiConfig.tenantId = session['tenantId'] ?? '';
    ApiConfig.employeeId = session['empId'] ?? '';

    final bgPrefs = await SharedPreferences.getInstance();
    await bgPrefs.setString('bg_base_url', ApiConfig.baseUrl);

    final isValid = await AuthService.validateSession();
    if (!mounted) return;
    if (!isValid) {
      await ApiConfig.clearSession();
      if (!mounted) return;
      _go(const LoginScreen());
      return;
    }

    final freshSession =
        await ApiConfig.getSession() ?? await AuthService.getSession();
    if (!mounted) return;
    if (freshSession == null) {
      _go(const LoginScreen());
      return;
    }

    // ── 2. GPS service check ───────────────────────────────────────────────
    if (_isMobile) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!serviceEnabled) {
        final open = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Enable GPS'),
            content: const Text(
              'GPS is turned off. Please enable it to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Exit'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Turn On'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (open == true) {
          await Geolocator.openLocationSettings();
        } else {
          SystemNavigator.pop();
        }
        return;
      }
    }

    // ── 3. FCM + background service ────────────────────────────────────────
    if (_isMobile) {
      await NotifyService.instance.initializeFCM();
      await NotifyService.instance.syncDeviceSession();
      await initBackgroundService();

      final int? savedEmpId =
          bgPrefs.getInt('employee_id') ??
          int.tryParse(bgPrefs.getString('employeeId') ?? '');
      final int? savedSessionId =
          bgPrefs.getInt('session_id_$savedEmpId') ??
          bgPrefs.getInt('session_id');
      final bool wasTracking =
          bgPrefs.getBool('tracking_active_$savedEmpId') ?? false;

      if (savedEmpId != null && wasTracking) {
        debugPrint(
          '[SplashRouter] Resuming tracking emp=$savedEmpId session=$savedSessionId',
        );
        await startBackgroundTracking(savedEmpId, sessionId: savedSessionId);
      } else {
        debugPrint('[SplashRouter] No active session to resume');
      }
    }

    // ── 4. Route by role ───────────────────────────────────────────────────
    final int loginId = int.parse(freshSession['loginId']!);
    final int empId = int.parse(freshSession['empId']!);
    final String userType = freshSession['userType'] ?? 'employee';
    final String roleName = (freshSession['roleName'] ?? '')
        .toLowerCase()
        .trim();
    final String tenantId = freshSession['tenantId'] ?? '';
    final int roleId = int.tryParse(freshSession['role'] ?? '0') ?? 0;

    List<Map<String, dynamic>>? permissions;
    if (userType != 'app_admin') {
      permissions = await PermissionsService.getMyPermissions();
      if (!mounted) return;
    }

    debugPrint(
      '[SplashRouter] empId=$empId userType=$userType roleName=$roleName',
    );

    final bool isAppAdmin = userType == 'app_admin';

    final Widget destination = isAppAdmin
        ? AppAdminMaintenanceScreen()
        : UserDashboardScreen(
            loginId: loginId,
            employeeId: empId.toString(),
            roleId: roleId.toString(),
            tenantId: tenantId,
            userType: userType,
            permissions: permissions,
          );

    // ── 5. Smart permission gate — only on mobile, only first time per user ─
    final bool isOrgAdmin = userType == 'org_admin';
    if (_isMobile && !isAppAdmin && !isOrgAdmin) {
      final needs = _PermNeeds.fromModules(permissions);
      final prefs = await SharedPreferences.getInstance();
      final alreadyGranted =
          prefs.getBool('permissions_granted_$loginId') ?? false;

      if (needs.hasAny && !alreadyGranted) {
        if (!mounted) return;
        _go(
          SmartPermissionGate(
            loginId: loginId,
            permissions: permissions,
            destination: destination,
          ),
        );
        return;
      }
    }

    _go(destination);
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
