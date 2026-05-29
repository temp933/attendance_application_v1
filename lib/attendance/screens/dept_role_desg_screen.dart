import 'package:flutter/material.dart';
import '../models/dept_role_desg_models.dart';
import '../services/dept_role_desg_service.dart';

// ─── Design Tokens (matching your existing panel) ────────────────────────────
const _primary = Color(0xFF1A56DB);
const _primaryLight = Color(0xFFEEF2FF);
const _surface = Color(0xFFF8FAFF);
const _card = Colors.white;
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF64748B);
const _textLight = Color(0xFF94A3B8);
const _success = Color(0xFF10B981);
const _successLight = Color(0xFFD1FAE5);
const _danger = Color(0xFFEF4444);
const _dangerLight = Color(0xFFFFE4E6);
const _border = Color(0xFFE2E8F0);
const _warning = Color(0xFFF59E0B);
const _warningLight = Color(0xFFFEF3C7);

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN — TabBar wrapper
// ═══════════════════════════════════════════════════════════════════════════════
class DeptRoleDesgScreen extends StatefulWidget {
  const DeptRoleDesgScreen({super.key});

  @override
  State<DeptRoleDesgScreen> createState() => _DeptRoleDesgScreenState();
}

class _DeptRoleDesgScreenState extends State<DeptRoleDesgScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      // ── App Bar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.manage_accounts_rounded,
                color: _primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Master Setup',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border, width: 1)),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: _primary,
              unselectedLabelColor: _textMid,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: _primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.apartment_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Departments'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Designations'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Roles'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // ── Tab Views ──────────────────────────────────────────────────────────
      body: TabBarView(
        controller: _tab,
        children: const [_DepartmentsTab(), _DesignationsTab(), _RolesTab()],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — DEPARTMENTS
// ═══════════════════════════════════════════════════════════════════════════════
class _DepartmentsTab extends StatefulWidget {
  const _DepartmentsTab();

  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = DepartmentService();
  late Future<List<DepartmentModel>> _future;
  String _search = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchAll();
  }

  // ✅ Assign future first, THEN call setState synchronously
  void _load() {
    final f = _svc.fetchAll();
    if (!mounted) return;
    setState(() {
      _future = f;
    }); // block body, explicitly returns void
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchAddBar(
          hint: 'Search departments...',
          onSearch: (v) => setState(() => _search = v),
          onAdd: _showFormDialog,
        ),
        Expanded(
          child: FutureBuilder<List<DepartmentModel>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingView();
              }
              if (snap.hasError) {
                return _ErrorView(
                  message: snap.error.toString().replaceAll('Exception: ', ''),
                  onRetry: _load,
                );
              }
              final list = (snap.data ?? [])
                  .where(
                    (d) => d.departmentName.toLowerCase().contains(
                      _search.toLowerCase(),
                    ),
                  )
                  .toList();

              if (list.isEmpty) {
                return _EmptyView(
                  message: _search.isEmpty
                      ? 'No departments yet.\nTap + Add to create one.'
                      : 'No results for "$_search"',
                  icon: Icons.apartment_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: list.length,
                itemBuilder: (_, i) => _DeptCard(
                  item: list[i],
                  onEdit: () => _showFormDialog(existing: list[i]),
                  onDelete: () => _confirmDelete(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  // FIND (the whole _showFormDialog method), REPLACE WITH:
  void _showFormDialog({DepartmentModel? existing}) {
    final nameCtrl = TextEditingController(
      text: existing?.departmentName ?? '',
    );
    String status = existing?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _AppDialog(
          title: existing == null ? 'Add Department' : 'Edit Department',
          icon: Icons.apartment_rounded,
          formKey: formKey,
          fields: [
            _AppTextField(
              ctrl: nameCtrl,
              label: 'Department Name',
              hint: 'e.g. Human Resources',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _StatusDropdown(
              value: status,
              onChanged: (v) => setLocal(() => status = v!),
            ),
          ],
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            if (existing == null) {
              await _svc.create(departmentName: nameCtrl.text, status: status);
            } else {
              await _svc.update(
                id: existing.id,
                departmentName: nameCtrl.text,
                status: status,
              );
            }
          },
        ),
      ),
    ).then((_) => _load()); // ✅ reload after dialog fully closes
  }

  void _confirmDelete(DepartmentModel item) {
    showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(
        name: item.departmentName,
        onConfirm: () async {
          await _svc.delete(item.id);
        },
      ),
    ).then((_) => _load()); // ✅ reload after dialog fully closes
  }
}

// ── Department Card ────────────────────────────────────────────────────────────
class _DeptCard extends StatelessWidget {
  final DepartmentModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeptCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _MasterCard(
      icon: Icons.apartment_rounded,
      code: '',
      name: item.departmentName,
      status: item.status,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — DESIGNATIONS
// ═══════════════════════════════════════════════════════════════════════════════
class _DesignationsTab extends StatefulWidget {
  const _DesignationsTab();

  @override
  State<_DesignationsTab> createState() => _DesignationsTabState();
}

class _DesignationsTabState extends State<_DesignationsTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = DesignationService();
  final _dSvc = DepartmentService();
  late Future<List<DesignationModel>> _future;
  List<DepartmentModel> _departments = [];
  String _search = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchAll();
    _loadDepartments();
  }

  // ✅ Assign future first, THEN call setState synchronously
  void _load() {
    final f = _svc.fetchAll();
    if (!mounted) return;
    setState(() {
      _future = f;
    }); // block body, explicitly returns void
  }

  Future<void> _loadDepartments() async {
    try {
      final list = await _dSvc.fetchAll();
      if (mounted) setState(() => _departments = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchAddBar(
          hint: 'Search designations...',
          onSearch: (v) => setState(() => _search = v),
          onAdd: _showFormDialog,
        ),
        Expanded(
          child: FutureBuilder<List<DesignationModel>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingView();
              }
              if (snap.hasError) {
                return _ErrorView(
                  message: snap.error.toString().replaceAll('Exception: ', ''),
                  onRetry: _load,
                );
              }
              final list = (snap.data ?? [])
                  .where(
                    (d) =>
                        d.designationName.toLowerCase().contains(
                          _search.toLowerCase(),
                        ) ||
                        d.departmentName.toLowerCase().contains(
                          _search.toLowerCase(),
                        ),
                  )
                  .toList();

              if (list.isEmpty) {
                return _EmptyView(
                  message: _search.isEmpty
                      ? 'No designations yet.\nTap + Add to create one.'
                      : 'No results for "$_search"',
                  icon: Icons.badge_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: list.length,
                itemBuilder: (_, i) => _DesgCard(
                  item: list[i],
                  onEdit: () => _showFormDialog(existing: list[i]),
                  onDelete: () => _confirmDelete(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // FIND (whole method), REPLACE WITH:
  void _showFormDialog({DesignationModel? existing}) {
    final nameCtrl = TextEditingController(
      text: existing?.designationName ?? '',
    );
    String status = existing?.status ?? 'Active';
    int? selectedDeptId = existing?.departmentId;
    final formKey = GlobalKey<FormState>();

    showDialog<bool>(
      // ← add <bool>
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _AppDialog(
          title: existing == null ? 'Add Designation' : 'Edit Designation',
          icon: Icons.badge_outlined,
          formKey: formKey,
          fields: [
            _AppTextField(
              ctrl: nameCtrl,
              label: 'Designation Name',
              hint: 'e.g. Manager',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textMid,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: selectedDeptId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                    filled: true,
                    fillColor: _surface,
                  ),
                  hint: const Text(
                    'Select department',
                    style: TextStyle(color: _textLight, fontSize: 13),
                  ),
                  items: _departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            d.departmentName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedDeptId = v),
                  validator: (_) =>
                      selectedDeptId == null ? 'Department is required' : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StatusDropdown(
              value: status,
              onChanged: (v) => setLocal(() => status = v!),
            ),
          ],
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            if (existing == null) {
              await _svc.create(
                designationName: nameCtrl.text,
                departmentId: selectedDeptId!,
                status: status,
              );
            } else {
              await _svc.update(
                id: existing.id,
                designationName: nameCtrl.text,
                departmentId: selectedDeptId!,
                status: status,
              );
            }
            // ❌ removed _load() from here
          },
        ),
      ),
    ).then((_) => _load()); // ✅ reload after dialog closes
  }

  void _confirmDelete(DesignationModel item) {
    showDialog<bool>(
      // ← add <bool>
      context: context,
      builder: (_) => _DeleteDialog(
        name: item.designationName,
        onConfirm: () async {
          await _svc.delete(item.id);
          // ❌ removed _load() from here
        },
      ),
    ).then((_) => _load()); // ✅ reload after dialog closes
  }
}

// ── Designation Card ───────────────────────────────────────────────────────────
class _DesgCard extends StatelessWidget {
  final DesignationModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DesgCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _MasterCard(
      icon: Icons.badge_outlined,
      code: '',
      name: item.designationName,
      status: item.status,
      subtitle: item.departmentName,
      subtitleIcon: Icons.apartment_rounded,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — ROLES
// ═══════════════════════════════════════════════════════════════════════════════
class _RolesTab extends StatefulWidget {
  const _RolesTab();

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab>
    with AutomaticKeepAliveClientMixin {
  final _svc = RoleService();
  late Future<List<RoleModel>> _future;
  String _search = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _svc.fetchAll(); // ✅ direct assign, no setState
  }

  // ✅ Assign future first, THEN call setState synchronously
  void _load() {
    final f = _svc.fetchAll();
    if (!mounted) return;
    setState(() {
      _future = f;
    }); // block body, explicitly returns void
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _SearchAddBar(
          hint: 'Search roles...',
          onSearch: (v) => setState(() => _search = v),
          onAdd: _showFormDialog,
        ),
        Expanded(
          child: FutureBuilder<List<RoleModel>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingView();
              }
              if (snap.hasError) {
                return _ErrorView(
                  message: snap.error.toString().replaceAll('Exception: ', ''),
                  onRetry: _load,
                );
              }
              final list = (snap.data ?? [])
                  .where(
                    (r) => r.roleName.toLowerCase().contains(
                      _search.toLowerCase(),
                    ),
                  )
                  .toList();

              if (list.isEmpty) {
                return _EmptyView(
                  message: _search.isEmpty
                      ? 'No roles yet.\nTap + Add to create one.'
                      : 'No results for "$_search"',
                  icon: Icons.shield_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: list.length,
                itemBuilder: (_, i) => _RoleCard(
                  item: list[i],
                  onEdit: () => _showFormDialog(existing: list[i]),
                  onDelete: () => _confirmDelete(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // FIND (whole method), REPLACE WITH:
  void _showFormDialog({RoleModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.roleName ?? '');
    String status = existing?.status ?? 'Active';
    final formKey = GlobalKey<FormState>();

    showDialog<bool>(
      // ← add <bool>
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => _AppDialog(
          title: existing == null ? 'Add Role' : 'Edit Role',
          icon: Icons.shield_outlined,
          formKey: formKey,
          fields: [
            _AppTextField(
              ctrl: nameCtrl,
              label: 'Role Name',
              hint: 'e.g. Administrator',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _StatusDropdown(
              value: status,
              onChanged: (v) => setLocal(() => status = v!),
            ),
          ],
          onConfirm: () async {
            if (!formKey.currentState!.validate()) return;
            if (existing == null) {
              await _svc.create(roleName: nameCtrl.text, status: status);
            } else {
              await _svc.update(
                id: existing.id,
                roleName: nameCtrl.text,
                status: status,
              );
            }
            // ❌ no _load() here
          },
        ),
      ),
    ).then((_) => _load()); // ✅ here
  }

  void _confirmDelete(RoleModel item) {
    showDialog<bool>(
      // ← add <bool>
      context: context,
      builder: (_) => _DeleteDialog(
        name: item.roleName,
        onConfirm: () async {
          await _svc.delete(item.id);
          // ❌ no _load() here
        },
      ),
    ).then((_) => _load()); // ✅ here
  }
}

// ── Role Card ──────────────────────────────────────────────────────────────────
class _RoleCard extends StatelessWidget {
  final RoleModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoleCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _MasterCard(
      icon: Icons.shield_outlined,
      code: '',
      name: item.roleName,
      status: item.status,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

// ── Master Card (used by all 3 tabs) ──────────────────────────────────────────
class _MasterCard extends StatelessWidget {
  final IconData icon;
  final String code;
  final String name;
  final String status;
  final String? subtitle;
  final IconData? subtitleIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MasterCard({
    required this.icon,
    required this.code,
    required this.name,
    required this.status,
    this.subtitle,
    this.subtitleIcon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Icon Box ────────────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive ? _primaryLight : _textLight.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isActive ? _primary : _textLight,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ── Name + Code + Subtitle ──────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Code chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      // Status badge
                      _StatusBadge(status: status),
                      // Subtitle (dept name for designations)
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          subtitleIcon ?? Icons.info_outline,
                          size: 12,
                          color: _textLight,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMid,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            _ActionButton(
              icon: Icons.edit_outlined,
              color: _textMid,
              tooltip: 'Edit',
              onTap: onEdit,
            ),
            const SizedBox(width: 2),
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              color: _danger,
              tooltip: 'Delete',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search + Add Bar ───────────────────────────────────────────────────────────
class _SearchAddBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;

  const _SearchAddBar({
    required this.hint,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      color: _card,
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                onChanged: onSearch,
                style: const TextStyle(fontSize: 13, color: _textDark),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _textLight,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Add button
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? _successLight : _warningLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive ? _success : _warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? _success : _warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Icon Button ─────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── App Dialog ─────────────────────────────────────────────────────────────────
class _AppDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final Future<void> Function() onConfirm;

  const _AppDialog({
    required this.title,
    required this.icon,
    required this.formKey,
    required this.fields,
    required this.onConfirm,
  });

  @override
  State<_AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<_AppDialog> {
  bool _loading = false;

  Future<void> _submit() async {
    if (!mounted) return;
    setState(() => _loading = true); // sync ✅

    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: _primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _textMid,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: _border, height: 1),
              const SizedBox(height: 20),

              // ── Form Fields ──────────────────────────────────────────────
              Form(
                key: widget.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.fields,
                ),
              ),
              const SizedBox(height: 24),

              // ── Actions ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMid,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delete Confirmation Dialog ─────────────────────────────────────────────────
class _DeleteDialog extends StatefulWidget {
  final String name;
  final Future<void> Function() onConfirm;

  const _DeleteDialog({required this.name, required this.onConfirm});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _loading = false;

  Future<void> _delete() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _dangerLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Record',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete\n"${widget.name}"?\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textMid,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _delete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text Field ─────────────────────────────────────────────────────────────────
class _AppTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final bool enabled;

  const _AppTextField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textMid,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          enabled: enabled,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: _textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textLight, fontSize: 13),
            filled: true,
            fillColor: enabled ? _surface : _border.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: const BorderSide(color: _danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _danger, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status Dropdown ────────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textMid,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
            filled: true,
            fillColor: _surface,
          ),
          items: const [
            DropdownMenuItem(value: 'Active', child: Text('Active')),
            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Loading View ───────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
    );
  }
}

// ── Empty View ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyView({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: _primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _textMid, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: _danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _textMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
