import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_admin_provider.dart';
import '../widgets/admin_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Plan Management Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppAdminPlanManagementScreen extends StatefulWidget {
  const AppAdminPlanManagementScreen({super.key});

  @override
  State<AppAdminPlanManagementScreen> createState() =>
      _AppAdminPlanManagementScreenState();
}

class _AppAdminPlanManagementScreenState
    extends State<AppAdminPlanManagementScreen> {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  // ── Category colours ───────────────────────────────────────────────────────
  static const Map<String, Color> _categoryColor = {
    'core': Color(0xFF1A56DB),
    'advanced': Color(0xFF0E9F6E),
    'premium': Color(0xFF7C3AED),
  };

  static const Map<String, String> _categoryLabel = {
    'core': 'Core',
    'advanced': 'Advanced',
    'premium': 'Premium',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<AppAdminProvider>();
    await Future.wait([prov.loadPlans(), prov.loadSystemModules()]);
  }

  // ── Snack ──────────────────────────────────────────────────────────────────
  void _snack(String msg, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
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
        backgroundColor: success ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Delete confirm dialog
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(Plan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Plan?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete "${plan.planName}"?\n'
          'This cannot be undone.',
          style: const TextStyle(fontSize: 14, color: _textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<AppAdminProvider>().deletePlan(plan.planId);
      _snack('Plan "${plan.planName}" deleted');
    } catch (e) {
      _snack(e.toString(), success: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Toggle active/inactive
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _toggle(Plan plan) async {
    try {
      await context.read<AppAdminProvider>().togglePlan(plan.planId);
      _snack(plan.isActive ? 'Plan deactivated' : 'Plan activated');
    } catch (e) {
      _snack(e.toString(), success: false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Open create/edit bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openPlanForm({Plan? editPlan}) async {
    Plan? detailedPlan;
    if (editPlan != null) {
      try {
        detailedPlan = await context.read<AppAdminProvider>().getPlanDetail(
          editPlan.planId,
        );
      } catch (e) {
        _snack('Failed to load plan details', success: false);
        return;
      }
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanFormSheet(
        editPlan: detailedPlan,
        allModules: context.read<AppAdminProvider>().allModules,
      ),
    );

    if (result == true) {
      _snack(editPlan == null ? 'Plan created!' : 'Plan updated!');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Open plan detail sheet
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openDetail(Plan plan) async {
    Plan? detail;
    try {
      detail = await context.read<AppAdminProvider>().getPlanDetail(
        plan.planId,
      );
    } catch (e) {
      _snack('Failed to load details', success: false);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanDetailSheet(plan: detail!),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppAdminProvider>();

    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Stats header ───────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildStatsHeader(prov)),

            // ── List ───────────────────────────────────────────────────────
            if (prov.isLoading && prov.plans.isEmpty)
              const SliverFillRemaining(child: _LoadingState())
            else if (prov.error != null && prov.plans.isEmpty)
              SliverFillRemaining(child: _ErrorState(onRetry: _load))
            else if (prov.plans.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  32 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PlanCard(
                      plan: prov.plans[i],
                      categoryColor: _categoryColor,
                      categoryLabel: _categoryLabel,
                      onTap: () => _openDetail(prov.plans[i]),
                      onEdit: () => _openPlanForm(editPlan: prov.plans[i]),
                      onToggle: () => _toggle(prov.plans[i]),
                      onDelete: () => _confirmDelete(prov.plans[i]),
                    ),
                    childCount: prov.plans.length,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlanForm(),
        backgroundColor: _primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Stats header ────────────────────────────────────────────────────────────
  Widget _buildStatsHeader(AppAdminProvider prov) {
    final activePlans = prov.plans.where((p) => p.isActive).length;
    final totalCompanies = prov.plans.fold<int>(0, (s, p) => s + p.tenantCount);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _statChip(
            '${prov.plans.length}',
            'Total Plans',
            Icons.layers_rounded,
          ),
          const SizedBox(width: 12),
          _statChip('$activePlans', 'Active', Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _statChip('$totalCompanies', 'Companies', Icons.business_rounded),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Plan Card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Plan plan;
  final Map<String, Color> categoryColor;
  final Map<String, String> categoryLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);

  const _PlanCard({
    required this.plan,
    required this.categoryColor,
    required this.categoryLabel,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  String _fmtPrice(double p) {
    if (p == 0) return 'Free';
    return '₹${p.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = plan.isActive ? _accent : _textLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top accent bar ───────────────────────────────────────────
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.4)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  // ── Name row ─────────────────────────────────────────────
                  Row(
                    children: [
                      // Icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.layers_rounded,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  plan.planName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _textDark,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: plan.isActive
                                        ? _accent.withValues(alpha: 0.1)
                                        : _textLight.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    plan.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: plan.isActive
                                          ? _accent
                                          : _textLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              plan.planCode,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action menu
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') onEdit();
                          if (v == 'toggle') onToggle();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Plan'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  plan.isActive
                                      ? Icons.pause_circle_rounded
                                      : Icons.play_circle_rounded,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(plan.isActive ? 'Deactivate' : 'Activate'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: _red,
                                ),
                                const SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: _red)),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: _textLight,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Pricing + users strip ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _infoItem(
                          Icons.calendar_month_rounded,
                          _fmtPrice(plan.priceMonthly),
                          '/mo',
                          _accent,
                        ),
                        _divider(),
                        _infoItem(
                          Icons.calendar_today_rounded,
                          _fmtPrice(plan.priceYearly),
                          '/yr',
                          const Color(0xFF1A56DB),
                        ),
                        _divider(),
                        _infoItem(
                          Icons.people_rounded,
                          plan.maxUsers == 0 ? '∞' : '${plan.maxUsers}',
                          'users',
                          _orange,
                        ),
                        _divider(),
                        _infoItem(
                          Icons.business_rounded,
                          '${plan.tenantCount}',
                          'cos',
                          const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Module count pill ────────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.extension_rounded,
                        size: 14,
                        color: _textLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${plan.moduleCount} modules included',
                        style: const TextStyle(fontSize: 12, color: _textMid),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to view →',
                        style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String sub, Color color) =>
      Expanded(
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(sub, style: const TextStyle(fontSize: 9, color: _textLight)),
          ],
        ),
      );

  Widget _divider() => Container(
    width: 1,
    height: 32,
    color: _border,
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Plan Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlanDetailSheet extends StatelessWidget {
  final Plan plan;

  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _surface = Color(0xFFF0F4FF);

  static const Map<String, Color> _catColor = {
    'core': Color(0xFF1A56DB),
    'advanced': Color(0xFF0E9F6E),
    'premium': Color(0xFF7C3AED),
  };

  const _PlanDetailSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    // Group modules by category
    final Map<String, List<SystemModule>> grouped = {};
    for (final m in plan.modules) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => CustomScrollView(
          controller: ctrl,
          slivers: [
            // Handle
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.planName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                              ),
                              Text(
                                plan.planCode,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: plan.isActive
                                ? _accent.withValues(alpha: 0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            plan.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: plan.isActive ? _accent : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pricing row
                    Row(
                      children: [
                        _priceChip(
                          '₹${plan.priceMonthly.toStringAsFixed(0)}/mo',
                          const Color(0xFF1A56DB),
                        ),
                        const SizedBox(width: 8),
                        _priceChip(
                          '₹${plan.priceYearly.toStringAsFixed(0)}/yr',
                          const Color(0xFF0E9F6E),
                        ),
                        const SizedBox(width: 8),
                        _priceChip(
                          '${plan.maxUsers == 0 ? "∞" : plan.maxUsers} users',
                          const Color(0xFFF97316),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Text(
                      '${plan.tenantCount} company(s) on this plan · '
                      '${plan.includedModules.length} modules included',
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: Divider(color: Color(0xFFE2E8F0), height: 1),
            ),

            // Module sections
            for (final entry in grouped.entries)
              SliverToBoxAdapter(
                child: _ModuleSection(
                  category: entry.key,
                  modules: entry.value,
                  color: _catColor[entry.key] ?? const Color(0xFF1A56DB),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _priceChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _ModuleSection extends StatelessWidget {
  final String category;
  final List<SystemModule> modules;
  final Color color;

  static const Map<String, String> _labels = {
    'core': 'Core Modules',
    'advanced': 'Advanced Modules',
    'premium': 'Premium Modules',
  };

  const _ModuleSection({
    required this.category,
    required this.modules,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                _labels[category] ?? category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...modules.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    m.isIncluded
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: m.isIncluded ? color : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.moduleName,
                      style: TextStyle(
                        fontSize: 13,
                        color: m.isIncluded
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        fontWeight: m.isIncluded
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (!m.isIncluded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Not included',
                        style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Plan Form (Create / Edit) Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlanFormSheet extends StatefulWidget {
  final Plan? editPlan;
  final List<SystemModule> allModules;

  const _PlanFormSheet({this.editPlan, required this.allModules});

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const Map<String, Color> _catColor = {
    'core': Color(0xFF1A56DB),
    'advanced': Color(0xFF0E9F6E),
    'premium': Color(0xFF7C3AED),
  };
  static const Map<String, String> _catLabel = {
    'core': 'Core Modules',
    'advanced': 'Advanced Modules',
    'premium': 'Premium Modules',
  };
  static const Map<String, IconData> _catIcon = {
    'core': Icons.hub_rounded,
    'advanced': Icons.rocket_launch_rounded,
    'premium': Icons.diamond_rounded,
  };

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _maxUsersCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _yearlyCtrl = TextEditingController();

  final Set<String> _selectedModuleIds = {};
  bool _isSubmitting = false;
  bool get _isEdit => widget.editPlan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editPlan;
    if (p != null) {
      _nameCtrl.text = p.planName;
      _codeCtrl.text = p.planCode;
      _maxUsersCtrl.text = p.maxUsers.toString();
      _monthlyCtrl.text = p.priceMonthly.toStringAsFixed(0);
      _yearlyCtrl.text = p.priceYearly.toStringAsFixed(0);
      for (final m in p.modules) {
        if (m.isIncluded) _selectedModuleIds.add(m.moduleId);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _maxUsersCtrl.dispose();
    _monthlyCtrl.dispose();
    _yearlyCtrl.dispose();
    super.dispose();
  }

  Map<String, List<SystemModule>> get _grouped {
    final Map<String, List<SystemModule>> g = {};
    for (final m in widget.allModules) {
      g.putIfAbsent(m.category, () => []).add(m);
    }
    return g;
  }

  void _toggleModule(String id) => setState(
    () => _selectedModuleIds.contains(id)
        ? _selectedModuleIds.remove(id)
        : _selectedModuleIds.add(id),
  );

  void _toggleCategory(String cat, List<SystemModule> modules) {
    final ids = modules.map((m) => m.moduleId).toSet();
    final allSelected = ids.every(_selectedModuleIds.contains);
    setState(() {
      if (allSelected) {
        _selectedModuleIds.removeAll(ids);
      } else {
        _selectedModuleIds.addAll(ids);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final data = {
        'plan_name': _nameCtrl.text.trim(),
        'plan_code': _codeCtrl.text.trim().toUpperCase(),
        'max_users': int.tryParse(_maxUsersCtrl.text) ?? 50,
        'price_monthly': double.tryParse(_monthlyCtrl.text) ?? 0,
        'price_yearly': double.tryParse(_yearlyCtrl.text) ?? 0,
        'module_ids': _selectedModuleIds.toList(),
      };

      final prov = context.read<AppAdminProvider>();
      if (_isEdit) {
        await prov.updatePlan(widget.editPlan!.planId, data);
      } else {
        await prov.createPlan(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: CustomScrollView(
            controller: ctrl,
            slivers: [
              // Handle
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        _isEdit ? 'Edit Plan' : 'New Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Form fields ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan Name
                      _label('Plan Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDec(
                          'e.g. Starter, Growth, Enterprise',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Plan Code (disabled on edit)
                      _label('Plan Code'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeCtrl,
                        enabled: !_isEdit,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _inputDec('e.g. STARTER').copyWith(
                          suffixText: _isEdit ? 'Cannot change' : null,
                          suffixStyle: const TextStyle(
                            fontSize: 11,
                            color: _textMid,
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Pricing row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Monthly Price (₹)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _monthlyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDec('0'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Yearly Price (₹)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _yearlyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDec('0'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Max users
                      _label('Max Users (0 = Unlimited)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _maxUsersCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec('50'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (int.tryParse(v) == null)
                            return 'Must be a number';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Module selection ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Modules',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedModuleIds.length} selected',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              for (final entry in _grouped.entries)
                SliverToBoxAdapter(
                  child: _ModuleSelector(
                    category: entry.key,
                    modules: entry.value,
                    selectedIds: _selectedModuleIds,
                    color: _catColor[entry.key] ?? _primary,
                    label: _catLabel[entry.key] ?? entry.key,
                    icon: _catIcon[entry.key] ?? Icons.extension_rounded,
                    onToggleModule: _toggleModule,
                    onToggleAll: () => _toggleCategory(entry.key, entry.value),
                  ),
                ),

              // ── Submit button ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    32 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Save Changes' : 'Create Plan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _textDark,
    ),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textMid, fontSize: 13),
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _border.withValues(alpha: 0.5)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Module Selector Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ModuleSelector extends StatelessWidget {
  final String category;
  final List<SystemModule> modules;
  final Set<String> selectedIds;
  final Color color;
  final String label;
  final IconData icon;
  final void Function(String) onToggleModule;
  final VoidCallback onToggleAll;

  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _surface = Color(0xFFF0F4FF);

  const _ModuleSelector({
    required this.category,
    required this.modules,
    required this.selectedIds,
    required this.color,
    required this.label,
    required this.icon,
    required this.onToggleModule,
    required this.onToggleAll,
  });

  bool get _allSelected =>
      modules.every((m) => selectedIds.contains(m.moduleId));
  int get _selectedCount =>
      modules.where((m) => selectedIds.contains(m.moduleId)).length;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            // Category header
            InkWell(
              onTap: onToggleAll,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          Text(
                            '$_selectedCount / ${modules.length} selected',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Select All toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _allSelected
                            ? color.withValues(alpha: 0.1)
                            : _surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _allSelected
                              ? color.withValues(alpha: 0.3)
                              : _border,
                        ),
                      ),
                      child: Text(
                        _allSelected ? 'Deselect All' : 'Select All',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _allSelected ? color : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Module rows
            ...modules.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final isLast = i == modules.length - 1;
              final selected = selectedIds.contains(m.moduleId);

              return Column(
                children: [
                  InkWell(
                    onTap: () => onToggleModule(m.moduleId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: selected ? color : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.moduleName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: selected
                                        ? _textDark
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                if (m.description != null)
                                  Text(
                                    m.description!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      color: Color(0xFFE2E8F0),
                      indent: 46,
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  State helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Color(0xFF1A56DB)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: Color(0xFF1A56DB),
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No Plans Yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap + New Plan to create your first plan',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 48),
        const SizedBox(height: 16),
        const Text(
          'Failed to load plans',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1A56DB),
          ),
        ),
      ],
    ),
  );
}
