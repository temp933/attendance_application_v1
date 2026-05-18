// // import 'package:geolocator/geolocator.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/services.dart';
// // import 'package:provider/provider.dart';
// // import 'attendance/screens/login_screen.dart';
// // import 'attendance/screens/emp_dashboard_screen.dart';
// // import 'attendance/screens/admin_dashboard.dart';
// // import 'attendance/screens/hr_dashboard_screen.dart';
// // import 'attendance/screens/team_lead_dashboard.dart';
// // import 'attendance/services/location_services.dart';
// // import 'attendance/services/auth_service.dart';
// // import 'attendance/services/background_service.dart';
// // import 'attendance/screens/manager_dashboard.dart';
// // import 'attendance/App Admin/app_admin_dashboard_screen.dart';
// // import 'attendance/services/app_admin_provider.dart';
// // import 'attendance/providers/api_config.dart';

// // void main() async {
// //   WidgetsFlutterBinding.ensureInitialized();

// //   if (!kIsWeb &&
// //       (defaultTargetPlatform == TargetPlatform.android ||
// //           defaultTargetPlatform == TargetPlatform.iOS)) {
// //     await initBackgroundService();
// //   }

// //   runApp(
// //     MultiProvider(
// //       providers: [
// //         Provider<LocationService>(create: (_) => LocationService()),
// //         Provider<AuthService>(create: (_) => AuthService()),
// //         ChangeNotifierProvider<AppAdminProvider>(
// //           create: (_) => AppAdminProvider(),
// //         ),
// //       ],
// //       child: const MyApp(),
// //     ),
// //   );
// // }

// // class MyApp extends StatelessWidget {
// //   const MyApp({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return const MaterialApp(
// //       debugShowCheckedModeBanner: false,
// //       home: SplashRouter(),
// //     );
// //   }
// // }

// // class SplashRouter extends StatefulWidget {
// //   const SplashRouter({super.key});

// //   @override
// //   State<SplashRouter> createState() => _SplashRouterState();
// // }

// // class _SplashRouterState extends State<SplashRouter>
// //     with WidgetsBindingObserver {
// //   bool _checking = false;

// //   @override
// //   void initState() {
// //     super.initState();
// //     WidgetsBinding.instance.addObserver(this);
// //     _checkSession();
// //   }

// //   @override
// //   void dispose() {
// //     WidgetsBinding.instance.removeObserver(this);
// //     super.dispose();
// //   }

// //   @override
// //   void didChangeAppLifecycleState(AppLifecycleState state) {
// //     if (state == AppLifecycleState.resumed) {
// //       _checkSession(); // re-check when user comes back from settings
// //     }
// //   }

// //   Future<void> _checkSession() async {
// //     if (_checking) return;
// //     _checking = true;

// //     // ── Step 0: Check if GPS is ON ─────────────────────────────────────────
// //     final serviceEnabled = await Geolocator.isLocationServiceEnabled();

// //     if (!mounted) {
// //       _checking = false;
// //       return;
// //     }

// //     if (!serviceEnabled) {
// //       final open = await showDialog<bool>(
// //         context: context,
// //         barrierDismissible: false,
// //         builder: (ctx) => AlertDialog(
// //           title: const Text('Enable Location'),
// //           content: const Text(
// //             'Location (GPS) is turned OFF.\n\n'
// //             'Please enable it to continue using the app.',
// //           ),
// //           actions: [
// //             TextButton(
// //               onPressed: () => Navigator.pop(ctx, false),
// //               child: const Text('Exit'),
// //             ),
// //             ElevatedButton(
// //               onPressed: () => Navigator.pop(ctx, true),
// //               child: const Text('Turn On'),
// //             ),
// //           ],
// //         ),
// //       );

// //       if (open == true) {
// //         await Geolocator.openLocationSettings();
// //         _checking = false;
// //         return;
// //       } else {
// //         _checking = false;
// //         SystemNavigator.pop();
// //         return;
// //       }
// //     }

// //     // ── Step 1: Load token + check session ────────────────────────────────
// //     await ApiConfig.loadFromPrefs(); // ← load token & tenantId from prefs
// //     // Add this temporarily to verify:
// //     debugPrint('Token after load: ${ApiConfig.headers['Authorization']}');
// //     debugPrint('TenantId after load: ${ApiConfig.tenantId}');
// //     final session = await AuthService.getSession();

// //     if (!mounted) {
// //       _checking = false;
// //       return;
// //     }

// //     if (session == null) {
// //       _checking = false;
// //       _go(const LoginScreen());
// //       return;
// //     }

// //     // Token is already loaded by loadFromPrefs, but set explicitly for safety
// //     ApiConfig.setToken(session['session_token'] ?? '');
// //     ApiConfig.tenantId = session['tenantId'] ?? '';
// //     ApiConfig.employeeId = session['empId'] ?? '';

// //     final isValid = await AuthService.validateSession();

// //     if (!mounted) {
// //       _checking = false;
// //       return;
// //     }

// //     if (!isValid) {
// //       await AuthService.clearSession();
// //       if (!mounted) {
// //         _checking = false;
// //         return;
// //       }
// //       _checking = false;
// //       _go(const LoginScreen());
// //       return;
// //     }

// //     // ── Step 2: Route by role ──────────────────────────────────────────────
// //     final int loginId = int.parse(session['loginId']!);
// //     final int empId = int.parse(session['empId']!);
// //     final int roleId = int.parse(session['role']!);
// //     final String username = session['username'] ?? '';
// //     final bool isAppAdmin = username.toLowerCase() == 'app_admin'.toLowerCase();
// //     final String tenantId = session['tenantId'] ?? '';

// //     Widget destination;

// //     if (roleId == 1) {
// //       destination = AdminDashboardScreen(
// //         loginId: loginId,
// //         employeeId: empId.toString(),
// //         roleId: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     } else if (roleId == 2) {
// //       destination = HRDashboardScreen(
// //         loginId: loginId,
// //         employeeId: empId.toString(),
// //         roleId: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     } else if (roleId == 3) {
// //       destination = TLDashboardScreen(
// //         loginId: loginId,
// //         employeeId: empId.toString(),
// //         role: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     } else if (isAppAdmin) {
// //       destination = AppAdminDashboardScreen(
// //         loginId: loginId,
// //         employeeId: empId.toString(),
// //         roleId: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     } else if (roleId == 8) {
// //       destination = ManagerDashboardScreen(
// //         loginId: loginId,
// //         employeeId: empId.toString(),
// //         roleId: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     } else {
// //       destination = DashboardScreen(
// //         loginId: loginId,
// //         empId: empId,
// //         role: roleId.toString(),
// //         tenantId: tenantId,
// //       );
// //     }

// //     _checking = false;
// //     _go(destination);
// //   }

// //   void _go(Widget screen) {
// //     if (!mounted) return;
// //     Navigator.pushReplacement(
// //       context,
// //       MaterialPageRoute(builder: (_) => screen),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return const Scaffold(body: Center(child: CircularProgressIndicator()));
// //   }
// // }
// import 'package:geolocator/geolocator.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import 'attendance/screens/login_screen.dart';
// import 'attendance/screens/emp_dashboard_screen.dart';
// import 'attendance/screens/admin_dashboard.dart';
// import 'attendance/screens/hr_dashboard_screen.dart';
// import 'attendance/screens/team_lead_dashboard.dart';
// import 'attendance/services/location_services.dart';
// import 'attendance/services/auth_service.dart';
// import 'attendance/services/background_service.dart';
// import 'attendance/screens/manager_dashboard.dart';
// import 'attendance/App Admin/app_admin_dashboard_screen.dart';
// import 'attendance/services/app_admin_provider.dart';
// import 'attendance/providers/api_config.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

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

// class _SplashRouterState extends State<SplashRouter>
//     with WidgetsBindingObserver {
//   bool _checking = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _checkSession();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) {
//       _checkSession();
//     }
//   }

//   Future<void> _checkSession() async {
//     if (_checking) return;
//     _checking = true;

//     // ── Step 0: GPS check ─────────────────────────────────────────────────
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!mounted) {
//       _checking = false;
//       return;
//     }

//     if (!serviceEnabled) {
//       final open = await showDialog<bool>(
//         context: context,
//         barrierDismissible: false,
//         builder: (ctx) => AlertDialog(
//           title: const Text('Enable Location'),
//           content: const Text(
//             'Location (GPS) is turned OFF.\n\n'
//             'Please enable it to continue using the app.',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx, false),
//               child: const Text('Exit'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(ctx, true),
//               child: const Text('Turn On'),
//             ),
//           ],
//         ),
//       );
//       if (open == true) {
//         await Geolocator.openLocationSettings();
//       } else {
//         SystemNavigator.pop();
//       }
//       _checking = false;
//       return;
//     }

//     // ── Step 1: Restore session from disk ─────────────────────────────────
//     await ApiConfig.loadFromPrefs();

//     // Read session using ApiConfig — keys are guaranteed to match
//     final session =
//         await ApiConfig.getSession() ?? await AuthService.getSession();

//     debugPrint('── SplashRouter session check ──');
//     debugPrint('token    : ${ApiConfig.headers['Authorization'] ?? 'none'}');
//     debugPrint('tenantId : ${ApiConfig.tenantId}');
//     debugPrint('employeeId: ${ApiConfig.employeeId}');

//     if (!mounted) {
//       _checking = false;
//       return;
//     }

//     if (session == null) {
//       _checking = false;
//       _go(const LoginScreen());
//       return;
//     }

//     // Restore in-memory values (loadFromPrefs already did token+tenant+emp,
//     // but set them again explicitly from the session map for safety)
//     ApiConfig.setToken(session['sessionToken'] ?? '');
//     ApiConfig.tenantId = session['tenantId'] ?? '';
//     ApiConfig.employeeId = session['empId'] ?? '';

//     // ── Step 2: Validate with server ──────────────────────────────────────
//     final isValid = await AuthService.validateSession();
//     if (!mounted) {
//       _checking = false;
//       return;
//     }

//     if (!isValid) {
//       await ApiConfig.clearSession();
//       if (!mounted) {
//         _checking = false;
//         return;
//       }
//       _checking = false;
//       _go(const LoginScreen());
//       return;
//     }

//     // ── Step 3: Route by role ─────────────────────────────────────────────
//     final int loginId = int.parse(session['loginId']!);
//     final int empId = int.parse(session['empId']!);
//     final int roleId = int.parse(session['role']!);
//     final String userType = session['userType'] ?? 'employee';
//     final String username = session['username'] ?? '';
//     final String tenantId = session['tenantId'] ?? '';

//     final bool isAppAdmin =
//         userType == 'app_admin' || username.toLowerCase() == 'app_admin';

//     Widget destination;

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

//     _checking = false;
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
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'attendance/screens/login_screen.dart';
import 'attendance/screens/emp_dashboard_screen.dart';
import 'attendance/screens/admin_dashboard.dart';
import 'attendance/screens/hr_dashboard_screen.dart';
import 'attendance/screens/team_lead_dashboard.dart';
import 'attendance/services/location_services.dart';
import 'attendance/services/auth_service.dart';
import 'attendance/services/background_service.dart';
import 'attendance/screens/manager_dashboard.dart';
import 'attendance/App Admin/app_admin_dashboard_screen.dart';
import 'attendance/services/app_admin_provider.dart';
import 'attendance/providers/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // ── Only runs ONCE on cold start. No lifecycle observer needed. ───────────
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // ── Step 0: GPS check ─────────────────────────────────────────────────
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

    // ── Step 1: Restore session from disk ─────────────────────────────────
    await ApiConfig.loadFromPrefs();
    final session =
        await ApiConfig.getSession() ?? await AuthService.getSession();

    debugPrint('── SplashRouter session check ──');
    debugPrint('token     : ${ApiConfig.headers['Authorization'] ?? 'none'}');
    debugPrint('tenantId  : ${ApiConfig.tenantId}');
    debugPrint('employeeId: ${ApiConfig.employeeId}');

    if (!mounted) return;

    if (session == null) {
      _go(const LoginScreen());
      return;
    }

    // Restore in-memory values
    ApiConfig.setToken(session['sessionToken'] ?? '');
    ApiConfig.tenantId = session['tenantId'] ?? '';
    ApiConfig.employeeId = session['empId'] ?? '';

    // ── Step 2: Validate with server ──────────────────────────────────────
    final isValid = await AuthService.validateSession();
    if (!mounted) return;

    if (!isValid) {
      await ApiConfig.clearSession();
      if (!mounted) return;
      _go(const LoginScreen());
      return;
    }

    // ── Step 3: Route by role ─────────────────────────────────────────────
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
    } else if (roleId == 1) {
      destination = AdminDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
      );
    } else if (roleId == 2) {
      destination = HRDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
      );
    } else if (roleId == 3) {
      destination = TLDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        role: roleId.toString(),
        tenantId: tenantId,
      );
    } else if (roleId == 8) {
      destination = ManagerDashboardScreen(
        loginId: loginId,
        employeeId: empId.toString(),
        roleId: roleId.toString(),
        tenantId: tenantId,
      );
    } else {
      destination = DashboardScreen(
        loginId: loginId,
        empId: empId,
        role: roleId.toString(),
        tenantId: tenantId,
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
