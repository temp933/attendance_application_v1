import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_admin_provider.dart';
import '../widgets/admin_widgets.dart';

class AppAdminCompanyDetailScreen extends StatefulWidget {
  final String tenantId;
  final String companyName;

  const AppAdminCompanyDetailScreen({
    super.key,
    required this.tenantId,
    required this.companyName,
  });

  @override
  State<AppAdminCompanyDetailScreen> createState() =>
      _AppAdminCompanyDetailScreenState();
}

class _AppAdminCompanyDetailScreenState
    extends State<AppAdminCompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _detail;
  List<dynamic> _tenantModules = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<AppAdminProvider>();
      final result = await provider.getTenantDetail(widget.tenantId);
      final modules = await provider.getTenantModules(widget.tenantId);
      setState(() {
        _detail = result['data'] ?? result;
        _tenantModules = modules;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.companyName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              'Company Details',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: _handleAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'change_plan',
                child: ListTile(
                  leading: Icon(Icons.layers_outlined),
                  title: Text('Change Plan'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'change_limit',
                child: ListTile(
                  leading: Icon(Icons.people_outline),
                  title: Text('Change User Limit'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'reset_password',
                child: ListTile(
                  leading: Icon(Icons.lock_reset_rounded),
                  title: Text('Reset Admin Password'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'suspend',
                child: ListTile(
                  leading: Icon(Icons.block_rounded, color: Colors.red),
                  title: Text(
                    'Suspend Company',
                    style: TextStyle(color: Colors.red),
                  ),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Modules'),
            Tab(text: 'Settings'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AdminColors.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdminErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                  AdminPrimaryButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(detail: _detail!),
                _ModulesTab(
                  tenantId: widget.tenantId,
                  modules: _tenantModules,
                  onChanged: _load,
                ),
                _SettingsTab(detail: _detail!),
                _LogsTab(tenantId: widget.tenantId),
              ],
            ),
    );
  }

  Future<void> _handleAction(String action) async {
    final provider = context.read<AppAdminProvider>();

    switch (action) {
      case 'change_plan':
        await _showChangePlanDialog(provider);
        break;
      case 'change_limit':
        await _showChangeUserLimitDialog(provider);
        break;
      case 'reset_password':
        await _showResetPasswordDialog(provider);
        break;
      case 'suspend':
        final confirm = await showAdminConfirm(
          context,
          title: 'Suspend Company',
          message:
              'Are you sure you want to suspend ${widget.companyName}? All users will lose access immediately.',
          confirmLabel: 'Suspend',
          confirmColor: AdminColors.danger,
        );
        if (confirm && mounted) {
          try {
            await provider.changeTenantStatus(
              widget.tenantId,
              'Suspended',
              'Suspended by App Admin',
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Company suspended'),
                  backgroundColor: AdminColors.danger,
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            _showError(e.toString());
          }
        }
        break;
    }
  }

  Future<void> _showChangePlanDialog(AppAdminProvider provider) async {
    await provider.loadPlans();
    if (!mounted) return;

    String? selectedPlanId = _detail?['plan_id'];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Plan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: StatefulBuilder(
          builder: (ctx, ss) => DropdownButtonFormField<String>(
            value: selectedPlanId,
            decoration: adminInput('Select Plan'),
            items: provider.plans
                .map<DropdownMenuItem<String>>(
                  (p) => DropdownMenuItem(
                    value: p['plan_id'].toString(),
                    child: Text(p['plan_name'] ?? ''),
                  ),
                )
                .toList(),
            onChanged: (v) => ss(() => selectedPlanId = v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (selectedPlanId != null) {
                try {
                  await provider.changeTenantPlan(
                    widget.tenantId,
                    selectedPlanId!,
                    null,
                  );
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Plan updated successfully'),
                        backgroundColor: AdminColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  _showError(e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeUserLimitDialog(AppAdminProvider provider) async {
    final ctrl = TextEditingController(text: '${_detail?['max_users'] ?? 50}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change User Limit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: adminInput(
            'Max Users (-1 = Unlimited)',
            icon: Icons.people_outline_rounded,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.changeTenantPlan(
                  widget.tenantId,
                  _detail?['plan_id'] ?? '',
                  int.tryParse(ctrl.text),
                );
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User limit updated'),
                      backgroundColor: AdminColors.success,
                    ),
                  );
                }
              } catch (e) {
                _showError(e.toString());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
            ),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetPasswordDialog(AppAdminProvider provider) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Admin Password',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set a new password for ${widget.companyName}\'s admin account.',
              style: const TextStyle(color: AdminColors.textMid),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              obscureText: true,
              decoration: adminInput(
                'New Password',
                icon: Icons.lock_outline_rounded,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (ctrl.text.length >= 6) {
                try {
                  await provider.resetTenantAdminPassword(
                    widget.tenantId,
                    ctrl.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset successfully'),
                        backgroundColor: AdminColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  _showError(e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.warning,
            ),
            child: const Text(
              'Reset Password',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AdminColors.danger),
    );
  }
}

// ─── OVERVIEW TAB ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> detail;
  const _OverviewTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final status = detail['status'] ?? '';
    final statusColor = AdminColors.statusColor(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status banner
          AdminCard(
            color: statusColor.withOpacity(0.06),
            child: Row(
              children: [
                Icon(
                  status == 'Active'
                      ? Icons.check_circle_rounded
                      : status == 'Trial'
                      ? Icons.timer_rounded
                      : Icons.block_rounded,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    if (detail['trial_ends_at'] != null && status == 'Trial')
                      Text(
                        'Trial ends: ${detail['trial_ends_at']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AdminColors.textMid,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info Card
          AdminCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Company Name',
                  value: detail['company_name'] ?? '',
                ),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(
                  label: 'Company Code',
                  value: detail['company_code'] ?? '',
                ),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(
                  label: 'Admin Email',
                  value: detail['admin_email'] ?? '',
                ),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(label: 'Admin Name', value: detail['admin_name'] ?? ''),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(label: 'Plan', value: detail['plan_name'] ?? ''),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(
                  label: 'Users',
                  value: detail['max_users'] == -1
                      ? '${detail['user_count'] ?? 0} (Unlimited)'
                      : '${detail['user_count'] ?? 0} / ${detail['max_users'] ?? 0}',
                ),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(label: 'Created', value: _fmt(detail['created_at'])),
                const Divider(height: 1, color: AdminColors.border),
                InfoRow(
                  label: 'Last Updated',
                  value: _fmt(detail['updated_at']),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }
}

// ─── MODULES TAB ──────────────────────────────────────────────────────────────
class _ModulesTab extends StatefulWidget {
  final String tenantId;
  final List<dynamic> modules;
  final VoidCallback onChanged;

  const _ModulesTab({
    required this.tenantId,
    required this.modules,
    required this.onChanged,
  });

  @override
  State<_ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends State<_ModulesTab> {
  Map<String, bool> _overrides = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final m in widget.modules) {
      final key = m['module_id'].toString();
      final override = m['override_enabled'];
      if (override != null) {
        _overrides[key] = override == 1 || override == true;
      }
    }
  }

  // Group modules by group
  Map<String, List<dynamic>> get _grouped {
    final map = <String, List<dynamic>>{};
    for (final m in widget.modules) {
      final g = (m['module_group'] ?? 'other').toString();
      map.putIfAbsent(g, () => []).add(m);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminCard(
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AdminColors.accent,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Toggle overrides to force enable/disable modules '
                    'regardless of the company\'s plan.',
                    style: TextStyle(fontSize: 12, color: AdminColors.textMid),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._grouped.entries.map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textMid,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                AdminCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: entry.value.asMap().entries.map((e) {
                      final i = e.key;
                      final m = e.value;
                      final moduleId = m['module_id'].toString();
                      final planIncluded =
                          m['plan_included'] == 1 || m['plan_included'] == true;
                      final hasOverride = _overrides.containsKey(moduleId);
                      final overrideValue =
                          _overrides[moduleId] ?? planIncluded;

                      return Column(
                        children: [
                          if (i > 0)
                            const Divider(height: 1, color: AdminColors.border),
                          ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: overrideValue
                                    ? AdminColors.success.withOpacity(0.1)
                                    : AdminColors.textLight.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.extension_outlined,
                                size: 16,
                                color: overrideValue
                                    ? AdminColors.success
                                    : AdminColors.textLight,
                              ),
                            ),
                            title: Text(
                              m['module_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textDark,
                              ),
                            ),
                            subtitle: Text(
                              hasOverride
                                  ? 'Override: ${overrideValue ? "Enabled" : "Disabled"}'
                                  : planIncluded
                                  ? 'Included in plan'
                                  : 'Not in plan',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasOverride
                                    ? AdminColors.warning
                                    : planIncluded
                                    ? AdminColors.success
                                    : AdminColors.textLight,
                              ),
                            ),
                            trailing: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Switch.adaptive(
                                    value: overrideValue,
                                    activeColor: AdminColors.success,
                                    onChanged: (val) =>
                                        _toggleModule(moduleId, val),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleModule(String moduleId, bool value) async {
    setState(() {
      _saving = true;
      _overrides[moduleId] = value;
    });
    try {
      await context.read<AppAdminProvider>().overrideModule(
        widget.tenantId,
        moduleId,
        value,
      );
    } catch (e) {
      // Revert
      setState(() => _overrides.remove(moduleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AdminColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── SETTINGS TAB ─────────────────────────────────────────────────────────────
class _SettingsTab extends StatelessWidget {
  final Map<String, dynamic> detail;
  const _SettingsTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final settings = (detail['settings'] as Map?) ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (settings.isEmpty)
            const AdminEmptyState(
              icon: Icons.settings_outlined,
              title: 'No Custom Settings',
              subtitle: 'Company is using default settings',
            )
          else
            AdminCard(
              child: Column(
                children: settings.entries
                    .map(
                      (e) => Column(
                        children: [
                          InfoRow(
                            label: e.key.replaceAll('_', ' '),
                            value: e.value.toString(),
                          ),
                          if (e.key != settings.keys.last)
                            const Divider(height: 1, color: AdminColors.border),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── LOGS TAB ─────────────────────────────────────────────────────────────────
class _LogsTab extends StatefulWidget {
  final String tenantId;
  const _LogsTab({required this.tenantId});

  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await context.read<AppAdminProvider>().loadLogs(
        tenantId: widget.tenantId,
      );
      // loadLogs stores in provider, but we also need to show here
      if (mounted) {
        setState(() {
          _logs = context.read<AppAdminProvider>().logs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AdminColors.primary),
      );
    }

    if (_logs.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Logs',
        subtitle: 'No activity recorded for this company',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (_, i) => _LogTile(data: _logs[i]),
    );
  }
}

class _LogTile extends StatelessWidget {
  final dynamic data;
  const _LogTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final action = (data['action'] ?? '').toString();
    final adminName = data['admin_name'] ?? 'Admin';
    final createdAt = data['created_at'] ?? '';

    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 16,
              color: AdminColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textDark,
                  ),
                ),
                Text(
                  'By $adminName',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AdminColors.textMid,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmt(createdAt),
            style: const TextStyle(fontSize: 11, color: AdminColors.textLight),
          ),
        ],
      ),
    );
  }

  String _fmt(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}
