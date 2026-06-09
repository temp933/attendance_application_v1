// // main.dart
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'attendance/screens/login_screen.dart';
// import 'attendance/screens/user_dashboard_screen.dart';
// import 'attendance/services/location_services.dart';
// import 'attendance/services/auth_service.dart';
// import 'attendance/services/background_service.dart';
// import 'attendance/services/notify.dart';
// import 'attendance/App Admin/app_admin_dashboard_screen.dart';
// import 'attendance/services/app_admin_provider.dart';
// import 'attendance/providers/api_config.dart';
// import 'attendance/services/permissions_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // ── 1. Firebase — mobile only ─────────────────────────────────────────────
//   if (!kIsWeb) {
//     await Firebase.initializeApp();
//   }

//   runApp(
//     MultiProvider(
//       providers: [
//         Provider<LocationService>(create: (_) => LocationService()),
//         Provider<AuthService>(create: (_) => AuthService()),
//         ChangeNotifierProvider<AppAdminProvider>(
//           create: (_) => AppAdminProvider(),
//         ),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: SplashRouter(),
//     );
//   }
// }

// class SplashRouter extends StatefulWidget {
//   const SplashRouter({super.key});

//   @override
//   State<SplashRouter> createState() => _SplashRouterState();
// }

// class _SplashRouterState extends State<SplashRouter> {
//   @override
//   void initState() {
//     super.initState();
//     _checkSession();
//   }

//   Future<void> _checkSession() async {
//     // ── 1. Restore session FIRST — no GPS or service init before this ─────
//     await ApiConfig.loadFromPrefs();
//     final session =
//         await ApiConfig.getSession() ?? await AuthService.getSession();

//     if (!mounted) return;

//     if (session == null) {
//       _go(const LoginScreen());
//       return; // ← fresh install stops here, no permissions prompted
//     }

//     ApiConfig.setToken(session['sessionToken'] ?? '');
//     ApiConfig.tenantId = session['tenantId'] ?? '';
//     ApiConfig.employeeId = session['empId'] ?? '';

//     // Save baseUrl for background isolate (ApiConfig statics unavailable there)
//     final bgPrefs = await SharedPreferences.getInstance();
//     await bgPrefs.setString('bg_base_url', ApiConfig.baseUrl);

//     final isValid = await AuthService.validateSession();
//     if (!mounted) return;

//     if (!isValid) {
//       await ApiConfig.clearSession();
//       if (!mounted) return;
//       _go(const LoginScreen());
//       return;
//     }

//     // ✅ Re-read session after validateSession() so userType is fresh from server
//     final freshSession =
//         await ApiConfig.getSession() ?? await AuthService.getSession();
//     if (!mounted) return;
//     if (freshSession == null) {
//       _go(const LoginScreen());
//       return;
//     }

//     // ── 2. GPS check — only for validated sessions ────────────────────────
//     if (!kIsWeb &&
//         (defaultTargetPlatform == TargetPlatform.android ||
//             defaultTargetPlatform == TargetPlatform.iOS)) {
//       final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!mounted) return;

//       if (!serviceEnabled) {
//         final open = await showDialog<bool>(
//           context: context,
//           barrierDismissible: false,
//           builder: (ctx) => AlertDialog(
//             title: const Text('Enable Location'),
//             content: const Text(
//               'Location (GPS) is turned OFF.\n\n'
//               'Please enable it to continue using the app.',
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx, false),
//                 child: const Text('Exit'),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(ctx, true),
//                 child: const Text('Turn On'),
//               ),
//             ],
//           ),
//         );
//         if (!mounted) return;
//         if (open == true) {
//           await Geolocator.openLocationSettings();
//         } else {
//           SystemNavigator.pop();
//         }
//         return;
//       }
//     }

//     // ── 3. FCM + background service — only for validated sessions ─────────
//     if (!kIsWeb &&
//         (defaultTargetPlatform == TargetPlatform.android ||
//             defaultTargetPlatform == TargetPlatform.iOS)) {
//       await NotifyService.instance.initializeFCM();
//       await NotifyService.instance.syncDeviceSession();
//       await initBackgroundService();

//       // ── Restart tracking if employee had an active session ────────────
//       final bgPrefs = await SharedPreferences.getInstance();
//       final int? savedEmpId =
//           bgPrefs.getInt('employee_id') ??
//           int.tryParse(bgPrefs.getString('employeeId') ?? '');
//       final int? savedSessionId =
//           bgPrefs.getInt('session_id_$savedEmpId') ??
//           bgPrefs.getInt('session_id');
//       final bool wasTracking =
//           bgPrefs.getBool('tracking_active_$savedEmpId') ?? false;

//       if (savedEmpId != null && wasTracking) {
//         debugPrint(
//           '[SplashRouter] Resuming background tracking emp=$savedEmpId session=$savedSessionId',
//         );
//         await startBackgroundTracking(savedEmpId, sessionId: savedSessionId);
//       } else {
//         debugPrint(
//           '[SplashRouter] No active tracking session to resume emp=$savedEmpId wasTracking=$wasTracking',
//         );
//       }
//     }

//     // ── 4. Route by role ──────────────────────────────────────────────────
//     final int loginId = int.parse(freshSession['loginId']!);
//     final int empId = int.parse(freshSession['empId']!);
//     final String userType = freshSession['userType'] ?? 'employee';
//     final String roleName = (freshSession['roleName'] ?? '')
//         .toLowerCase()
//         .trim();
//     final String username = freshSession['username'] ?? '';
//     final String tenantId = freshSession['tenantId'] ?? '';
//     final int roleId = int.tryParse(freshSession['role'] ?? '0') ?? 0;

//     // ✅ Fetch permissions on every cold start (not just fresh login)
//     List<Map<String, dynamic>>? permissions;
//     if (userType != 'app_admin' && userType != 'org_admin') {
//       permissions = await PermissionsService.getMyPermissions();
//       if (!mounted) return;
//     }

//     debugPrint(
//       '[SplashRouter] empId=$empId userType=$userType roleName=$roleName',
//     );

//     final bool isAppAdmin =
//         userType == 'app_admin' || username.toLowerCase() == 'app_admin';

//     final Widget destination;

//     if (isAppAdmin) {
//       destination = AppAdminDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         roleId: roleId.toString(),
//         tenantId: tenantId,
//       );
//     } else {
//       // ✅ Route by userType (set from role_name on server — stable across tenants)
//       // Never route by numeric roleId alone
//       destination = UserDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         roleId: roleId.toString(),
//         tenantId: tenantId,
//         userType: userType,
//         permissions: permissions,
//       );
//     }

//     _go(destination);
//   }

//   void _go(Widget screen) {
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => screen),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));
//   }
  // }
  // main.dart
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
  import 'attendance/App Admin/app_admin_dashboard_screen.dart';
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
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PermissionGate(), // ← permission gate FIRST, always
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PermissionGate
  //
  // On the very first launch (and any launch where permissions are missing),
  // this screen explains why permissions are needed and requests them before
  // doing anything else. Only after all required permissions are granted does
  // it hand off to SplashRouter.
  //
  // This satisfies:
  //   • Google Play's "Permission rationale must be shown before request"
  //   • Android 12+ background location restriction (must grant foreground first)
  //   • iOS "Always Allow" two-step flow
  // ─────────────────────────────────────────────────────────────────────────────
  class PermissionGate extends StatefulWidget {
    const PermissionGate({super.key});

    @override
    State<PermissionGate> createState() => _PermissionGateState();
  }

  class _PermissionGateState extends State<PermissionGate> {
    _GateStep _step = _GateStep.checking;
    String? _denyReason;

    @override
    void initState() {
      super.initState();
      _run();
    }

    // ── Permission flow ────────────────────────────────────────────────────────
    Future<void> _run() async {
      if (kIsWeb) {
        _advance();
        return;
      }

      // Only run the full flow on mobile
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        _advance();
        return;
      }

      // ── Check if we already have everything ───────────────────────────────
      if (await _allGranted()) {
        _advance();
        return;
      }

      // ── Show rationale screen ──────────────────────────────────────────────
      if (mounted) setState(() => _step = _GateStep.rationale);
    }

    /// Returns true only when every required permission is already granted.
    Future<bool> _allGranted() async {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      final whenInUse = await Permission.locationWhenInUse.status;
      if (!whenInUse.isGranted) return false;

      final always = await Permission.locationAlways.status;
      if (!always.isGranted) return false;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final notif = await Permission.notification.status;
        if (!notif.isGranted) return false;
      }

      return true;
    }

    /// Request every permission in the correct order and return whether all
    /// required ones were granted.
    Future<bool> _requestAll() async {
      // ── Step 1: GPS service must be ON ────────────────────────────────────
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
              'This app needs GPS to record attendance.\n\n'
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
          // Give the user time to toggle and come back
          await Future.delayed(const Duration(seconds: 2));
        }
        if (!await Geolocator.isLocationServiceEnabled()) {
          _denyReason = 'GPS is disabled. Please enable it in Settings.';
          return false;
        }
      }

      // ── Step 2: Location When In Use (foreground) ─────────────────────────
      // Must grant this before Android lets us ask for "Always".
      var whenInUse = await Permission.locationWhenInUse.status;
      if (!whenInUse.isGranted) {
        whenInUse = await Permission.locationWhenInUse.request();
      }
      if (!whenInUse.isGranted) {
        if (whenInUse.isPermanentlyDenied) {
          _denyReason =
              'Location permission is permanently denied.\nOpen Settings → App → Permissions → Location and allow it.';
        } else {
          _denyReason = 'Location permission is required to record attendance.';
        }
        return false;
      }

      // ── Step 3: Location Always (background) ──────────────────────────────
      // On Android 10+ the OS shows a separate "Allow all the time" dialog.
      // On iOS this triggers the "Always Allow" upgrade sheet.
      var always = await Permission.locationAlways.status;
      if (!always.isGranted) {
        // Show our rationale dialog before the OS prompt
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
                'site check-ins and GPS attendance even when the screen is off.\n\n'
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
        if (always.isPermanentlyDenied) {
          _denyReason =
              'Background location is permanently denied.\n\n'
              'Open Settings → App → Permissions → Location → Allow all the time.';
        } else {
          _denyReason =
              'Background location is required to track site attendance.';
        }
        return false;
      }

      // ── Step 4: Notifications (Android 13+ / TIRAMISU) ────────────────────
      if (defaultTargetPlatform == TargetPlatform.android) {
        var notif = await Permission.notification.status;
        if (!notif.isGranted) {
          notif = await Permission.notification.request();
        }
        // Notifications are optional — don't block the user if denied
        if (!notif.isGranted) {
          debugPrint(
            '[Permissions] Notification permission denied — continuing anyway',
          );
        }
      }

      return true;
    }

    // ── Grant all permissions when user taps "Continue" ──────────────────────
    Future<void> _onContinue() async {
      if (mounted) setState(() => _step = _GateStep.requesting);

      final granted = await _requestAll();
      if (!mounted) return;

      if (granted) {
        _advance();
      } else {
        setState(() => _step = _GateStep.denied);
      }
    }

    /// Open app settings so the user can manually enable permissions.
    Future<void> _openSettings() async {
      await openAppSettings();
      // After they return, re-check
      if (!mounted) return;
      if (await _allGranted()) {
        _advance();
      } else {
        setState(() => _step = _GateStep.rationale);
      }
    }

    /// All permissions satisfied — hand off to SplashRouter.
    void _advance() {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashRouter()),
      );
    }

    // ── UI ─────────────────────────────────────────────────────────────────────
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
          return _RationaleBody(onContinue: _onContinue);

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

  // ── Rationale UI ─────────────────────────────────────────────────────────────
  class _RationaleBody extends StatelessWidget {
    final VoidCallback onContinue;
    const _RationaleBody({required this.onContinue});

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
                  Icons.location_on_rounded,
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
              'To record your attendance and track site visits accurately, '
              'the app needs the following permissions:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _permRow(
              icon: Icons.gps_fixed_rounded,
              color: Colors.green.shade600,
              title: 'Location — Always',
              desc:
                  'Tracks GPS check-ins and site presence even when the screen is off.',
            ),
            const SizedBox(height: 14),
            _permRow(
              icon: Icons.notifications_rounded,
              color: Colors.indigo.shade500,
              title: 'Notifications',
              desc: 'Shows background tracking status and attendance alerts.',
            ),
            const SizedBox(height: 36),
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
                      'Your location data is only sent to your company\'s HR server '
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
              reason ?? 'Location permission is required to use this app.',
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
  // SplashRouter — session check & routing (unchanged logic, permission-free now)
  // ─────────────────────────────────────────────────────────────────────────────
  class SplashRouter extends StatefulWidget {
    const SplashRouter({super.key});

    @override
    State<SplashRouter> createState() => _SplashRouterState();
  }

  class _SplashRouterState extends State<SplashRouter> {
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

      // ── 2. GPS service check (permission already guaranteed by PermissionGate)
      //       Only verify the service is switched ON, not the permission itself.
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
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
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
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
      final String username = freshSession['username'] ?? '';
      final String tenantId = freshSession['tenantId'] ?? '';
      final int roleId = int.tryParse(freshSession['role'] ?? '0') ?? 0;

      List<Map<String, dynamic>>? permissions;
      if (userType != 'app_admin' && userType != 'org_admin') {
        permissions = await PermissionsService.getMyPermissions();
        if (!mounted) return;
      }

      debugPrint(
        '[SplashRouter] empId=$empId userType=$userType roleName=$roleName',
      );

      final bool isAppAdmin =
          userType == 'app_admin' || username.toLowerCase() == 'app_admin';

      final Widget destination = isAppAdmin
          ? AppAdminDashboardScreen(
              loginId: loginId,
              employeeId: empId.toString(),
              roleId: roleId.toString(),
              tenantId: tenantId,
            )
          : UserDashboardScreen(
              loginId: loginId,
              employeeId: empId.toString(),
              roleId: roleId.toString(),
              tenantId: tenantId,
              userType: userType,
              permissions: permissions,
            );

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
