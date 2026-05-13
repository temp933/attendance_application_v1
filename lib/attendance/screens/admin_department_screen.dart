// // import 'package:flutter/material.dart';
// // import '../services/department_service.dart';
// // import '../models/departmentmodel.dart';

// // /// =================== ADMIN DEPARTMENTS SCREEN ===================
// // class AdminDepartmentsScreen extends StatefulWidget {
// //   final String tenantId;
// //   const AdminDepartmentsScreen({super.key, required this.tenantId});

// //   @override
// //   State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
// // }

// // class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
// //   late final DepartmentService service;
// //   late Future<List<DepartmentModel>> futureDepts;

// //   @override
// //   void initState() {
// //     super.initState();
// //     print(
// //       'DEBUG AdminDepartmentsScreen tenantId: "${widget.tenantId}"',
// //     ); // ← ADD
// //     service = DepartmentService(tenantId: widget.tenantId);
// //     futureDepts = service.fetchDepartments();
// //   }

// //   void refresh() {
// //     setState(() {
// //       futureDepts = service.fetchDepartments();
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text(" "),
// //         backgroundColor: const Color.fromARGB(255, 255, 255, 255),
// //       ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: addDeptDialog,
// //         child: const Icon(Icons.add),
// //       ),
// //       body: FutureBuilder<List<DepartmentModel>>(
// //         future: futureDepts,
// //         builder: (context, snapshot) {
// //           // ── ADD THESE TWO ──
// //           if (snapshot.hasError) {
// //             return Center(child: Text('Error: ${snapshot.error}'));
// //           }
// //           if (snapshot.connectionState == ConnectionState.waiting) {
// //             return const Center(child: CircularProgressIndicator());
// //           }
// //           // ── REPLACE the old !snapshot.hasData check ──
// //           if (!snapshot.hasData || snapshot.data!.isEmpty) {
// //             return const Center(child: Text("No departments found"));
// //           }

// //           final depts = snapshot.data!;
// //           return ListView.builder(
// //             itemCount: depts.length,
// //             itemBuilder: (context, i) {
// //               final d = depts[i];
// //               return Card(
// //                 child: ListTile(
// //                   title: Text(d.name),
// //                   subtitle: Text("Status: ${d.status}"),
// //                   trailing: Row(
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       IconButton(
// //                         icon: const Icon(Icons.people),
// //                         tooltip: "View Employees",
// //                         onPressed: () => openEmployees(d),
// //                       ),
// //                       IconButton(
// //                         icon: Icon(
// //                           d.status == "Active"
// //                               ? Icons.block
// //                               : Icons.check_circle,
// //                         ),
// //                         tooltip: d.status == "Active"
// //                             ? "Deactivate"
// //                             : "Activate",
// //                         onPressed: () async {
// //                           final newStatus = d.status == "Active"
// //                               ? "Inactive"
// //                               : "Active";
// //                           await service.updateDepartmentStatus(d.id, newStatus);
// //                           refresh();
// //                         },
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               );
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }

// //   /// ---------------- ADD DEPARTMENT ----------------
// //   void addDeptDialog() {
// //     final ctrl = TextEditingController();
// //     showDialog(
// //       context: context,
// //       builder: (_) => AlertDialog(
// //         title: const Text("Add Department"),
// //         content: TextField(controller: ctrl),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(context),
// //             child: const Text("Cancel"),
// //           ),
// //           ElevatedButton(
// //             onPressed: () async {
// //               if (ctrl.text.trim().isEmpty) return;
// //               await service.addDepartment(ctrl.text.trim());
// //               Navigator.pop(context);
// //               refresh();
// //             },
// //             child: const Text("Add"),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   /// ---------------- OPEN EMPLOYEES ----------------
// //   void openEmployees(DepartmentModel dept) {
// //     Navigator.push(
// //       context,
// //       MaterialPageRoute(
// //         builder: (_) => DepartmentEmployeesScreen(
// //           department: dept,
// //           tenantId: widget.tenantId,
// //         ),
// //       ),
// //     );
// //   }
// // }

// // /// =================== DEPARTMENT EMPLOYEES SCREEN ===================
// // class DepartmentEmployeesScreen extends StatefulWidget {
// //   final DepartmentModel department;

// //   final String tenantId;
// //   const DepartmentEmployeesScreen({
// //     super.key,
// //     required this.department,
// //     required this.tenantId,
// //   });

// //   @override
// //   State<DepartmentEmployeesScreen> createState() =>
// //       _DepartmentEmployeesScreenState();
// // }

// // class _DepartmentEmployeesScreenState extends State<DepartmentEmployeesScreen> {
// //   late final DepartmentService service;
// //   late Future<List<Map<String, dynamic>>> futureEmployees;

// //   // Cache all departments to avoid repeated fetch
// //   List<DepartmentModel>? allDepts;

// //   @override
// //   void initState() {
// //     super.initState();
// //     service = DepartmentService(tenantId: widget.tenantId); // ← ADD THIS
// //     futureEmployees = service.fetchDeptEmployees(widget.department.id);
// //     service.fetchDepartments().then((value) => allDepts = value);
// //   }

// //   void refreshEmployees() {
// //     setState(() {
// //       futureEmployees = service.fetchDeptEmployees(widget.department.id);
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: Text("Employees - ${widget.department.name}"),
// //         backgroundColor: Colors.teal,
// //       ),
// //       body: FutureBuilder<List<Map<String, dynamic>>>(
// //         future: futureEmployees,
// //         builder: (context, snapshot) {
// //           if (!snapshot.hasData) {
// //             return const Center(child: CircularProgressIndicator());
// //           }

// //           final emps = snapshot.data!;
// //           if (emps.isEmpty) {
// //             return const Center(child: Text("No employees in this department"));
// //           }

// //           return ListView.builder(
// //             itemCount: emps.length,
// //             itemBuilder: (context, i) {
// //               final e = emps[i];
// //               return Card(
// //                 child: ListTile(
// //                   title: Text(e['first_name']),
// //                   subtitle: Text(e['email_id']),
// //                   trailing: IconButton(
// //                     icon: const Icon(Icons.swap_horiz),
// //                     tooltip: "Transfer Employee",
// //                     onPressed: () => transferDialog(e['emp_id']),
// //                   ),
// //                 ),
// //               );
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }

// //   /// ---------------- TRANSFER EMPLOYEE ----------------
// //   void transferDialog(int empId) {
// //     final reasonCtrl = TextEditingController();
// //     int? selectedDeptId;

// //     final targetDepts = (allDepts ?? [])
// //         .where((d) => d.id != widget.department.id)
// //         .toList();

// //     showDialog(
// //       context: context,
// //       builder: (context) {
// //         return StatefulBuilder(
// //           builder: (context, setState) {
// //             final isValid =
// //                 selectedDeptId != null && reasonCtrl.text.trim().isNotEmpty;

// //             return AlertDialog(
// //               title: const Text("Transfer Employee"),
// //               content: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   DropdownButtonFormField<int>(
// //                     decoration: const InputDecoration(
// //                       labelText: "Select New Department",
// //                     ),
// //                     items: targetDepts
// //                         .map(
// //                           (d) => DropdownMenuItem<int>(
// //                             value: d.id,
// //                             child: Text(d.name),
// //                           ),
// //                         )
// //                         .toList(),
// //                     onChanged: (val) => setState(() => selectedDeptId = val),
// //                   ),
// //                   const SizedBox(height: 12),
// //                   TextField(
// //                     controller: reasonCtrl,
// //                     decoration: const InputDecoration(labelText: "Reason"),
// //                     onChanged: (_) => setState(() {}),
// //                   ),
// //                 ],
// //               ),
// //               actions: [
// //                 Row(
// //                   children: [
// //                     Expanded(
// //                       child: TextButton(
// //                         onPressed: () => Navigator.pop(context),
// //                         child: const Text("Cancel"),
// //                       ),
// //                     ),
// //                     const SizedBox(width: 8),
// //                     Expanded(
// //                       child: ElevatedButton(
// //                         onPressed: isValid
// //                             ? () async {
// //                                 await service.transferEmployee(
// //                                   empId: empId,
// //                                   toDept: selectedDeptId!,
// //                                   reason: reasonCtrl.text.trim(),
// //                                 );
// //                                 if (!mounted) return;
// //                                 Navigator.pop(context);
// //                                 refreshEmployees();
// //                               }
// //                             : null,
// //                         child: const Text("Transfer"),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ],
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';
// import '../services/department_service.dart';
// import '../models/departmentmodel.dart';

// // ─── Design Tokens ────────────────────────────────────────────────────────────
// const _primary = Color(0xFF1A56DB);
// const _primaryLight = Color(0xFFEEF2FF);
// const _surface = Color(0xFFF8FAFF);
// const _card = Colors.white;
// const _textDark = Color(0xFF0F172A);
// const _textMid = Color(0xFF64748B);
// const _textLight = Color(0xFF94A3B8);
// const _success = Color(0xFF10B981);
// const _warning = Color(0xFFF59E0B);
// const _danger = Color(0xFFEF4444);
// const _border = Color(0xFFE2E8F0);

// // ─── Models ───────────────────────────────────────────────────────────────────
// class RoleModel {
//   final int id;
//   final String name;
//   RoleModel({required this.id, required this.name});
//   factory RoleModel.fromJson(Map<String, dynamic> j) =>
//       RoleModel(id: j['role_id'], name: j['role_name']);
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // ADMIN DEPARTMENTS SCREEN
// // ═══════════════════════════════════════════════════════════════════════════════
// class AdminDepartmentsScreen extends StatefulWidget {
//   final String tenantId;
//   const AdminDepartmentsScreen({super.key, required this.tenantId});
//   @override
//   State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
// }

// class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen>
//     with SingleTickerProviderStateMixin {
//   late final DepartmentService _svc;
//   late Future<List<DepartmentModel>> _futureDepts;
//   List<RoleModel> _allRoles = [];
//   String _deptFilter = '';
//   int? _roleFilter;
//   late TabController _tabCtrl;

//   @override
//   void initState() {
//     super.initState();
//     _svc = DepartmentService(tenantId: widget.tenantId);
//     _tabCtrl = TabController(length: 2, vsync: this);
//     _futureDepts = _svc.fetchDepartments();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadRoles(); // ← calls setState after frame, but...
//     });
//   }

//   @override
//   void dispose() {
//     _tabCtrl.dispose();
//     super.dispose();
//   }

//   void _reload() {
//     setState(() {
//       _futureDepts = _svc
//           .fetchDepartments(); // assignment happens, void returned
//     });
//   }

//   Future<void> _loadRoles() async {
//     try {
//       final roles = await _svc.fetchAllRoles();
//       if (mounted) {
//         setState(
//           // ← this setState's CALLBACK
//           () => _allRoles = roles.map((r) => RoleModel.fromJson(r)).toList(),
//         ); // ← arrow returns a List, which is fine... BUT
//       }
//     } catch (_) {}
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _surface,
//       body: Column(
//         children: [
//           _buildHeader(),
//           _buildTabs(),
//           Expanded(
//             child: TabBarView(
//               controller: _tabCtrl,
//               children: [
//                 _DepartmentsTab(
//                   futureDepts: _futureDepts,
//                   svc: _svc,
//                   allRoles: _allRoles,
//                   tenantId: widget.tenantId,
//                   onReload: _reload,
//                   onRolesChanged: _loadRoles,
//                 ),
//                 _RolesTab(
//                   allRoles: _allRoles,
//                   svc: _svc,
//                   onRolesChanged: _loadRoles,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
//       color: _card,
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: _primaryLight,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: const Icon(
//               Icons.apartment_rounded,
//               color: _primary,
//               size: 20,
//             ),
//           ),
//           const SizedBox(width: 12),
//           const Expanded(
//             child: Text(
//               'Departments & Roles',
//               style: TextStyle(
//                 fontSize: 17,
//                 fontWeight: FontWeight.w700,
//                 color: _textDark,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTabs() {
//     return Container(
//       color: _card,
//       child: TabBar(
//         controller: _tabCtrl,
//         labelColor: _primary,
//         unselectedLabelColor: _textMid,
//         labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
//         indicatorColor: _primary,
//         indicatorWeight: 2,
//         tabs: const [
//           Tab(text: 'Departments'),
//           Tab(text: 'Roles'),
//         ],
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // DEPARTMENTS TAB
// // ═══════════════════════════════════════════════════════════════════════════════
// class _DepartmentsTab extends StatefulWidget {
//   final Future<List<DepartmentModel>> futureDepts;
//   final DepartmentService svc;
//   final List<RoleModel> allRoles;
//   final String tenantId;
//   final VoidCallback onReload;
//   final VoidCallback onRolesChanged;

//   const _DepartmentsTab({
//     required this.futureDepts,
//     required this.svc,
//     required this.allRoles,
//     required this.tenantId,
//     required this.onReload,
//     required this.onRolesChanged,
//   });

//   @override
//   State<_DepartmentsTab> createState() => _DepartmentsTabState();
// }

// class _DepartmentsTabState extends State<_DepartmentsTab> {
//   String _search = '';

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         _buildSearchBar(),
//         Expanded(
//           child: FutureBuilder<List<DepartmentModel>>(
//             future: widget.futureDepts,
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return _ErrorView(
//                   message: snapshot.error.toString(),
//                   onRetry: widget.onReload,
//                 );
//               }
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator());
//               }
//               final depts = (snapshot.data ?? [])
//                   .where(
//                     (d) => d.name.toLowerCase().contains(_search.toLowerCase()),
//                   )
//                   .toList();

//               if (depts.isEmpty) {
//                 return _EmptyView(
//                   message: _search.isEmpty
//                       ? 'No departments yet'
//                       : 'No results for "$_search"',
//                   icon: Icons.apartment_outlined,
//                 );
//               }

//               return ListView.builder(
//                 padding: const EdgeInsets.all(16),
//                 itemCount: depts.length,
//                 itemBuilder: (_, i) => _DeptCard(
//                   dept: depts[i],
//                   svc: widget.svc,
//                   allRoles: widget.allRoles,
//                   tenantId: widget.tenantId,
//                   onChanged: widget.onReload,
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSearchBar() {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//       color: _card,
//       child: Row(
//         children: [
//           Expanded(
//             child: Container(
//               height: 40,
//               decoration: BoxDecoration(
//                 color: _surface,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: _border),
//               ),
//               child: TextField(
//                 onChanged: (v) => setState(() => _search = v),
//                 style: const TextStyle(fontSize: 13),
//                 decoration: const InputDecoration(
//                   hintText: 'Search departments...',
//                   hintStyle: TextStyle(color: _textLight, fontSize: 13),
//                   prefixIcon: Icon(Icons.search, size: 18, color: _textLight),
//                   border: InputBorder.none,
//                   contentPadding: EdgeInsets.symmetric(vertical: 10),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           _AddButton(
//             label: 'Add Dept',
//             onTap: () => _showAddDeptDialog(context),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showAddDeptDialog(BuildContext context) {
//     final ctrl = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (_) => _AppDialog(
//         title: 'Add Department',
//         icon: Icons.apartment_rounded,
//         content: _AppTextField(ctrl: ctrl, label: 'Department Name'),
//         onConfirm: () async {
//           if (ctrl.text.trim().isEmpty) return;
//           await widget.svc.addDepartment(ctrl.text.trim());
//           widget.onReload();
//         },
//         confirmLabel: 'Add',
//       ),
//     );
//   }
// }

// // ─── Department Card ──────────────────────────────────────────────────────────
// class _DeptCard extends StatefulWidget {
//   final DepartmentModel dept;
//   final DepartmentService svc;
//   final List<RoleModel> allRoles;
//   final String tenantId;
//   final VoidCallback onChanged;

//   const _DeptCard({
//     required this.dept,
//     required this.svc,
//     required this.allRoles,
//     required this.tenantId,
//     required this.onChanged,
//   });

//   @override
//   State<_DeptCard> createState() => _DeptCardState();
// }

// class _DeptCardState extends State<_DeptCard> {
//   bool _expanded = false;
//   List<Map<String, dynamic>>? _roles;
//   bool _loadingRoles = false;

//   Future<void> _loadRoles() async {
//     if (_roles != null) return;
//     setState(() => _loadingRoles = true);
//     try {
//       final roles = await widget.svc.fetchDeptRoles(widget.dept.id);
//       if (mounted) setState(() => _roles = roles);
//     } catch (_) {
//       if (mounted) setState(() => _roles = []);
//     } finally {
//       if (mounted) setState(() => _loadingRoles = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isActive = widget.dept.status == 'Active';
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: _card,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _border),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // ── Header row ──
//           InkWell(
//             onTap: () {
//               setState(() => _expanded = !_expanded);
//               if (!_expanded) _loadRoles();
//             },
//             borderRadius: BorderRadius.circular(14),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 40,
//                     height: 40,
//                     decoration: BoxDecoration(
//                       color: isActive
//                           ? _primary.withOpacity(0.1)
//                           : _textLight.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: Icon(
//                       Icons.apartment_rounded,
//                       color: isActive ? _primary : _textLight,
//                       size: 20,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           widget.dept.name,
//                           style: const TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                             color: _textDark,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 2,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: isActive
//                                     ? _success.withOpacity(0.1)
//                                     : _textLight.withOpacity(0.1),
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               child: Text(
//                                 widget.dept.status,
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   fontWeight: FontWeight.w600,
//                                   color: isActive ? _success : _textLight,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   // Toggle status
//                   IconButton(
//                     icon: Icon(
//                       isActive ? Icons.toggle_on : Icons.toggle_off,
//                       color: isActive ? _success : _textLight,
//                       size: 28,
//                     ),
//                     tooltip: isActive ? 'Deactivate' : 'Activate',
//                     onPressed: () {
//                       final newStatus = isActive ? 'Inactive' : 'Active';
//                       widget.svc
//                           .updateDepartmentStatus(widget.dept.id, newStatus)
//                           .then((_) => widget.onChanged())
//                           .catchError((_) {});
//                     },
//                   ),
//                   // Expand arrow
//                   Icon(
//                     _expanded
//                         ? Icons.keyboard_arrow_up
//                         : Icons.keyboard_arrow_down,
//                     color: _textMid,
//                     size: 20,
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // ── Expanded section ──
//           if (_expanded) ...[
//             Divider(height: 1, color: _border),
//             _buildExpandedContent(),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildExpandedContent() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Roles section
//           Row(
//             children: [
//               const Icon(Icons.badge_outlined, size: 14, color: _textMid),
//               const SizedBox(width: 6),
//               const Text(
//                 'Roles in this department',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: _textMid,
//                 ),
//               ),
//               const Spacer(),
//               // View employees placeholder button
//               TextButton.icon(
//                 onPressed: () => _showEmployeesPlaceholder(),
//                 icon: const Icon(Icons.people_outline, size: 14),
//                 label: const Text('Employees', style: TextStyle(fontSize: 11)),
//                 style: TextButton.styleFrom(
//                   foregroundColor: _primary,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   minimumSize: Size.zero,
//                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),

//           if (_loadingRoles)
//             const Center(
//               child: SizedBox(
//                 width: 20,
//                 height: 20,
//                 child: CircularProgressIndicator(strokeWidth: 2),
//               ),
//             )
//           else if (_roles == null || _roles!.isEmpty)
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _surface,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: _border),
//               ),
//               child: const Row(
//                 children: [
//                   Icon(Icons.info_outline, size: 14, color: _textLight),
//                   SizedBox(width: 8),
//                   Text(
//                     'No roles assigned yet',
//                     style: TextStyle(fontSize: 12, color: _textLight),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Wrap(
//               spacing: 8,
//               runSpacing: 6,
//               children: _roles!
//                   .map((r) => _RoleChip(name: r['role_name']))
//                   .toList(),
//             ),

//           const SizedBox(height: 12),

//           // Action buttons row
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () => _showEmployeesPlaceholder(),
//                   icon: const Icon(Icons.people_outline, size: 16),
//                   label: const Text(
//                     'View Employees',
//                     style: TextStyle(fontSize: 12),
//                   ),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: _primary,
//                     side: BorderSide(color: _primary.withOpacity(0.4)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () => _showDeleteDialog(),
//                   icon: const Icon(Icons.delete_outline, size: 16),
//                   label: const Text('Delete', style: TextStyle(fontSize: 12)),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: _danger,
//                     side: BorderSide(color: _danger.withOpacity(0.4)),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   void _showEmployeesPlaceholder() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Row(
//           children: [
//             const Icon(Icons.people_outline, color: _primary),
//             const SizedBox(width: 10),
//             Text(widget.dept.name),
//           ],
//         ),
//         content: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             color: _primaryLight,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: const [
//               Icon(Icons.construction_rounded, size: 40, color: _primary),
//               SizedBox(height: 12),
//               Text(
//                 'Employee filter view\ncoming soon',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: _primary,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 14,
//                 ),
//               ),
//               SizedBox(height: 6),
//               Text(
//                 'Department & role wise employee\nfiltering will be available here',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(color: _textMid, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showDeleteDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Text('Delete Department'),
//         content: Text(
//           'Delete "${widget.dept.name}"? This cannot be undone if no employees are assigned.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               widget.svc
//                   .deleteDepartment(widget.dept.id)
//                   .then((_) {
//                     widget.onChanged();
//                   })
//                   .catchError((e) {
//                     if (mounted) {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(
//                           content: Text(
//                             e.toString().replaceAll('Exception: ', ''),
//                           ),
//                           backgroundColor: _danger,
//                         ),
//                       );
//                     }
//                   });
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _danger,
//               foregroundColor: Colors.white,
//             ),
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // ROLES TAB
// // ═══════════════════════════════════════════════════════════════════════════════
// class _RolesTab extends StatelessWidget {
//   final List<RoleModel> allRoles;
//   final DepartmentService svc;
//   final VoidCallback onRolesChanged;

//   const _RolesTab({
//     required this.allRoles,
//     required this.svc,
//     required this.onRolesChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Header bar
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
//           color: _card,
//           child: Row(
//             children: [
//               const Expanded(
//                 child: Text(
//                   'All Roles',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                     color: _textDark,
//                   ),
//                 ),
//               ),
//               _AddButton(
//                 label: 'Add Role',
//                 onTap: () => _showAddRoleDialog(context),
//               ),
//             ],
//           ),
//         ),
//         Divider(height: 1, color: _border),
//         Expanded(
//           child: allRoles.isEmpty
//               ? _EmptyView(
//                   message: 'No roles yet. Add your first role.',
//                   icon: Icons.badge_outlined,
//                 )
//               : ListView.builder(
//                   padding: const EdgeInsets.all(16),
//                   itemCount: allRoles.length,
//                   itemBuilder: (_, i) {
//                     final role = allRoles[i];
//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 8),
//                       decoration: BoxDecoration(
//                         color: _card,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: _border),
//                       ),
//                       child: ListTile(
//                         leading: Container(
//                           width: 36,
//                           height: 36,
//                           decoration: BoxDecoration(
//                             color: _primaryLight,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Icon(
//                             Icons.badge_outlined,
//                             color: _primary,
//                             size: 18,
//                           ),
//                         ),
//                         title: Text(
//                           role.name,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: _textDark,
//                           ),
//                         ),
//                         subtitle: Text(
//                           'Role ID: ${role.id}',
//                           style: const TextStyle(
//                             fontSize: 11,
//                             color: _textLight,
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//         ),
//       ],
//     );
//   }

//   void _showAddRoleDialog(BuildContext context) {
//     final ctrl = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (_) => _AppDialog(
//         title: 'Add Role',
//         icon: Icons.badge_outlined,
//         content: _AppTextField(ctrl: ctrl, label: 'Role Name'),
//         onConfirm: () async {
//           if (ctrl.text.trim().isEmpty) return;
//           await svc.addRole(ctrl.text.trim());
//           onRolesChanged();
//         },
//         confirmLabel: 'Add',
//       ),
//     );
//   }
// }

// // ═══════════════════════════════════════════════════════════════════════════════
// // SHARED WIDGETS
// // ═══════════════════════════════════════════════════════════════════════════════

// class _RoleChip extends StatelessWidget {
//   final String name;
//   const _RoleChip({required this.name});
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//     decoration: BoxDecoration(
//       color: _primaryLight,
//       borderRadius: BorderRadius.circular(20),
//       border: Border.all(color: _primary.withOpacity(0.2)),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.badge_outlined, size: 12, color: _primary),
//         const SizedBox(width: 4),
//         Text(
//           name,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//             color: _primary,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// class _AddButton extends StatelessWidget {
//   final String label;
//   final VoidCallback onTap;
//   const _AddButton({required this.label, required this.onTap});
//   @override
//   Widget build(BuildContext context) => ElevatedButton.icon(
//     onPressed: onTap,
//     icon: const Icon(Icons.add, size: 16),
//     label: Text(label, style: const TextStyle(fontSize: 12)),
//     style: ElevatedButton.styleFrom(
//       backgroundColor: _primary,
//       foregroundColor: Colors.white,
//       elevation: 0,
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//     ),
//   );
// }

// class _AppDialog extends StatelessWidget {
//   final String title;
//   final IconData icon;
//   final Widget content;
//   final Future<void> Function() onConfirm;
//   final String confirmLabel;

//   const _AppDialog({
//     required this.title,
//     required this.icon,
//     required this.content,
//     required this.onConfirm,
//     required this.confirmLabel,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       title: Row(
//         children: [
//           Icon(icon, color: _primary, size: 20),
//           const SizedBox(width: 10),
//           Text(
//             title,
//             style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
//           ),
//         ],
//       ),
//       content: content,
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel', style: TextStyle(color: _textMid)),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             onConfirm().then((_) {
//               if (context.mounted) Navigator.pop(context);
//             });
//           },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: _primary,
//             foregroundColor: Colors.white,
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//           child: Text(confirmLabel),
//         ),
//       ],
//     );
//   }
// }

// class _AppTextField extends StatelessWidget {
//   final TextEditingController ctrl;
//   final String label;
//   const _AppTextField({required this.ctrl, required this.label});
//   @override
//   Widget build(BuildContext context) => TextField(
//     controller: ctrl,
//     autofocus: true,
//     decoration: InputDecoration(
//       labelText: label,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(10),
//         borderSide: const BorderSide(color: _primary, width: 1.5),
//       ),
//     ),
//   );
// }

// class _EmptyView extends StatelessWidget {
//   final String message;
//   final IconData icon;
//   const _EmptyView({required this.message, required this.icon});
//   @override
//   Widget build(BuildContext context) => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 48, color: _textLight),
//         const SizedBox(height: 12),
//         Text(message, style: const TextStyle(color: _textMid, fontSize: 14)),
//       ],
//     ),
//   );
// }

// class _ErrorView extends StatelessWidget {
//   final String message;
//   final VoidCallback onRetry;
//   const _ErrorView({required this.message, required this.onRetry});
//   @override
//   Widget build(BuildContext context) => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.error_outline, size: 48, color: _danger),
//         const SizedBox(height: 12),
//         Text(
//           message,
//           textAlign: TextAlign.center,
//           style: const TextStyle(color: _textMid, fontSize: 13),
//         ),
//         const SizedBox(height: 16),
//         ElevatedButton.icon(
//           onPressed: onRetry,
//           icon: const Icon(Icons.refresh, size: 16),
//           label: const Text('Retry'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: _primary,
//             foregroundColor: Colors.white,
//           ),
//         ),
//       ],
//     ),
//   );
// }

import 'package:flutter/material.dart';
import '../services/department_service.dart';
import '../models/departmentmodel.dart';
import 'dept_roles_screen.dart';
import 'dept_shared_widgets.dart';

// ─── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF1A56DB);
const _primaryLight = Color(0xFFEEF2FF);
const _surface = Color(0xFFF8FAFF);
const _card = Colors.white;
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF64748B);
const _textLight = Color(0xFF94A3B8);
const _success = Color(0xFF10B981);
const _danger = Color(0xFFEF4444);
const _border = Color(0xFFE2E8F0);

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 1 — DEPARTMENT LIST
// ═══════════════════════════════════════════════════════════════════════════════
class AdminDepartmentsScreen extends StatefulWidget {
  final String tenantId;
  const AdminDepartmentsScreen({super.key, required this.tenantId});

  @override
  State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
  late final DepartmentService _svc;
  late Future<List<DepartmentModel>> _futureDepts;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _svc = DepartmentService(tenantId: widget.tenantId);
    _futureDepts = _svc.fetchDepartments();
  }

  // ✅ Fix 1: block body so setState returns void, not a Future
  void _reload() {
    setState(() {
      _futureDepts = _svc.fetchDepartments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      color: _card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Departments',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: _card,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search departments...',
                  hintStyle: TextStyle(color: _textLight, fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: _textLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          DeptPrimaryButton(
            label: 'Add Dept',
            icon: Icons.add,
            onTap: () => _showAddDeptDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<DepartmentModel>>(
      future: _futureDepts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return DeptErrorView(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final depts = (snapshot.data ?? [])
            .where((d) => d.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

        if (depts.isEmpty) {
          return DeptEmptyView(
            message: _search.isEmpty
                ? 'No departments yet'
                : 'No results for "$_search"',
            icon: Icons.apartment_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: depts.length,
          itemBuilder: (_, i) => _DeptCard(
            dept: depts[i],
            svc: _svc,
            tenantId: widget.tenantId,
            onChanged: _reload,
          ),
        );
      },
    );
  }

  void _showAddDeptDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => DeptAppDialog(
        title: 'Add Department',
        icon: Icons.apartment_rounded,
        content: DeptAppTextField(ctrl: ctrl, label: 'Department Name'),
        confirmLabel: 'Add',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          await _svc.addDepartment(ctrl.text.trim());
          _reload();
        },
      ),
    );
  }
}

// ─── Department Card ───────────────────────────────────────────────────────────
class _DeptCard extends StatelessWidget {
  final DepartmentModel dept;
  final DepartmentService svc;
  final String tenantId;
  final VoidCallback onChanged;

  const _DeptCard({
    required this.dept,
    required this.svc,
    required this.tenantId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = dept.status == 'Active';

    return GestureDetector(
      // ✅ Tap card → navigate to Page 2 (Roles)
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DeptRolesScreen(dept: dept, svc: svc, tenantId: tenantId),
          ),
        );
        // Refresh when returning from roles page
        onChanged();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive ? _primaryLight : _textLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.apartment_rounded,
                  color: isActive ? _primary : _textLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Name + status badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dept.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DeptStatusBadge(status: dept.status),
                  ],
                ),
              ),

              // Toggle active/inactive
              IconButton(
                icon: Icon(
                  isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: isActive ? _success : _textLight,
                  size: 30,
                ),
                tooltip: isActive ? 'Deactivate' : 'Activate',
                onPressed: () {
                  final newStatus = isActive ? 'Inactive' : 'Active';
                  svc
                      .updateDepartmentStatus(dept.id, newStatus)
                      .then((_) => onChanged())
                      .catchError((_) {});
                },
              ),

              // Edit
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _textMid,
                  size: 20,
                ),
                tooltip: 'Edit',
                onPressed: () => _showEditDialog(context),
              ),

              // Delete
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: _danger,
                  size: 20,
                ),
                tooltip: 'Delete',
                onPressed: () => _showDeleteDialog(context),
              ),

              // Chevron → go to roles
              const Icon(Icons.chevron_right, color: _textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: dept.name);
    showDialog(
      context: context,
      builder: (_) => DeptAppDialog(
        title: 'Edit Department',
        icon: Icons.edit_outlined,
        content: DeptAppTextField(ctrl: ctrl, label: 'Department Name'),
        confirmLabel: 'Save',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty || ctrl.text.trim() == dept.name) return;
          await svc.updateDepartmentName(dept.id, ctrl.text.trim());
          onChanged();
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Department'),
        content: Text('Delete "${dept.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc.deleteDepartment(dept.id).then((_) => onChanged()).catchError(
                (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: _danger,
                    ),
                  );
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
