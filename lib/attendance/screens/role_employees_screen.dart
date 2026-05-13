import 'package:flutter/material.dart';
import '../services/department_service.dart';
import '../models/departmentmodel.dart';
import 'dept_roles_screen.dart' show RoleModel;
import 'dept_shared_widgets.dart';
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
// PAGE 3 — EMPLOYEES IN A ROLE
// ═══════════════════════════════════════════════════════════════════════════════
class RoleEmployeesScreen extends StatefulWidget {
  final DepartmentModel dept;
  final RoleModel role;
  final DepartmentService svc;
  final String tenantId;

  const RoleEmployeesScreen({
    super.key,
    required this.dept,
    required this.role,
    required this.svc,
    required this.tenantId,
  });

  @override
  State<RoleEmployeesScreen> createState() => _RoleEmployeesScreenState();
}

class _RoleEmployeesScreenState extends State<RoleEmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String _error = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      // Fetch all employees in this dept, then filter by role_id client-side
      // OR if you have a /roles/:roleId/employees endpoint, use that instead
      final all = await widget.svc.fetchDeptEmployees(widget.dept.id);
      if (mounted) {
        setState(() {
          _employees = all
              .where((e) => e['role_id'] == widget.role.id)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered => _employees
      .where(
        (e) =>
            '${e['first_name']} ${e['last_name']}'.toLowerCase().contains(
              _search.toLowerCase(),
            ) ||
            '${e['email_id']}'.toLowerCase().contains(_search.toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(context),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(8, 16, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: _textDark,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_outline, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.role.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                Text(
                  widget.dept.name,
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
            ),
          ),
          // Employee count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_employees.length} employee${_employees.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: _card,
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
            hintText: 'Search employees...',
            hintStyle: TextStyle(color: _textLight, fontSize: 13),
            prefixIcon: Icon(Icons.search, size: 18, color: _textLight),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error.isNotEmpty) {
      return DeptErrorView(message: _error, onRetry: _loadEmployees);
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return DeptEmptyView(
        message: _search.isEmpty
            ? 'No employees with this role yet'
            : 'No results for "$_search"',
        icon: Icons.people_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _EmployeeCard(emp: filtered[i]),
    );
  }
}

// ─── Employee Card ─────────────────────────────────────────────────────────────
class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  const _EmployeeCard({required this.emp});

  @override
  Widget build(BuildContext context) {
    final name = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    final email = emp['email_id'] ?? '';
    final status = emp['status'] ?? 'Active';
    final isActive = status == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar circle with initials
            CircleAvatar(
              radius: 20,
              backgroundColor: _primaryLight,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 11, color: _textMid),
                  ),
                ],
              ),
            ),

            DeptStatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}
