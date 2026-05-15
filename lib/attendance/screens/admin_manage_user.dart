import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/employee_service.dart';
import 'shared_form_widgets.dart';

import 'package:http/http.dart' as http;
import '../providers/api_client.dart';
import '../providers/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

String? validateDob(String? val) {
  if (val == null || val.trim().isEmpty) {
    return 'Date of Birth is required';
  }
  final dt = DateTime.tryParse(val.trim());
  if (dt == null) {
    return 'Invalid date format';
  }
  final today = DateTime.now();
  final age =
      today.year -
      dt.year -
      ((today.month < dt.month ||
              (today.month == dt.month && today.day < dt.day))
          ? 1
          : 0);
  if (age < 18) {
    return 'Employee must be at least 18 years old';
  }
  if (age > 80) {
    return 'Please enter a valid date of birth';
  }
  return null;
}

/// Date of joining must be provided and must not be in the future.
String? validateDoj(String? val) {
  if (val == null || val.trim().isEmpty) {
    return 'Date of Joining is required';
  }
  final dt = DateTime.tryParse(val.trim());
  if (dt == null) {
    return 'Invalid date format';
  }
  if (dt.isAfter(DateTime.now())) {
    return 'Joining date cannot be in the future';
  }
  return null;
}

/// Optional DOJ — only validates format / future if provided.
String? validateDojOptional(String? val) {
  if (val == null || val.trim().isEmpty) {
    return null;
  }
  final dt = DateTime.tryParse(val.trim());
  if (dt == null) {
    return 'Invalid date format';
  }
  if (dt.isAfter(DateTime.now())) {
    return 'Joining date cannot be in the future';
  }
  return null;
}

String? validateDor(String? val, String status, String dojText) {
  if (status == 'Relieved') {
    if (val == null || val.trim().isEmpty) {
      return 'Required when status is Relieved';
    }
  }
  if (val == null || val.trim().isEmpty) return null; // optional otherwise
  final dt = DateTime.tryParse(val.trim());
  if (dt == null) {
    return 'Invalid date format';
  }
  if (dt.isAfter(DateTime.now())) {
    return 'Relieving date cannot be in the future';
  }
  final doj = DateTime.tryParse(dojText.trim());
  if (doj != null && dt.isBefore(doj)) {
    return 'Relieving date must be after joining date';
  }
  return null;
}

/// Years of experience: 0–50.
String? validateYoe(String? val) {
  if (val == null || val.trim().isEmpty) {
    return 'Years of Experience is required';
  }
  final n = int.tryParse(val.trim());
  if (n == null) {
    return 'Must be a whole number';
  }
  if (n < 0) {
    return 'Cannot be negative';
  }
  if (n > 50) {
    return 'Maximum 50 years';
  }
  return null;
}

/// Department dropdown — must be selected.
String? validateDept(int? val) =>
    val == null ? 'Please select a department' : null;

/// Role dropdown — must be selected.
String? validateRole(int? val) =>
    val == null ? 'Please select a role/designation' : null;

// Responsive helper
class _Screen {
  final double width;
  const _Screen(this.width);
  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;
  double get pagePadding => isMobile
      ? 12
      : isTablet
      ? 20
      : 28;
  double get cardPadding => isMobile ? 14 : 20;
  double get sectionSpacing => isMobile ? 12 : 16;
  double get titleFontSize => isMobile ? 15 : 17;
  double get bodyFontSize => isMobile ? 13 : 14;
  double get captionFontSize => isMobile ? 11 : 12;
}

Widget _row2(BuildContext ctx, Widget a, Widget b, {double sp = 12}) {
  if (_Screen(MediaQuery.of(ctx).size.width).isMobile) {
    return Column(
      children: [
        a,
        SizedBox(height: sp),
        b,
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: a),
      SizedBox(width: sp),
      Expanded(child: b),
    ],
  );
}

Widget _row3(BuildContext ctx, Widget a, Widget b, Widget c, {double sp = 12}) {
  final s = _Screen(MediaQuery.of(ctx).size.width);
  if (s.isMobile) {
    return Column(
      children: [
        a,
        SizedBox(height: sp),
        b,
        SizedBox(height: sp),
        c,
      ],
    );
  }
  if (s.isTablet) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: a),
            SizedBox(width: sp),
            Expanded(child: b),
          ],
        ),
        SizedBox(height: sp),
        c,
      ],
    );
  }
  return Row(
    children: [
      Expanded(child: a),
      SizedBox(width: sp),
      Expanded(child: b),
      SizedBox(width: sp),
      Expanded(child: c),
    ],
  );
}

PreferredSizeWidget _buildAppBar(
  String title, {
  String? subtitle,
  List<Widget>? actions,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(72),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x401A56DB),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            const BackButton(color: Colors.white),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
            ),
            if (actions != null) ...actions,
            const SizedBox(width: 8),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _inputDec(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: _textMid, fontSize: 13),
  filled: true,
  fillColor: _surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _primary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: _red.withValues(alpha: 0.6)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _red, width: 1.5),
  ),
);

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.color = _primary,
    this.bgColor = const Color(0xFFEEF2FF),
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final List<_Tile> tiles;

  const _DetailCard({
    required this.icon,
    required this.title,
    this.color = _primary,
    this.bgColor = const Color(0xFFEEF2FF),
    required this.tiles,
  });

  @override
  Widget build(BuildContext context) {
    final visible = tiles
        .where((t) => t.value != null && t.value.toString().isNotEmpty)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: visible.map(_buildRow).toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_Tile t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Row(
            children: [
              Icon(t.icon, size: 14, color: _textMid),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textMid,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            t.value?.toString() ?? '-',
            maxLines: t.maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight:
                  (t.value == null ||
                      t.value.toString().isEmpty ||
                      t.value.toString() == '-')
                  ? FontWeight.w400
                  : FontWeight.w600,
              color:
                  (t.value == null ||
                      t.value.toString().isEmpty ||
                      t.value.toString() == '-')
                  ? _textLight
                  : _textDark,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Tile {
  final IconData icon;
  final String label;
  final dynamic value;
  final int maxLines;
  const _Tile(this.icon, this.label, this.value, {this.maxLines = 2});
}

Widget _loader() => const Center(
  child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
);

Widget _errorWidget(String msg, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, color: _red, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          'Something went wrong',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _textMid),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: retry,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text(
            'Try Again',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE USER SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ManageUserScreen extends StatefulWidget {
  final String roleId;
  final String tenantId;
  const ManageUserScreen({
    super.key,
    required this.roleId,
    required this.tenantId,
  });
  @override
  State<ManageUserScreen> createState() => ManageUserScreenState();
}

class ManageUserScreenState extends State<ManageUserScreen> {
  bool _loading = true;
  String? _error;
  List<Employee> employees = [];
  String searchText = '';
  String selectedDepartment = 'All';
  List<String> departmentList = ['All'];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
    debugPrint('╔══════════════════════════════════════════════╗');
    debugPrint('║         ADD EMPLOYEE — API CONFIG             ║');
    debugPrint('╠══════════════════════════════════════════════╣');
    debugPrint(
      '║  tenantId  : ${ApiConfig.tenantId.isEmpty ? "❌ EMPTY" : ApiConfig.tenantId}',
    );
    debugPrint(
      '║  employeeId: ${ApiConfig.employeeId.isEmpty ? "❌ EMPTY" : ApiConfig.employeeId}',
    );
    debugPrint(
      '║  token     : ${ApiConfig.headers['Authorization'] ?? "❌ MISSING"}',
    );
    debugPrint(
      '║  x-tenant  : ${ApiConfig.headers['x-tenant-id'] ?? "❌ MISSING"}',
    );
    debugPrint('╚══════════════════════════════════════════════╝');
    // ─────────────────────────────────────────────────────────────────
  }

  void refreshUsers() => _fetchEmployees();

  Future<void> _fetchEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        EmployeeService.fetchAllEmployees(),
        EmployeeService.fetchDepartments(),
      ]);
      if (!mounted) return;

      final masterList = results[0] as List<Employee>;
      final deptData = results[1] as List<Map<String, dynamic>>;

      // Fetch PENDING and REJECTED separately
      final pendingRes = await ApiClient.get('/pending-request?status=PENDING');
      final rejectedRes = await ApiClient.get(
        '/pending-request?status=REJECTED',
      );

      final pendingJson = (jsonDecode(pendingRes.body)['data'] as List? ?? []);
      final rejectedJson =
          (jsonDecode(rejectedRes.body)['data'] as List? ?? []);

      final pendingList = [
        ...pendingJson,
        ...rejectedJson,
      ].map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();

      // Only exclude pending/rejected entries whose emp_id already exists
      // in master AND whose status is not what we need to show
      // Rule:
      //   - NEW requests (emp_id == 0 or null) → always show (they have no master record)
      //   - UPDATE requests (emp_id != 0) → show the master record + show pending/rejected on top
      //     but DON'T duplicate — only add if not already represented
      final masterEmpIds = masterList
          .map((e) => e.empId)
          .where((id) => id != 0)
          .toSet();

      // For UPDATE requests: we want to show the pending/rejected badge on the
      // existing master card — so we attach the pending info to the master employee
      // For NEW requests: show as separate card with badge

      // Step 1: attach pending/rejected status to master employees if they have one
      final Map<int, Employee> pendingByEmpId = {};
      final List<Employee> newRequests = []; // NEW requests only

      for (final p in pendingList) {
        if (p.empId != 0 && p.empId != null && masterEmpIds.contains(p.empId)) {
          // This is an UPDATE request for an existing employee
          // We'll overlay the status on the master record
          pendingByEmpId[p.empId!] = p;
        } else {
          // This is a NEW request — show as its own card
          newRequests.add(p);
        }
      }

      // Step 2: build master list, overlaying pending status where applicable
      final updatedMasterList = masterList.map((e) {
        final pending = pendingByEmpId[e.empId];
        if (pending != null) {
          // Return a copy of the master employee but with pending status info
          return e.copyWithPendingStatus(
            adminApprove: pending.adminApprove,
            requestId: pending.requestId,
          );
        }
        return e;
      }).toList();

      setState(() {
        employees = [...updatedMasterList, ...newRequests];
        departmentList = ['All', ...deptData.map((d) => d['name'].toString())];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Employee> get _filtered {
    var list = employees.where((e) {
      final name = '${e.firstName ?? ''} ${e.lastName ?? ''}'.toLowerCase();
      return name.contains(searchText) ||
          (e.email ?? '').toLowerCase().contains(searchText) ||
          (e.phone ?? '').contains(searchText);
    }).toList();

    if (selectedDepartment != 'All') {
      list = list.where((e) => e.departmentName == selectedDepartment).toList();
    }

    return list;
  }
  // Helper: build display name for a TL map

  String _tlName(Map<String, dynamic> tl) =>
      (tl['name']?.toString() ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          Container(
            color: _card,
            padding: EdgeInsets.symmetric(
              horizontal: s.pagePadding,
              vertical: 12,
            ),
            // In build(), replace the search+dept filter container:
            child: s.isMobile
                ? Column(
                    children: [
                      _searchField(),
                      const SizedBox(height: 8),
                      _deptFilter(),
                      const SizedBox(height: 8),
                      // _tlFilter(), // ← ADD
                    ],
                  )
                : s.isTablet
                ? Column(
                    children: [
                      _searchField(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _deptFilter()),
                          const SizedBox(width: 10),
                          // Expanded(child: _tlFilter()), // ← ADD
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: _searchField()),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _deptFilter()),
                      const SizedBox(width: 10),
                      // Expanded(flex: 2, child: _tlFilter()), // ← ADD
                    ],
                  ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          Expanded(
            child: _loading
                ? _loader()
                : _error != null
                ? _errorWidget(_error!, _fetchEmployees)
                : RefreshIndicator(
                    onRefresh: _fetchEmployees,
                    color: _primary,
                    child: _buildList(s),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add Employee',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEmployeePage()),
          );
          _fetchEmployees();
        },
      ),
    );
  }

  Widget _searchField() => TextField(
    decoration: InputDecoration(
      hintText: 'Search by name, email or phone…',
      hintStyle: const TextStyle(color: _textLight, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, color: _textLight, size: 20),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    ),
    onChanged: (v) => setState(() => searchText = v.toLowerCase()),
  );

  Widget _deptFilter() => DropdownButtonFormField<String>(
    initialValue: departmentList.contains(selectedDepartment)
        ? selectedDepartment
        : 'All',
    isExpanded: true,
    style: const TextStyle(color: _textDark, fontSize: 13),
    decoration: InputDecoration(
      labelText: 'By Department', // ← ADD LABEL
      labelStyle: const TextStyle(color: _textMid, fontSize: 12),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    ),
    items: departmentList
        .map(
          (e) => DropdownMenuItem(
            value: e,
            child: Text(e, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) => setState(() => selectedDepartment = v!),
  );
  Widget _buildList(_Screen s) {
    final list = _filtered;
    if (list.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_outline_rounded,
                    size: 36,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No employees found',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Try adjusting your search or filter.',
                  style: TextStyle(fontSize: 13, color: _textMid),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(s.pagePadding, 16, s.pagePadding, 80),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _EmployeeCard(
        employee: list[i],
        screen: s,
        onTap: () => _onTap(list[i]),
      ),
    );
  }

  Future<void> _onTap(Employee e) async {
    late String id, source;
    late bool readOnly;

    if (e.adminApprove == 'PENDING') {
      // Has a pending request — show request details, read-only
      if (e.requestId == null) return;
      id = e.requestId.toString();
      source = 'REQUEST';
      readOnly = true;
    } else if (e.adminApprove == 'REJECTED') {
      // Has a rejected request — show request, allow resubmit
      if (e.requestId == null) return;
      id = e.requestId.toString();
      source = 'REQUEST';
      readOnly = false;
    } else {
      // Approved / active employee — show master record, allow edit
      if (e.empId == 0) return;
      id = e.empId.toString();
      source = 'MASTER';
      readOnly = false;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDetailPage(
          id: id,
          source: source,
          readOnly: readOnly,
          userRoleId: widget.roleId,
        ),
      ),
    );
    if (result == true && mounted) _fetchEmployees();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee list card
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeCard extends StatefulWidget {
  final Employee employee;
  final _Screen screen;
  final VoidCallback onTap;

  const _EmployeeCard({
    required this.employee,
    required this.screen,
    required this.onTap,
  });

  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard> {
  late final Future<http.Response> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = (widget.employee.empId != 0)
        ? ApiClient.get('/employees/${widget.employee.empId}/photo')
        : (widget.employee.requestId != null)
        ? ApiClient.get('/pending-request/${widget.employee.requestId}/photo')
        : Future.value(http.Response('', 404));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final screen = widget.screen;
    final fullName =
        '${e.firstName ?? ''} ${e.midName ?? ''} ${e.lastName ?? ''}'.trim();
    final initial = (e.firstName?.isNotEmpty == true ? e.firstName![0] : '?')
        .toUpperCase();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(screen.isMobile ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
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
              FutureBuilder<http.Response>(
                future: _photoFuture,
                builder: (context, snap) {
                  final hasPhoto =
                      snap.hasData &&
                      snap.data!.statusCode == 200 &&
                      snap.data!.bodyBytes.isNotEmpty;
                  return Container(
                    width: screen.isMobile ? 42 : 46,
                    height: screen.isMobile ? 42 : 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasPhoto
                          ? Image.memory(
                              snap.data!.bodyBytes,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: screen.isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? '-' : fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: screen.bodyFontSize,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.email ?? '-',
                      style: TextStyle(
                        fontSize: screen.captionFontSize,
                        color: _textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.departmentName ?? '-',
                      style: TextStyle(
                        fontSize: screen.captionFontSize - 1,
                        color: _textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusBadge(e.adminApprove),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _textLight,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    // For master employees with no pending request, show nothing (they're normal)
    if (status == null || status.toUpperCase() == 'APPROVED') {
      return const SizedBox.shrink();
    }

    Color color;
    switch (status.toUpperCase()) {
      case 'PENDING':
        color = _amber;
        break;
      case 'REJECTED':
        color = _red;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD EMPLOYEE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});
  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final _eduKey = GlobalKey<EducationFormSectionState>();

  final firstNameCtrl = TextEditingController();
  final midNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final fatherCtrl = TextEditingController();
  final emergencyRelationCtrl = TextEditingController();
  final emergencyCtrl = TextEditingController();
  final dojCtrl = TextEditingController();
  final permAddrCtrl = TextEditingController();
  final commAddrCtrl = TextEditingController();
  final yearsExpCtrl = TextEditingController();
  final aadharCtrl = TextEditingController();
  final panCtrl = TextEditingController();
  final passportCtrl = TextEditingController();
  final pfCtrl = TextEditingController();
  final esicCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String gender = 'Male', employmentType = 'Permanent', workType = 'Full Time';
  int? selectedDeptId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], roles = [];
  int? selectedTlId;
  bool _submitting = false;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoPath; // used only on non-web for multipart upload
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  // In AddEmployeePage / EditPage — when department changes, reload roles
  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(), // fan-out, now always returns a list
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      // Don't crash the form — just leave lists empty
      debugPrint('_loadDropdowns error: $e');
    }
  }

  // Optional: refresh roles when user picks a department
  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedRoleId = null; // reset role when dept changes
      roles = [];
    });
    if (deptId != null) {
      final deptRoles = await EmployeeService.fetchRoles(deptId: deptId);
      if (mounted) setState(() => roles = deptRoles);
    }
  }

  @override
  void dispose() {
    for (final c in [
      firstNameCtrl,
      midNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      dojCtrl,
      permAddrCtrl,
      commAddrCtrl,
      yearsExpCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl,
      pfCtrl,
      esicCtrl,
      usernameCtrl,
      passwordCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    const sp = 12.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(
        'Add New Employee',
        subtitle: 'Fill in employee details',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // ── Personal Information ──────────────────────────────────────
                  _SectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),

                    children: [
                      // ── Profile Photo ──────────────────────────────────────
                      GestureDetector(
                        onTap: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: 800,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setState(() {
                              _selectedPhotoBytes = bytes;
                              _selectedPhotoPath = picked.path;
                            });
                          }
                        },
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _border, width: 2),
                            ),
                            child: _selectedPhotoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.memory(
                                      _selectedPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        color: _textMid,
                                        size: 28,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Photo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row3(
                        context,
                        FormTextField(
                          firstNameCtrl,
                          'First Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          midNameCtrl,
                          'Middle Name',
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          lastNameCtrl,
                          'Last Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          emailCtrl,
                          'Email',
                          required: true,
                          fieldType: 'email',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          phoneCtrl,
                          'Phone',
                          required: true,
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        // ── DOB with age >= 18 validation ──────────────────────
                        FormDateField(
                          dobCtrl,
                          'Date of Birth',
                          padding: EdgeInsets.zero,
                          lastDate: DateTime.now().subtract(
                            const Duration(days: 365 * 18),
                          ), // max = 18 yrs ago
                          validator: validateDob,
                        ),
                        FormDropdownString(
                          'Gender',
                          gender,
                          ['Male', 'Female', 'Other'],
                          (v) => setState(() => gender = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          fatherCtrl,
                          'Father Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          emergencyCtrl,
                          'Emergency Contact',
                          required: true,
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        emergencyRelationCtrl,
                        'Emergency Contact Relation',
                        required: true,
                        padding: EdgeInsets.zero,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Relation is required (e.g. Father, Spouse)'
                            : null,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),

                  // ── Employment Information ────────────────────────────────────
                  _SectionCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Employment Information',
                    color: _purple,
                    bgColor: const Color(0xFFF5F3FF),
                    children: [
                      _row2(
                        context,
                        FormDropdownMap(
                          'Department',
                          departments,
                          selectedDeptId,
                          _onDeptChanged, // ← replaces the inline setState
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownMap(
                          'Role / Designation',
                          roles,
                          selectedRoleId,
                          (v) => setState(() => selectedRoleId = v),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),

                      SizedBox(height: sp),
                      // ── DOJ — cannot be in future ──────────────────────────
                      FormDateField(
                        dojCtrl,
                        'Date of Joining',
                        padding: EdgeInsets.zero,
                        lastDate: DateTime.now(),
                        validator: validateDoj,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormDropdownString(
                          'Employment Type',
                          employmentType,
                          ['Permanent', 'Contract', 'Intern'],
                          (v) => setState(() => employmentType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownString(
                          'Work Type',
                          workType,
                          ['Full Time', 'Part Time'],
                          (v) => setState(() => workType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        permAddrCtrl,
                        'Permanent Address',
                        required: true,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      CopyAddressRow(
                        sourceController: permAddrCtrl,
                        targetController: commAddrCtrl,
                        useIconButton: false,
                      ),
                      SizedBox(height: sp),
                      // ── Years of experience 0–50 ───────────────────────────
                      FormTextField(
                        yearsExpCtrl,
                        'Years of Experience',
                        required: true,
                        fieldType: 'yoe',
                        padding: EdgeInsets.zero,
                        validator: validateYoe,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),

                  // ── Documents & Statutory ─────────────────────────────────────
                  _SectionCard(
                    icon: Icons.description_outlined,
                    title: 'Documents & Statutory',
                    color: _red,
                    bgColor: const Color(0xFFFFF1F2),
                    children: [
                      _row2(
                        context,
                        FormTextField(
                          aadharCtrl,
                          'Aadhar Number',
                          required: true,
                          fieldType: 'aadhar',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          panCtrl,
                          'PAN Number',
                          required: true,
                          fieldType: 'pan',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          passportCtrl,
                          'Passport Number',
                          fieldType: 'passport',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          pfCtrl,
                          'PF Number',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        esicCtrl,
                        'ESIC Number',
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  EducationFormSection(key: _eduKey),
                  SizedBox(height: s.sectionSpacing),

                  // ── Login Credentials ─────────────────────────────────────────
                  _SectionCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Login Credentials',
                    color: _amber,
                    bgColor: const Color(0xFFFFFBEB),
                    children: [
                      _row2(
                        context,
                        FormTextField(
                          usernameCtrl,
                          'Username',
                          required: true,
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          passwordCtrl,
                          'Password',
                          required: true,
                          fieldType: 'password',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _submitting ? 'Submitting…' : 'Submit Employee Request',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDeptId == null) {
      _snack('Please select a department');
      return;
    }
    if (selectedRoleId == null) {
      _snack('Please select a role / designation');
      return;
    }
    if (!(_eduKey.currentState?.validate() ?? false)) {
      _snack('Please add at least one education record');
      return;
    }

    setState(() => _submitting = true);

    final body = {
      'tenant_id': ApiConfig.tenantId, // ← ADD
      'created_by': ApiConfig.employeeId, // ← ADD
      'first_name': firstNameCtrl.text,
      'mid_name': midNameCtrl.text,
      'last_name': lastNameCtrl.text,
      'email_id': emailCtrl.text,
      'phone_number': phoneCtrl.text,
      'date_of_birth': dobCtrl.text,
      'gender': gender,
      'department_id': selectedDeptId,
      'role_id': selectedRoleId,
      'date_of_joining': dojCtrl.text,
      'employment_type': employmentType,
      'work_type': workType,
      'permanent_address': permAddrCtrl.text,
      'communication_address': commAddrCtrl.text,
      'aadhar_number': aadharCtrl.text,
      'pan_number': panCtrl.text,
      'passport_number': passportCtrl.text,
      'father_name': fatherCtrl.text,
      'emergency_contact_relation': emergencyRelationCtrl.text,
      'emergency_contact': emergencyCtrl.text,
      'pf_number': pfCtrl.text,
      'esic_number': esicCtrl.text,
      'years_experience': int.tryParse(yearsExpCtrl.text),
      'username': usernameCtrl.text,
      'password': passwordCtrl.text,
      'request_type': 'NEW',
      'education': _eduKey.currentState?.getEntries() ?? [],
      'tl_id': selectedTlId,
    };

    try {
      final res = await ApiClient.post('/pending-request', body);
      if (!mounted) return;

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        // ── Upload photo if one was selected ─────────────────────────────────
        if (_selectedPhotoBytes != null) {
          try {
            final empId = data['emp_id'];
            final requestId = data['request_id'];

            late Uri photoUri;
            if (empId != null) {
              photoUri = Uri.parse(
                '${ApiConfig.baseUrl}/employees/$empId/photo',
              );
            } else if (requestId != null) {
              photoUri = Uri.parse(
                '${ApiConfig.baseUrl}/pending-request/$requestId/photo',
              );
            } else {
              throw Exception('No ID returned for photo upload');
            }

            final photoReq = http.MultipartRequest('POST', photoUri);

            // ← ADD THESE — auth header was missing, causing the 401
            photoReq.headers.addAll(ApiConfig.headers);

            photoReq.files.add(
              http.MultipartFile.fromBytes(
                'photo',
                _selectedPhotoBytes!,
                filename: 'photo.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );
            await photoReq.send();
          } catch (_) {
            // non-fatal
          }
        }

        final isDirectSave = data['emp_id'] != null;
        _snack(
          isDirectSave
              ? 'Employee added successfully!'
              : 'Employee request submitted for approval.',
          ok: true,
        );
        if (mounted) Navigator.pop(context);
      } else {
        _snack(data['message'] ?? 'Submission failed');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE DETAIL PAGE  (unchanged logic, just carried over)
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDetailPage extends StatefulWidget {
  final String id, source;
  final bool readOnly;
  final String userRoleId;
  const EmployeeDetailPage({
    super.key,
    required this.id,
    required this.source,
    this.readOnly = false,
    this.userRoleId = '2',
  });
  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  Map<String, dynamic>? employeeData;
  bool isLoading = true;
  Future<http.Response>? _photoFuture;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    if (widget.source == 'MASTER') {
      _photoFuture = ApiClient.get('/employees/${widget.id}/photo');
    } else {
      // ← ADD THIS — widget.id IS the request_id when source == 'REQUEST'
      _photoFuture = ApiClient.get('/pending-request/${widget.id}/photo');
    }
  }

  Future<void> _fetchDetails() async {
    final path = widget.source == 'MASTER'
        ? '/employees/${widget.id}'
        : '/pending-request/${widget.id}';
    try {
      final res = await ApiClient.get(path);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final emp = data is Map && data.containsKey('data')
            ? data['data']
            : data;
        setState(() {
          employeeData = Map<String, dynamic>.from(emp);
          isLoading = false;
        });

        // Only fetch education separately for MASTER
        // REQUEST already has education embedded in the response (row.education)
        if (widget.source == 'MASTER') {
          final eduId = emp['emp_id'];
          if (eduId != null) {
            final er = await ApiClient.get('/employees/$eduId/education');
            if (er.statusCode == 200 && mounted) {
              setState(
                () => employeeData!['education'] = jsonDecode(er.body)['data'],
              );
            }
          }
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _fmtDate(dynamic d) {
    if (d == null || d.toString().isEmpty) return '-';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')} ${_mon(dt.month)} ${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }

  String _mon(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  String _maskAadhar(dynamic d) {
    if (d == null || d.toString().isEmpty) return '-';
    final s = d.toString();
    return s.length <= 4 ? s : 'XXXX-XXXX-${s.substring(s.length - 4)}';
  }

  List<Map<String, dynamic>> get _eduList {
    final raw = employeeData?['education'];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  bool get _isRejected =>
      widget.source == 'REQUEST' &&
      employeeData?['admin_approve'] == 'REJECTED';
  bool get _canEdit => !widget.readOnly;

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(
        'Employee Profile',
        subtitle: 'View employee information',
        actions: [
          if (_canEdit && widget.source == 'MASTER')
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              tooltip: 'Edit Employee',
              onPressed: employeeData == null
                  ? null
                  : () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmployeeEditPage(
                            employee: Employee.fromJson(employeeData!),
                            source: 'MASTER',
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    },
            ),
          if (_canEdit && _isRejected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'Resubmit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: _amber.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EmployeeResubmitPage(requestData: employeeData!),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            ),
        ],
      ),
      body: isLoading
          ? _loader()
          : employeeData == null
          ? _emptyState()
          : RefreshIndicator(
              onRefresh: _fetchDetails,
              color: _primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(s.pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        _heroCard(s),
                        SizedBox(height: s.sectionSpacing),
                        if (s.isMobile) ...[
                          _basicCard(),
                          SizedBox(height: s.sectionSpacing),
                          _contactCard(),
                          SizedBox(height: s.sectionSpacing),
                          _employmentCard(),
                          SizedBox(height: s.sectionSpacing),
                          _documentsCard(),
                          SizedBox(height: s.sectionSpacing),
                          _loginCard(),
                          SizedBox(height: s.sectionSpacing),
                          _educationCard(),
                          if (_isRejected) ...[
                            SizedBox(height: s.sectionSpacing),
                            _rejectionCard(),
                          ],
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _basicCard()),
                              const SizedBox(width: 12),
                              Expanded(child: _contactCard()),
                            ],
                          ),
                          SizedBox(height: s.sectionSpacing),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _employmentCard()),
                              const SizedBox(width: 12),
                              Expanded(child: _documentsCard()),
                            ],
                          ),
                          SizedBox(height: s.sectionSpacing),
                          _loginCard(),
                          SizedBox(height: s.sectionSpacing),
                          _educationCard(),
                          if (_isRejected) ...[
                            SizedBox(height: s.sectionSpacing),
                            _rejectionCard(),
                          ],
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: _primary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No data found',
          style: TextStyle(color: _textMid, fontSize: 15),
        ),
      ],
    ),
  );

  Widget _heroCard(_Screen s) {
    final fullName =
        '${employeeData!['first_name'] ?? ''} ${employeeData!['mid_name'] ?? ''} ${employeeData!['last_name'] ?? ''}'
            .trim();
    final statusText = widget.source == 'MASTER'
        ? employeeData!['status'] ?? '-'
        : employeeData!['admin_approve'] ?? '-';
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    Color statusColor;
    switch (statusText.toUpperCase()) {
      case 'ACTIVE':
        statusColor = _accent;
        break;
      case 'PENDING':
        statusColor = _amber;
        break;
      case 'REJECTED':
        statusColor = _red;
        break;
      default:
        statusColor = _textLight;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(s.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<http.Response>(
                      future:
                          _photoFuture ?? Future.value(http.Response('', 404)),
                      builder: (context, snap) {
                        final hasPhoto =
                            snap.hasData &&
                            snap.data!.statusCode == 200 &&
                            snap.data!.bodyBytes.isNotEmpty;
                        return Container(
                          width: s.isMobile ? 52 : 64,
                          height: s.isMobile ? 52 : 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              s.isMobile ? 14 : 18,
                            ),
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              s.isMobile ? 12 : 16,
                            ),
                            child: hasPhoto
                                ? Image.memory(
                                    snap.data!.bodyBytes,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        fontSize: s.isMobile ? 22 : 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? 'Unknown' : fullName,
                            style: TextStyle(
                              fontSize: s.isMobile ? 17 : 21,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            employeeData!['role_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            employeeData!['department_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  widget.source == 'MASTER'
                                      ? 'ID: ${employeeData!["emp_id"] ?? "-"}'
                                      : 'Req: ${employeeData!["request_id"] ?? "-"}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _heroStat(
                      employeeData!['employment_type']?.toString() ?? '-',
                      'TYPE',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      employeeData!['work_type']?.toString() ?? '-',
                      'WORK',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      employeeData!['years_experience'] != null
                          ? '${employeeData!["years_experience"]} yrs'
                          : '-',
                      'EXP',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _heroVDiv() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.12),
  );

  Widget _basicCard() => _DetailCard(
    icon: Icons.person_outline_rounded,
    title: 'Basic Information',
    color: _primary,
    bgColor: const Color(0xFFEEF2FF),
    tiles: [
      _Tile(Icons.wc_rounded, 'Gender', employeeData!['gender']),
      _Tile(
        Icons.cake_outlined,
        'Date of Birth',
        _fmtDate(employeeData!['date_of_birth']),
      ),
      _Tile(
        Icons.family_restroom_rounded,
        'Father Name',
        employeeData!['father_name'],
      ),
    ],
  );

  Widget _contactCard() => _DetailCard(
    icon: Icons.contact_mail_outlined,
    title: 'Contact Information',
    color: _purple,
    bgColor: const Color(0xFFF5F3FF),
    tiles: [
      _Tile(Icons.email_outlined, 'Email', employeeData!['email_id']),
      _Tile(Icons.phone_outlined, 'Phone', employeeData!['phone_number']),
      _Tile(
        Icons.emergency_outlined,
        'Emergency Contact',
        employeeData!['emergency_contact'],
      ),
      _Tile(
        Icons.people_outline_rounded,
        'Relation to Employee',
        employeeData!['emergency_contact_relation'],
      ),
      _Tile(
        Icons.home_outlined,
        'Permanent Address',
        employeeData!['permanent_address'],
        maxLines: 3,
      ),
      _Tile(
        Icons.location_on_outlined,
        'Communication Address',
        employeeData!['communication_address'],
        maxLines: 3,
      ),
    ],
  );

  Widget _employmentCard() => _DetailCard(
    icon: Icons.work_outline_rounded,
    title: 'Employment Information',
    color: _amber,
    bgColor: const Color(0xFFFFFBEB),
    tiles: [
      _Tile(
        Icons.business_outlined,
        'Department',
        employeeData!['department_name'],
      ),
      _Tile(Icons.badge_outlined, 'Designation', employeeData!['role_name']),

      _Tile(
        Icons.calendar_today_outlined,
        'Date of Joining',
        _fmtDate(employeeData!['date_of_joining']),
      ),
      if (employeeData!['date_of_relieving'] != null &&
          employeeData!['date_of_relieving'].toString().isNotEmpty)
        _Tile(
          Icons.event_busy_outlined,
          'Date of Relieving',
          _fmtDate(employeeData!['date_of_relieving']),
        ),
      _Tile(
        Icons.category_outlined,
        'Employment Type',
        employeeData!['employment_type'],
      ),
      _Tile(
        Icons.access_time_outlined,
        'Work Type',
        employeeData!['work_type'],
      ),
      _Tile(
        Icons.timeline_rounded,
        'Experience',
        '${employeeData!["years_experience"] ?? "-"} yrs',
      ),
    ],
  );

  Widget _documentsCard() => _DetailCard(
    icon: Icons.description_outlined,
    title: 'Documents & Statutory',
    color: _red,
    bgColor: const Color(0xFFFFF1F2),
    tiles: [
      _Tile(
        Icons.credit_card_outlined,
        'Aadhar',
        employeeData!['aadhar_number']?.toString().isNotEmpty == true
            ? _maskAadhar(employeeData!['aadhar_number'])
            : 'Not provided',
      ),
      _Tile(
        Icons.assignment_outlined,
        'PAN',
        employeeData!['pan_number']?.toString().isNotEmpty == true
            ? employeeData!['pan_number']
            : 'Not provided',
      ),
      _Tile(
        Icons.flight_outlined,
        'Passport',
        employeeData!['passport_number']?.toString().isNotEmpty == true
            ? employeeData!['passport_number']
            : 'Not provided',
      ),
      _Tile(
        Icons.account_balance_outlined,
        'PF Number',
        employeeData!['pf_number'],
      ),
      _Tile(
        Icons.health_and_safety_outlined,
        'ESIC Number',
        employeeData!['esic_number'],
      ),
    ],
  );

  Widget _loginCard() {
    final username = employeeData!['username']?.toString() ?? '';
    if (username.isEmpty) return const SizedBox.shrink();
    return _DetailCard(
      icon: Icons.lock_outline_rounded,
      title: 'Login Credentials',
      color: _accent,
      bgColor: const Color(0xFFECFDF5),
      tiles: [_Tile(Icons.person_pin_outlined, 'Username', username)],
    );
  }

  Widget _educationCard() {
    final list = _eduList;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: _accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Education Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
                if (list.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${list.length} record${list.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.school_outlined, size: 36, color: _textLight),
                    SizedBox(height: 10),
                    Text(
                      'No education records found',
                      style: TextStyle(color: _textMid, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: list.map((e) => _EduDetailCard(entry: e)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rejectionCard() => Container(
    decoration: BoxDecoration(
      color: _red.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _red.withValues(alpha: 0.3)),
    ),
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: _red, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rejection Reason',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _red,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employeeData!['reject_reason'] ?? '-',
                style: const TextStyle(color: _red, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Education read-only card
// ─────────────────────────────────────────────────────────────────────────────
class _EduDetailCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EduDetailCard({required this.entry});

  static const _colors = {
    '10': Color(0xFF6366F1),
    '12': Color(0xFF8B5CF6),
    'Diploma': Color(0xFFF59E0B),
    'UG': Color(0xFF0E9F6E),
    'PG': Color(0xFF1A56DB),
    'PhD': Color(0xFFEF4444),
  };
  static const _labels = {
    '10': 'Class 10',
    '12': 'Class 12 (HSC)',
    'Diploma': 'Diploma',
    'UG': 'Under Graduate',
    'PG': 'Post Graduate',
    'PhD': 'Doctorate (PhD)',
  };

  @override
  Widget build(BuildContext context) {
    final level = entry['education_level']?.toString() ?? '';
    final color = _colors[level] ?? _textMid;
    final stream = entry['stream']?.toString() ?? '';
    final college = entry['college_name']?.toString() ?? '';
    final uni = entry['university']?.toString() ?? '';
    final score = entry['score']?.toString() ?? '';
    final year = entry['year_of_passout']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stream.isNotEmpty ? stream : (_labels[level] ?? level),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (score.isNotEmpty)
                _chip(Icons.percent_rounded, '$score%', color),
              if (year.isNotEmpty)
                _chip(Icons.calendar_today_rounded, year, _purple),
              if (college.isNotEmpty)
                _chip(Icons.account_balance_rounded, college, _primary),
              if (uni.isNotEmpty) _chip(Icons.school_outlined, uni, _amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
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

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE RESUBMIT PAGE
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeResubmitPage extends StatefulWidget {
  final Map<String, dynamic> requestData;
  const EmployeeResubmitPage({super.key, required this.requestData});
  @override
  State<EmployeeResubmitPage> createState() => _EmployeeResubmitPageState();
}

class _EmployeeResubmitPageState extends State<EmployeeResubmitPage> {
  final _formKey = GlobalKey<FormState>();
  final _eduKey = GlobalKey<EducationFormSectionState>();

  late TextEditingController firstNameCtrl,
      midNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      dojCtrl,
      permAddrCtrl,
      commAddrCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl,
      usernameCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      pfCtrl,
      esicCtrl,
      yearsExpCtrl;

  String gender = 'Male', employmentType = 'Permanent', workType = 'Full Time';
  int? selectedDeptId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], roles = [];
  int? selectedTlId;
  bool _submitting = false;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoPath;
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _initialEdu = [];

  @override
  void initState() {
    super.initState();
    final d = widget.requestData;
    firstNameCtrl = TextEditingController(text: d['first_name'] ?? '');
    midNameCtrl = TextEditingController(text: d['mid_name'] ?? '');
    lastNameCtrl = TextEditingController(text: d['last_name'] ?? '');
    emailCtrl = TextEditingController(text: d['email_id'] ?? '');
    phoneCtrl = TextEditingController(text: d['phone_number'] ?? '');
    dobCtrl = TextEditingController(text: _fmtDate(d['date_of_birth']));
    dojCtrl = TextEditingController(text: _fmtDate(d['date_of_joining']));
    permAddrCtrl = TextEditingController(text: d['permanent_address'] ?? '');
    commAddrCtrl = TextEditingController(
      text: d['communication_address'] ?? '',
    );
    aadharCtrl = TextEditingController(text: d['aadhar_number'] ?? '');
    panCtrl = TextEditingController(text: d['pan_number'] ?? '');
    passportCtrl = TextEditingController(text: d['passport_number'] ?? '');
    usernameCtrl = TextEditingController(text: d['username'] ?? '');
    fatherCtrl = TextEditingController(text: d['father_name'] ?? '');
    emergencyRelationCtrl = TextEditingController(
      text: d['emergency_contact_relation'] ?? '',
    );
    emergencyCtrl = TextEditingController(text: d['emergency_contact'] ?? '');
    pfCtrl = TextEditingController(text: d['pf_number'] ?? '');
    esicCtrl = TextEditingController(text: d['esic_number'] ?? '');
    yearsExpCtrl = TextEditingController(
      text: d['years_experience']?.toString() ?? '',
    );
    gender = d['gender'] ?? 'Male';
    employmentType = d['employment_type'] ?? 'Permanent';
    workType = d['work_type'] ?? 'Full Time';
    selectedDeptId = d['department_id'] != null
        ? int.tryParse(d['department_id'].toString())
        : null;
    selectedRoleId = d['role_id'] != null
        ? int.tryParse(d['role_id'].toString())
        : null;

    selectedTlId = d['tl_id'] != null
        ? int.tryParse(d['tl_id'].toString())
        : null;
    if (d['education'] is List) {
      _initialEdu = (d['education'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    _loadDropdowns();
  }

  String _fmtDate(dynamic d) {
    if (d == null || d.toString().isEmpty) return '';
    try {
      return DateTime.parse(d.toString()).toIso8601String().split('T').first;
    } catch (_) {
      return d.toString();
    }
  }

  // In AddEmployeePage / EditPage — when department changes, reload roles
  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(), // fan-out, now always returns a list
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      // Don't crash the form — just leave lists empty
      debugPrint('_loadDropdowns error: $e');
    }
  }

  // Optional: refresh roles when user picks a department
  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedRoleId = null; // reset role when dept changes
      roles = [];
    });
    if (deptId != null) {
      final deptRoles = await EmployeeService.fetchRoles(deptId: deptId);
      if (mounted) setState(() => roles = deptRoles);
    }
  }

  @override
  void dispose() {
    for (final c in [
      firstNameCtrl,
      midNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      dojCtrl,
      permAddrCtrl,
      commAddrCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl,
      usernameCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      pfCtrl,
      esicCtrl,
      yearsExpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    const sp = 12.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(
        'Edit & Resubmit',
        subtitle: 'Fix and resubmit your request',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Rejection reason banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.05),
                      border: Border.all(color: _red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: _red,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rejection Reason:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.requestData['reject_reason'] ?? '-',
                                style: const TextStyle(
                                  color: _red,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  _SectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),
                    children: [
                      // ── Profile Photo ─────────────────────────────────────────────
                      GestureDetector(
                        onTap: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: 800,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setState(() {
                              _selectedPhotoBytes = bytes;
                              _selectedPhotoPath = picked.path;
                            });
                          }
                        },
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _border, width: 2),
                            ),
                            child: _selectedPhotoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.memory(
                                      _selectedPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        color: _textMid,
                                        size: 28,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Add Photo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _textMid,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _row3(
                        context,
                        FormTextField(
                          firstNameCtrl,
                          'First Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          midNameCtrl,
                          'Middle Name',
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          lastNameCtrl,
                          'Last Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          emailCtrl,
                          'Email',
                          required: true,
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          phoneCtrl,
                          'Phone',
                          required: true,
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormDateField(
                          dobCtrl,
                          'Date of Birth',
                          padding: EdgeInsets.zero,
                          lastDate: DateTime.now().subtract(
                            const Duration(days: 365 * 18),
                          ),
                          validator: validateDob,
                        ),
                        FormDropdownString(
                          'Gender',
                          gender,
                          ['Male', 'Female', 'Other'],
                          (v) => setState(() => gender = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          fatherCtrl,
                          'Father Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          emergencyCtrl,
                          'Emergency Contact',
                          required: true,
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        emergencyRelationCtrl,
                        'Emergency Contact Relation',
                        required: true,
                        padding: EdgeInsets.zero,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Relation is required (e.g. Father, Spouse)'
                            : null,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Employment Information',
                    color: _purple,
                    bgColor: const Color(0xFFF5F3FF),
                    children: [
                      _row2(
                        context,
                        FormDropdownMap(
                          'Department',
                          departments,
                          selectedDeptId,
                          (v) => setState(() => selectedDeptId = v),
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownMap(
                          'Role',
                          roles,
                          selectedRoleId,
                          (v) => setState(() => selectedRoleId = v),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormDateField(
                        dojCtrl,
                        'Date of Joining',
                        padding: EdgeInsets.zero,
                        lastDate: DateTime.now(),
                        validator: validateDoj,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormDropdownString(
                          'Employment Type',
                          employmentType,
                          ['Permanent', 'Contract', 'Intern'],
                          (v) => setState(() => employmentType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownString(
                          'Work Type',
                          workType,
                          ['Full Time', 'Part Time'],
                          (v) => setState(() => workType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        permAddrCtrl,
                        'Permanent Address',
                        required: true,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      CopyAddressRow(
                        sourceController: permAddrCtrl,
                        targetController: commAddrCtrl,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        yearsExpCtrl,
                        'Years of Experience',
                        fieldType: 'yoe',
                        padding: EdgeInsets.zero,
                        validator: validateYoe,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.description_outlined,
                    title: 'Documents & Statutory',
                    color: _red,
                    bgColor: const Color(0xFFFFF1F2),
                    children: [
                      _row2(
                        context,
                        FormTextField(
                          aadharCtrl,
                          'Aadhar Number',
                          required: true,
                          fieldType: 'aadhar',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          panCtrl,
                          'PAN Number',
                          required: true,
                          fieldType: 'pan',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          passportCtrl,
                          'Passport Number',
                          fieldType: 'passport',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          pfCtrl,
                          'PF Number',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        esicCtrl,
                        'ESIC Number',
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        usernameCtrl,
                        'Username',
                        required: true,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  EducationFormSection(
                    key: _eduKey,
                    initialEntries: _initialEdu,
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _amber,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _submitting ? 'Submitting…' : 'Resubmit for Approval',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _submitting ? null : _resubmit,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDeptId == null) {
      _snack('Please select a department');
      return;
    }
    if (selectedRoleId == null) {
      _snack('Please select a role');
      return;
    }
    // ← ADD THIS
    if (!(_eduKey.currentState?.validate() ?? false)) {
      _snack('Please add at least one education record');
      return;
    }

    setState(() => _submitting = true);
    final body = {
      'tenant_id': ApiConfig.tenantId, // ← ADD
      'updated_by': ApiConfig.employeeId, // ← ADD
      'first_name': firstNameCtrl.text,
      'mid_name': midNameCtrl.text,
      'last_name': lastNameCtrl.text,
      'email_id': emailCtrl.text,
      'phone_number': phoneCtrl.text,
      'date_of_birth': dobCtrl.text,
      'gender': gender,
      'department_id': selectedDeptId,
      'role_id': selectedRoleId,
      'date_of_joining': dojCtrl.text,
      'employment_type': employmentType,
      'work_type': workType,
      'permanent_address': permAddrCtrl.text,
      'communication_address': commAddrCtrl.text,
      'aadhar_number': aadharCtrl.text,
      'pan_number': panCtrl.text,
      'passport_number': passportCtrl.text,
      'username': usernameCtrl.text,
      'father_name': fatherCtrl.text,
      'emergency_contact_relation': emergencyRelationCtrl.text,
      'emergency_contact': emergencyCtrl.text,
      'pf_number': pfCtrl.text,
      'esic_number': esicCtrl.text,
      'years_experience': int.tryParse(yearsExpCtrl.text),
      'education': _eduKey.currentState?.getEntries() ?? [],
      'tl_id': selectedTlId,
    };
    try {
      final res = await ApiClient.put(
        '/pending-request/${widget.requestData["request_id"]}/resubmit',
        body,
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final requestId = widget.requestData['request_id'];
        if (_selectedPhotoBytes != null && requestId != null) {
          try {
            final photoReq = http.MultipartRequest(
              'POST',
              Uri.parse(
                '${ApiConfig.baseUrl}/pending-request/$requestId/photo',
              ),
            );
            photoReq.headers.addAll(ApiConfig.headers); // ← ADD THIS
            photoReq.files.add(
              http.MultipartFile.fromBytes(
                'photo',
                _selectedPhotoBytes!,
                filename: 'photo.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );
            await photoReq.send();
          } catch (_) {}
        }
        _snack('Request resubmitted!', ok: true);
        Navigator.pop(context, true);
      } else {
        _snack(data['message'] ?? 'Resubmit failed');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: ok ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPLOYEE EDIT PAGE
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeEditPage extends StatefulWidget {
  final Employee employee;
  final String source;
  const EmployeeEditPage({
    super.key,
    required this.employee,
    required this.source,
  });
  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _eduKey = GlobalKey<EducationFormSectionState>();
  late Employee original;
  late final Future<http.Response> _existingPhotoFuture;
  late TextEditingController firstNameCtrl,
      midNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      dojCtrl,
      dorCtrl,
      permAddrCtrl,
      commAddrCtrl,
      editReasonCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      pfCtrl,
      esicCtrl,
      yearsExpCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl;

  String workType = 'Full Time',
      gender = 'Male',
      employmentType = 'Permanent',
      status = 'Active';
  int? selectedDeptId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], roles = [];
  int? selectedTlId;
  bool _submitting = false, _loadingEdu = true;
  Uint8List? _selectedPhotoBytes;
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _initialEdu = [];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    original = widget.employee;
    String fmt(DateTime? dt) =>
        dt == null ? '' : dt.toIso8601String().split('T').first;

    firstNameCtrl = TextEditingController(text: e.firstName);
    midNameCtrl = TextEditingController(text: e.midName);
    lastNameCtrl = TextEditingController(text: e.lastName);
    emailCtrl = TextEditingController(text: e.email);
    phoneCtrl = TextEditingController(text: e.phone);
    dobCtrl = TextEditingController(
      text: fmt(e.dob != null ? DateTime.tryParse(e.dob!) : null),
    );
    dojCtrl = TextEditingController(
      text: fmt(
        e.dateOfJoining != null ? DateTime.tryParse(e.dateOfJoining!) : null,
      ),
    );
    dorCtrl = TextEditingController(
      text: e.dateOfRelieving != null ? fmt(e.dateOfRelieving) : '',
    );
    permAddrCtrl = TextEditingController(text: e.address);
    commAddrCtrl = TextEditingController(
      text: e.communicationAddress ?? e.city ?? '',
    );
    editReasonCtrl = TextEditingController();
    fatherCtrl = TextEditingController(text: e.fatherName ?? '');
    emergencyRelationCtrl = TextEditingController(
      text: e.emergencyContactRelation ?? '',
    );
    emergencyCtrl = TextEditingController(text: e.emergencyContact ?? '');
    pfCtrl = TextEditingController(text: e.pfNumber ?? '');
    esicCtrl = TextEditingController(text: e.esicNumber ?? '');
    yearsExpCtrl = TextEditingController(
      text: e.yearsExperience?.toString() ?? '',
    );

    workType = e.workType ?? 'Full Time';
    gender = e.gender ?? 'Male';
    employmentType = e.employmentType ?? 'Permanent';
    status = e.status ?? 'Active';
    selectedDeptId = e.departmentId;
    selectedRoleId = e.roleId;
    aadharCtrl = TextEditingController(text: e.aadharNumber ?? '');
    panCtrl = TextEditingController(text: e.panNumber ?? '');
    passportCtrl = TextEditingController(text: e.passportNumber ?? '');
    selectedTlId = e.tlId;
    _existingPhotoFuture = ApiClient.get(
      '/employees/${widget.employee.empId}/photo',
    );
    _loadDropdowns();
    _loadExistingEducation();
  }

  // In AddEmployeePage / EditPage — when department changes, reload roles

  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(), // fan-out, now always returns a list
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      // Don't crash the form — just leave lists empty
      debugPrint('_loadDropdowns error: $e');
    }
  }

  // Optional: refresh roles when user picks a department
  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedRoleId = null; // reset role when dept changes
      roles = [];
    });
    if (deptId != null) {
      final deptRoles = await EmployeeService.fetchRoles(deptId: deptId);
      if (mounted) setState(() => roles = deptRoles);
    }
  }

  Future<void> _loadExistingEducation() async {
    setState(() => _loadingEdu = true);
    try {
      final list = await EmployeeService.fetchEducation(widget.employee.empId);
      if (!mounted) return;
      setState(() {
        _initialEdu = list
            .map(
              (e) => {
                'education_level': e.educationLevel ?? '',
                'stream': e.stream ?? '',
                'score': e.score ?? '',
                'year_of_passout': e.yearOfPassout ?? '',
                'university': e.university ?? '',
                'college_name': e.collegeName ?? '',
              },
            )
            .toList();
        _loadingEdu = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingEdu = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      firstNameCtrl,
      midNameCtrl,
      lastNameCtrl,
      emailCtrl,
      phoneCtrl,
      dobCtrl,
      dojCtrl,
      dorCtrl,
      permAddrCtrl,
      commAddrCtrl,
      editReasonCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      pfCtrl,
      esicCtrl,
      yearsExpCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    const sp = 12.0;

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(
        'Edit Employee',
        subtitle: 'Update employee information',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(s.pagePadding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _SectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),
                    children: [
                      // ── Profile Photo ──────────────────────────────────────
                      GestureDetector(
                        onTap: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 80,
                            maxWidth: 800,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setState(() => _selectedPhotoBytes = bytes);
                            // try {
                            //   final photoReq = http.MultipartRequest(
                            //     'POST',
                            //     Uri.parse(
                            //       '$baseUrl/employees/${widget.employee.empId}/photo',
                            //     ),
                            //   );
                            //   photoReq.files.add(
                            //     http.MultipartFile.fromBytes(
                            //       'photo',
                            //       bytes,
                            //       filename: 'photo.jpg',
                            //     ),
                            //   );
                            //   await photoReq.send();
                            // } catch (_) {}
                          }
                        },
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: _border, width: 2),
                            ),
                            child: _selectedPhotoBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Image.memory(
                                      _selectedPhotoBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : FutureBuilder<http.Response>(
                                    future: _existingPhotoFuture,
                                    builder: (context, snap) {
                                      if (snap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _primary,
                                            ),
                                          ),
                                        );
                                      }
                                      final hasPhoto =
                                          snap.hasData &&
                                          snap.data!.statusCode == 200 &&
                                          snap.data!.bodyBytes.isNotEmpty;
                                      return hasPhoto
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                              child: Image.memory(
                                                snap.data!.bodyBytes,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add_a_photo_outlined,
                                                  color: _textMid,
                                                  size: 28,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Change Photo',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _textMid,
                                                  ),
                                                ),
                                              ],
                                            );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ... rest of children (_row3 etc.)
                      _row3(
                        context,
                        FormTextField(
                          firstNameCtrl,
                          'First Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          midNameCtrl,
                          'Middle Name',
                          optional: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          lastNameCtrl,
                          'Last Name',
                          required: true,
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          emailCtrl,
                          'Email',
                          required: true,
                          fieldType: 'email',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          phoneCtrl,
                          'Phone',
                          required: true,
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        // ── DOB age >= 18 ──────────────────────────────────────
                        FormDateField(
                          dobCtrl,
                          'Date of Birth',
                          padding: EdgeInsets.zero,
                          lastDate: DateTime.now().subtract(
                            const Duration(days: 365 * 18),
                          ),
                          validator: validateDob,
                        ),
                        FormDropdownString(
                          'Gender',
                          gender,
                          ['Male', 'Female', 'Other'],
                          (v) => setState(() => gender = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          fatherCtrl,
                          'Father Name',
                          fieldType: 'name',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          emergencyCtrl,
                          'Emergency Contact',
                          fieldType: 'phone',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        emergencyRelationCtrl,
                        'Emergency Contact Relation',
                        padding: EdgeInsets.zero,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return null;
                          } // optional on edit
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Employment Information',
                    color: _purple,
                    bgColor: const Color(0xFFF5F3FF),
                    children: [
                      _row2(
                        context,
                        FormDropdownMap(
                          'Department',
                          departments,
                          selectedDeptId,
                          (v) => setState(() => selectedDeptId = v),
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownMap(
                          'Role',
                          roles,
                          selectedRoleId,
                          (v) => setState(() => selectedRoleId = v),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),

                      SizedBox(height: sp),
                      // ── DOJ optional on edit but validated if filled ──────────
                      FormDateField(
                        dojCtrl,
                        'Date of Joining',
                        padding: EdgeInsets.zero,
                        lastDate: DateTime.now(),
                        validator: validateDojOptional,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormDropdownString(
                          'Employment Type',
                          employmentType,
                          ['Permanent', 'Contract', 'Intern'],
                          (v) => setState(() => employmentType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        FormDropdownString(
                          'Work Type',
                          workType,
                          ['Full Time', 'Part Time'],
                          (v) => setState(() => workType = v!),
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        permAddrCtrl,
                        'Permanent Address',
                        required: true,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      CopyAddressRow(
                        sourceController: permAddrCtrl,
                        targetController: commAddrCtrl,
                        useIconButton: false,
                      ),
                      SizedBox(height: sp),
                      // ── YOE 0–50 on edit ──────────────────────────────────────
                      FormTextField(
                        yearsExpCtrl,
                        'Years of Experience',
                        fieldType: 'yoe',
                        padding: EdgeInsets.zero,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return null;
                          } // optional on edit
                          final n = int.tryParse(v.trim());
                          if (n == null) return 'Must be a whole number';
                          if (n < 0) return 'Cannot be negative';
                          if (n > 50) return 'Maximum 50 years';
                          return null;
                        },
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.description_outlined,
                    title: 'Documents & Statutory',
                    color: _red,
                    bgColor: const Color(0xFFFFF1F2),
                    children: [
                      _row2(
                        context,
                        FormTextField(
                          aadharCtrl,
                          'Aadhar Number',
                          required: true,
                          fieldType: 'aadhar',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          panCtrl,
                          'PAN Number',
                          required: true,
                          fieldType: 'pan',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      _row2(
                        context,
                        FormTextField(
                          passportCtrl,
                          'Passport Number',
                          fieldType: 'passport',
                          padding: EdgeInsets.zero,
                        ),
                        FormTextField(
                          pfCtrl,
                          'PF Number',
                          padding: EdgeInsets.zero,
                        ),
                        sp: sp,
                      ),
                      SizedBox(height: sp),
                      FormTextField(
                        esicCtrl,
                        'ESIC Number',
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.toggle_on_outlined,
                    title: 'Status & Dates',
                    color: _accent,
                    bgColor: const Color(0xFFECFDF5),
                    children: [
                      FormDropdownString(
                        'Status',
                        status,
                        ['Active', 'Inactive', 'Relieved'],
                        (v) => setState(() => status = v!),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      // ── DOR: required if Relieved, must be after DOJ ──────────
                      FormDateField(
                        dorCtrl,
                        'Date of Relieving (if applicable)',
                        required: false,
                        padding: EdgeInsets.zero,
                        lastDate: DateTime.now(),
                        validator: (val) =>
                            validateDor(val, status, dojCtrl.text),
                      ),
                    ],
                  ),

                  SizedBox(height: s.sectionSpacing),
                  _loadingEdu
                      ? Container(
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading education details…',
                                style: TextStyle(color: _textMid, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : EducationFormSection(
                          key: _eduKey,
                          initialEntries: _initialEdu,
                        ),

                  SizedBox(height: s.sectionSpacing),
                  _SectionCard(
                    icon: Icons.edit_note_rounded,
                    title: 'Reason for Edit',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),
                    children: [
                      TextFormField(
                        controller: editReasonCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13, color: _textDark),
                        decoration: _inputDec('').copyWith(
                          labelText: null,
                          hintText: 'Explain why this record is being updated…',
                          hintStyle: const TextStyle(
                            color: _textLight,
                            fontSize: 13,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Edit reason is required'
                            : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _submitting ? 'Submitting…' : 'Submit Edit Request',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _submitting ? null : _submitEdit,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDeptId == null) {
      _snack('Please select a department');
      return;
    }
    if (selectedRoleId == null) {
      _snack('Please select a role');
      return;
    }
    // ← ADD THIS
    if (!(_eduKey.currentState?.validate() ?? false)) {
      _snack('Please add at least one education record');
      return;
    }
    setState(() => _submitting = true);

    final body = {
      'request_type': 'UPDATE',
      'tenant_id': ApiConfig.tenantId, // ← ADD
      'updated_by': ApiConfig.employeeId, // ← ADD
      'emp_id': widget.employee.empId,
      'first_name': firstNameCtrl.text,
      'mid_name': midNameCtrl.text,
      'last_name': lastNameCtrl.text,
      'email_id': emailCtrl.text,
      'phone_number': phoneCtrl.text,
      'date_of_birth': dobCtrl.text,
      'gender': gender,
      'date_of_joining': dojCtrl.text,
      'date_of_relieving': dorCtrl.text,
      'employment_type': employmentType,
      'work_type': workType,
      'department_id': selectedDeptId,
      'role_id': selectedRoleId,
      'tl_id': selectedTlId,
      'permanent_address': permAddrCtrl.text,
      'communication_address': commAddrCtrl.text,
      'status': status,
      'edit_reason': editReasonCtrl.text,
      'father_name': fatherCtrl.text,
      'emergency_contact_relation': emergencyRelationCtrl.text,
      'emergency_contact': emergencyCtrl.text,
      'pf_number': pfCtrl.text,
      'esic_number': esicCtrl.text,
      'years_experience': int.tryParse(yearsExpCtrl.text),
      'education': _eduKey.currentState?.getEntries() ?? [],
      'aadhar_number': aadharCtrl.text,
      'pan_number': panCtrl.text,
      'passport_number': passportCtrl.text,
    };

    try {
      final res = await ApiClient.post('/pending-request', body);
      if (!mounted) return;

      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final requestId = data['request_id'];

        // ✅ UPLOAD PHOTO IF CHANGED
        if (_selectedPhotoBytes != null && requestId != null) {
          try {
            final photoReq = http.MultipartRequest(
              'POST',
              Uri.parse(
                '${ApiConfig.baseUrl}/pending-request/$requestId/photo',
              ),
            );
            photoReq.headers.addAll(ApiConfig.headers); // ← ADD THIS
            photoReq.files.add(
              http.MultipartFile.fromBytes(
                'photo',
                _selectedPhotoBytes!,
                filename: 'photo.jpg',
                contentType: MediaType('image', 'jpeg'),
              ),
            );
            final photoRes = await photoReq.send();

            if (photoRes.statusCode != 200) {
              print('Photo upload failed: ${photoRes.statusCode}');
            }
          } catch (photoErr) {
            print('Photo upload error: $photoErr');
          }
        }

        _snack(data['message'] ?? 'Edit request submitted!', ok: true);
        Navigator.pop(context, true);
      } else {
        _snack(data['message'] ?? 'Submission failed');
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: ok ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
