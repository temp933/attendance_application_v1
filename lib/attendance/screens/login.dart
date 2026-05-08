// import 'package:flutter/material.dart';
// import 'admin_home.dart';
// import 'employee_home.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController idController = TextEditingController();
//   final TextEditingController passController = TextEditingController();

//   String error = "";

//   void login() {
//     String id = idController.text.trim();
//     String pass = passController.text.trim();

//     if (id == "admin" && pass == "123") {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const AdminHome()),
//       );
//     } else if (id == "emp" && pass == "123") {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const EmployeeHome(employeeId: 2)),
//       );
//     } else {
//       setState(() {
//         error = "Invalid Login ID or Password";
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Login")),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Card(
//             elevation: 6,
//             child: Padding(
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Text(
//                     "Attendance System Login",
//                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 20),

//                   TextField(
//                     controller: idController,
//                     decoration: const InputDecoration(
//                       labelText: "Login ID",
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   const SizedBox(height: 15),

//                   TextField(
//                     controller: passController,
//                     obscureText: true,
//                     decoration: const InputDecoration(
//                       labelText: "Password",
//                       border: OutlineInputBorder(),
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   if (error.isNotEmpty)
//                     Text(error, style: const TextStyle(color: Colors.red)),

//                   const SizedBox(height: 20),

//                   ElevatedButton(
//                     onPressed: login,
//                     child: const Text("LOGIN"),
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 45),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
// // import 'package:flutter/material.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'admin_home.dart';
// // import 'employee_home.dart';

// // class LoginScreen extends StatefulWidget {
// //   const LoginScreen({super.key});

// //   @override
// //   State<LoginScreen> createState() => _LoginScreenState();
// // }

// // class _LoginScreenState extends State<LoginScreen> {
// //   final TextEditingController idController = TextEditingController();
// //   final TextEditingController passController = TextEditingController();

// //   String error = "";

// //   @override
// //   void initState() {
// //     super.initState();
// //     _checkLogin(); // check if user already logged in
// //   }

// //   // Check login state from SharedPreferences
// //   void _checkLogin() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
// //     final role = prefs.getString('role') ?? '';

// //     if (isLoggedIn) {
// //       // Navigate directly to appropriate home screen
// //       if (role == 'admin') {
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(builder: (_) => const AdminHome()),
// //         );
// //       } else if (role == 'emp') {
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(builder: (_) => const EmployeeHome(employeeId: 2)),
// //         );
// //       }
// //     }
// //   }

// //   void login() async {
// //     String id = idController.text.trim();
// //     String pass = passController.text.trim();

// //     if (id == "admin" && pass == "123") {
// //       // Save login state
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.setBool('is_logged_in', true);
// //       await prefs.setString('role', 'admin');

// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(builder: (_) => const AdminHome()),
// //       );
// //     } else if (id == "emp" && pass == "123") {
// //       // Save login state
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.setBool('is_logged_in', true);
// //       await prefs.setString('role', 'emp');

// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(builder: (_) => const EmployeeHome(employeeId: 2)),
// //       );
// //     } else {
// //       setState(() {
// //         error = "Invalid Login ID or Password";
// //       });
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text("Login")),
// //       body: Center(
// //         child: Padding(
// //           padding: const EdgeInsets.all(20),
// //           child: Card(
// //             elevation: 6,
// //             child: Padding(
// //               padding: const EdgeInsets.all(20),
// //               child: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   const Text(
// //                     "Attendance System Login",
// //                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// //                   ),
// //                   const SizedBox(height: 20),

// //                   TextField(
// //                     controller: idController,
// //                     decoration: const InputDecoration(
// //                       labelText: "Login ID",
// //                       border: OutlineInputBorder(),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 15),

// //                   TextField(
// //                     controller: passController,
// //                     obscureText: true,
// //                     decoration: const InputDecoration(
// //                       labelText: "Password",
// //                       border: OutlineInputBorder(),
// //                     ),
// //                   ),

// //                   const SizedBox(height: 20),

// //                   if (error.isNotEmpty)
// //                     Text(error, style: const TextStyle(color: Colors.red)),

// //                   const SizedBox(height: 20),

// //                   ElevatedButton(
// //                     onPressed: login,
// //                     child: const Text("LOGIN"),
// //                     style: ElevatedButton.styleFrom(
// //                       minimumSize: const Size(double.infinity, 45),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// // import 'package:flutter/material.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'admin_home.dart';
// // import 'employee_home.dart';

// // class LoginScreen extends StatefulWidget {
// //   const LoginScreen({super.key});

// //   @override
// //   State<LoginScreen> createState() => _LoginScreenState();
// // }

// // class _LoginScreenState extends State<LoginScreen> {
// //   final TextEditingController _idCtrl = TextEditingController();
// //   final TextEditingController _passCtrl = TextEditingController();

// //   String _error = '';

// //   @override
// //   void initState() {
// //     super.initState();
// //     // Defer until the first frame so Navigator works safely from initState
// //     WidgetsBinding.instance.addPostFrameCallback((_) => _checkLogin());
// //   }

// //   @override
// //   void dispose() {
// //     _idCtrl.dispose();
// //     _passCtrl.dispose();
// //     super.dispose();
// //   }

// //   // ── Auto-login if session exists ─────────────────────────────────────────
// //   Future<void> _checkLogin() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final loggedIn = prefs.getBool('is_logged_in') ?? false;
// //     final role = prefs.getString('role') ?? '';

// //     if (!mounted) return;
// //     if (!loggedIn) return;

// //     _navigateByRole(role);
// //   }

// //   // ── Login ────────────────────────────────────────────────────────────────
// //   Future<void> _login() async {
// //     final id = _idCtrl.text.trim();
// //     final pass = _passCtrl.text.trim();

// //     if (id.isEmpty || pass.isEmpty) {
// //       setState(() => _error = 'Please enter Login ID and Password');
// //       return;
// //     }

// //     String? role;

// //     if (id == 'admin' && pass == '123') {
// //       role = 'admin';
// //     } else if (id == 'emp' && pass == '123') {
// //       role = 'emp';
// //     }

// //     if (role != null) {
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.setBool('is_logged_in', true);
// //       await prefs.setString('role', role);

// //       if (!mounted) return; // guard after every await ✅
// //       _navigateByRole(role);
// //     } else {
// //       setState(() => _error = 'Invalid Login ID or Password');
// //     }
// //   }

// //   // ── Central navigation helper ────────────────────────────────────────────
// //   void _navigateByRole(String role) {
// //     final Widget destination;

// //     if (role == 'admin') {
// //       destination = const AdminHome();
// //     } else if (role == 'emp') {
// //       destination = const EmployeeHome(employeeId: 2);
// //     } else {
// //       return; // unknown role — stay on login
// //     }

// //     Navigator.pushReplacement(
// //       context,
// //       MaterialPageRoute(builder: (_) => destination),
// //     );
// //   }

// //   // ── Build ────────────────────────────────────────────────────────────────
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Login')),
// //       body: Center(
// //         child: SingleChildScrollView(
// //           padding: const EdgeInsets.all(20),
// //           child: Card(
// //             elevation: 6,
// //             child: Padding(
// //               padding: const EdgeInsets.all(24),
// //               child: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   const Text(
// //                     'Attendance System Login',
// //                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// //                   ),
// //                   const SizedBox(height: 24),

// //                   TextField(
// //                     controller: _idCtrl,
// //                     textInputAction: TextInputAction.next,
// //                     decoration: const InputDecoration(
// //                       labelText: 'Login ID',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                   ),
// //                   const SizedBox(height: 16),

// //                   TextField(
// //                     controller: _passCtrl,
// //                     obscureText: true,
// //                     textInputAction: TextInputAction.done,
// //                     onSubmitted: (_) => _login(),
// //                     decoration: const InputDecoration(
// //                       labelText: 'Password',
// //                       border: OutlineInputBorder(),
// //                     ),
// //                   ),

// //                   if (_error.isNotEmpty) ...[
// //                     const SizedBox(height: 14),
// //                     Text(
// //                       _error,
// //                       style: const TextStyle(color: Colors.red, fontSize: 13),
// //                       textAlign: TextAlign.center,
// //                     ),
// //                   ],

// //                   const SizedBox(height: 24),

// //                   ElevatedButton(
// //                     style: ElevatedButton.styleFrom(
// //                       // style before child ✅
// //                       minimumSize: const Size(double.infinity, 48),
// //                     ),
// //                     onPressed: _login,
// //                     child: const Text('LOGIN'), // child is last ✅
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_home.dart';
import 'employee_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Check if already logged in — skip login screen
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Auto-login if session exists ─────────────────────────────────────────
  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? '';
    final empId = prefs.getInt('employee_id');
    final name = prefs.getString('emp_name') ?? '';

    if (role.isEmpty) return; // not logged in

    // Stale session guard: employee role but no empId saved (old login format)
    // Clear it so user is forced to log in fresh via the new API login
    if (role == 'employee' && empId == null) {
      await prefs.clear();
      return;
    }

    if (!mounted) return;
    _navigate(role, empId, name);
  }

  // ── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final loginId = _idCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (loginId.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter Login ID and Password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // POST /auth/login → { id, name, role }
      final Map<String, dynamic> user = await ApiService.login(
        loginId,
        password,
      );

      // Persist session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', user['role'] as String);
      await prefs.setString('emp_name', user['name'] as String);
      await prefs.setInt('employee_id', user['id'] as int);

      if (!mounted) return;
      _navigate(
        user['role'] as String,
        user['id'] as int,
        user['name'] as String,
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Navigate by role ──────────────────────────────────────────────────────
  void _navigate(String role, int? empId, String name) {
    Widget destination;

    if (role == 'admin') {
      destination = const AdminHome();
    } else if (role == 'employee' && empId != null) {
      destination = EmployeeHome(
        employeeId: empId,
        employeeName: name.isNotEmpty ? name : 'Employee',
      );
    } else {
      setState(() {
        _error = 'Unknown role. Contact admin.';
        _isLoading = false;
      });
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Attendance System',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 28),

                  // Login ID
                  TextField(
                    controller: _idCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Login ID',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  // Error message
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
