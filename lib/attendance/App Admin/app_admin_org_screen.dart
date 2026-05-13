import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/api_config.dart';

const String baseUrl = ApiConfig.baseUrl;
// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class OrgStats {
  final int totalOrgs;
  final int activeOrgs;
  final int trialOrgs;
  final int suspendedOrgs;
  final int expiredOrgs;
  final int totalEmployees;

  OrgStats({
    required this.totalOrgs,
    required this.activeOrgs,
    required this.trialOrgs,
    required this.suspendedOrgs,
    required this.expiredOrgs,
    required this.totalEmployees,
  });

  factory OrgStats.fromJson(Map<String, dynamic> j) => OrgStats(
    totalOrgs: _i(j['total_orgs']),
    activeOrgs: _i(j['active_orgs']),
    trialOrgs: _i(j['trial_orgs']),
    suspendedOrgs: _i(j['suspended_orgs']),
    expiredOrgs: _i(j['expired_orgs']),
    totalEmployees: _i(j['total_employees']),
  );

  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
}

class Organization {
  final String tenantId;
  final String companyName;
  final String? companyCode;
  final String status;
  final int maxUsers;
  final String adminEmail;
  final String? hrEmail;
  final String? contactNumber;
  final String? contactPerson;
  final String? companyAddress;
  final String? domainName;
  final String? gstNumber;
  final String? timezone;
  final DateTime? trialEndsAt;
  final DateTime? planStartsAt;
  final DateTime? planEndsAt;
  final DateTime createdAt;
  final String? planName;
  final String? planCode;
  final double? priceMonthly;
  final double? priceYearly;
  final int employeeCount;
  final int activeEmployeeCount;
  final int daysRemaining;

  Organization({
    required this.tenantId,
    required this.companyName,
    this.companyCode,
    required this.status,
    required this.maxUsers,
    required this.adminEmail,
    this.hrEmail,
    this.contactNumber,
    this.contactPerson,
    this.companyAddress,
    this.domainName,
    this.gstNumber,
    this.timezone,
    this.trialEndsAt,
    this.planStartsAt,
    this.planEndsAt,
    required this.createdAt,
    this.planName,
    this.planCode,
    this.priceMonthly,
    this.priceYearly,
    required this.employeeCount,
    required this.activeEmployeeCount,
    required this.daysRemaining,
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
    tenantId: j['tenant_id'],
    companyName: j['company_name'],
    companyCode: j['company_code'],
    status: j['status'],
    maxUsers: _i(j['max_users']),
    adminEmail: j['admin_email'],
    hrEmail: j['hr_email'],
    contactNumber: j['contact_number'],
    contactPerson: j['contact_person'],
    companyAddress: j['company_address'],
    domainName: j['domain_name'],
    gstNumber: j['gst_number'],
    timezone: j['timezone'],
    trialEndsAt: _d(j['trial_ends_at']),
    planStartsAt: _d(j['plan_starts_at']),
    planEndsAt: _d(j['plan_ends_at']),
    createdAt: _d(j['created_at']) ?? DateTime.now(),
    planName: j['plan_name'],
    planCode: j['plan_code'],
    priceMonthly: double.tryParse(j['price_monthly']?.toString() ?? ''),
    priceYearly: double.tryParse(j['price_yearly']?.toString() ?? ''),
    employeeCount: _i(j['employee_count']),
    activeEmployeeCount: _i(j['active_employee_count']),
    daysRemaining: _i(j['days_remaining']),
  );

  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class OrgService {
  final String baseUrl;

  OrgService({required this.baseUrl,});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'usertype': 'app_admin',
  };

  Future<Map<String, dynamic>> fetchOrganizations({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status != 'all') 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse(
      '$baseUrl/app-admin/organizations',
    ).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    return jsonDecode(resp.body);
  }

  Future<Map<String, dynamic>> fetchOrganizationDetail(String tenantId) async {
    final uri = Uri.parse('$baseUrl/app-admin/organizations/$tenantId');
    final resp = await http.get(uri, headers: _headers);
    return jsonDecode(resp.body);
  }

  Future<bool> updateStatus(String tenantId, String status) async {
    final uri = Uri.parse(
      '$baseUrl/app-admin/organizations/$tenantId/status',
    );
    final resp = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    final data = jsonDecode(resp.body);
    return data['success'] == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppAdminOrgScreen extends StatefulWidget {

  const AppAdminOrgScreen({super.key,});

  @override
  State<AppAdminOrgScreen> createState() => _AppAdminOrgScreenState();
}

class _AppAdminOrgScreenState extends State<AppAdminOrgScreen> {
  late final OrgService _service;

  bool _loading = true;
  String? _error;

  OrgStats? _stats;
  List<Organization> _orgs = [];

  String _selectedStatus = 'all';
  String _search = '';
  int _page = 1;
  int _totalPages = 1;

  final _searchCtrl = TextEditingController();
  final _debounce = ValueNotifier<String>('');

  final List<_StatusTab> _tabs = const [
    _StatusTab('all', 'All'),
    _StatusTab('active', 'Active'),
    _StatusTab('trial', 'Trial'),
    _StatusTab('suspended', 'Suspended'),
    _StatusTab('expired', 'Expired'),
  ];

  @override
  void initState() {
    super.initState();
    _service = OrgService(baseUrl: baseUrl,);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchOrganizations(
        status: _selectedStatus,
        search: _search.isEmpty ? null : _search,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _stats = OrgStats.fromJson(data['stats']);
        _orgs = (data['organizations'] as List)
            .map((e) => Organization.fromJson(e))
            .toList();
        _totalPages = data['pagination']['total_pages'] ?? 1;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _search = v;
    _page = 1;
    _fetchData();
  }

  void _onStatusTab(String status) {
    setState(() {
      _selectedStatus = status;
      _page = 1;
    });
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _fetchData)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_stats != null) _StatsRow(stats: _stats!),
                          const SizedBox(height: 16),
                          _SearchBar(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                          ),
                          const SizedBox(height: 12),
                          _StatusTabBar(
                            tabs: _tabs,
                            selected: _selectedStatus,
                            onTap: _onStatusTab,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: _orgs.isEmpty
                        ? const SliverToBoxAdapter(child: _EmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _OrgCard(
                                  org: _orgs[i],
                                  service: _service,
                                  onRefresh: _fetchData,
                                  onTap: () => _openDetail(_orgs[i]),
                                ),
                              ),
                              childCount: _orgs.length,
                            ),
                          ),
                  ),
                  if (_totalPages > 1)
                    SliverToBoxAdapter(
                      child: _Pagination(
                        page: _page,
                        total: _totalPages,
                        onPrev: _page > 1
                            ? () {
                                setState(() => _page--);
                                _fetchData();
                              }
                            : null,
                        onNext: _page < _totalPages
                            ? () {
                                setState(() => _page++);
                                _fetchData();
                              }
                            : null,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    title: const Text(
      'Organizations',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2E),
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFFE8EAED)),
    ),
  );

  void _openDetail(Organization org) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OrgDetailScreen(org: org, service: _service, onRefresh: _fetchData),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final OrgStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatCard(
            'Total',
            stats.totalOrgs.toString(),
            const Color(0xFF4361EE),
          ),
          _StatCard(
            'Active',
            stats.activeOrgs.toString(),
            const Color(0xFF06D6A0),
          ),
          _StatCard(
            'Trial',
            stats.trialOrgs.toString(),
            const Color(0xFFFFB703),
          ),
          _StatCard(
            'Suspended',
            stats.suspendedOrgs.toString(),
            const Color(0xFFEF476F),
          ),
          _StatCard(
            'Employees',
            stats.totalEmployees.toString(),
            const Color(0xFF7209B7),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 4)],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search company, email, contact...',
          hintStyle: TextStyle(color: Color(0xFFADB5BD), fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Color(0xFFADB5BD), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusTab {
  final String value;
  final String label;
  const _StatusTab(this.value, this.label);
}

class _StatusTabBar extends StatelessWidget {
  final List<_StatusTab> tabs;
  final String selected;
  final ValueChanged<String> onTap;
  const _StatusTabBar({
    required this.tabs,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: tabs
            .map(
              (t) => GestureDetector(
                onTap: () => onTap(t.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected == t.value
                        ? const Color(0xFF4361EE)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected == t.value
                          ? const Color(0xFF4361EE)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected == t.value
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Org Card
// ─────────────────────────────────────────────────────────────────────────────

class _OrgCard extends StatelessWidget {
  final Organization org;
  final OrgService service;
  final VoidCallback onRefresh;
  final VoidCallback onTap;

  const _OrgCard({
    required this.org,
    required this.service,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(org.status);
    final daysColor = org.daysRemaining <= 7
        ? const Color(0xFFEF476F)
        : org.daysRemaining <= 30
        ? const Color(0xFFFFB703)
        : const Color(0xFF06D6A0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  _AvatarCircle(name: org.companyName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.companyName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (org.companyCode != null)
                          Text(
                            org.companyCode!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: org.status, color: statusColor),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F3F4)),
            // Info chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.people_alt_outlined,
                        label:
                            '${org.activeEmployeeCount}/${org.maxUsers} users',
                        color: const Color(0xFF4361EE),
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.workspace_premium_outlined,
                        label: org.planName ?? 'No plan',
                        color: const Color(0xFF7209B7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.email_outlined,
                        label: org.adminEmail,
                        color: const Color(0xFF6B7280),
                        flex: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: org.planEndsAt != null
                            ? 'Ends ${DateFormat('dd MMM yyyy').format(org.planEndsAt!)}'
                            : org.trialEndsAt != null
                            ? 'Trial ends ${DateFormat('dd MMM yyyy').format(org.trialEndsAt!)}'
                            : 'No end date',
                        color: daysColor,
                      ),
                      const SizedBox(width: 8),
                      if (org.daysRemaining > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: daysColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${org.daysRemaining}d left',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: daysColor,
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
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'active' => const Color(0xFF06D6A0),
    'trial' => const Color(0xFFFFB703),
    'suspended' => const Color(0xFFEF476F),
    'expired' => const Color(0xFF9CA3AF),
    _ => const Color(0xFF9CA3AF),
  };
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  const _AvatarCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF4361EE),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool flex;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.flex = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        flex
            ? Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
    return flex ? Expanded(child: chip) : chip;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination
// ─────────────────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int page;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pagination({
    required this.page,
    required this.total,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            color: onPrev != null
                ? const Color(0xFF4361EE)
                : const Color(0xFFD1D5DB),
          ),
          Text(
            'Page $page of $total',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: onNext != null
                ? const Color(0xFF4361EE)
                : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & Error States
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.business_outlined, size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text(
            'No organizations found',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF476F)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Screen
// ─────────────────────────────────────────────────────────────────────────────

class OrgDetailScreen extends StatefulWidget {
  final Organization org;
  final OrgService service;
  final VoidCallback onRefresh;

  const OrgDetailScreen({
    super.key,
    required this.org,
    required this.service,
    required this.onRefresh,
  });

  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen> {
  late Organization _org;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _org = widget.org;
    _loadFresh();
  }

  Future<void> _loadFresh() async {
    try {
      final data = await widget.service.fetchOrganizationDetail(_org.tenantId);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() => _org = Organization.fromJson(data['organization']));
      }
    } catch (_) {}
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _updating = true);
    final ok = await widget.service.updateStatus(_org.tenantId, newStatus);
    if (!mounted) return;
    setState(() => _updating = false);
    if (ok) {
      widget.onRefresh();
      _loadFresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status changed to $newStatus'),
          backgroundColor: const Color(0xFF06D6A0),
        ),
      );
    }
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StatusSheet(
        current: _org.status,
        onSelect: (s) {
          Navigator.pop(context);
          _changeStatus(s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_org.status);
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF1A1A2E)),
        title: Text(
          _org.companyName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          if (_updating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _showStatusSheet,
              child: const Text(
                'Change status',
                style: TextStyle(color: Color(0xFF4361EE), fontSize: 13),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAED)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hero Card
            _DetailHero(org: _org, statusColor: statusColor),
            const SizedBox(height: 12),
            // Metrics row
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Employees',
                    value: '${_org.activeEmployeeCount}/${_org.maxUsers}',
                    color: const Color(0xFF4361EE),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.timer_outlined,
                    label: 'Days Left',
                    value: _org.daysRemaining > 0
                        ? '${_org.daysRemaining}'
                        : 'Expired',
                    color: _org.daysRemaining > 30
                        ? const Color(0xFF06D6A0)
                        : _org.daysRemaining > 7
                        ? const Color(0xFFFFB703)
                        : const Color(0xFFEF476F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Plan',
                    value: _org.planName ?? '—',
                    color: const Color(0xFF7209B7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Plan dates
            _SectionCard(
              title: 'Plan & Dates',
              icon: Icons.date_range_outlined,
              children: [
                _DetailRow('Plan', _org.planName ?? '—'),
                _DetailRow('Plan Code', _org.planCode ?? '—'),
                _DetailRow(
                  'Plan Start',
                  _org.planStartsAt != null
                      ? fmt.format(_org.planStartsAt!)
                      : '—',
                ),
                _DetailRow(
                  'Plan End',
                  _org.planEndsAt != null ? fmt.format(_org.planEndsAt!) : '—',
                ),
                _DetailRow(
                  'Trial End',
                  _org.trialEndsAt != null
                      ? fmt.format(_org.trialEndsAt!)
                      : '—',
                ),
                _DetailRow('Max Users', _org.maxUsers.toString()),
              ],
            ),
            const SizedBox(height: 12),
            // Contact info
            _SectionCard(
              title: 'Contact Information',
              icon: Icons.contact_mail_outlined,
              children: [
                _DetailRow('Admin Email', _org.adminEmail),
                _DetailRow('HR Email', _org.hrEmail ?? '—'),
                _DetailRow('Contact Person', _org.contactPerson ?? '—'),
                _DetailRow('Contact Number', _org.contactNumber ?? '—'),
                _DetailRow('Address', _org.companyAddress ?? '—'),
              ],
            ),
            const SizedBox(height: 12),
            // Company info
            _SectionCard(
              title: 'Company Details',
              icon: Icons.business_outlined,
              children: [
                _DetailRow('Company Code', _org.companyCode ?? '—'),
                _DetailRow('Domain', _org.domainName ?? '—'),
                _DetailRow('GST Number', _org.gstNumber ?? '—'),
                _DetailRow('Timezone', _org.timezone ?? '—'),
                _DetailRow('Created At', fmt.format(_org.createdAt)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'active' => const Color(0xFF06D6A0),
    'trial' => const Color(0xFFFFB703),
    'suspended' => const Color(0xFFEF476F),
    _ => const Color(0xFF9CA3AF),
  };
}

class _DetailHero extends StatelessWidget {
  final Organization org;
  final Color statusColor;
  const _DetailHero({required this.org, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              org.companyName
                  .split(' ')
                  .take(2)
                  .map((w) => w[0])
                  .join()
                  .toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF4361EE),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org.companyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (org.companyCode != null)
                  Text(
                    org.companyCode!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    org.status[0].toUpperCase() + org.status.substring(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF4361EE)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F4)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A2E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StatusSheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelect;
  const _StatusSheet({required this.current, required this.onSelect});

  static const _options = [
    ('active', 'Active', Color(0xFF06D6A0), Icons.check_circle_outline),
    ('trial', 'Trial', Color(0xFFFFB703), Icons.hourglass_empty),
    ('suspended', 'Suspended', Color(0xFFEF476F), Icons.block_outlined),
    ('expired', 'Expired', Color(0xFF9CA3AF), Icons.timer_off_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change Organization Status',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            ..._options.map((opt) {
              final (val, label, color, icon) = opt;
              final isSelected = current == val;
              return GestureDetector(
                onTap: isSelected ? null : () => onSelect(val),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.4)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? color : const Color(0xFF374151),
                        ),
                      ),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check, size: 18, color: color),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
