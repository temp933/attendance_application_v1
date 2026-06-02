// // main.dart
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'package:firebase_core/firebase_core.dart';

// import 'attendance/screens/login_screen.dart';
// import 'attendance/screens/emp_dashboard_screen.dart';
// import 'attendance/screens/admin_dashboard.dart';
// import 'attendance/screens/hr_dashboard_screen.dart';
// import 'attendance/screens/team_lead_dashboard.dart';
// import 'attendance/services/location_services.dart';
// import 'attendance/services/auth_service.dart';
// import 'attendance/services/background_service.dart';
// import 'attendance/services/notify.dart';
// import 'attendance/screens/manager_dashboard.dart';
// import 'attendance/App Admin/app_admin_dashboard_screen.dart';
// import 'attendance/services/app_admin_provider.dart';
// import 'attendance/providers/api_config.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // ── 1. Firebase — mobile only ─────────────────────────────────────────────
//   if (!kIsWeb) {
//     await Firebase.initializeApp();
//   }

//   // ── 2. FCM / notifications — mobile only ─────────────────────────────────
//   if (!kIsWeb &&
//       (defaultTargetPlatform == TargetPlatform.android ||
//           defaultTargetPlatform == TargetPlatform.iOS)) {
//     await NotifyService.instance.initializeFCM();
//   }

//   // ── 3. Background service — mobile only ──────────────────────────────────
//   if (!kIsWeb &&
//       (defaultTargetPlatform == TargetPlatform.android ||
//           defaultTargetPlatform == TargetPlatform.iOS)) {
//     await initBackgroundService();
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
//     // ── GPS check — mobile only ───────────────────────────────────────────
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

//     // ── Restore session ───────────────────────────────────────────────────
//     await ApiConfig.loadFromPrefs();
//     final session =
//         await ApiConfig.getSession() ?? await AuthService.getSession();

//     if (!mounted) return;

//     if (session == null) {
//       _go(const LoginScreen());
//       return;
//     }

//     ApiConfig.setToken(session['sessionToken'] ?? '');
//     ApiConfig.tenantId = session['tenantId'] ?? '';
//     ApiConfig.employeeId = session['empId'] ?? '';

//     final isValid = await AuthService.validateSession();
//     if (!mounted) return;

//     if (!isValid) {
//       await ApiConfig.clearSession();
//       if (!mounted) return;
//       _go(const LoginScreen());
//       return;
//     }

//     // ── Re-sync FCM token — mobile only ──────────────────────────────────
//     if (!kIsWeb &&
//         (defaultTargetPlatform == TargetPlatform.android ||
//             defaultTargetPlatform == TargetPlatform.iOS)) {
//       await NotifyService.instance.syncDeviceSession();
//     }

//     // ── Route by role ─────────────────────────────────────────────────────
//     final int loginId = int.parse(session['loginId']!);
//     final int empId = int.parse(session['empId']!);
//     final int roleId = int.parse(session['role']!);
//     final String userType = session['userType'] ?? 'employee';
//     final String username = session['username'] ?? '';
//     final String tenantId = session['tenantId'] ?? '';

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
//     } else if (roleId == 1) {
//       destination = AdminDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         roleId: roleId.toString(),
//         tenantId: tenantId,
//       );
//     } else if (roleId == 2) {
//       destination = HRDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         roleId: roleId.toString(),
//         tenantId: tenantId,
//       );
//     } else if (roleId == 3) {
//       destination = TLDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         role: roleId.toString(),
//         tenantId: tenantId,
//       );
//     } else if (roleId == 8) {
//       destination = ManagerDashboardScreen(
//         loginId: loginId,
//         employeeId: empId.toString(),
//         roleId: roleId.toString(),
//         tenantId: tenantId,
//       );
//     } else {
//       destination = DashboardScreen(
//         loginId: loginId,
//         empId: empId,
//         role: roleId.toString(),
//         tenantId: tenantId,
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
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'attendance/screens/login_screen.dart';
import 'attendance/screens/user_dashboard_screen.dart';
import 'attendance/services/location_services.dart';
import 'attendance/services/auth_service.dart';
import 'attendance/services/background_service.dart';
import 'attendance/services/notify.dart';
import 'attendance/services/permissions_service.dart';
import 'attendance/App Admin/app_admin_dashboard_screen.dart';
import 'attendance/services/app_admin_provider.dart';
import 'attendance/providers/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase — mobile only ─────────────────────────────────────────────
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  // ── 2. FCM / notifications — mobile only ─────────────────────────────────
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await NotifyService.instance.initializeFCM();
  }

  // ── 3. Background service — mobile only ──────────────────────────────────
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await initBackgroundService();
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
    // ── GPS check — mobile only ───────────────────────────────────────────
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

    // ── Restore session ───────────────────────────────────────────────────
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

    final isValid = await AuthService.validateSession();
    if (!mounted) return;

    if (!isValid) {
      await ApiConfig.clearSession();
      if (!mounted) return;
      _go(const LoginScreen());
      return;
    }

    // ── Re-sync FCM token — mobile only ──────────────────────────────────
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await NotifyService.instance.syncDeviceSession();
    }

    // ── Route by role ─────────────────────────────────────────────────────
    final int loginId = int.parse(session['loginId']!);
    final int empId = int.parse(session['empId']!);
    final int roleId = int.parse(session['role']!);
    final String userType = session['userType'] ?? 'employee';
    final String username = session['username'] ?? '';
    final String tenantId = session['tenantId'] ?? '';

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
      // ── Fetch permissions for non-app-admin users ─────────────────────
      List<Map<String, dynamic>>? permissions;
      // if (userType != 'org_admin') {
      //   permissions = await PermissionsService.getMyPermissions();
      // }
      if (!mounted) return;

      destination = UserDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
        userType: userType,
        permissions: permissions, // null = full access for org_admin
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
