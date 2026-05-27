import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/api_config.dart';

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
  final String? planId;
  final List<String> modules;
  final int employeeCount;
  final int activeEmployeeCount;
  // FIX: daysRemaining can be negative (expired plans); use int not clamped
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
    this.planId,
    this.modules = const [],
    required this.employeeCount,
    required this.activeEmployeeCount,
    required this.daysRemaining,
  });

  factory Organization.fromJson(Map<String, dynamic> j) => Organization(
    tenantId: j['tenant_id']?.toString() ?? '',
    companyName: j['company_name']?.toString() ?? 'Unknown',
    companyCode: j['company_code']?.toString(),
    // FIX: default to 'unknown' if status is null/missing
    status: j['status']?.toString() ?? 'unknown',
    maxUsers: _i(j['max_users']),
    adminEmail: j['admin_email']?.toString() ?? '',
    hrEmail: j['hr_email']?.toString(),
    contactNumber: j['contact_number']?.toString(),
    contactPerson: j['contact_person']?.toString(),
    companyAddress: j['company_address']?.toString(),
    domainName: j['domain_name']?.toString(),
    gstNumber: j['gst_number']?.toString(),
    timezone: j['timezone']?.toString(),
    trialEndsAt: _d(j['trial_ends_at']),
    planStartsAt: _d(j['plan_starts_at']),
    planEndsAt: _d(j['plan_ends_at']),
    createdAt: _d(j['created_at']) ?? DateTime.now(),
    planName: j['plan_name']?.toString(),
    planCode: j['plan_code']?.toString(),
    priceMonthly: double.tryParse(j['price_monthly']?.toString() ?? ''),
    priceYearly: double.tryParse(j['price_yearly']?.toString() ?? ''),
    planId: j['plan_id']?.toString(),
    modules:
        (j['modules'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [],
    employeeCount: _i(j['employee_count']),
    activeEmployeeCount: _i(j['active_employee_count']),
    // FIX: allow negative values (expired); don't clamp to 0
    daysRemaining: _iSigned(j['days_remaining']),
  );

  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  // FIX: signed int parser for days_remaining (can be negative)
  static int _iSigned(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  static DateTime? _d(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// FIX: removed duplicate top-level baseUrl constant; service takes it as param
// ─────────────────────────────────────────────────────────────────────────────

class OrgService {
  final String baseUrl;

  const OrgService({required this.baseUrl});

  // FIX: added sessiontoken header — backend requireAppAdmin checks for it
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'usertype': 'app_admin',
    'sessiontoken':
        '531cbe9341dc6a8ac5775818d2f2fb99c4877ba9ff8250732b89c93e1b6jdgte', // replace with real token if needed
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
    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchOrganizationDetail(String tenantId) async {
    final uri = Uri.parse('$baseUrl/app-admin/organizations/$tenantId');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<bool> updateStatus(String tenantId, String status) async {
    final uri = Uri.parse('$baseUrl/app-admin/organizations/$tenantId/status');
    final resp = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['success'] == true;
  }

  Future<bool> updateDetails(
    String tenantId,
    Map<String, dynamic> fields,
  ) async {
    final uri = Uri.parse('$baseUrl/app-admin/organizations/$tenantId/details');
    final resp = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode(fields),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['success'] == true;
  }

  Future<List<Map<String, dynamic>>> fetchPlans() async {
    final uri = Uri.parse('$baseUrl/plans/list');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) throw Exception('Failed to fetch plans');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['plans'] ?? []);
  }

  Future<bool> resetAdminPassword(String tenantId) async {
    final uri = Uri.parse(
      '$baseUrl/app-admin/organizations/$tenantId/reset-password',
    );
    final resp = await http.post(uri, headers: _headers);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['success'] == true;
  }

  Future<bool> updatePlan(String tenantId, Map<String, dynamic> fields) async {
    final uri = Uri.parse('$baseUrl/app-admin/organizations/$tenantId/plan');
    final resp = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode(fields),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['success'] == true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppAdminOrgScreen extends StatefulWidget {
  const AppAdminOrgScreen({super.key});

  @override
  State<AppAdminOrgScreen> createState() => _AppAdminOrgScreenState();
}

class _AppAdminOrgScreenState extends State<AppAdminOrgScreen> {
  // FIX: use ApiConfig.baseUrl directly; no top-level constant to conflict with
  late final OrgService _service = OrgService(baseUrl: ApiConfig.baseUrl);

  bool _loading = true;
  String? _error;

  OrgStats? _stats;
  List<Organization> _orgs = [];

  String _selectedStatus = 'all';
  String _search = '';
  int _page = 1;
  int _totalPages = 1;

  final _searchCtrl = TextEditingController();

  // FIX: proper debounce timer replacing unused ValueNotifier
  Timer? _debounceTimer;
  List<Organization> get _expiringOrgs =>
      _orgs.where((o) => o.daysRemaining > 0 && o.daysRemaining <= 7).toList();
  static const _tabs = [
    _StatusTab('all', 'All'),
    _StatusTab('active', 'Active'),
    _StatusTab('trial', 'Trial'),
    _StatusTab('suspended', 'Suspended'),
    _StatusTab('expired', 'Expired'),
  ];

  @override
  void initState() {
    super.initState();
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
        _stats = OrgStats.fromJson(data['stats'] as Map<String, dynamic>);
        _orgs = (data['organizations'] as List<dynamic>)
            .map((e) => Organization.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalPages =
            (data['pagination'] as Map<String, dynamic>)['total_pages']
                as int? ??
            1;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // FIX: debounce search — wait 400ms after user stops typing before fetching
  void _onSearchChanged(String v) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _search = v;
      _page = 1;
      _fetchData();
    });
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
    _debounceTimer?.cancel(); // FIX: cancel pending debounce on dispose
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
                          if (_expiringOrgs.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFFFFB703,
                                  ).withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_outlined,
                                    color: Color(0xFFFFB703),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_expiringOrgs.length} org${_expiringOrgs.length > 1 ? 's' : ''} expiring within 7 days',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF92600A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _onStatusTab('active'),
                                    child: const Text(
                                      'View',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFFFB703),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  // FIX: daysRemaining <= 0 means expired/no date — show grey, not green
  Color _daysColor(int days) {
    if (days <= 0) return const Color(0xFF9CA3AF);
    if (days <= 7) return const Color(0xFFEF476F);
    if (days <= 30) return const Color(0xFFFFB703);
    return const Color(0xFF06D6A0);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(org.status);
    final daysColor = _daysColor(org.daysRemaining);

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
                        if (org.companyCode != null &&
                            org.companyCode!.isNotEmpty)
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
                      // FIX: show 'Expired' badge when days <= 0, positive label otherwise
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
                        )
                      else if (org.daysRemaining <= 0 &&
                          (org.planEndsAt != null || org.trialEndsAt != null))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CA3AF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Expired',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
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

// FIX: guard against empty/single-char names to avoid index crash
class _AvatarCircle extends StatelessWidget {
  final String name;
  const _AvatarCircle({required this.name});

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w[0]).join().toUpperCase();

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
    // FIX: guard against empty status string
    final label = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : 'Unknown';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
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
    child: Padding(
      padding: const EdgeInsets.all(24),
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
  // FIX: track fresh-load state separately so UI can show a subtle indicator
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _org = widget.org;
    _loadFresh();
  }

  Future<void> _resetAdminPassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Reset Password?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Text('A reset link will be sent to ${_org.adminEmail}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB703),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Reset'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await widget.service.resetAdminPassword(_org.tenantId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reset link'),
          backgroundColor: Color(0xFFEF476F),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reset link sent to ${_org.adminEmail}'),
        backgroundColor: const Color(0xFF06D6A0),
      ),
    );
  }

  Future<void> _loadFresh() async {
    if (!mounted) return;
    setState(() => _refreshing = true);
    try {
      final data = await widget.service.fetchOrganizationDetail(_org.tenantId);
      if (!mounted) return;
      if (data['success'] == true && data['organization'] != null) {
        setState(
          () => _org = Organization.fromJson(
            data['organization'] as Map<String, dynamic>,
          ),
        );
      }
    } catch (e) {
      // FIX: show a non-intrusive snackbar instead of silently swallowing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not refresh: $e'),
            backgroundColor: const Color(0xFFEF476F),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      final ok = await widget.service.updateStatus(_org.tenantId, newStatus);
      if (!mounted) return;
      if (ok) {
        widget.onRefresh();
        await _loadFresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status changed to $newStatus'),
              backgroundColor: const Color(0xFF06D6A0),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: Color(0xFFEF476F),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF476F),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                _org.companyName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            // FIX: subtle refresh indicator alongside company name
            if (_refreshing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF9CA3AF),
                ),
              ),
          ],
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
          else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF4361EE)),
              tooltip: 'Edit details',
              onPressed: _showEditSheet,
            ),
            TextButton(
              onPressed: _showStatusSheet,
              child: const Text(
                'Status',
                style: TextStyle(color: Color(0xFF4361EE), fontSize: 13),
              ),
            ),
          ],
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
            _DetailHero(org: _org, statusColor: statusColor),
            const SizedBox(height: 12),
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
                    // FIX: negative means expired, 0 means no date set
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

            const SizedBox(height: 12),
            _SectionCard(
              title: 'Plan Modules',
              icon: Icons.extension_outlined,
              children: [
                if (_org.modules.isEmpty)
                  const _DetailRow('Modules', 'No modules assigned')
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _org.modules
                          .map(
                            (m) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4361EE,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                m,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4361EE),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        org: _org,
        service: widget.service,
        onSaved: () {
          widget.onRefresh();
          _loadFresh();
        },
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

// ─────────────────────────────────────────────────────────────────────────────
// Detail sub-widgets (unchanged logic, kept for completeness)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailHero extends StatelessWidget {
  final Organization org;
  final Color statusColor;
  const _DetailHero({required this.org, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    // FIX: reuse safe initials logic
    final words = org.companyName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w[0]).join().toUpperCase();
    // FIX: guard empty status
    final statusLabel = org.status.isNotEmpty
        ? org.status[0].toUpperCase() + org.status.substring(1)
        : 'Unknown';

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
              initials,
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
                if (org.companyCode != null && org.companyCode!.isNotEmpty)
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
                    statusLabel,
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

// ignore_for_file: unused_element

/// Full-featured edit bottom sheet for org details + plan.
class _EditSheet extends StatefulWidget {
  final Organization org;
  final OrgService service;
  final VoidCallback onSaved;

  const _EditSheet({
    required this.org,
    required this.service,
    required this.onSaved,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _saving = false;

  // ── Contact/Details fields ──
  late final TextEditingController _companyName;
  late final TextEditingController _companyCode;
  late final TextEditingController _adminEmail;
  late final TextEditingController _hrEmail;
  late final TextEditingController _contactPerson;
  late final TextEditingController _contactNumber;
  late final TextEditingController _companyAddress;
  late final TextEditingController _domainName;
  late final TextEditingController _gstNumber;
  late final TextEditingController _timezone;

  // ── Plan fields ──
  late final TextEditingController _maxUsers;
  DateTime? _planStartsAt;
  DateTime? _planEndsAt;
  DateTime? _trialEndsAt;

  final _detailsFormKey = GlobalKey<FormState>();
  final _planFormKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _plans = [];
  String? _selectedPlanId;
  int? _planMaxUsers; // the ceiling from the chosen plan
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    final o = widget.org;
    _companyName = TextEditingController(text: o.companyName);
    _companyCode = TextEditingController(text: o.companyCode ?? '');
    _adminEmail = TextEditingController(text: o.adminEmail);
    _hrEmail = TextEditingController(text: o.hrEmail ?? '');
    _contactPerson = TextEditingController(text: o.contactPerson ?? '');
    _contactNumber = TextEditingController(text: o.contactNumber ?? '');
    _companyAddress = TextEditingController(text: o.companyAddress ?? '');
    _domainName = TextEditingController(text: o.domainName ?? '');
    _gstNumber = TextEditingController(text: o.gstNumber ?? '');
    _timezone = TextEditingController(text: o.timezone ?? '');
    _maxUsers = TextEditingController(text: o.maxUsers.toString());
    _planStartsAt = o.planStartsAt;
    _planEndsAt = o.planEndsAt;
    _trialEndsAt = o.trialEndsAt;
    _selectedPlanId = widget.org.planId; // add planId to Organization model
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await widget.service.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans.where((p) => p['is_active'] == 1).toList();
        _loadingPlans = false;
        // set ceiling from currently selected plan
        final current = _plans.firstWhere(
          (p) => p['plan_id'] == _selectedPlanId,
          orElse: () => {},
        );
        _planMaxUsers = current.isEmpty ? null : current['max_users'] as int?;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  void _onPlanChanged(String? planId) {
    if (planId == null) return;
    final plan = _plans.firstWhere(
      (p) => p['plan_id'] == planId,
      orElse: () => {},
    );
    setState(() {
      _selectedPlanId = planId;
      _planMaxUsers = plan.isEmpty
          ? null
          : int.tryParse(plan['max_users'].toString());
      // clamp current value if it exceeds the new plan ceiling
      final current = int.tryParse(_maxUsers.text) ?? 0;
      if (_planMaxUsers != null && current > _planMaxUsers!) {
        _maxUsers.text = _planMaxUsers.toString();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [
      _companyName,
      _companyCode,
      _adminEmail,
      _hrEmail,
      _contactPerson,
      _contactNumber,
      _companyAddress,
      _domainName,
      _gstNumber,
      _timezone,
      _maxUsers,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'company_name': _companyName.text.trim(),
        'company_code': _companyCode.text.trim(),
        'admin_email': _adminEmail.text.trim(),
        'hr_email': _hrEmail.text.trim(),
        'contact_person': _contactPerson.text.trim(),
        'contact_number': _contactNumber.text.trim(),
        'company_address': _companyAddress.text.trim(),
        'domain_name': _domainName.text.trim(),
        'gst_number': _gstNumber.text.trim(),
        'timezone': _timezone.text.trim(),
      };
      final ok = await widget.service.updateDetails(
        widget.org.tenantId,
        payload,
      );
      if (!mounted) return;
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        _showSnack('Details updated successfully', const Color(0xFF06D6A0));
      } else {
        _showSnack('Failed to update details', const Color(0xFFEF476F));
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', const Color(0xFFEF476F));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePlan() async {
    if (!_planFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final payload = <String, dynamic>{
        if (_selectedPlanId != null) 'plan_id': _selectedPlanId, // ← ADD
        'max_users': int.tryParse(_maxUsers.text.trim()) ?? widget.org.maxUsers,
        if (_planStartsAt != null) 'plan_starts_at': fmt.format(_planStartsAt!),
        if (_planEndsAt != null) 'plan_ends_at': fmt.format(_planEndsAt!),
        if (_trialEndsAt != null) 'trial_ends_at': fmt.format(_trialEndsAt!),
      };
      final ok = await widget.service.updatePlan(widget.org.tenantId, payload);
      if (!mounted) return;
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        _showSnack('Plan updated successfully', const Color(0xFF06D6A0));
      } else {
        _showSnack('Failed to update plan', const Color(0xFFEF476F));
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', const Color(0xFFEF476F));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext ctx,
    DateTime? initial,
    ValueChanged<DateTime> onPicked,
  ) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4361EE),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomPad),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit Organization',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: const Color(0xFF9CA3AF),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: const Color(0xFF4361EE),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Contact & Details'),
                Tab(text: 'Plan & Dates'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _DetailsTab(
                  formKey: _detailsFormKey,
                  companyName: _companyName,
                  companyCode: _companyCode,
                  adminEmail: _adminEmail,
                  hrEmail: _hrEmail,
                  contactPerson: _contactPerson,
                  contactNumber: _contactNumber,
                  companyAddress: _companyAddress,
                  domainName: _domainName,
                  gstNumber: _gstNumber,
                  timezone: _timezone,
                ),
                _PlanTab(
                  formKey: _planFormKey,
                  maxUsers: _maxUsers,
                  planStartsAt: _planStartsAt,
                  planEndsAt: _planEndsAt,
                  trialEndsAt: _trialEndsAt,
                  onPickPlanStart: (ctx) => _pickDate(
                    ctx,
                    _planStartsAt,
                    (d) => setState(() => _planStartsAt = d),
                  ),
                  onPickPlanEnd: (ctx) => _pickDate(
                    ctx,
                    _planEndsAt,
                    (d) => setState(() => _planEndsAt = d),
                  ),
                  onPickTrialEnd: (ctx) => _pickDate(
                    ctx,
                    _trialEndsAt,
                    (d) => setState(() => _trialEndsAt = d),
                  ),
                  plans: _plans,
                  selectedPlanId: _selectedPlanId,
                  planMaxUsers: _planMaxUsers,
                  loadingPlans: _loadingPlans,
                  onPlanChanged: _onPlanChanged,
                ),
              ],
            ),
          ),
          // Save button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving
                      ? null
                      : () {
                          if (_tabCtrl.index == 0) {
                            _saveDetails();
                          } else {
                            _savePlan();
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _tabCtrl,
                          builder: (_, __) => Text(
                            _tabCtrl.index == 0 ? 'Save Details' : 'Save Plan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact & Details Tab ──────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController companyName;
  final TextEditingController companyCode;
  final TextEditingController adminEmail;
  final TextEditingController hrEmail;
  final TextEditingController contactPerson;
  final TextEditingController contactNumber;
  final TextEditingController companyAddress;
  final TextEditingController domainName;
  final TextEditingController gstNumber;
  final TextEditingController timezone;

  const _DetailsTab({
    required this.formKey,
    required this.companyName,
    required this.companyCode,
    required this.adminEmail,
    required this.hrEmail,
    required this.contactPerson,
    required this.contactNumber,
    required this.companyAddress,
    required this.domainName,
    required this.gstNumber,
    required this.timezone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _EditSection(
              title: 'Company',
              icon: Icons.business_outlined,
              fields: [
                _EditField(
                  label: 'Company Name',
                  controller: companyName,
                  required: true,
                ),
                _EditField(label: 'Company Code', controller: companyCode),
                _EditField(
                  label: 'Domain Name',
                  controller: domainName,
                  hint: 'e.g. company.com',
                ),
                _EditField(label: 'GST Number', controller: gstNumber),
                _EditField(
                  label: 'Timezone',
                  controller: timezone,
                  hint: 'e.g. Asia/Kolkata',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditSection(
              title: 'Contact',
              icon: Icons.contact_mail_outlined,
              fields: [
                _EditField(
                  label: 'Admin Email',
                  controller: adminEmail,
                  required: true,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                _EditField(
                  label: 'HR Email',
                  controller: hrEmail,
                  keyboardType: TextInputType.emailAddress,
                ),
                _EditField(label: 'Contact Person', controller: contactPerson),
                _EditField(
                  label: 'Contact Number',
                  controller: contactNumber,
                  keyboardType: TextInputType.phone,
                ),
                _EditField(
                  label: 'Company Address',
                  controller: companyAddress,
                  maxLines: 2,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Plan & Dates Tab ───────────────────────────────────────────────────────

class _PlanTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController maxUsers;
  final DateTime? planStartsAt;
  final DateTime? planEndsAt;
  final DateTime? trialEndsAt;
  final Future<void> Function(BuildContext) onPickPlanStart;
  final Future<void> Function(BuildContext) onPickPlanEnd;
  final Future<void> Function(BuildContext) onPickTrialEnd;
  // ── NEW params ──
  final List<Map<String, dynamic>> plans;
  final String? selectedPlanId;
  final int? planMaxUsers;
  final bool loadingPlans;
  final ValueChanged<String?> onPlanChanged;

  const _PlanTab({
    required this.formKey,
    required this.maxUsers,
    required this.planStartsAt,
    required this.planEndsAt,
    required this.trialEndsAt,
    required this.onPickPlanStart,
    required this.onPickPlanEnd,
    required this.onPickTrialEnd,
    required this.plans,
    required this.selectedPlanId,
    required this.planMaxUsers,
    required this.loadingPlans,
    required this.onPlanChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _EditSection(
              title: 'Plan & Limits',
              icon: Icons.workspace_premium_outlined,
              fields: const [],
              children: [
                // ── Plan Dropdown ──
                if (loadingPlans)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedPlanId,
                    decoration: InputDecoration(
                      labelText: 'Plan',
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF4361EE),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    items: plans
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p['plan_id'] as String,
                            child: Text(
                              '${p['plan_name']} (max ${p['max_users']} users)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onPlanChanged,
                  ),
                const SizedBox(height: 10),
                // ── Max Users field ──
                TextFormField(
                  controller: maxUsers,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Max Users *',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                    helperText: planMaxUsers != null
                        ? 'Plan allows up to $planMaxUsers users'
                        : null,
                    helperStyle: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF4361EE),
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFEF476F)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFEF476F),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final parsed = int.tryParse(v);
                    if (parsed == null) return 'Must be a number';
                    if (parsed < 1) return 'Must be at least 1';
                    if (planMaxUsers != null && parsed > planMaxUsers!) {
                      return 'Exceeds plan limit of $planMaxUsers users';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditSection(
              title: 'Plan Dates',
              icon: Icons.date_range_outlined,
              children: [
                _DatePickerRow(
                  label: 'Plan Starts',
                  value: planStartsAt != null ? fmt.format(planStartsAt!) : '—',
                  onTap: () => onPickPlanStart(context),
                ),
                const Divider(height: 1, color: Color(0xFFF1F3F4)),
                _DatePickerRow(
                  label: 'Plan Ends',
                  value: planEndsAt != null ? fmt.format(planEndsAt!) : '—',
                  onTap: () => onPickPlanEnd(context),
                ),
                const Divider(height: 1, color: Color(0xFFF1F3F4)),
                _DatePickerRow(
                  label: 'Trial Ends',
                  value: trialEndsAt != null ? fmt.format(trialEndsAt!) : '—',
                  onTap: () => onPickTrialEnd(context),
                ),
              ],
              fields: const [],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
// ── Reusable sub-widgets ───────────────────────────────────────────────────

class _EditSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_EditField> fields;
  final List<Widget>? children;

  const _EditSection({
    required this.title,
    required this.icon,
    required this.fields,
    this.children,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: const Color(0xFF4361EE)),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                ...fields.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: f,
                  ),
                ),
                if (children != null) ...children!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? hint;
  final String? Function(String?)? validator;

  const _EditField({
    required this.label,
    required this.controller,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4361EE), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF476F)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF476F), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      validator:
          validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: Color(0xFF4361EE),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _DangerRow({
    required this.label,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
