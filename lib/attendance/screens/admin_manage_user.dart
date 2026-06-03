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
  VoidCallback? onRefresh,
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

class ManageUserScreenState extends State<ManageUserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _showFab = true;

  // ── Master tab state ──────────────────────────────────────────────────────
  bool _masterLoading = true;
  String? _masterError;
  List<Employee> _masterEmployees = [];

  // ── Requests tab state ────────────────────────────────────────────────────
  bool _reqLoading = true;
  String? _reqError;
  List<Employee> _requestEmployees = []; // PENDING + REJECTED only

  // ── Shared filter state ───────────────────────────────────────────────────
  String searchText = '';
  String selectedDepartment = 'All';
  List<String> departmentList = ['All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // ── Hide FAB when on Requests tab ─────────────────────────────────────
    _tabController.addListener(() {
      if (!mounted) return;
      // Only act when animation is complete and index actually changed
      if (_tabController.indexIsChanging) return;
      setState(() => _showFab = _tabController.index == 0);
    });
    // Refresh data when tab animation settles
    _tabController.animation?.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        if (_tabController.index == 0) {
          _fetchMaster();
        } else {
          _fetchRequests();
        }
      }
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void refreshUsers() => _fetchAll();

  Future<void> _fetchAll() async {
    await Future.wait([_fetchMaster(), _fetchRequests()]);
  }

  // ── Fetch only APPROVED / ACTIVE employees from master ───────────────────
  Future<void> _fetchMaster() async {
    setState(() {
      _masterLoading = true;
      _masterError = null;
    });
    try {
      final results = await Future.wait([
        EmployeeService.fetchAllEmployees(),
        EmployeeService.fetchDepartments(),
      ]);
      if (!mounted) return;
      final masterList = results[0] as List<Employee>;
      final deptData = results[1] as List<Map<String, dynamic>>;
      setState(() {
        // Master tab shows ONLY master records — no pending overlay
        _masterEmployees = masterList;
        departmentList = ['All', ...deptData.map((d) => d['name'].toString())];
        _masterLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _masterError = e.toString();
        _masterLoading = false;
      });
    }
  }

  // ── Fetch PENDING + REJECTED from pending_request table only ─────────────
  Future<void> _fetchRequests() async {
    setState(() {
      _reqLoading = true;
      _reqError = null;
    });
    try {
      final pendingRes = await ApiClient.get('/pending-request?status=PENDING');
      final rejectedRes = await ApiClient.get(
        '/pending-request?status=REJECTED',
      );

      if (!mounted) return;

      final pendingJson = jsonDecode(pendingRes.body)['data'] as List? ?? [];
      final rejectedJson = jsonDecode(rejectedRes.body)['data'] as List? ?? [];

      setState(() {
        _requestEmployees = [
          ...pendingJson,
          ...rejectedJson,
        ].map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
        _reqLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reqError = e.toString();
        _reqLoading = false;
      });
    }
  }

  // ── Filtered lists ────────────────────────────────────────────────────────
  List<Employee> _filterList(List<Employee> source) {
    var list = source.where((e) {
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

  // ── Navigation helpers ────────────────────────────────────────────────────
  Future<void> _onMasterTap(Employee e) async {
    if (e.empId == 0 || e.empId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDetailPage(
          id: e.empId.toString(),
          source: 'MASTER',
          readOnly: false,
          userRoleId: widget.roleId,
        ),
      ),
    );
    if (mounted) _fetchMaster();
  }

  Future<void> _onRequestTap(Employee e) async {
    if (e.requestId == null) return;
    final isPending = e.adminApprove?.toUpperCase() == 'PENDING';
    final isRejected = e.adminApprove?.toUpperCase() == 'REJECTED';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDetailPage(
          id: e.requestId.toString(),
          source: 'REQUEST',
          readOnly: isPending, // PENDING → read-only, REJECTED → editable
          userRoleId: widget.roleId,
        ),
      ),
    );
    if (mounted) _fetchRequests();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          // ── Tab bar ──────────────────────────────────────────────────────
          // ── Tab bar ──────────────────────────────────────────────
          Container(
            color: _card,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: _primary,
                    unselectedLabelColor: _textMid,
                    indicatorColor: _primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_tabController.index == 0) _fetchMaster();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_rounded, size: 16),
                              const SizedBox(width: 5),
                              const Flexible(
                                child: Text(
                                  'Employees',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_masterEmployees.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                _tabCount(_masterEmployees.length, _primary),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_tabController.index == 1) _fetchRequests();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pending_actions_rounded,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              const Flexible(
                                child: Text(
                                  'Requests',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_requestEmployees.isNotEmpty) ...[
                                const SizedBox(width: 5),
                                _tabCount(_requestEmployees.length, _amber),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Refresh button ────────────────────────────────
                
              ],
            ),
          ),
          // ── Filter bar (shared) ──────────────────────────────────────────
          Container(
            color: _card,
            padding: EdgeInsets.fromLTRB(s.pagePadding, 10, s.pagePadding, 10),
            child: s.isMobile
                ? Column(
                    children: [
                      _searchField(),
                      const SizedBox(height: 8),
                      _deptFilter(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: _searchField()),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _deptFilter()),
                    ],
                  ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MasterTab(
                  loading: _masterLoading,
                  error: _masterError,
                  employees: _filterList(_masterEmployees),
                  screen: s,
                  onRefresh: _fetchMaster,
                  onTap: _onMasterTap,
                ),
                _RequestsTab(
                  loading: _reqLoading,
                  error: _reqError,
                  employees: _filterList(_requestEmployees),
                  screen: s,
                  onRefresh: _fetchRequests,
                  onTap: _onRequestTap,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.extended(
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
                _fetchAll();
              },
            )
          : null,
    );
  }

  Widget _tabCount(int n, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$n',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );

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
      labelText: 'By Department',
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
  int? selectedDeptId, selectedDesignationId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], designations = [], roles = [];
  int? selectedTlId;
  bool _submitting = false;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoPath; // used only on non-web for multipart upload
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    _loadReportingManagers();
  }

  // In AddEmployeePage / EditPage — when department changes, reload roles
  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
        designations = []; // empty until dept is selected
      });
    } catch (e) {
      debugPrint('_loadDropdowns error: $e');
    }
  }

  List<Map<String, dynamic>> _deptEmployees = [];
  List<String> _approverRoles = [];
  String? _selectedReportingRole;

  Future<void> _loadReportingManagers() async {
    final results = await Future.wait([
      EmployeeService.fetchLeaveApprovers(),
      EmployeeService.fetchLeaveApproverRoles(), // ← ADD
    ]);
    if (!mounted) return;
    setState(() {
      _deptEmployees = results[0] as List<Map<String, dynamic>>;
      _approverRoles = results[1] as List<String>; // ← ADD
    });
  }

  // DELETE the old getter entirely and replace with:
  List<String> get _reportingRoles => _approverRoles;
  List<Map<String, dynamic>> get _filteredApprovers {
    if (_selectedReportingRole == null) return _deptEmployees;
    return _deptEmployees
        .where((e) => e['role_name']?.toString() == _selectedReportingRole)
        .toList();
  }

  Widget _buildReportingToDropdowns(double sp) {
    if (_approverRoles.isEmpty) return const SizedBox.shrink();

    // Get filtered approvers by role
    final filtered = _filteredApprovers;

    // Split into same-dept and others based on selectedDeptId
    // _deptEmployees has department_id; look it up per emp
    List<Map<String, dynamic>> sameDept = [];
    List<Map<String, dynamic>> otherDept = [];

    for (final emp in filtered) {
      // department_id may be on emp directly or via dept lookup
      final empDeptId = emp['department_id'] != null
          ? int.tryParse(emp['department_id'].toString())
          : null;
      if (selectedDeptId != null && empDeptId == selectedDeptId) {
        sameDept.add(emp);
      } else {
        otherDept.add(emp);
      }
    }

    // Build dropdown items with group headers
    List<DropdownMenuItem<int>> items = [];

    if (sameDept.isNotEmpty) {
      items.add(_groupHeader('── Same Department ──'));
      items.addAll(sameDept.map((emp) => _approverItem(emp)));
    }

    if (otherDept.isNotEmpty) {
      items.add(_groupHeader('── Others ──'));
      items.addAll(otherDept.map((emp) => _approverItem(emp)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedReportingRole,
          isExpanded: true,
          decoration: _inputDec('Reporting To — Filter by Role'),
          hint: const Text(
            'All roles',
            style: TextStyle(color: _textLight, fontSize: 13),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All roles', overflow: TextOverflow.ellipsis),
            ),
            ..._reportingRoles.map(
              (r) => DropdownMenuItem<String>(
                value: r,
                child: Text(r, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            _selectedReportingRole = v;
            selectedTlId = null;
          }),
        ),
        SizedBox(height: sp),
        DropdownButtonFormField<int>(
          value: selectedTlId,
          isExpanded: true,
          decoration: _inputDec('Reporting To — Select Employee'),
          hint: const Text(
            'Select reporting manager',
            style: TextStyle(color: _textLight, fontSize: 13),
          ),
          items: items,
          onChanged: (v) {
            if (v != null) setState(() => selectedTlId = v);
          },
        ),
      ],
    );
  }

  DropdownMenuItem<int> _groupHeader(String label) {
    return DropdownMenuItem<int>(
      value: null,
      enabled: false,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textMid,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  DropdownMenuItem<int> _approverItem(Map<String, dynamic> emp) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final dept = emp['department_name']?.toString() ?? '';
    final id = emp['emp_id'] is int
        ? emp['emp_id'] as int
        : int.tryParse(emp['emp_id'].toString());
    return DropdownMenuItem<int>(
      value: id,
      child: Text(
        dept.isNotEmpty ? '$name ($dept)' : name,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedDesignationId = null;
      designations = [];
      selectedTlId = null;
      // ← do NOT clear _deptEmployees — managers list is global
    });
    if (deptId != null) {
      final list = await EmployeeService.fetchDesignations(deptId: deptId);
      if (mounted) setState(() => designations = list);
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
                      FormDropdownMap(
                        'Department',
                        departments,
                        selectedDeptId,
                        _onDeptChanged,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Designation',
                        designations,
                        selectedDesignationId,
                        (v) => setState(() => selectedDesignationId = v),
                        padding: EdgeInsets.zero,
                      ),

                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Role',
                        roles,
                        selectedRoleId,
                        (v) => setState(() => selectedRoleId = v),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      _buildReportingToDropdowns(sp),
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
    if (selectedDesignationId == null) {
      _snack('Please select a designation');
      return;
    }
    if (selectedRoleId == null) {
      _snack('Please select a role');
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
      'designation_id': selectedDesignationId,
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
  Map<String, dynamic>? employeeData; // pending / master data
  Map<String, dynamic>?
  masterData; // master "before" — only for UPDATE requests
  bool isLoading = true;
  Future<http.Response>? _photoFuture;

  // ── colours for the comparison view ──────────────────────────────────────
  static const Color _beforeBg = Color(0xFFF8FAFF);
  static const Color _afterBg = Color(0xFFFFF8F0);
  static const Color _beforeLabel = Color(0xFF1A56DB);
  static const Color _afterLabel = Color(0xFFF59E0B);
  static const Color _changedBg = Color(0xFFFFFBEB);
  static const Color _changedBorder = Color(0xFFFDE68A);

  bool get _isUpdateRequest =>
      widget.source == 'REQUEST' &&
      employeeData?['request_type']?.toString().toUpperCase() == 'UPDATE';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
    if (widget.source == 'MASTER') {
      _photoFuture = ApiClient.get('/employees/${widget.id}/photo');
    } else {
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

        // For MASTER → fetch education separately
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
          return;
        }

        // For REQUEST that is an UPDATE → also fetch master "before" data
        final reqType = emp['request_type']?.toString().toUpperCase();
        final empId = emp['emp_id'];
        if (reqType == 'UPDATE' && empId != null) {
          try {
            final masterRes = await ApiClient.get('/employees/$empId');
            if (masterRes.statusCode == 200 && mounted) {
              final md = jsonDecode(masterRes.body);
              final masterEmp = md is Map && md.containsKey('data')
                  ? md['data']
                  : md;
              // also fetch master education
              final er = await ApiClient.get('/employees/$empId/education');
              final masterEmpMap = Map<String, dynamic>.from(masterEmp);
              if (er.statusCode == 200) {
                masterEmpMap['education'] = jsonDecode(er.body)['data'];
              }
              if (mounted) setState(() => masterData = masterEmpMap);
            }
          } catch (_) {}
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _editReasonCard() {
    final reason = employeeData!['edit_reason']?.toString() ?? '';
    if (reason.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: _primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reason for Edit',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  List<Map<String, dynamic>> _eduListFrom(Map<String, dynamic>? data) {
    final raw = data?['education'];
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  bool get _isRejected =>
      widget.source == 'REQUEST' &&
      employeeData?['admin_approve'] == 'REJECTED';
  bool get _canEdit => !widget.readOnly;

  // ── helpers to detect changed fields ─────────────────────────────────────
  bool _changed(String key) {
    if (masterData == null) return false;
    final before = masterData![key]?.toString().trim() ?? '';
    final after = employeeData![key]?.toString().trim() ?? '';
    return before != after && after.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final s = _Screen(MediaQuery.of(context).size.width);
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(
        'Employee Profile',
        subtitle: 'View employee information',
        onRefresh: () {
          setState(() {
            isLoading = true;
            employeeData = null;
            masterData = null;
          });
          _fetchDetails();
          if (widget.source == 'MASTER') {
            _photoFuture = ApiClient.get('/employees/${widget.id}/photo');
          } else {
            _photoFuture = ApiClient.get('/pending-request/${widget.id}/photo');
          }
        },
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
                      if (result == true && mounted)
                        Navigator.pop(context, true);
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
                  if (result == true && mounted) Navigator.pop(context, true);
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

                        // ── Before/After legend for UPDATE requests ───────────
                        if (_isUpdateRequest && masterData != null)
                          _comparisonLegend(),

                        if (_isUpdateRequest && masterData != null)
                          SizedBox(height: s.sectionSpacing),

                        // ── Cards ─────────────────────────────────────────────
                        if (s.isMobile) ...[
                          _basicCard(s),
                          SizedBox(height: s.sectionSpacing),
                          _contactCard(s),
                          SizedBox(height: s.sectionSpacing),
                          _employmentCard(s),
                          SizedBox(height: s.sectionSpacing),
                          _documentsCard(s),
                          SizedBox(height: s.sectionSpacing),
                          _loginCard(),
                          SizedBox(height: s.sectionSpacing),
                          _educationCard(s),
                          if (_isRejected) ...[
                            SizedBox(height: s.sectionSpacing),
                            _rejectionCard(),
                          ],
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _basicCard(s)),
                              const SizedBox(width: 12),
                              Expanded(child: _contactCard(s)),
                            ],
                          ),
                          SizedBox(height: s.sectionSpacing),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _employmentCard(s)),
                              const SizedBox(width: 12),
                              Expanded(child: _documentsCard(s)),
                            ],
                          ),
                          SizedBox(height: s.sectionSpacing),
                          _loginCard(),
                          SizedBox(height: s.sectionSpacing),
                          _educationCard(s),
                          if (_isRejected) ...[
                            SizedBox(height: s.sectionSpacing),
                            _rejectionCard(),
                          ],
                          if (widget.source == 'REQUEST') ...[
                            SizedBox(height: s.sectionSpacing),
                            _editReasonCard(),
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

  // ── Legend ──────────────────────────────────────────────────────────────
  Widget _comparisonLegend() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.compare_arrows_rounded, size: 16, color: _textMid),
            SizedBox(width: 6),
            Text(
              'Changes:',
              style: TextStyle(
                fontSize: 12,
                color: _textMid,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        _legendDot(_beforeLabel, 'Before'),
        _legendDot(_afterLabel, 'After'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _changedBg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _changedBorder),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'Changed',
              style: TextStyle(fontSize: 11, color: _textMid),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
    ],
  );

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

    // For UPDATE requests, also show the original master name if it differs
    final masterFullName = masterData != null
        ? '${masterData!['first_name'] ?? ''} ${masterData!['mid_name'] ?? ''} ${masterData!['last_name'] ?? ''}'
              .trim()
        : null;
    final nameChanged =
        masterFullName != null &&
        masterFullName.isNotEmpty &&
        masterFullName != fullName;
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
                          if (nameChanged) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'was: $masterFullName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                              if (_isUpdateRequest)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _amber.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _amber.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Text(
                                    'UPDATE REQUEST',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
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

  // ── Comparison-aware detail card builder ─────────────────────────────────
  // WITH THIS:
  Widget _basicCard(_Screen s) {
    final masterFullName = masterData != null
        ? '${masterData!['first_name'] ?? ''} ${masterData!['mid_name'] ?? ''} ${masterData!['last_name'] ?? ''}'
              .trim()
        : null;
    final pendingFullName =
        '${employeeData!['first_name'] ?? ''} ${employeeData!['mid_name'] ?? ''} ${employeeData!['last_name'] ?? ''}'
            .trim();
    final nameChanged =
        masterFullName != null &&
        masterFullName.isNotEmpty &&
        masterFullName != pendingFullName;

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
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Basic Information',
                  style: TextStyle(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Full Name row — always shown, comparison-aware ────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + CHANGED badge
                      Row(
                        children: [
                          const Text(
                            'Full Name',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (nameChanged) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Text(
                                'CHANGED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _afterLabel,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (nameChanged) ...[
                        // Before
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _beforeLabel.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _beforeLabel.withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Text(
                                'Before',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _beforeLabel,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                masterFullName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: _textMid,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: _textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.only(left: 62),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: _amber.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 5),
                        // After
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _afterLabel.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _afterLabel.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'After',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _afterLabel,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pendingFullName.isEmpty ? '-' : pendingFullName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: _textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // No change — just show the name plainly
                        Text(
                          pendingFullName.isEmpty ? '-' : pendingFullName,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: pendingFullName.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: pendingFullName.isEmpty
                                ? _textLight
                                : _textDark,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: _border),
                // ── Remaining fields via normal comparison rows ───────────
                ...[
                  _CompField('Gender', 'gender', isDate: false),
                  _CompField('Date of Birth', 'date_of_birth', isDate: true),
                  _CompField('Father Name', 'father_name', isDate: false),
                ].map(
                  (f) => (_isUpdateRequest && masterData != null)
                      ? _comparisonRow(f)
                      : _simpleRow(f),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(_Screen s) => _buildDetailCard(
    icon: Icons.contact_mail_outlined,
    title: 'Contact Information',
    color: _purple,
    bgColor: const Color(0xFFF5F3FF),
    fields: [
      _CompField('Email', 'email_id', isDate: false),
      _CompField('Phone', 'phone_number', isDate: false),
      _CompField('Emergency Contact', 'emergency_contact', isDate: false),
      _CompField('Relation', 'emergency_contact_relation', isDate: false),
      _CompField(
        'Permanent Address',
        'permanent_address',
        isDate: false,
        maxLines: 3,
      ),
      _CompField(
        'Communication Address',
        'communication_address',
        isDate: false,
        maxLines: 3,
      ),
    ],
  );

  Widget _employmentCard(_Screen s) => _buildDetailCard(
    icon: Icons.work_outline_rounded,
    title: 'Employment Information',
    color: _amber,
    bgColor: const Color(0xFFFFFBEB),
    fields: [
      _CompField('Department', 'department_name', isDate: false),
      _CompField('Designation', 'role_name', isDate: false),
      _CompField('Date of Joining', 'date_of_joining', isDate: true),
      _CompField('Employment Type', 'employment_type', isDate: false),
      _CompField('Work Type', 'work_type', isDate: false),
      _CompField(
        'Experience',
        'years_experience',
        isDate: false,
        suffix: ' yrs',
      ),
    ],
    extraTiles:
        (employeeData!['date_of_relieving'] != null &&
            employeeData!['date_of_relieving'].toString().isNotEmpty)
        ? [_CompField('Date of Relieving', 'date_of_relieving', isDate: true)]
        : [],
  );

  Widget _documentsCard(_Screen s) => _buildDetailCard(
    icon: Icons.description_outlined,
    title: 'Documents & Statutory',
    color: _red,
    bgColor: const Color(0xFFFFF1F2),
    fields: [
      _CompField('Aadhar', 'aadhar_number', isDate: false, mask: true),
      _CompField('PAN', 'pan_number', isDate: false),
      _CompField('Passport', 'passport_number', isDate: false),
      _CompField('PF Number', 'pf_number', isDate: false),
      _CompField('ESIC Number', 'esic_number', isDate: false),
    ],
  );

  // ── Core card builder with before/after logic ─────────────────────────────
  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required Color color,
    required Color bgColor,
    required List<_CompField> fields,
    List<_CompField> extraTiles = const [],
  }) {
    final allFields = [...fields, ...extraTiles];
    final showComparison = _isUpdateRequest && masterData != null;

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
          // Header
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
            child: Column(
              children: allFields.map((f) {
                if (showComparison) {
                  return _comparisonRow(f);
                } else {
                  return _simpleRow(f);
                }
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Simple row (MASTER view or NEW request) ───────────────────────────────
  Widget _simpleRow(_CompField f) {
    String val = employeeData![f.key]?.toString() ?? '';
    if (f.isDate) val = _fmtDate(val.isEmpty ? null : val);
    if (f.mask && val.isNotEmpty) val = _maskAadhar(val);
    if (val.isEmpty) val = '-';
    if (f.suffix.isNotEmpty && val != '-') val = '$val${f.suffix}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              f.label,
              style: const TextStyle(
                fontSize: 12,
                color: _textMid,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              val,
              maxLines: f.maxLines,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: val == '-' ? FontWeight.w400 : FontWeight.w600,
                color: val == '-' ? _textLight : _textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Comparison row (UPDATE request — shows before & after) ───────────────
  Widget _comparisonRow(_CompField f) {
    String beforeVal = masterData![f.key]?.toString() ?? '';
    String afterVal = employeeData![f.key]?.toString() ?? '';

    if (f.isDate) {
      beforeVal = _fmtDate(beforeVal.isEmpty ? null : beforeVal);
      afterVal = _fmtDate(afterVal.isEmpty ? null : afterVal);
    }
    if (f.mask) {
      if (beforeVal.isNotEmpty) beforeVal = _maskAadhar(beforeVal);
      if (afterVal.isNotEmpty) afterVal = _maskAadhar(afterVal);
    }
    if (f.suffix.isNotEmpty) {
      if (beforeVal.isNotEmpty && beforeVal != '-')
        beforeVal = '$beforeVal${f.suffix}';
      if (afterVal.isNotEmpty && afterVal != '-')
        afterVal = '$afterVal${f.suffix}';
    }

    final hasChanged =
        beforeVal.trim() != afterVal.trim() &&
        afterVal.trim().isNotEmpty &&
        afterVal.trim() != '-';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: hasChanged
          ? BoxDecoration(
              color: _changedBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _changedBorder),
            )
          : null,
      padding: hasChanged ? const EdgeInsets.all(10) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field label + changed badge
          Row(
            children: [
              Text(
                f.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasChanged) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _amber.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'CHANGED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _afterLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Before row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _beforeLabel.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _beforeLabel.withValues(alpha: 0.2),
                  ),
                ),
                child: const Text(
                  'Before',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _beforeLabel,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  beforeVal.isEmpty ? '-' : beforeVal,
                  maxLines: f.maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: hasChanged ? _textMid : _textDark,
                    fontWeight: FontWeight.w500,
                    decoration: hasChanged ? TextDecoration.lineThrough : null,
                    decorationColor: _textLight,
                  ),
                ),
              ),
            ],
          ),
          if (hasChanged) ...[
            const SizedBox(height: 5),
            // Arrow
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Icon(
                Icons.arrow_downward_rounded,
                size: 14,
                color: _amber.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 5),
            // After row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _afterLabel.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _afterLabel.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'After',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _afterLabel,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    afterVal.isEmpty ? '-' : afterVal,
                    maxLines: f.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: _textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _educationCard(_Screen s) {
    final pendingEdu = _eduListFrom(employeeData);
    final masterEdu = _eduListFrom(masterData);
    final showComparison = _isUpdateRequest && masterData != null;

    // Check if any edu row actually has a change
    final hasChangedRows = pendingEdu.any((e) {
      final changed = e['is_changed'];
      return changed == 1 || changed == true || changed?.toString() == '1';
    });

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
          // ── Header ──────────────────────────────────────────────────────────
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
                if (pendingEdu.isNotEmpty)
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
                      '${pendingEdu.length} record${pendingEdu.length > 1 ? "s" : ""}',
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

          // ── Body ────────────────────────────────────────────────────────────
          if (!showComparison || !hasChangedRows)
            // Simple view: MASTER or NEW request, or no edu changes at all
            pendingEdu.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 36,
                            color: _textLight,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No education records found',
                            style: TextStyle(color: _textMid, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: pendingEdu
                          .map((e) => _EduDetailCard(entry: e))
                          .toList(),
                    ),
                  )
          else
            // Comparison view: per-row before/after based on action_type
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pendingEdu.map((pendingRow) {
                  final isChanged =
                      pendingRow['is_changed'] == 1 ||
                      pendingRow['is_changed'] == true ||
                      pendingRow['is_changed']?.toString() == '1';

                  if (!isChanged) {
                    // Unchanged — show normally
                    return _EduDetailCard(entry: pendingRow);
                  }

                  final actionType = (pendingRow['action_type'] ?? 'ADD')
                      .toString()
                      .toUpperCase();

                  if (actionType == 'ADD') {
                    return _EduComparisonCard(
                      actionType: 'ADD',
                      beforeEntry: null,
                      afterEntry: pendingRow,
                    );
                  } else if (actionType == 'DELETE') {
                    // Find the master row by original_edu_id
                    final origId = pendingRow['original_edu_id'];
                    final masterRow = masterEdu.firstWhere(
                      (m) => m['edu_id']?.toString() == origId?.toString(),
                      orElse: () => pendingRow,
                    );
                    return _EduComparisonCard(
                      actionType: 'DELETE',
                      beforeEntry: masterRow,
                      afterEntry: null,
                    );
                  } else {
                    // UPDATE
                    final origId = pendingRow['original_edu_id'];
                    final masterRow = masterEdu.firstWhere(
                      (m) => m['edu_id']?.toString() == origId?.toString(),
                      orElse: () => <String, dynamic>{},
                    );
                    return _EduComparisonCard(
                      actionType: 'UPDATE',
                      beforeEntry: masterRow.isEmpty ? null : masterRow,
                      afterEntry: pendingRow,
                    );
                  }
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eduSectionHeader(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

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
// Education comparison card (ADD / UPDATE / DELETE)
// ─────────────────────────────────────────────────────────────────────────────
class _EduComparisonCard extends StatelessWidget {
  final String actionType; // 'ADD', 'UPDATE', 'DELETE'
  final Map<String, dynamic>? beforeEntry;
  final Map<String, dynamic>? afterEntry;

  const _EduComparisonCard({
    required this.actionType,
    required this.beforeEntry,
    required this.afterEntry,
  });

  static const Color _beforeLabel = Color(0xFF1A56DB);
  static const Color _afterLabel = Color(0xFFF59E0B);
  static const Color _addBg = Color(0xFFECFDF5);
  static const Color _addBorder = Color(0xFF6EE7B7);
  static const Color _deleteBg = Color(0xFFFFF1F2);
  static const Color _deleteBorder = Color(0xFFFCA5A5);
  static const Color _changedBg = Color(0xFFFFFBEB);
  static const Color _changedBorder = Color(0xFFFDE68A);

  Color get _cardBg => switch (actionType) {
    'ADD' => _addBg,
    'DELETE' => _deleteBg,
    _ => _changedBg,
  };

  Color get _cardBorder => switch (actionType) {
    'ADD' => _addBorder,
    'DELETE' => _deleteBorder,
    _ => _changedBorder,
  };

  Color get _badgeColor => switch (actionType) {
    'ADD' => const Color(0xFF0E9F6E),
    'DELETE' => const Color(0xFFEF4444),
    _ => _afterLabel,
  };

  String get _badgeText => switch (actionType) {
    'ADD' => 'NEW',
    'DELETE' => 'DELETED',
    _ => 'CHANGED',
  };

  IconData get _badgeIcon => switch (actionType) {
    'ADD' => Icons.add_circle_outline_rounded,
    'DELETE' => Icons.remove_circle_outline_rounded,
    _ => Icons.edit_outlined,
  };

  Widget _sideLabel(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Action type badge ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _badgeColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_badgeIcon, size: 11, color: _badgeColor),
                const SizedBox(width: 4),
                Text(
                  _badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _badgeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── ADD: just show the new record ──────────────────────────────────
          if (actionType == 'ADD' && afterEntry != null) ...[
            _sideLabel('After', _afterLabel),
            const SizedBox(height: 6),
            _EduDetailCard(entry: afterEntry!),
          ]
          // ── DELETE: show old record dimmed ─────────────────────────────────
          else if (actionType == 'DELETE' && beforeEntry != null) ...[
            _sideLabel('Before', _beforeLabel),
            const SizedBox(height: 6),
            Opacity(opacity: 0.55, child: _EduDetailCard(entry: beforeEntry!)),
          ]
          // ── UPDATE: field-level diff — before then after ───────────────────
          else if (actionType == 'UPDATE') ...[
            if (beforeEntry != null) ...[
              _sideLabel('Before', _beforeLabel),
              const SizedBox(height: 6),
              _EduFieldDiff(
                before: beforeEntry!,
                after: afterEntry ?? {},
                showSide: 'before',
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 16,
                  color: _afterLabel.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (afterEntry != null) ...[
              _sideLabel('After', _afterLabel),
              const SizedBox(height: 6),
              _EduFieldDiff(
                before: beforeEntry ?? {},
                after: afterEntry!,
                showSide: 'after',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EduFieldDiff extends StatelessWidget {
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final String showSide; // 'before' or 'after'

  const _EduFieldDiff({
    required this.before,
    required this.after,
    required this.showSide,
  });

  static const Color _beforeLabel = Color(0xFF1A56DB);
  static const Color _afterLabel = Color(0xFFF59E0B);

  static const _fields = [
    ('Education Level', 'education_level'),
    ('Stream', 'stream'),
    ('Score', 'score'),
    ('Year of Passout', 'year_of_passout'),
    ('University', 'university'),
    ('College', 'college_name'),
  ];

  @override
  Widget build(BuildContext context) {
    final isBefore = showSide == 'before';
    final source = isBefore ? before : after;
    final color = isBefore ? _beforeLabel : _afterLabel;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: _fields.map((field) {
          final label = field.$1;
          final key = field.$2;
          final beforeVal = before[key]?.toString().trim() ?? '';
          final afterVal = after[key]?.toString().trim() ?? '';
          final hasChanged = beforeVal != afterVal;
          final val = source[key]?.toString().trim() ?? '';
          if (val.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: hasChanged ? color : _textMid,
                      fontWeight: hasChanged
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    val.isEmpty ? '-' : val,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasChanged ? _textDark : _textMid,
                      fontWeight: hasChanged
                          ? FontWeight.w700
                          : FontWeight.w400,
                      decoration: (isBefore && hasChanged)
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: _textLight,
                    ),
                  ),
                ),
                if (hasChanged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _afterLabel.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '✦',
                      style: TextStyle(fontSize: 9, color: _afterLabel),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CompField {
  final String label;
  final String key;
  final bool isDate;
  final bool mask;
  final int maxLines;
  final String suffix;
  const _CompField(
    this.label,
    this.key, {
    required this.isDate,
    this.mask = false,
    this.maxLines = 2,
    this.suffix = '',
  });
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
      dorCtrl, // ← NEW: Date of Relieving
      permAddrCtrl,
      commAddrCtrl,
      aadharCtrl,
      panCtrl,
      passportCtrl,
      pfCtrl,
      esicCtrl,
      usernameCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      yearsExpCtrl,
      resubmitReasonCtrl; // ← NEW: reason for resubmit

  String gender = 'Male',
      employmentType = 'Permanent',
      workType = 'Full Time',
      status = 'Active'; // ← NEW

  int? selectedDeptId, selectedDesignationId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], designations = [], roles = [];
  int? selectedTlId;
  bool _submitting = false;
  Uint8List? _selectedPhotoBytes;
  late Future<http.Response> _existingPhotoFuture; // ← show existing photo
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
    dorCtrl = TextEditingController(text: _fmtDate(d['date_of_relieving']));
    permAddrCtrl = TextEditingController(text: d['permanent_address'] ?? '');
    commAddrCtrl = TextEditingController(
      text: d['communication_address'] ?? '',
    );
    aadharCtrl = TextEditingController(text: d['aadhar_number'] ?? '');
    panCtrl = TextEditingController(text: d['pan_number'] ?? '');
    passportCtrl = TextEditingController(text: d['passport_number'] ?? '');
    pfCtrl = TextEditingController(text: d['pf_number'] ?? '');
    esicCtrl = TextEditingController(text: d['esic_number'] ?? '');
    usernameCtrl = TextEditingController(text: d['username'] ?? '');
    fatherCtrl = TextEditingController(text: d['father_name'] ?? '');
    emergencyRelationCtrl = TextEditingController(
      text: d['emergency_contact_relation'] ?? '',
    );
    emergencyCtrl = TextEditingController(text: d['emergency_contact'] ?? '');
    yearsExpCtrl = TextEditingController(
      text: d['years_experience']?.toString() ?? '',
    );
    resubmitReasonCtrl = TextEditingController();

    gender = d['gender'] ?? 'Male';
    employmentType = d['employment_type'] ?? 'Permanent';
    workType = d['work_type'] ?? 'Full Time';
    status = d['status'] ?? 'Active';

    selectedDeptId = d['department_id'] != null
        ? int.tryParse(d['department_id'].toString())
        : null;
    selectedDesignationId = d['designation_id'] != null
        ? int.tryParse(d['designation_id'].toString())
        : null;
    selectedRoleId = d['role_id'] != null
        ? int.tryParse(d['role_id'].toString())
        : null;

    if (d['education'] is List) {
      _initialEdu = (d['education'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Load existing photo from the pending request
    final requestId = d['request_id'];
    _existingPhotoFuture = requestId != null
        ? ApiClient.get('/pending-request/$requestId/photo')
        : Future.value(http.Response('', 404));

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

  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(),
        if (selectedDeptId != null)
          EmployeeService.fetchDesignations(deptId: selectedDeptId)
        else
          Future.value(<Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
        designations = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint('_loadDropdowns error: $e');
    }
  }

  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedDesignationId = null;
      designations = [];
    });
    if (deptId != null) {
      final list = await EmployeeService.fetchDesignations(deptId: deptId);
      if (mounted) setState(() => designations = list);
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
      aadharCtrl,
      panCtrl,
      passportCtrl,
      pfCtrl,
      esicCtrl,
      usernameCtrl,
      fatherCtrl,
      emergencyRelationCtrl,
      emergencyCtrl,
      yearsExpCtrl,
      resubmitReasonCtrl,
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
                  // ── Rejection reason banner ───────────────────────────────
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

                  // ── Personal Information ──────────────────────────────────
                  _SectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),
                    children: [
                      // ── Profile Photo ─────────────────────────────────────
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
                                                  'Add Photo',
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

                  // ── Employment Information ────────────────────────────────
                  _SectionCard(
                    icon: Icons.work_outline_rounded,
                    title: 'Employment Information',
                    color: _purple,
                    bgColor: const Color(0xFFF5F3FF),
                    children: [
                      FormDropdownMap(
                        'Department',
                        departments,
                        selectedDeptId,
                        _onDeptChanged,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Designation',
                        designations,
                        selectedDesignationId,
                        (v) => setState(() => selectedDesignationId = v),
                        padding: EdgeInsets.zero,
                      ),

                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Role',
                        roles,
                        selectedRoleId,
                        (v) => setState(() => selectedRoleId = v),
                        padding: EdgeInsets.zero,
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
                        useIconButton: false,
                      ),
                      SizedBox(height: sp),
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

                  // ── Documents & Statutory ─────────────────────────────────
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

                  if ((widget.requestData['request_type']
                              ?.toString()
                              .toUpperCase() ??
                          'NEW') ==
                      'UPDATE') ...[
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
                  ],

                  if ((widget.requestData['request_type']
                              ?.toString()
                              .toUpperCase() ??
                          'NEW') ==
                      'NEW') ...[
                    SizedBox(height: s.sectionSpacing),
                    _SectionCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Login Credentials',
                      color: _amber,
                      bgColor: const Color(0xFFFFFBEB),
                      children: [
                        FormTextField(
                          usernameCtrl,
                          'Username',
                          required: true,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: s.sectionSpacing),

                  // ── Education ─────────────────────────────────────────────
                  EducationFormSection(
                    key: _eduKey,
                    initialEntries: _initialEdu,
                  ),

                  SizedBox(height: s.sectionSpacing),

                  // ── Reason for Resubmit ───────────────────────────────────
                  _SectionCard(
                    icon: Icons.edit_note_rounded,
                    title: 'Reason for Resubmit',
                    color: _primary,
                    bgColor: const Color(0xFFEEF2FF),
                    children: [
                      TextFormField(
                        controller: resubmitReasonCtrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 13, color: _textDark),
                        decoration: _inputDec('').copyWith(
                          labelText: null,
                          hintText:
                              'Explain what you corrected in this resubmission…',
                          hintStyle: const TextStyle(
                            color: _textLight,
                            fontSize: 13,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please explain what was corrected'
                            : null,
                      ),
                    ],
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
    if (selectedDesignationId == null) {
      _snack('Please select a designation');
      return;
    }
    if (selectedRoleId == null) {
      _snack('Please select a role');
      return;
    }
    if (!(_eduKey.currentState?.validate() ?? false)) {
      _snack('Please add at least one education record');
      return;
    }

    setState(() => _submitting = true);

    final isNew =
        (widget.requestData['request_type']?.toString().toUpperCase() ??
            'NEW') ==
        'NEW';

    final body = {
      'tenant_id': ApiConfig.tenantId,
      'updated_by': ApiConfig.employeeId,
      'first_name': firstNameCtrl.text,
      'mid_name': midNameCtrl.text,
      'last_name': lastNameCtrl.text,
      'email_id': emailCtrl.text,
      'phone_number': phoneCtrl.text,
      'date_of_birth': dobCtrl.text,
      'gender': gender,
      'designation_id': selectedDesignationId,
      'role_id': selectedRoleId,
      'date_of_joining': dojCtrl.text,
      'employment_type': employmentType,
      'work_type': workType,
      'permanent_address': permAddrCtrl.text,
      'communication_address': commAddrCtrl.text,
      'aadhar_number': aadharCtrl.text,
      'pan_number': panCtrl.text,
      'passport_number': passportCtrl.text,
      'pf_number': pfCtrl.text,
      'esic_number': esicCtrl.text,
      'father_name': fatherCtrl.text,
      'emergency_contact_relation': emergencyRelationCtrl.text,
      'emergency_contact': emergencyCtrl.text,
      'years_experience': int.tryParse(yearsExpCtrl.text),
      'resubmit_reason': resubmitReasonCtrl.text,
      'education': _eduKey.currentState?.getEntries() ?? [],
      'tl_id': selectedTlId,
      if (isNew) 'username': usernameCtrl.text,
      if (!isNew) 'status': status,
      if (!isNew) 'date_of_relieving': dorCtrl.text,
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
          } catch (_) {}
        }
        _snack('Request resubmitted successfully!', ok: true);
        if (mounted) Navigator.pop(context, true);
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
  int? selectedDeptId, selectedDesignationId, selectedRoleId;
  List<Map<String, dynamic>> departments = [], designations = [], roles = [];
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
    selectedDesignationId = e.designationId;
    selectedRoleId = e.roleId;
    aadharCtrl = TextEditingController(text: e.aadharNumber ?? '');
    panCtrl = TextEditingController(text: e.panNumber ?? '');
    passportCtrl = TextEditingController(text: e.passportNumber ?? '');
    selectedTlId = e.reportingToEmployeeId;
    _existingPhotoFuture = ApiClient.get(
      '/employees/${widget.employee.empId}/photo',
    );
    _loadDropdowns();
    _loadExistingEducation();
    if (selectedDeptId != null) {
      _loadReportingManagers();
    }
  }

  // In AddEmployeePage / EditPage — when department changes, reload roles
  Future<void> _loadDropdowns() async {
    try {
      final results = await Future.wait([
        EmployeeService.fetchDepartments(),
        EmployeeService.fetchRoles(),
        if (selectedDeptId != null)
          EmployeeService.fetchDesignations(deptId: selectedDeptId)
        else
          EmployeeService.fetchDesignations(),
      ]);
      if (!mounted) return;
      setState(() {
        departments = results[0] as List<Map<String, dynamic>>;
        roles = results[1] as List<Map<String, dynamic>>;
        designations = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint('_loadDropdowns error: $e');
    }
  }

  // ── State variable (same name, different data source) ──
  List<Map<String, dynamic>> _deptEmployees = [];
  List<String> _approverRoles = [];
  String? _selectedReportingRole;

  // ── Load once at init — not per-dept ──
  Future<void> _loadReportingManagers() async {
    final results = await Future.wait([
      EmployeeService.fetchLeaveApprovers(),
      EmployeeService.fetchLeaveApproverRoles(),
    ]);
    if (!mounted) return;
    setState(() {
      _deptEmployees = results[0] as List<Map<String, dynamic>>;
      _approverRoles = results[1] as List<String>;
    });
  }

  List<String> get _reportingRoles => _approverRoles;

  List<Map<String, dynamic>> get _filteredApprovers {
    if (_selectedReportingRole == null) return _deptEmployees;
    return _deptEmployees
        .where((e) => e['role_name']?.toString() == _selectedReportingRole)
        .toList();
  }

  Widget _buildReportingToDropdowns(double sp) {
    if (_approverRoles.isEmpty) return const SizedBox.shrink();

    // Get filtered approvers by role
    final filtered = _filteredApprovers;

    // Split into same-dept and others based on selectedDeptId
    // _deptEmployees has department_id; look it up per emp
    List<Map<String, dynamic>> sameDept = [];
    List<Map<String, dynamic>> otherDept = [];

    for (final emp in filtered) {
      // department_id may be on emp directly or via dept lookup
      final empDeptId = emp['department_id'] != null
          ? int.tryParse(emp['department_id'].toString())
          : null;
      if (selectedDeptId != null && empDeptId == selectedDeptId) {
        sameDept.add(emp);
      } else {
        otherDept.add(emp);
      }
    }

    // Build dropdown items with group headers
    List<DropdownMenuItem<int>> items = [];

    if (sameDept.isNotEmpty) {
      items.add(_groupHeader('── Same Department ──'));
      items.addAll(sameDept.map((emp) => _approverItem(emp)));
    }

    if (otherDept.isNotEmpty) {
      items.add(_groupHeader('── Others ──'));
      items.addAll(otherDept.map((emp) => _approverItem(emp)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedReportingRole,
          isExpanded: true,
          decoration: _inputDec('Reporting To — Filter by Role'),
          hint: const Text(
            'All roles',
            style: TextStyle(color: _textLight, fontSize: 13),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All roles', overflow: TextOverflow.ellipsis),
            ),
            ..._reportingRoles.map(
              (r) => DropdownMenuItem<String>(
                value: r,
                child: Text(r, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            _selectedReportingRole = v;
            selectedTlId = null;
          }),
        ),
        SizedBox(height: sp),
        DropdownButtonFormField<int>(
          value: selectedTlId,
          isExpanded: true,
          decoration: _inputDec('Reporting To — Select Employee'),
          hint: const Text(
            'Select reporting manager',
            style: TextStyle(color: _textLight, fontSize: 13),
          ),
          items: items,
          onChanged: (v) {
            if (v != null) setState(() => selectedTlId = v);
          },
        ),
      ],
    );
  }

  DropdownMenuItem<int> _groupHeader(String label) {
    return DropdownMenuItem<int>(
      value: null,
      enabled: false,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textMid,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  DropdownMenuItem<int> _approverItem(Map<String, dynamic> emp) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final dept = emp['department_name']?.toString() ?? '';
    final id = emp['emp_id'] is int
        ? emp['emp_id'] as int
        : int.tryParse(emp['emp_id'].toString());
    return DropdownMenuItem<int>(
      value: id,
      child: Text(
        dept.isNotEmpty ? '$name ($dept)' : name,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _onDeptChanged(int? deptId) async {
    setState(() {
      selectedDeptId = deptId;
      selectedDesignationId = null;
      designations = [];
      selectedTlId = null;
      _selectedReportingRole = null;
      _deptEmployees = [];
    });
    if (deptId != null) {
      final list = await EmployeeService.fetchDesignations(deptId: deptId);
      if (mounted) setState(() => designations = list);
      _loadReportingManagers();
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
                'edu_id': e.eduId,
                'original_edu_id': e.eduId,
                'education_level': e.educationLevel ?? '',
                'stream': e.stream ?? '',
                'score': e.score ?? '',
                'year_of_passout': e.yearOfPassout ?? '',
                'university': e.university ?? '',
                'college_name': e.collegeName ?? '',
                'action_type': 'UPDATE',
                'is_changed': 0,
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
                      FormDropdownMap(
                        'Department',
                        departments,
                        selectedDeptId,
                        _onDeptChanged,
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Designation',
                        designations,
                        selectedDesignationId,
                        (v) => setState(() => selectedDesignationId = v),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      FormDropdownMap(
                        'Role',
                        roles,
                        selectedRoleId,
                        (v) => setState(() => selectedRoleId = v),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: sp),
                      _buildReportingToDropdowns(sp),
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
    if (selectedDesignationId == null) {
      _snack('Please select a designation');
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
      'designation_id': selectedDesignationId,
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
      'education': _eduKey.currentState?.getChangedEntries() ?? [],
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Master Employees  (no status badge at all)
// ─────────────────────────────────────────────────────────────────────────────
class _MasterTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Employee> employees;
  final _Screen screen;
  final Future<void> Function() onRefresh;
  final void Function(Employee) onTap;

  const _MasterTab({
    required this.loading,
    required this.error,
    required this.employees,
    required this.screen,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _loader();
    if (error != null) return _errorWidget(error!, onRefresh);
    if (employees.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          screen.pagePadding,
          16,
          screen.pagePadding,
          80,
        ),
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _MasterCard(
          employee: employees[i],
          screen: screen,
          onTap: () => onTap(employees[i]),
        ),
      ),
    );
  }

  Widget _emptyState() => ListView(
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — Pending / Rejected Requests
// ─────────────────────────────────────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Employee> employees;
  final _Screen screen;
  final Future<void> Function() onRefresh;
  final void Function(Employee) onTap;

  const _RequestsTab({
    required this.loading,
    required this.error,
    required this.employees,
    required this.screen,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _loader();
    if (error != null) return _errorWidget(error!, onRefresh);
    if (employees.isEmpty) return _emptyState();
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          screen.pagePadding,
          16,
          screen.pagePadding,
          80,
        ),
        itemCount: employees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _RequestCard(
          employee: employees[i],
          screen: screen,
          onTap: () => onTap(employees[i]),
        ),
      ),
    );
  }

  Widget _emptyState() => ListView(
    children: [
      const SizedBox(height: 120),
      Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pending_actions_rounded,
                size: 36,
                color: _amber,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending or rejected requests',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'All requests have been processed.',
              style: TextStyle(fontSize: 13, color: _textMid),
            ),
          ],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Master employee card  — NO status badge
// ─────────────────────────────────────────────────────────────────────────────
class _MasterCard extends StatefulWidget {
  final Employee employee;
  final _Screen screen;
  final VoidCallback onTap;

  const _MasterCard({
    required this.employee,
    required this.screen,
    required this.onTap,
  });

  @override
  State<_MasterCard> createState() => _MasterCardState();
}

class _MasterCardState extends State<_MasterCard> {
  late final Future<http.Response> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = widget.employee.empId != 0
        ? ApiClient.get('/employees/${widget.employee.empId}/photo')
        : Future.value(http.Response('', 404));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final s = widget.screen;
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
          padding: EdgeInsets.all(s.isMobile ? 12 : 14),
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
              // Avatar
              FutureBuilder<http.Response>(
                future: _photoFuture,
                builder: (context, snap) {
                  final hasPhoto =
                      snap.hasData &&
                      snap.data!.statusCode == 200 &&
                      snap.data!.bodyBytes.isNotEmpty;
                  return Container(
                    width: s.isMobile ? 42 : 46,
                    height: s.isMobile ? 42 : 46,
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
                                  fontSize: s.isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? '-' : fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: s.bodyFontSize,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.email ?? '-',
                      style: TextStyle(
                        fontSize: s.captionFontSize,
                        color: _textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.departmentName ?? '-',
                      style: TextStyle(
                        fontSize: s.captionFontSize - 1,
                        color: _textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request card  — WITH status badge (PENDING / REJECTED)
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final Employee employee;
  final _Screen screen;
  final VoidCallback onTap;

  const _RequestCard({
    required this.employee,
    required this.screen,
    required this.onTap,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late final Future<http.Response> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = widget.employee.requestId != null
        ? ApiClient.get('/pending-request/${widget.employee.requestId}/photo')
        : Future.value(http.Response('', 404));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.employee;
    final s = widget.screen;
    final fullName =
        '${e.firstName ?? ''} ${e.midName ?? ''} ${e.lastName ?? ''}'.trim();
    final initial = (e.firstName?.isNotEmpty == true ? e.firstName![0] : '?')
        .toUpperCase();

    final status = e.adminApprove?.toUpperCase() ?? '';
    final isPending = status == 'PENDING';
    final statusColor = isPending ? _amber : _red;

    // Request type label: NEW or UPDATE
    final reqType = e.requestType?.toUpperCase() ?? '';

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(s.isMobile ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            color: statusColor.withValues(alpha: 0.02),
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
              // Avatar
              FutureBuilder<http.Response>(
                future: _photoFuture,
                builder: (context, snap) {
                  final hasPhoto =
                      snap.hasData &&
                      snap.data!.statusCode == 200 &&
                      snap.data!.bodyBytes.isNotEmpty;
                  return Container(
                    width: s.isMobile ? 42 : 46,
                    height: s.isMobile ? 42 : 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPending
                            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                            : [
                                const Color(0xFFEF4444),
                                const Color(0xFFDC2626),
                              ],
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
                                  fontSize: s.isMobile ? 16 : 18,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? '-' : fullName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: s.bodyFontSize,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.email ?? '-',
                      style: TextStyle(
                        fontSize: s.captionFontSize,
                        color: _textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          e.departmentName ?? '-',
                          style: TextStyle(
                            fontSize: s.captionFontSize - 1,
                            color: _textLight,
                          ),
                        ),
                        if (reqType.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              reqType,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusBadge(status, statusColor),
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

  Widget _statusBadge(String status, Color color) => Container(
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
          status,
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
