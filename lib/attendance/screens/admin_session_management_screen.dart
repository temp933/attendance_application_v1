import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
// Represents a user's current login/session state for the admin panel.
// Note there are TWO independent lock mechanisms — see isAccountLocked
// vs isLocked below — both must be checked separately in the UI.
class SessionUser {
  final int loginId;
  final String? empId;
  final String username;
  final String fullName;
  final String roleName;
  final String departmentName;
  final int roleId;
  final bool isLoggedIn;
  final String accountStatus; // 'Active' | 'Inactive'
  final bool
  isAccountLocked; // admin manually locked this account (permanent until admin unlocks)
  final String? sessionDevice;
  final DateTime? lastLoginAt;
  final DateTime? sessionExpiresAt;
  final int failedAttempts;
  final bool
  isLocked; // auto-locked from too many failed login attempts (temporary, expires at lockedUntil)
  final DateTime? lockedUntil;

  const SessionUser({
    required this.loginId,
    this.empId,
    required this.username,
    required this.fullName,
    required this.roleName,
    this.departmentName = 'No Department',
    required this.roleId,
    required this.isLoggedIn,
    this.accountStatus = 'Active',
    this.isAccountLocked = false,
    this.sessionDevice,
    this.lastLoginAt,
    this.sessionExpiresAt,
    this.failedAttempts = 0,
    this.isLocked = false,
    this.lockedUntil,
  });

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
    loginId: (j['loginId'] as num?)?.toInt() ?? 0,
    empId: j['empId']?.toString(),
    username: j['username'] as String? ?? '',
    fullName: (j['fullName'] as String?)?.trim().isNotEmpty == true
        ? j['fullName'] as String
        : j['username'] as String? ?? '',
    roleName: j['roleName'] as String? ?? 'Employee',
    departmentName: j['departmentName'] as String? ?? 'No Department',
    roleId: (j['roleId'] as num?)?.toInt() ?? 4,
    isLoggedIn: j['isLoggedIn'] == true,
    accountStatus: j['accountStatus'] as String? ?? 'Active',
    isAccountLocked: j['isAccountLocked'] == true,
    sessionDevice: j['sessionDevice'] as String?,
    lastLoginAt: j['lastLoginAt'] != null
        ? DateTime.tryParse(j['lastLoginAt'] as String)
        : null,
    sessionExpiresAt: j['sessionExpiresAt'] != null
        ? DateTime.tryParse(j['sessionExpiresAt'] as String)
        : null,
    failedAttempts: (j['failedAttempts'] as num?)?.toInt() ?? 0,
    isLocked: j['isLocked'] == true,
    lockedUntil: j['lockedUntil'] != null
        ? DateTime.tryParse(j['lockedUntil'] as String)
        : null,
  );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  /// True if the account is locked by any means
  bool get anyLocked => isAccountLocked || isLocked;
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
// Thin wrapper over the /admin/sessions endpoints. Each action method
// just posts and throws on failure — calling code handles confirm
// dialogs and UI feedback (see _run / _confirm in the screen below).
class _SessionService {
  static Future<List<SessionUser>> fetchAll() async {
    final res = await ApiClient.get('/admin/sessions');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return (body['data'] as List)
            .map((e) => SessionUser.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    throw Exception('Failed to fetch sessions');
  }

  static Future<void> forceLogout(int loginId) async {
    final res = await ApiClient.post(
      '/admin/sessions/$loginId/force-logout',
      {},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Force logout failed');
    }
  }

  // Clears the auto (brute-force) lock — NOT the same as unlockAccount below
  static Future<void> unlock(int loginId) async {
    final res = await ApiClient.post('/admin/sessions/$loginId/unlock', {});
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Unlock failed');
    }
  }

  // Admin-initiated permanent lock — distinct from the brute-force lock above
  static Future<void> lockAccount(int loginId) async {
    final res = await ApiClient.post(
      '/admin/sessions/$loginId/lock-account',
      {},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Lock failed');
    }
  }

  static Future<void> unlockAccount(int loginId) async {
    final res = await ApiClient.post(
      '/admin/sessions/$loginId/unlock-account',
      {},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Unlock account failed');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminSessionManagementScreen extends StatefulWidget {
  const AdminSessionManagementScreen({super.key});

  @override
  State<AdminSessionManagementScreen> createState() =>
      _AdminSessionManagementScreenState();
}

class _AdminSessionManagementScreenState
    extends State<AdminSessionManagementScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF8F9FC);
  static const _card = Colors.white;
  static const _primary = Color(0xFF2563EB);
  static const _primaryLight = Color(0xFFEFF6FF);
  static const _success = Color(0xFF16A34A);
  static const _successLight = Color(0xFFF0FDF4);
  static const _danger = Color(0xFFDC2626);
  static const _dangerLight = Color(0xFFFEF2F2);
  static const _warning = Color(0xFFD97706);
  static const _purple = Color(0xFF7C3AED);
  static const _purpleLight = Color(0xFFF5F3FF);
  static const _slate = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _textDark = Color(0xFF0F172A);
  static const _textMid = Color(0xFF475569);

  List<SessionUser> _all = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _search = '';
  String _filter = 'all'; // all | active | inactive | locked

  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await _SessionService.fetchAll();
      if (mounted) setState(() => _all = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Search across name/username/role/device, combined with the active
  // status filter chip (all/active/inactive/locked)
  List<SessionUser> get _filtered => _all.where((s) {
    final q = _search.toLowerCase();
    final matchSearch =
        q.isEmpty ||
        s.fullName.toLowerCase().contains(q) ||
        s.username.toLowerCase().contains(q) ||
        s.roleName.toLowerCase().contains(q) ||
        (s.sessionDevice?.toLowerCase().contains(q) ?? false);
    final matchFilter = switch (_filter) {
      'active' => s.isLoggedIn,
      'inactive' => !s.isLoggedIn && !s.anyLocked,
      'locked' => s.anyLocked,
      _ => true,
    };
    return matchSearch && matchFilter;
  }).toList();

  int get _activeCount => _all.where((s) => s.isLoggedIn).length;
  int get _lockedCount => _all.where((s) => s.anyLocked).length;
  int get _inactiveCount =>
      _all.where((s) => !s.isLoggedIn && !s.anyLocked).length;

  // ── Actions ────────────────────────────────────────────────────────────────
  // Ends the user's session immediately — also closes any open
  // attendance session server-side (see confirm dialog body)
  Future<void> _doForceLogout(SessionUser u) async {
    final ok = await _confirm(
      title: 'Force Logout',
      body:
          'Log out "${u.fullName}" immediately?\n\nTheir active attendance session will also be closed.',
      confirmText: 'Force Logout',
      confirmColor: _danger,
    );
    if (!ok) return;
    await _run(() => _SessionService.forceLogout(u.loginId));
    _snack('${u.fullName} logged out successfully.', _danger);
  }

  Future<void> _doUnlockBruteForce(SessionUser u) async {
    await _run(() => _SessionService.unlock(u.loginId));
    _snack('Brute-force lock cleared for ${u.fullName}.', _success);
  }

  Future<void> _doLockAccount(SessionUser u) async {
    final ok = await _confirm(
      title: 'Lock Account',
      body:
          'Lock "${u.fullName}"\'s account?\n\nThey will be immediately logged out and will not be able to log in until unlocked.',
      confirmText: 'Lock Account',
      confirmColor: _danger,
    );
    if (!ok) return;
    await _run(() => _SessionService.lockAccount(u.loginId));
    _snack('${u.fullName}\'s account has been locked.', _danger);
  }

  Future<void> _doUnlockAccount(SessionUser u) async {
    final ok = await _confirm(
      title: 'Unlock Account',
      body:
          'Re-enable "${u.fullName}"\'s account?\n\nThey will be able to log in again.',
      confirmText: 'Unlock Account',
      confirmColor: _success,
    );
    if (!ok) return;
    await _run(() => _SessionService.unlockAccount(u.loginId));
    _snack('${u.fullName}\'s account has been unlocked.', _success);
  }

  // Shared wrapper for all lock/unlock/logout actions: shows the busy
  // overlay, runs the action, then reloads the list to reflect new state
  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      await _load();
    } catch (e) {
      _snack('Error: $e', _danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmText,
    required Color confirmColor,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => _ConfirmDialog(
          title: title,
          body: body,
          confirmText: confirmText,
          confirmColor: confirmColor,
        ),
      ) ??
      false;

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatLockTime(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m remaining';
    return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
  }

  // Maps role_id to its badge color/icon: 1=Super Admin, 2=Admin/Manager,
  // 3=TL/HR, anything else falls back to a neutral "Employee" style
  ({Color bg, Color fg, IconData icon}) _roleStyle(int roleId) =>
      switch (roleId) {
        1 => (
          bg: _dangerLight,
          fg: _danger,
          icon: Icons.admin_panel_settings_rounded,
        ),
        2 => (bg: _primaryLight, fg: _primary, icon: Icons.people_alt_rounded),
        3 => (bg: _purpleLight, fg: _purple, icon: Icons.group_rounded),
        _ => (
          bg: const Color(0xFFF1F5F9),
          fg: _slate,
          icon: Icons.person_rounded,
        ),
      };

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Stack(
      children: [
        _buildBody(),
        if (_busy)
          Container(
            color: Colors.black.withValues(alpha: 0.18),
            child: const Center(
              child: CircularProgressIndicator(color: _primary),
            ),
          ),
      ],
    ),
  );

  Widget _buildBody() {
    if (_loading) return _buildSkeleton();
    if (_error != null) return _buildError();
    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: 14),
                  _buildSearchBar(),
                  const SizedBox(height: 10),
                  _buildFilterRow(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          if (_filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildCard(_filtered[i]),
                  ),
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Stats ──────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() => Row(
    children: [
      Expanded(
        child: _statCard(
          '${_all.length}',
          'Total',
          Icons.people_rounded,
          _primary,
          _primaryLight,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          '$_activeCount',
          'Active',
          Icons.circle,
          _success,
          _successLight,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          '$_inactiveCount',
          'Offline',
          Icons.circle_outlined,
          _slate,
          const Color(0xFFF1F5F9),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _statCard(
          '$_lockedCount',
          'Locked',
          Icons.lock_rounded,
          _danger,
          _dangerLight,
        ),
      ),
    ],
  );

  Widget _statCard(
    String val,
    String label,
    IconData icon,
    Color fg,
    Color bg,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: fg, size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          val,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: fg,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _slate,
          ),
        ),
      ],
    ),
  );

  // ── Search ─────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    height: 44,
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      style: const TextStyle(fontSize: 13.5, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search name, username, role…',
        hintStyle: TextStyle(color: _slate, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: _slate),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    ),
  );

  // ── Filter chips ────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    const filters = [
      ('all', 'All'),
      ('active', 'Active'),
      ('inactive', 'Offline'),
      ('locked', 'Locked'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? _primary : _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? _primary : _border,
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _textMid,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Session card ────────────────────────────────────────────────────────────
  Widget _buildCard(SessionUser u) {
    final rs = _roleStyle(u.roleId);
    final isActive = u.isLoggedIn;

    // Border color priority: account-locked > brute-force locked > active > default
    // (most severe/important state wins when multiple could apply)
    final borderColor = u.isAccountLocked
        ? _danger.withValues(alpha: 0.4)
        : u.isLocked
        ? _warning.withValues(alpha: 0.4)
        : isActive
        ? _success.withValues(alpha: 0.25)
        : _border;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
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
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: u.isAccountLocked ? _dangerLight : rs.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (u.isAccountLocked ? _danger : rs.fg).withValues(
                        alpha: 0.2,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: u.isAccountLocked
                        ? const Icon(
                            Icons.lock_rounded,
                            color: _danger,
                            size: 18,
                          )
                        : Text(
                            u.initials,
                            style: TextStyle(
                              color: rs.fg,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: u.isAccountLocked ? _danger : _textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${u.username}',
                        style: const TextStyle(fontSize: 12, color: _slate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(u),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: _border),

          // ── Info rows ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
              children: [
                _infoRow(
                  icon: rs.icon,
                  iconColor: rs.fg,
                  label: 'Role',
                  value: u.roleName,
                  valueColor: rs.fg,
                  bold: true,
                ),
                _infoRow(
                  // ← add this block
                  icon: Icons.business_rounded,
                  iconColor: _slate,
                  label: 'Department',
                  value: u.departmentName,
                ),
                if (isActive && u.sessionDevice != null)
                  _infoRow(
                    icon: Icons.phone_android_rounded,
                    iconColor: _slate,
                    label: 'Device',
                    value: u.sessionDevice!,
                  ),
                _infoRow(
                  icon: Icons.schedule_rounded,
                  iconColor: _slate,
                  label: 'Last Login',
                  value: _timeAgo(u.lastLoginAt),
                ),
                if (u.isAccountLocked)
                  _infoRow(
                    icon: Icons.block_rounded,
                    iconColor: _danger,
                    label: 'Status',
                    value: 'Account locked by admin',
                    valueColor: _danger,
                  ),
                if (u.isLocked && u.lockedUntil != null)
                  _infoRow(
                    icon: Icons.lock_clock_rounded,
                    iconColor: _warning,
                    label: 'Locked Until',
                    value: _formatLockTime(u.lockedUntil!),
                    valueColor: _warning,
                  ),
                if (u.failedAttempts > 0 && !u.isLocked && !u.isAccountLocked)
                  _infoRow(
                    icon: Icons.warning_amber_rounded,
                    iconColor: _warning,
                    label: 'Failed Attempts',
                    value: '${u.failedAttempts}',
                    valueColor: _warning,
                  ),
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────────────────────
          // Action buttons shown depend on current lock/session state:
          // admin-lock toggle always shown; brute-force clear and force
          // logout only appear when relevant (mutually exclusive states)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                // Left: Lock / Unlock account toggle
                if (u.isAccountLocked)
                  _actionBtn(
                    icon: Icons.lock_open_rounded,
                    label: 'Unlock Account',
                    onTap: () => _doUnlockAccount(u),
                    color: _success,
                  )
                else
                  _actionBtn(
                    icon: Icons.lock_rounded,
                    label: 'Lock Account',
                    onTap: () => _doLockAccount(u),
                    color: _danger,
                    outlined: true,
                  ),

                const Spacer(),

                // Right: clear brute-force lock
                if (u.isLocked && !u.isAccountLocked) ...[
                  _actionBtn(
                    icon: Icons.lock_open_rounded,
                    label: 'Clear Lock',
                    onTap: () => _doUnlockBruteForce(u),
                    color: _warning,
                  ),
                  const SizedBox(width: 8),
                ],

                // Right: force logout (only if actively logged in)
                if (isActive && !u.isAccountLocked)
                  _actionBtn(
                    icon: Icons.logout_rounded,
                    label: 'Force Logout',
                    onTap: () => _doForceLogout(u),
                    color: _danger,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(SessionUser u) {
    if (u.isAccountLocked)
      return _pill('Locked', _danger, _dangerLight, Icons.lock_rounded);
    if (u.isLocked)
      return _pill(
        'Blocked',
        _warning,
        const Color(0xFFFFFBEB),
        Icons.lock_clock_rounded,
      );
    if (u.isLoggedIn)
      return _pill('Active', _success, _successLight, Icons.circle);
    return _pill(
      'Offline',
      _slate,
      const Color(0xFFF1F5F9),
      Icons.circle_outlined,
    );
  }

  Widget _pill(String label, Color fg, Color bg, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: fg),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _slate,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: valueColor ?? _textDark,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool outlined = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
        boxShadow: outlined
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: outlined ? color : Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: outlined ? color : Colors.white,
            ),
          ),
        ],
      ),
    ),
  );

  // ── Skeleton ───────────────────────────────────────────────────────────────
  // Animated shimmer placeholder shown during initial load — shape
  // roughly mirrors the real layout (stats row, search, filters, cards)
  Widget _buildSkeleton() => SingleChildScrollView(
    // ← add this
    physics: const NeverScrollableScrollPhysics(), // skeleton shouldn't scroll
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _shimmerBox(height: 92, radius: 12),
        const SizedBox(height: 12),
        _shimmerBox(height: 44, radius: 12),
        const SizedBox(height: 10),
        _shimmerBox(height: 36, radius: 20),
        const SizedBox(height: 14),
        for (int i = 0; i < 4; i++) ...[
          _shimmerBox(height: 160, radius: 14),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
  Widget _shimmerBox({required double height, double radius = 8}) =>
      AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (_, __) {
          final v = _shimmerCtrl.value;
          return Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFFE2E8F0),
                  Color(0xFFF1F5F9),
                  Color(0xFFE2E8F0),
                ],
                stops: [
                  (v - 0.3).clamp(0.0, 1.0),
                  v.clamp(0.0, 1.0),
                  (v + 0.3).clamp(0.0, 1.0),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        },
      );

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: _dangerLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, color: _danger, size: 32),
        ),
        const SizedBox(height: 14),
        const Text(
          'Failed to load sessions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(_error ?? '', style: const TextStyle(color: _slate, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.manage_search_rounded, size: 48, color: _border),
        const SizedBox(height: 12),
        const Text(
          'No users found',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _slate,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────
// Generic yes/no confirmation used by all destructive actions in this
// file (force logout, lock/unlock account) — title/body/color are
// parameterized per call site rather than having a dialog per action
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmText;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmText,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    ),
    content: Text(
      body,
      style: const TextStyle(
        fontSize: 13.5,
        color: Color(0xFF475569),
        height: 1.5,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: confirmColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirmText),
      ),
    ],
  );
}
