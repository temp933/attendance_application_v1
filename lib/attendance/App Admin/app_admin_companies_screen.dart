import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_admin_provider.dart';
import '../widgets/admin_widgets.dart';
import 'app_admin_company_detail_screen.dart';
import 'app_admin_create_company_screen.dart';

class AppAdminCompaniesScreen extends StatefulWidget {
  const AppAdminCompaniesScreen({super.key});

  @override
  State<AppAdminCompaniesScreen> createState() =>
      _AppAdminCompaniesScreenState();
}

class _AppAdminCompaniesScreenState extends State<AppAdminCompaniesScreen> {
  final _searchCtrl = TextEditingController();
  String _filterStatus = 'All';
  String _filterPlan = 'All';
  List<dynamic> _filtered = [];

  final _statusOptions = ['All', 'Active', 'Trial', 'Suspended', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppAdminProvider>().loadTenants();
      await context.read<AppAdminProvider>().loadPlans();
      _applyFilter();
    });
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final provider = context.read<AppAdminProvider>();
    final q = _searchCtrl.text.toLowerCase();

    setState(() {
      _filtered = provider.tenants.where((t) {
        final name = (t['company_name'] ?? '').toString().toLowerCase();
        final code = (t['company_code'] ?? '').toString().toLowerCase();
        final status = (t['status'] ?? '').toString();
        final planCode = (t['plan_code'] ?? '').toString();

        final matchSearch = q.isEmpty || name.contains(q) || code.contains(q);
        final matchStatus = _filterStatus == 'All' || status == _filterStatus;
        final matchPlan = _filterPlan == 'All' || planCode == _filterPlan;

        return matchSearch && matchStatus && matchPlan;
      }).toList();
    });
  }

  List<String> _getPlanOptions(List<dynamic> plans) {
    final codes = ['All', ...plans.map((p) => p['plan_code'].toString())];
    return codes.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppAdminProvider>();

    // Update filtered when tenants change
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilter());

    return Scaffold(
      backgroundColor: AdminColors.bg,
      body: Column(
        children: [
          // ── Search + Filters ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  decoration:
                      adminInput(
                        'Search companies...',
                        icon: Icons.search_rounded,
                      ).copyWith(
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applyFilter();
                                },
                              )
                            : null,
                      ),
                ),
                const SizedBox(height: 10),

                // Filters
                Row(
                  children: [
                    Expanded(
                      child: _FilterChips(
                        options: _statusOptions,
                        selected: _filterStatus,
                        onSelected: (v) {
                          setState(() => _filterStatus = v);
                          _applyFilter();
                        },
                        colorMap: {
                          'Active': AdminColors.success,
                          'Trial': AdminColors.accent,
                          'Suspended': AdminColors.danger,
                          'Cancelled': AdminColors.textLight,
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Count bar ───────────────────────────────────────────────────
          Container(
            color: AdminColors.bg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} companies',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.textMid,
                  ),
                ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: provider.isLoading && provider.tenants.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AdminColors.primary,
                    ),
                  )
                : _filtered.isEmpty
                ? AdminEmptyState(
                    icon: Icons.business_outlined,
                    title: 'No companies found',
                    subtitle: _searchCtrl.text.isNotEmpty
                        ? 'Try a different search'
                        : 'Create your first company',
                    action: AdminPrimaryButton(
                      label: 'Create Company',
                      icon: Icons.add_rounded,
                      onPressed: () => _openCreate(),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await provider.loadTenants();
                      _applyFilter();
                    },
                    color: AdminColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _CompanyCard(data: _filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AdminColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Company',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _openCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppAdminCreateCompanyScreen()),
    ).then((_) {
      context.read<AppAdminProvider>().loadTenants();
    });
  }
}

// ─── FILTER CHIPS ─────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, Color>? colorMap;

  const _FilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.colorMap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isSelected = selected == o;
          final color = colorMap?[o] ?? AdminColors.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : AdminColors.border,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AdminColors.textMid,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── COMPANY CARD ─────────────────────────────────────────────────────────────
class _CompanyCard extends StatelessWidget {
  final dynamic data;
  const _CompanyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['company_name'] ?? '';
    final code = data['company_code'] ?? '';
    final status = data['status'] ?? '';
    final planName = data['plan_name'] ?? '';
    final planCode = data['plan_code'] ?? '';
    final userCount = data['user_count'] ?? 0;
    final maxUsers = data['max_users'] ?? 0;
    final adminEmail = data['admin_email'] ?? '';
    final trialEnds = data['trial_ends_at'];

    final statusColor = AdminColors.statusColor(status);
    final planColor = AdminColors.planColor(planCode);

    final userPct = maxUsers > 0
        ? (userCount / maxUsers).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final userFull = maxUsers > 0 && userCount >= maxUsers;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AdminCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppAdminCompanyDetailScreen(
                tenantId: data['tenant_id'],
                companyName: name,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ────────────────────────────────────────────────
            Row(
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.primary,
                      ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.textDark,
                        ),
                      ),
                      Text(
                        'Code: $code',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AdminColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(label: status, color: statusColor),
                    const SizedBox(height: 4),
                    PlanBadge(planCode: planCode, planName: planName),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AdminColors.border),
            const SizedBox(height: 10),

            // ── Bottom row ─────────────────────────────────────────────
            Row(
              children: [
                // Users
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color: userFull
                                ? AdminColors.danger
                                : AdminColors.textMid,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            maxUsers == -1
                                ? '$userCount users'
                                : '$userCount / $maxUsers users',
                            style: TextStyle(
                              fontSize: 11,
                              color: userFull
                                  ? AdminColors.danger
                                  : AdminColors.textMid,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (maxUsers > 0 && maxUsers != -1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: userPct,
                              backgroundColor: AdminColors.accent.withOpacity(
                                0.12,
                              ),
                              valueColor: AlwaysStoppedAnimation(
                                userFull
                                    ? AdminColors.danger
                                    : AdminColors.accent,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trial / Admin email
                if (status == 'Trial' && trialEnds != null)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: 'Ends ${_formatDate(trialEnds)}',
                    color: AdminColors.warning,
                  )
                else if (adminEmail.isNotEmpty)
                  Flexible(
                    child: Text(
                      adminEmail,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.textMid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AdminColors.textLight,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
