// main.dart
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  // ── 1. Firebase — mobile only ─────────────────────────────────────────────
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
      home: SplashRouter(),
    );
  }
}

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
    // ── 1. Restore session FIRST — no GPS or service init before this ─────
    await ApiConfig.loadFromPrefs();
    final session =
        await ApiConfig.getSession() ?? await AuthService.getSession();

    if (!mounted) return;

    if (session == null) {
      _go(const LoginScreen());
      return; // ← fresh install stops here, no permissions prompted
    }

    ApiConfig.setToken(session['sessionToken'] ?? '');
    ApiConfig.tenantId = session['tenantId'] ?? '';
    ApiConfig.employeeId = session['empId'] ?? '';

    // Save baseUrl for background isolate (ApiConfig statics unavailable there)
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

    // ✅ Re-read session after validateSession() so userType is fresh from server
    final freshSession =
        await ApiConfig.getSession() ?? await AuthService.getSession();
    if (!mounted) return;
    if (freshSession == null) {
      _go(const LoginScreen());
      return;
    }

    // ── 2. GPS check — only for validated sessions ────────────────────────
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
            title: const Text('Enable Location'),
            content: const Text(
              'Location (GPS) is turned OFF.\n\n'
              'Please enable it to continue using the app.',
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

    // ── 3. FCM + background service — only for validated sessions ─────────
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await NotifyService.instance.initializeFCM();
      await NotifyService.instance.syncDeviceSession();
      await initBackgroundService();

      // ── Restart tracking if employee had an active session ────────────
      final bgPrefs = await SharedPreferences.getInstance();
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
          '[SplashRouter] Resuming background tracking emp=$savedEmpId session=$savedSessionId',
        );
        await startBackgroundTracking(savedEmpId, sessionId: savedSessionId);
      } else {
        debugPrint(
          '[SplashRouter] No active tracking session to resume emp=$savedEmpId wasTracking=$wasTracking',
        );
      }
    }

    // ── 4. Route by role ──────────────────────────────────────────────────
    final int loginId = int.parse(freshSession['loginId']!);
    final int empId = int.parse(freshSession['empId']!);
    final String userType = freshSession['userType'] ?? 'employee';
    final String roleName = (freshSession['roleName'] ?? '')
        .toLowerCase()
        .trim();
    final String username = freshSession['username'] ?? '';
    final String tenantId = freshSession['tenantId'] ?? '';
    final int roleId = int.tryParse(freshSession['role'] ?? '0') ?? 0;

    // ✅ Fetch permissions on every cold start (not just fresh login)
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

    final Widget destination;

    if (isAppAdmin) {
      destination = AppAdminDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
      );
    } else {
      // ✅ Route by userType (set from role_name on server — stable across tenants)
      // Never route by numeric roleId alone
      destination = UserDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
        userType: userType,
        permissions: permissions,
      );
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
