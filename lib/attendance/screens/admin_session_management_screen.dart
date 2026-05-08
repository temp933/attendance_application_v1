import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'responsive_utils.dart';
import '../providers/api_client.dart';
import '../providers/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class SessionUser {
  final int loginId;
  final int? empId;
  final String username;
  final String fullName;
  final String roleName;
  final bool isLoggedIn;
  final String? sessionDevice;
  final DateTime? lastLoginAt;

  SessionUser({
    required this.loginId,
    this.empId,
    required this.username,
    required this.fullName,
    required this.roleName,
    required this.isLoggedIn,
    this.sessionDevice,
    this.lastLoginAt,
  });

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
    loginId: j['loginId'] ?? 0,
    empId: j['empId'],
    username: j['username'] ?? '',
    fullName: j['fullName'] ?? j['username'] ?? '',
    roleName: j['roleName'] ?? '-',
    isLoggedIn: j['isLoggedIn'] == true,
    sessionDevice: j['sessionDevice'],
    lastLoginAt: j['lastLoginAt'] != null
        ? DateTime.tryParse(j['lastLoginAt'].toString())
        : null,
  );

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _SessionService {
  static Future<List<SessionUser>> fetchAll() async {
    final res = await ApiClient.get('/admin/sessions');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        return (body['data'] as List)
            .map((e) => SessionUser.fromJson(e))
            .toList();
      }
    }
    throw Exception('Failed to fetch sessions');
  }

  static Future<void> forceLogout(int loginId, {int? empId}) async {
    // Backend now handles attendance + session close in one call
    final res = await ApiClient.post(
      '/admin/sessions/$loginId/force-logout',
      {},
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Force logout failed');
    }
  }

  static Future<void> forceLogoutAll(int empId) async {
    final res = await ApiClient.post(
      '/admin/sessions/force-logout-all/$empId',
      {},
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Force logout all failed');
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
  // ── Design Tokens — copied exactly from EmployeeProfileScreen ───────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  List<SessionUser> _allSessions = [];
  bool _isLoading = true;
  bool _actionLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _filterStatus = 'All';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSessions();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sessions = await _SessionService.fetchAll();
      setState(() {
        _allSessions = sessions;
        _isLoading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load sessions. Check your connection.';
        _isLoading = false;
      });
    }
  }

  // ── Filtering ────────────────────────────────────────────────────────────────
  List<SessionUser> get _filtered {
    return _allSessions.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          s.fullName.toLowerCase().contains(q) ||
          s.username.toLowerCase().contains(q) ||
          s.roleName.toLowerCase().contains(q) ||
          (s.sessionDevice?.toLowerCase().contains(q) ?? false);
      final matchFilter = switch (_filterStatus) {
        'LoggedIn' => s.isLoggedIn,
        'LoggedOut' => !s.isLoggedIn,
        _ => true,
      };
      return matchSearch && matchFilter;
    }).toList();
  }

  int get _activeCount => _allSessions.where((s) => s.isLoggedIn).length;
  int get _idleCount => _allSessions.where((s) => !s.isLoggedIn).length;

  // ── Actions ───────────────────────────────────────────────────────────────────
  Future<void> _handleForceLogout(SessionUser user) async {
    final ok = await _confirmDialog(
      title: 'Force Logout',
      message:
          'This will immediately log out "${user.fullName}" from their current device and end their active attendance session.\n\nThey can log in again from any device.',
      confirmLabel: 'Force Logout',
      confirmColor: _red,
    );
    if (!ok) return;
    setState(() => _actionLoading = true);
    try {
      await _SessionService.forceLogout(user.loginId, empId: user.empId);
      _snack('${user.fullName} has been logged out and session ended.', _red);
      await _loadSessions();
    } catch (e) {
      _snack('Error: $e', _red);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleForceLogoutAll(SessionUser user) async {
    if (user.empId == null) {
      _snack('Employee ID not found for this user', _amber);
      return;
    }
    final ok = await _confirmDialog(
      title: 'Revoke All Sessions',
      message:
          'Force logout "${user.fullName}" from ALL devices?\n\nThey can log in again from any device.',
      confirmLabel: 'Revoke All',
      confirmColor: const Color(0xFFEA580C),
    );
    if (!ok) return;
    setState(() => _actionLoading = true);
    try {
      await _SessionService.forceLogoutAll(user.empId!);
      _snack(
        'All sessions for ${user.fullName} cleared.',
        const Color(0xFFEA580C),
      );
      await _loadSessions();
    } catch (e) {
      _snack('Error: $e', _red);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(color: _textMid, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: _textMid)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: confirmColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────
  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _red;
      case 'hr':
        return _primary;
      case 'tl':
      case 'team lead':
      case 'teamlead':
        return _purple;
      default:
        return _accent;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null
          ? _buildError(r)
          : FadeTransition(
              opacity: _fadeAnim,
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadSessions,
                    color: _primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                MediaQuery.of(context).padding.top +
                                kToolbarHeight +
                                8,
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 32),
                          sliver: SliverToBoxAdapter(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: r.contentMaxWidth,
                                ),
                                child: _buildBody(r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_actionLoading)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── AppBar — same style as profile screen ────────────────────────────────────
  PreferredSizeWidget _buildAppBar() => AppBar(
    // backgroundColor: _primary,
    foregroundColor: const Color.fromARGB(255, 9, 9, 9),
    elevation: 0,
    // title: const Text(
    //   'Session Management',
    //   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    // ),
    actions: [
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _loadSessions,
      ),
      const SizedBox(width: 4),
    ],
  );

  // ── Error — same as profile screen ──────────────────────────────────────────
  Widget _buildError(Responsive r) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load sessions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadSessions,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Body ─────────────────────────────────────────────────────────────────────
  Widget _buildBody(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(r),
        const SizedBox(height: 16),
        _buildSearchBar(r),
        const SizedBox(height: 12),
        _buildFilterChips(r),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          _buildEmpty(r)
        else if (r.useTwoColSections)
          _buildTwoColGrid(r)
        else
          _buildSingleColList(r),
      ],
    );
  }

  // ── Hero Card — gradient, same pattern as profile hero ───────────────────────
  Widget _buildHeroCard(Responsive r) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              r.isDesktop
                  ? 28
                  : r.isTablet
                  ? 24
                  : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon block — mirrors avatar block
                    Container(
                      width: r.avatarSize,
                      height: r.avatarSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          r.isDesktop ? 22 : 18,
                        ),
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.manage_accounts_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    SizedBox(width: r.isDesktop ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login Sessions',
                            style: TextStyle(
                              fontSize: r.heroNameSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Monitor and control active device sessions',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: r.bodyTextSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 14),
                // Stat row — same _heroStat pattern
                Row(
                  children: [
                    _heroStat('${_allSessions.length}', 'Total Users', r),
                    _heroVDiv(),
                    _heroStat('$_activeCount', 'Logged In', r),
                    _heroVDiv(),
                    _heroStat('$_idleCount', 'Logged Out', r),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String v, String l, Responsive r) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _heroVDiv() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.12));

  // ── Search bar ───────────────────────────────────────────────────────────────
  Widget _buildSearchBar(Responsive r) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14, color: _textDark),
        decoration: InputDecoration(
          hintText: 'Search by name, username, role or device…',
          hintStyle: const TextStyle(color: _textLight, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _textMid),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────────
  Widget _buildFilterChips(Responsive r) {
    final opts = ['All', 'LoggedIn', 'LoggedOut'];
    final labels = {
      'All': 'All Users',
      'LoggedIn': 'Logged In',
      'LoggedOut': 'Logged Out',
    };
    return Row(
      children: opts.map((opt) {
        final selected = _filterStatus == opt;
        final color = opt == 'LoggedIn'
            ? _accent
            : opt == 'LoggedOut'
            ? _textMid
            : _primary;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filterStatus = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? color : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color : _border,
                  width: 1.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                labels[opt]!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _textMid,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Desktop 2-col grid ───────────────────────────────────────────────────────
  Widget _buildTwoColGrid(Responsive r) {
    final items = _filtered;
    return Column(
      children: List.generate((items.length / 2).ceil(), (i) {
        final a = items[i * 2];
        final b = (i * 2 + 1 < items.length) ? items[i * 2 + 1] : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSessionCard(r, a)),
                const SizedBox(width: 12),
                Expanded(
                  child: b != null ? _buildSessionCard(r, b) : const SizedBox(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Single col list ──────────────────────────────────────────────────────────
  Widget _buildSingleColList(Responsive r) {
    return Column(
      children: _filtered
          .map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSessionCard(r, s),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmpty(Responsive r) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.symmetric(vertical: 48),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(r.cardRadius),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(Icons.people_outline_rounded, size: 48, color: _textLight),
        const SizedBox(height: 12),
        const Text(
          'No users found',
          style: TextStyle(
            color: _textMid,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // SESSION CARD — matches section card structure from profile screen
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSessionCard(Responsive r, SessionUser user) {
    final isActive = user.isLoggedIn;
    final roleColor = _roleColor(user.roleName);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: isActive ? _accent.withOpacity(0.3) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header — same as _buildSection header ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Avatar — same style as profile hero avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: roleColor.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: r.sectionTitleSize,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.username,
                        style: const TextStyle(color: _textMid, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge — same pill pattern as profile
                _statusBadge(isActive),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: _border),

          // ── Info rows — same _buildInfoRow style ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                _infoRow(
                  r,
                  'Role',
                  user.roleName,
                  pill: true,
                  pillColor: roleColor,
                ),
                _infoRow(
                  r,
                  'Device',
                  isActive ? (user.sessionDevice ?? 'Unknown device') : '-',
                ),
                _infoRow(r, 'Last Login', _timeAgo(user.lastLoginAt)),
              ],
            ),
          ),

          // ── Action area ────────────────────────────────────────────────────
          // ── Action area ────────────────────────────────────────────────────
          // ── Action area ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ✅ ALWAYS AVAILABLE
                OutlinedButton.icon(
                  onPressed: () => _handleResetPassword(user),
                  icon: const Icon(Icons.lock_reset, size: 14),
                  label: const Text('Reset Pass'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: BorderSide(color: _primary),
                  ),
                ),

                // ✅ ONLY IF LOGGED IN
                if (isActive) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _handleForceLogout(user),
                    icon: const Icon(Icons.logout_rounded, size: 14),
                    label: const Text('Force Logout'),
                    style: FilledButton.styleFrom(backgroundColor: _red),
                  ),
                ],
              ],
            ),
          ),
          // else
          //   Padding(
          //     padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.end,
          //       children: [
          //         Icon(
          //           Icons.check_circle_outline_rounded,
          //           size: 14,
          //           color: _textLight,
          //         ),
          //         const SizedBox(width: 5),
          //         Text(
          //           'No active session',
          //           style: TextStyle(
          //             fontSize: 12,
          //             color: _textLight,
          //             fontStyle: FontStyle.italic,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }

  // ── Info row — same pattern as profile _buildInfoRow ────────────────────────
  Widget _infoRow(
    Responsive r,
    String label,
    String value, {
    bool pill = false,
    Color pillColor = _primary,
  }) {
    final isEmpty = value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.infoLabelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _textMid,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: pill && !isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: pillColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          color: pillColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: isEmpty ? _textLight : _textDark,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResetPassword(SessionUser user) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Password',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 13,
                  color: _textMid,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info banner ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: _amber),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'User will be logged out from all devices and must change this password on next login.',
                        style: TextStyle(fontSize: 12, color: _textMid),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── New password ────────────────────────────────────────────
              TextField(
                controller: passwordController,
                obscureText: obscureNew,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setDlg(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Confirm password ────────────────────────────────────────
              TextField(
                controller: confirmController,
                obscureText: obscureConfirm,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: const TextStyle(fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setDlg(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _textMid)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.lock_reset, size: 16),
              label: const Text('Reset'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    // ── Client-side validation ────────────────────────────────────────────────
    final newPass = passwordController.text.trim();
    final confirmPass = confirmController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _snack('Please fill in both password fields', _amber);
      return;
    }
    if (newPass != confirmPass) {
      _snack('Passwords do not match', _red);
      return;
    }
    if (newPass.length < 8) {
      _snack('Password must be at least 8 characters', _red);
      return;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(newPass)) {
      _snack('Password must contain at least one letter', _red);
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPass)) {
      _snack('Password must contain at least one number', _red);
      return;
    }

    setState(() => _actionLoading = true);

    try {
      final res = await ApiClient.post('/auth/reset-password', {
        'emp_id': user.empId,
        'new_password': newPass,
        'confirm_password': confirmPass,
      });

      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        _snack(
          '✓ Password reset for ${user.fullName}. They are now logged out from all devices.',
          _accent,
        );
        // ── Refresh list so session card updates to "Logged Out" ─────────────
        await _loadSessions();
      } else {
        _snack(body['message'] ?? 'Reset failed', _red);
      }
    } catch (e) {
      _snack('Network error. Please try again.', _red);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  // ── Status badge — same pill style as profile _statusBadge ──────────────────
  Widget _statusBadge(bool isActive) {
    final color = isActive ? _accent : _textLight;
    final label = isActive ? 'Logged In' : 'Logged Out';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
