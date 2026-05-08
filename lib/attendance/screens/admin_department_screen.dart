// import 'package:flutter/material.dart';
// import '../services/department_service.dart';
// import '../models/departmentmodel.dart';

// class AdminDepartmentsScreen extends StatefulWidget {
//   const AdminDepartmentsScreen({super.key});

//   @override
//   State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
// }

// class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
//   final DepartmentService service = DepartmentService();

//   late Future<List<DepartmentModel>> futureDepts;

//   @override
//   void initState() {
//     super.initState();
//     futureDepts = service.fetchDepartments();
//   }

//   void refresh() {
//     setState(() {
//       futureDepts = service.fetchDepartments();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Department Management")),
//       floatingActionButton: FloatingActionButton(
//         onPressed: addDeptDialog,
//         child: const Icon(Icons.add),
//       ),
//       body: FutureBuilder<List<DepartmentModel>>(
//         future: futureDepts,
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           final depts = snapshot.data!;

//           return ListView.builder(
//             itemCount: depts.length,
//             itemBuilder: (context, i) {
//               final d = depts[i];
//               return Card(
//                 child: ListTile(
//                   title: Text(d.name),
//                   subtitle: Text("Status: ${d.status}"),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.people),
//                         onPressed: () => openEmployees(d),
//                       ),
//                       IconButton(
//                         icon: Icon(
//                           d.status == "Active"
//                               ? Icons.block
//                               : Icons.check_circle,
//                         ),
//                         onPressed: () async {
//                           final newStatus = d.status == "Active"
//                               ? "Inactive"
//                               : "Active";
//                           await service.updateDepartmentStatus(d.id, newStatus);
//                           refresh();
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//   /// ADD DEPARTMENT
//   void addDeptDialog() {
//     final ctrl = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: const Text("Add Department"),
//         content: TextField(controller: ctrl),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancel"),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               await service.addDepartment(ctrl.text);
//               Navigator.pop(context);
//               refresh();
//             },
//             child: const Text("Add"),
//           ),
//         ],
//       ),
//     );
//   }

//   /// OPEN EMPLOYEES
//   void openEmployees(DepartmentModel dept) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => DepartmentEmployeesScreen(department: dept),
//       ),
//     );
//   }
// }

// /// ================= EMPLOYEES PAGE =================
// class DepartmentEmployeesScreen extends StatefulWidget {
//   final DepartmentModel department;
//   const DepartmentEmployeesScreen({super.key, required this.department});

//   @override
//   State<DepartmentEmployeesScreen> createState() =>
//       _DepartmentEmployeesScreenState();
// }

// class _DepartmentEmployeesScreenState extends State<DepartmentEmployeesScreen> {
//   final DepartmentService service = DepartmentService();
//   late Future<List<Map<String, dynamic>>> futureEmployees;

//   @override
//   void initState() {
//     super.initState();
//     futureEmployees = service.fetchDeptEmployees(widget.department.id);
//   }

//   void refresh() {
//     setState(() {
//       futureEmployees = service.fetchDeptEmployees(widget.department.id);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Employees - ${widget.department.name}")),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: futureEmployees,
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           final emps = snapshot.data!;

//           return ListView.builder(
//             itemCount: emps.length,
//             itemBuilder: (c, i) {
//               final e = emps[i];
//               return ListTile(
//                 title: Text(e['first_name']),
//                 subtitle: Text(e['email_id']),
//                 trailing: IconButton(
//                   icon: const Icon(Icons.swap_horiz),
//                   onPressed: () => transferDialog(e['emp_id']),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }

//  /// TRANSFER EMPLOYEE
// void transferDialog(int empId) async {
//   final reasonCtrl = TextEditingController();
//   int? selectedDeptId;

//   // fetch all departments
//   final allDepts = await service.fetchDepartments();

//   // remove current department
//   final targetDepts =
//       allDepts.where((d) => d.id != widget.department.id).toList();

//   showDialog(
//     context: context,
//     builder: (context) {
//       return StatefulBuilder(
//         builder: (context, setState) {
//           final isValid =
//               selectedDeptId != null && reasonCtrl.text.trim().isNotEmpty;

//           return AlertDialog(
//             title: const Text("Transfer Employee"),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 /// DEPARTMENT DROPDOWN
//                 DropdownButtonFormField<int>(
//                   decoration: const InputDecoration(
//                     labelText: "Select New Department",
//                   ),
//                   initialValue: selectedDeptId,
//                   items: targetDepts.map((d) {
//                     return DropdownMenuItem<int>(
//                       value: d.id,
//                       child: Text(d.name),
//                     );
//                   }).toList(),
//                   onChanged: (val) {
//                     setState(() {
//                       selectedDeptId = val;
//                     });
//                   },
//                 ),

//                 const SizedBox(height: 12),

//                 /// REASON
//                 TextField(
//                   controller: reasonCtrl,
//                   decoration: const InputDecoration(labelText: "Reason"),
//                   onChanged: (_) => setState(() {}),
//                 ),
//               ],
//             ),

//             /// BUTTONS IN ONE ROW
//             actions: [
//               Row(
//                 children: [
//                   Expanded(
//                     child: TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: const Text("Cancel"),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: ElevatedButton(
//                       onPressed: isValid
//                           ? () async {
//                               await service.transferEmployee(
//                                 empId: empId,
//                                 toDept: selectedDeptId!,
//                                 reason: reasonCtrl.text.trim(),
//                               );

//                               if (!mounted) return;

//                               Navigator.pop(context);
//                               refresh(); // reload employees
//                             }
//                           : null,
//                       child: const Text("Transfer"),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           );
//         },
//       );
//     },
//   );
// }

// }
import 'package:flutter/material.dart';
import '../services/department_service.dart';
import '../models/departmentmodel.dart';

/// =================== ADMIN DEPARTMENTS SCREEN ===================
class AdminDepartmentsScreen extends StatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
  final DepartmentService service = DepartmentService();
  late Future<List<DepartmentModel>> futureDepts;

  @override
  void initState() {
    super.initState();
    futureDepts = service.fetchDepartments();
  }

  void refresh() {
    setState(() {
      futureDepts = service.fetchDepartments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(" "),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addDeptDialog,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<DepartmentModel>>(
        future: futureDepts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final depts = snapshot.data!;
          if (depts.isEmpty) {
            return const Center(child: Text("No departments found"));
          }

          return ListView.builder(
            itemCount: depts.length,
            itemBuilder: (context, i) {
              final d = depts[i];
              return Card(
                child: ListTile(
                  title: Text(d.name),
                  subtitle: Text("Status: ${d.status}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.people),
                        tooltip: "View Employees",
                        onPressed: () => openEmployees(d),
                      ),
                      IconButton(
                        icon: Icon(
                          d.status == "Active"
                              ? Icons.block
                              : Icons.check_circle,
                        ),
                        tooltip: d.status == "Active"
                            ? "Deactivate"
                            : "Activate",
                        onPressed: () async {
                          final newStatus = d.status == "Active"
                              ? "Inactive"
                              : "Active";
                          await service.updateDepartmentStatus(d.id, newStatus);
                          refresh();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ---------------- ADD DEPARTMENT ----------------
  void addDeptDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Department"),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await service.addDepartment(ctrl.text.trim());
              Navigator.pop(context);
              refresh();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  /// ---------------- OPEN EMPLOYEES ----------------
  void openEmployees(DepartmentModel dept) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepartmentEmployeesScreen(department: dept),
      ),
    );
  }
}

/// =================== DEPARTMENT EMPLOYEES SCREEN ===================
class DepartmentEmployeesScreen extends StatefulWidget {
  final DepartmentModel department;
  const DepartmentEmployeesScreen({super.key, required this.department});

  @override
  State<DepartmentEmployeesScreen> createState() =>
      _DepartmentEmployeesScreenState();
}

class _DepartmentEmployeesScreenState extends State<DepartmentEmployeesScreen> {
  final DepartmentService service = DepartmentService();
  late Future<List<Map<String, dynamic>>> futureEmployees;

  // Cache all departments to avoid repeated fetch
  List<DepartmentModel>? allDepts;

  @override
  void initState() {
    super.initState();
    futureEmployees = service.fetchDeptEmployees(widget.department.id);

    // Cache all departments once
    service.fetchDepartments().then((value) => allDepts = value);
  }

  void refreshEmployees() {
    setState(() {
      futureEmployees = service.fetchDeptEmployees(widget.department.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Employees - ${widget.department.name}"),
        backgroundColor: Colors.teal,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureEmployees,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final emps = snapshot.data!;
          if (emps.isEmpty) {
            return const Center(child: Text("No employees in this department"));
          }

          return ListView.builder(
            itemCount: emps.length,
            itemBuilder: (context, i) {
              final e = emps[i];
              return Card(
                child: ListTile(
                  title: Text(e['first_name']),
                  subtitle: Text(e['email_id']),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: "Transfer Employee",
                    onPressed: () => transferDialog(e['emp_id']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ---------------- TRANSFER EMPLOYEE ----------------
  void transferDialog(int empId) {
    final reasonCtrl = TextEditingController();
    int? selectedDeptId;

    final targetDepts = (allDepts ?? [])
        .where((d) => d.id != widget.department.id)
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isValid =
                selectedDeptId != null && reasonCtrl.text.trim().isNotEmpty;

            return AlertDialog(
              title: const Text("Transfer Employee"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: "Select New Department",
                    ),
                    items: targetDepts
                        .map(
                          (d) => DropdownMenuItem<int>(
                            value: d.id,
                            child: Text(d.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => selectedDeptId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: "Reason"),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isValid
                            ? () async {
                                await service.transferEmployee(
                                  empId: empId,
                                  toDept: selectedDeptId!,
                                  reason: reasonCtrl.text.trim(),
                                );
                                if (!mounted) return;
                                Navigator.pop(context);
                                refreshEmployees();
                              }
                            : null,
                        child: const Text("Transfer"),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
