import 'dept_shared_widgets.dart';
import 'package:flutter/material.dart';
import '../services/department_service.dart';
import '../models/departmentmodel.dart';
import 'role_employees_screen.dart';

// reuse same tokens — or move to a shared theme file
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

// ─── Role Model ────────────────────────────────────────────────────────────────
class RoleModel {
  final int id;
  final String name;
  final String status;

  RoleModel({required this.id, required this.name, this.status = 'Active'});

  factory RoleModel.fromJson(Map<String, dynamic> j) => RoleModel(
    id: j['role_id'],
    name: j['role_name'],
    status: j['status'] ?? 'Active',
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE 2 — ROLES FOR A DEPARTMENT
// ═══════════════════════════════════════════════════════════════════════════════
class DeptRolesScreen extends StatefulWidget {
  final DepartmentModel dept;
  final DepartmentService svc;
  final String tenantId;

  const DeptRolesScreen({
    super.key,
    required this.dept,
    required this.svc,
    required this.tenantId,
  });

  @override
  State<DeptRolesScreen> createState() => _DeptRolesScreenState();
}

class _DeptRolesScreenState extends State<DeptRolesScreen> {
  List<RoleModel> _roles = [];
  bool _loading = true;
  String _error = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final raw = await widget.svc.fetchDeptRoles(widget.dept.id);
      if (mounted) {
        setState(() {
          _roles = raw.map((r) => RoleModel.fromJson(r)).toList();
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

  List<RoleModel> get _filtered => _roles
      .where((r) => r.name.toLowerCase().contains(_search.toLowerCase()))
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
          // Back button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: _textDark,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          // Dept icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.badge_outlined, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.dept.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                Text(
                  '${_roles.length} role${_roles.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _textMid),
                ),
              ],
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
                  hintText: 'Search roles...',
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
            label: 'Add Role',
            icon: Icons.add,
            onTap: () => _showAddRoleDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error.isNotEmpty) {
      return DeptErrorView(message: _error, onRetry: _loadRoles);
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return DeptEmptyView(
        message: _search.isEmpty
            ? 'No roles yet. Add your first role.'
            : 'No results for "$_search"',
        icon: Icons.badge_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _RoleCard(
        role: filtered[i],
        dept: widget.dept,
        svc: widget.svc,
        tenantId: widget.tenantId,
        onChanged: _loadRoles,
      ),
    );
  }

  void _showAddRoleDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => DeptAppDialog(
        title: 'Add Role',
        icon: Icons.badge_outlined,
        content: DeptAppTextField(ctrl: ctrl, label: 'Role Name'),
        confirmLabel: 'Add',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty) return;
          await widget.svc.addRole(widget.dept.id, ctrl.text.trim());
          _loadRoles();
        },
      ),
    );
  }
}

// ─── Role Card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final RoleModel role;
  final DepartmentModel dept;
  final DepartmentService svc;
  final String tenantId;
  final VoidCallback onChanged;

  const _RoleCard({
    required this.role,
    required this.dept,
    required this.svc,
    required this.tenantId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = role.status == 'Active';

    return GestureDetector(
      // ✅ Tap role → navigate to Page 3 (Employees)
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoleEmployeesScreen(
              dept: dept,
              role: role,
              svc: svc,
              tenantId: tenantId,
            ),
          ),
        );
      },
      child: Container(
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
              // Role icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isActive ? _primaryLight : _textLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.badge_outlined,
                  color: isActive ? _primary : _textLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),

              // Role name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    DeptStatusBadge(status: role.status),
                  ],
                ),
              ),

              // Toggle status
              IconButton(
                icon: Icon(
                  isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  color: isActive ? _success : _textLight,
                  size: 28,
                ),
                tooltip: isActive ? 'Deactivate' : 'Activate',
                onPressed: () {
                  final newStatus = isActive ? 'Inactive' : 'Active';
                  svc
                      .updateRoleStatus(dept.id, role.id, newStatus)
                      .then((_) => onChanged())
                      .catchError((_) {});
                },
              ),

              // Edit
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: _textMid,
                  size: 18,
                ),
                tooltip: 'Edit',
                onPressed: () => _showEditDialog(context),
              ),

              // Delete
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: _danger,
                  size: 18,
                ),
                tooltip: 'Delete',
                onPressed: () => _showDeleteDialog(context),
              ),

              const Icon(Icons.chevron_right, color: _textLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: role.name);
    showDialog(
      context: context,
      builder: (_) => DeptAppDialog(
        title: 'Edit Role',
        icon: Icons.edit_outlined,
        content: DeptAppTextField(ctrl: ctrl, label: 'Role Name'),
        confirmLabel: 'Save',
        onConfirm: () async {
          if (ctrl.text.trim().isEmpty || ctrl.text.trim() == role.name) return;
          await svc.updateRoleName(dept.id, role.id, ctrl.text.trim());
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
        title: const Text('Delete Role'),
        content: Text(
          'Delete "${role.name}"? Employees with this role must be reassigned first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              svc
                  .deleteRole(dept.id, role.id)
                  .then((_) => onChanged())
                  .catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                        backgroundColor: _danger,
                      ),
                    );
                  });
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
