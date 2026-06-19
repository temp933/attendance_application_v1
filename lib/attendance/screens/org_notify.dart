import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../providers/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1 — MODELS
// ─────────────────────────────────────────────────────────────────────────────

int _parseInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
double _parseDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

class OrgNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  final String scope;
  final String status;
  final int totalTargets;
  final int sentCount;
  final int failedCount;
  final int openedCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? scheduledAt;
  final String? imageUrl;

  OrgNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.scope,
    required this.status,
    required this.totalTargets,
    required this.sentCount,
    required this.failedCount,
    required this.openedCount,
    required this.createdBy,
    required this.createdAt,
    this.sentAt,
    this.scheduledAt,
    this.imageUrl,
  });

  factory OrgNotification.fromJson(Map<String, dynamic> j) => OrgNotification(
    id: _parseInt(j['id']),
    title: j['title'] ?? '',
    message: j['message'] ?? '',
    type: j['type'] ?? 'general',
    scope: j['scope'] ?? 'all',
    status: j['status'] ?? 'draft',
    totalTargets: _parseInt(j['total_targets']),
    sentCount: _parseInt(j['sent_count']),
    failedCount: _parseInt(j['failed_count']),
    openedCount: _parseInt(j['opened_count']),
    createdBy: j['created_by']?.toString() ?? '',
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
        : DateTime.now(),
    sentAt: j['sent_at'] != null ? DateTime.tryParse(j['sent_at']) : null,
    scheduledAt: j['scheduled_at'] != null
        ? DateTime.tryParse(j['scheduled_at'])
        : null,
    imageUrl: j['image_url'],
  );

  double get openRate =>
      sentCount > 0 ? (openedCount / sentCount * 100).clamp(0.0, 100.0) : 0.0;
}

class OrgDashboardSummary {
  final int totalNotifications;
  final int totalSent;
  final int totalFailed;
  final int totalOpened;
  final int scheduledCount;
  final double openRate;

  OrgDashboardSummary({
    required this.totalNotifications,
    required this.totalSent,
    required this.totalFailed,
    required this.totalOpened,
    required this.scheduledCount,
    required this.openRate,
  });

  factory OrgDashboardSummary.fromJson(Map<String, dynamic> j) =>
      OrgDashboardSummary(
        totalNotifications: _parseInt(j['total_notifications']),
        totalSent: _parseInt(j['total_sent']),
        totalFailed: _parseInt(j['total_failed']),
        totalOpened: _parseInt(j['total_opened']),
        scheduledCount: _parseInt(j['scheduled_count']),
        openRate: _parseDouble(j['open_rate']),
      );
}

class OrgTargetPreview {
  final int totalEmployees;

  OrgTargetPreview({required this.totalEmployees});

  factory OrgTargetPreview.fromJson(Map<String, dynamic> j) =>
      OrgTargetPreview(totalEmployees: _parseInt(j['total_employees']));
}

class OrgAnalyticsTrend {
  final String date;
  final int sent;
  final int failed;
  final int opened;

  OrgAnalyticsTrend({
    required this.date,
    required this.sent,
    required this.failed,
    required this.opened,
  });

  factory OrgAnalyticsTrend.fromJson(Map<String, dynamic> j) =>
      OrgAnalyticsTrend(
        date: j['date'] ?? '',
        sent: _parseInt(j['sent']),
        failed: _parseInt(j['failed']),
        opened: _parseInt(j['opened']),
      );
}

class OrgTypeBreakdown {
  final String type;
  final int total;
  final int totalSent;
  final int totalFailed;
  final double openRate;

  OrgTypeBreakdown({
    required this.type,
    required this.total,
    required this.totalSent,
    required this.totalFailed,
    required this.openRate,
  });

  factory OrgTypeBreakdown.fromJson(Map<String, dynamic> j) => OrgTypeBreakdown(
    type: j['type'] ?? '',
    total: _parseInt(j['total']),
    totalSent: _parseInt(j['total_sent']),
    totalFailed: _parseInt(j['total_failed']),
    openRate: _parseDouble(j['open_rate']),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2 — SERVICE
// tenant_id is automatically injected by authMiddleware via the JWT token
// ─────────────────────────────────────────────────────────────────────────────

class OrgNotifyService {
  final String baseUrl;
  final String token;

  const OrgNotifyService({required this.baseUrl, required this.token});

  String get _base => '$baseUrl/org-notifications';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<T> _get<T>(String path, T Function(dynamic) parse) async {
    final res = await http.get(Uri.parse('$_base$path'), headers: _headers);
    if (res.statusCode == 200) return parse(json.decode(res.body));
    throw Exception('GET $path failed: ${res.statusCode}');
  }

  Future<T> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(dynamic) parse,
  ) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: json.encode(body),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return parse(json.decode(res.body));
    }
    final err = json.decode(res.body);
    throw Exception(err['message'] ?? 'POST $path failed');
  }

  Future<void> _patch(String path, [Map<String, dynamic>? body]) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: _headers,
      body: body != null ? json.encode(body) : null,
    );
    if (res.statusCode != 200) {
      final err = json.decode(res.body);
      throw Exception(err['message'] ?? 'PATCH $path failed');
    }
  }

  Future<Map<String, dynamic>> dashboard() => _get('/dashboard', (d) => d);

  Future<List<Map<String, dynamic>>> departments() =>
      _get('/departments', (d) => List<Map<String, dynamic>>.from(d['data']));

  Future<List<Map<String, dynamic>>> roles() =>
      _get('/roles', (d) => List<Map<String, dynamic>>.from(d['data']));

  Future<List<Map<String, dynamic>>> employees() =>
      _get('/employees', (d) => List<Map<String, dynamic>>.from(d['data']));

  // Future<Map<String, dynamic>> history({
  //   int page = 1,
  //   int limit = 20,
  //   String? type,
  //   String? status,
  //   String? search,
  // }) async {
  //   final q = <String, String>{
  //     'page': '$page',
  //     'limit': '$limit',
  //     if (type != null) 'type': type,
  //     if (status != null) 'status': status,
  //     if (search != null && search.isNotEmpty) 'search': search,
  //   };
  //   final uri = Uri.parse('$_base/history').replace(queryParameters: q);
  //   final res = await http.get(uri, headers: _headers);
  //   if (res.statusCode == 200) return json.decode(res.body);
  //   throw Exception('history failed: ${res.statusCode}');
  // }

  Future<Map<String, dynamic>> send({
    required String title,
    required String message,
    required String type,
    required String scope,
    Map<String, dynamic>? scopeMeta,
    String? imageUrl,
    String? scheduledAt,
  }) => _post('/send', {
    'title': title,
    'message': message,
    'type': type,
    'scope': scope,
    if (scopeMeta != null) 'scope_meta': scopeMeta,
    if (imageUrl != null) 'image_url': imageUrl,
    if (scheduledAt != null) 'scheduled_at': scheduledAt,
  }, (d) => d);

  Future<Map<String, dynamic>> detail(int id) => _get('/$id', (d) => d);
  Future<void> cancel(int id) => _patch('/$id/cancel');
  Future<Map<String, dynamic>> retry(int id) =>
      _post('/$id/retry', {}, (d) => d);

  Future<Map<String, dynamic>> analytics() =>
      _get('/analytics/summary', (d) => d);

  Future<OrgTargetPreview> previewTargets({
    required String scope,
    Map<String, dynamic>? scopeMeta,
  }) => _post('/preview-targets', {
    'scope': scope,
    if (scopeMeta != null) 'scope_meta': scopeMeta,
  }, (d) => OrgTargetPreview.fromJson(d));
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3 — THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _bg = Color(0xFFF5F6FA);
const _white = Colors.white;
const _accent = Color(0xFF4361EE);
const _success = Color(0xFF06D6A0);
const _warning = Color(0xFFFFB703);
const _error = Color(0xFFEF476F);
const _purple = Color(0xFF7209B7);
const _cyan = Color(0xFF4CC9F0);
const _teal = Color(0xFF0F9B8E);
const _textPri = Color(0xFF1A1A2E);
const _textSec = Color(0xFF6B7280);
const _textMut = Color(0xFF9CA3AF);
const _borderCol = Color(0xFFE2E8F0);
const _divider = Color(0xFFF1F3F4);

// Org-specific types — no global/system types like app_update/billing_reminder
const _orgTypes = [
  'general',
  'announcement',
  'policy_update',
  'urgent',
  'reminder',
];

// Org-specific scopes
const _orgScopes = ['all', 'by_department', 'by_role', 'specific'];

Color _statusColor(String s) {
  switch (s.toLowerCase()) {
    case 'sent':
      return _success;
    case 'sending':
      return _accent;
    case 'scheduled':
      return _warning;
    case 'failed':
      return _error;
    case 'cancelled':
      return _textMut;
    case 'draft':
      return _purple;
    default:
      return _textSec;
  }
}

Color _typeColor(String t) {
  switch (t.toLowerCase()) {
    case 'general':
      return _accent;
    case 'announcement':
      return _purple;
    case 'policy_update':
      return _teal;
    case 'urgent':
      return _error;
    case 'reminder':
      return _warning;
    default:
      return _textSec;
  }
}

String _typeLabel(String t) {
  switch (t) {
    case 'general':
      return 'General';
    case 'announcement':
      return 'Announcement';
    case 'policy_update':
      return 'Policy Update';
    case 'urgent':
      return 'Urgent';
    case 'reminder':
      return 'Reminder';
    default:
      return t;
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'general':
      return Icons.campaign_outlined;
    case 'announcement':
      return Icons.record_voice_over_outlined;
    case 'policy_update':
      return Icons.policy_outlined;
    case 'urgent':
      return Icons.priority_high_rounded;
    case 'reminder':
      return Icons.alarm_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

String _scopeLabel(String s) {
  switch (s) {
    case 'all':
      return 'All Employees';
    case 'by_department':
      return 'By Department';
    case 'by_role':
      return 'By Role';
    case 'specific':
      return 'Specific Employees';
    default:
      return s;
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4 — SHARED WIDGETS (prefixed _O to avoid conflict with global file)
// ─────────────────────────────────────────────────────────────────────────────

class _OCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderLeft;
  final Color? borderColor;

  const _OCard({
    required this.child,
    this.padding,
    this.onTap,
    this.borderLeft,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: borderLeft != null
            ? Border(left: BorderSide(color: borderLeft!, width: 3))
            : Border.all(color: borderColor ?? _borderCol),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    ),
  );
}

class _OStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final String? sub;

  const _OStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _white,
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
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const Spacer(),
            if (sub != null)
              Text(
                sub!,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: _textSec)),
      ],
    ),
  );
}

class _OStatusChip extends StatelessWidget {
  final String status;
  const _OStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    final label = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : 'Unknown';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _OTypeChip extends StatelessWidget {
  final String type;
  const _OTypeChip(this.type);

  @override
  Widget build(BuildContext context) {
    final c = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), color: c, size: 11),
          const SizedBox(width: 4),
          Text(
            _typeLabel(type),
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _OSectionHeader(this.title, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      if (icon != null) ...[
        Icon(icon, size: 15, color: _accent),
        const SizedBox(width: 6),
      ],
      Text(
        title,
        style: const TextStyle(
          color: _textPri,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _OStatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _OStatPill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 3),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _OProgressRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _OProgressRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(color: _textSec, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '$value / $total',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: _divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;
  const _OFilterChip({
    required this.label,
    required this.selected,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? _accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : _white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c : _borderCol),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 11, color: _white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? _white : _textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ONotifTile extends StatelessWidget {
  final OrgNotification n;
  final VoidCallback? onTap;
  const _ONotifTile(this.n, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d · h:mm a');
    return _OCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  n.title,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _OStatusChip(n.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            n.message,
            style: const TextStyle(color: _textSec, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _OTypeChip(n.type),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _scopeLabel(n.scope),
                    style: const TextStyle(color: _textMut, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (n.status == 'sent') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _OStatPill(
                  icon: Icons.send_outlined,
                  value: _fmt(n.sentCount),
                  color: _success,
                ),
                const SizedBox(width: 10),
                _OStatPill(
                  icon: Icons.error_outline,
                  value: _fmt(n.failedCount),
                  color: _error,
                ),
                const SizedBox(width: 10),
                _OStatPill(
                  icon: Icons.visibility_outlined,
                  value: '${n.openRate.toStringAsFixed(1)}%',
                  color: _cyan,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            n.scheduledAt != null
                ? 'Scheduled: ${fmt.format(n.scheduledAt!)}'
                : n.sentAt != null
                ? 'Sent: ${fmt.format(n.sentAt!)}'
                : 'Created: ${fmt.format(n.createdAt)}',
            style: const TextStyle(color: _textMut, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

extension _StrExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5 — MAIN CONSOLE
// ─────────────────────────────────────────────────────────────────────────────

class OrgNotifyConsole extends StatefulWidget {
  const OrgNotifyConsole({super.key});

  @override
  State<OrgNotifyConsole> createState() => _OrgNotifyConsoleState();
}

class _OrgNotifyConsoleState extends State<OrgNotifyConsole> {
  late final OrgNotifyService _svc;
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.dashboard_outlined, label: 'Overview'),
    (icon: Icons.send_outlined, label: 'Send'),
    (icon: Icons.bar_chart_outlined, label: 'Analytics'),
  ];

  final _overviewKey = GlobalKey<_OrgOverviewScreenState>();
  final _analyticsKey = GlobalKey<_OrgAnalyticsScreenState>();

  @override
  void initState() {
    super.initState();
    _svc = OrgNotifyService(
      baseUrl: ApiConfig.baseUrl,
      token: ApiConfig.getToken(),
    );
  }

  void _refreshCurrentTab(int i) {
    switch (i) {
      case 0:
        _overviewKey.currentState?._load();
        break;

      case 2:
        _analyticsKey.currentState?._load();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _OrgOverviewScreen(key: _overviewKey, svc: _svc),
      _OrgSendScreen(svc: _svc),
      _OrgAnalyticsScreen(key: _analyticsKey, svc: _svc),
    ];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A56DB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ORG ADMIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            tooltip: 'Refresh',
            onPressed: () => _refreshCurrentTab(_tab),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: _white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: List.generate(_tabs.length, (i) {
                    final t = _tabs[i];
                    final sel = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_tab == i) _refreshCurrentTab(i);
                          setState(() => _tab = i);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.label,
                                style: TextStyle(
                                  color: sel ? _accent : _textSec,
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                height: 3,
                                width: sel ? 44 : 0,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                Container(height: 1, color: _borderCol),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _tab, children: screens),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6 — OVERVIEW SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrgOverviewScreen extends StatefulWidget {
  final OrgNotifyService svc;
  const _OrgOverviewScreen({super.key, required this.svc});

  @override
  State<_OrgOverviewScreen> createState() => _OrgOverviewScreenState();
}

class _OrgOverviewScreenState extends State<_OrgOverviewScreen> {
  OrgDashboardSummary? _summary;
  List<OrgNotification> _recent = [];
  bool _loading = true;
  String? _errMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errMsg = null;
    });
    try {
      final data = await widget.svc.dashboard();
      setState(() {
        _summary = OrgDashboardSummary.fromJson(data['summary']);
        _recent = (data['recent'] as List)
            .map((e) => OrgNotification.fromJson(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errMsg = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    if (_errMsg != null) return _OErrorView(message: _errMsg!, onRetry: _load);

    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _OStatCard(
                          label: 'Total Sent',
                          value: _fmt(s.totalSent),
                          icon: Icons.send_outlined,
                          color: _accent,
                        ),
                        _OStatCard(
                          label: 'Failed',
                          value: _fmt(s.totalFailed),
                          icon: Icons.error_outline,
                          color: _error,
                        ),
                        _OStatCard(
                          label: 'Open Rate',
                          value: '${s.openRate.toStringAsFixed(1)}%',
                          icon: Icons.visibility_outlined,
                          color: _cyan,
                          sub: '${_fmt(s.totalOpened)} opens',
                        ),
                        _OStatCard(
                          label: 'Scheduled',
                          value: _fmt(s.scheduledCount),
                          icon: Icons.schedule_outlined,
                          color: _warning,
                        ),
                        _OStatCard(
                          label: 'Total',
                          value: _fmt(s.totalNotifications),
                          icon: Icons.all_inbox_outlined,
                          color: _purple,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _OSectionHeader(
                    'Recent Notifications',
                    icon: Icons.notifications_outlined,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (_recent.isEmpty)
            const SliverToBoxAdapter(child: _OEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ONotifTile(
                      _recent[i],
                      onTap: () => _openDetail(ctx, _recent[i].id),
                    ),
                  ),
                  childCount: _recent.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext ctx, int id) => Navigator.push(
    ctx,
    MaterialPageRoute(
      builder: (_) => _OrgDetailScreen(svc: widget.svc, id: id),
    ),
  ).then((_) => _load());
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 7 — SEND SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrgSendScreen extends StatefulWidget {
  final OrgNotifyService svc;
  const _OrgSendScreen({required this.svc});

  @override
  State<_OrgSendScreen> createState() => _OrgSendScreenState();
}

class _OrgSendScreenState extends State<_OrgSendScreen> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();

  String _type = 'general';
  String _scope = 'all';
  bool _schedule = false;
  DateTime? _scheduledAt;
  bool _sending = false;
  bool _previewing = false;
  OrgTargetPreview? _preview;

  // Pickers
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _employees = [];

  List<Map<String, dynamic>> _selectedDepts = [];
  List<Map<String, dynamic>> _selectedRoles = [];
  List<Map<String, dynamic>> _selectedEmps = [];

  bool _depsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _depsLoading = true);
    try {
      final results = await Future.wait([
        widget.svc.departments(),
        widget.svc.roles(),
        widget.svc.employees(),
      ]);
      setState(() {
        _departments = results[0];
        _roles = results[1];
        _employees = results[2];
      });
    } catch (e) {
      debugPrint('[org-notify] meta load failed: $e');
    }
    setState(() => _depsLoading = false);
  }

  Map<String, dynamic>? get _scopeMeta {
    switch (_scope) {
      case 'by_department':
        final ids = _selectedDepts.map((d) => d['id']).toList();
        return ids.isEmpty ? null : {'department_ids': ids};
      case 'by_role':
        final ids = _selectedRoles.map((r) => r['id']).toList();
        return ids.isEmpty ? null : {'role_ids': ids};
      case 'specific':
        final ids = _selectedEmps.map((e) => e['emp_id']).toList();
        return ids.isEmpty ? null : {'emp_ids': ids};
      default:
        return null;
    }
  }

  Future<void> _doPreview() async {
    setState(() => _previewing = true);
    try {
      final p = await widget.svc.previewTargets(
        scope: _scope,
        scopeMeta: _scopeMeta,
      );
      setState(() => _preview = p);
    } catch (e) {
      _snack('Preview failed: $e');
    } finally {
      setState(() => _previewing = false);
    }
  }

  Future<void> _doSend() async {
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      _snack('Title and message are required');
      return;
    }
    if (_scope == 'by_department' && _selectedDepts.isEmpty) {
      _snack('Please select at least one department');
      return;
    }
    if (_scope == 'by_role' && _selectedRoles.isEmpty) {
      _snack('Please select at least one role');
      return;
    }
    if (_scope == 'specific' && _selectedEmps.isEmpty) {
      _snack('Please select at least one employee');
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.svc.send(
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
        type: _type,
        scope: _scope,
        scopeMeta: _scopeMeta,
        imageUrl: _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
        scheduledAt: _schedule && _scheduledAt != null
            ? _scheduledAt!.toIso8601String()
            : null,
      );
      _snack(
        _schedule ? 'Notification scheduled!' : 'Notification sent!',
        isSuccess: true,
      );
      _titleCtrl.clear();
      _msgCtrl.clear();
      _imgCtrl.clear();
      setState(() {
        _preview = null;
        _schedule = false;
        _scheduledAt = null;
        _selectedDepts = [];
        _selectedRoles = [];
        _selectedEmps = [];
      });
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _success : _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(
      () => _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  // ── Generic multi-select bottom sheet ───────────────────────────────────────
  Future<void> _showPicker<T>({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelOf,
    required String Function(Map<String, dynamic>) keyOf,
    required List<Map<String, dynamic>> selected,
    required void Function(List<Map<String, dynamic>>) onDone,
  }) async {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(items);
    final tempSelected = Set<String>.from(selected.map((e) => keyOf(e)));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          void doFilter(String q) {
            setModal(() {
              filtered = q.isEmpty
                  ? List.from(items)
                  : items
                        .where(
                          (o) => labelOf(
                            o,
                          ).toLowerCase().contains(q.toLowerCase()),
                        )
                        .toList();
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: _textPri,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onDone(
                                items
                                    .where(
                                      (o) => tempSelected.contains(keyOf(o)),
                                    )
                                    .toList(),
                              );
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _borderCol),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: doFilter,
                          style: const TextStyle(color: _textPri, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(color: _textMut, fontSize: 13),
                            prefixIcon: Icon(
                              Icons.search,
                              color: _textMut,
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${tempSelected.length} selected',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (tempSelected.isNotEmpty)
                            GestureDetector(
                              onTap: () => setModal(() => tempSelected.clear()),
                              child: const Text(
                                'Clear all',
                                style: TextStyle(color: _error, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: _borderCol),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No items found',
                            style: TextStyle(color: _textMut),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            final key = keyOf(item);
                            final isSel = tempSelected.contains(key);
                            return InkWell(
                              onTap: () => setModal(() {
                                if (isSel)
                                  tempSelected.remove(key);
                                else
                                  tempSelected.add(key);
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? _accent.withOpacity(0.05)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(color: _divider),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? _accent
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isSel ? _accent : _borderCol,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSel
                                          ? const Icon(
                                              Icons.check,
                                              color: _white,
                                              size: 13,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      labelOf(item),
                                      style: const TextStyle(
                                        color: _textPri,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  InputDecoration _fieldDec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13, color: _textSec),
        hintStyle: const TextStyle(fontSize: 13, color: _textMut),
        prefixIcon: icon != null ? Icon(icon, color: _textMut, size: 18) : null,
        filled: true,
        fillColor: _white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _borderCol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      );

  // ── Tags row for selected items ─────────────────────────────────────────────
  Widget _tagsRow(
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) labelOf,
    String Function(Map<String, dynamic>) keyOf,
    VoidCallback onRemove(String key),
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items.map((o) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labelOf(o),
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onRemove(keyOf(o)),
                  child: const Icon(Icons.close, size: 12, color: _accent),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Type picker ────────────────────────────────────────────────
            _OSectionHeader('Notification Type', icon: Icons.category_outlined),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _orgTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final t = _orgTypes[i];
                  final sel = _type == t;
                  final c = _typeColor(t);
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? c : _white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? c : _borderCol),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _typeIcon(t),
                            color: sel ? _white : _textMut,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _typeLabel(t),
                            style: TextStyle(
                              color: sel ? _white : _textSec,
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // ── Target scope ───────────────────────────────────────────────
            _OSectionHeader('Send To', icon: Icons.people_outline),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _orgScopes.map((s) {
                final sel = _scope == s;
                return GestureDetector(
                  onTap: () => setState(() {
                    _scope = s;
                    _preview = null;
                    if (s != 'by_department') _selectedDepts = [];
                    if (s != 'by_role') _selectedRoles = [];
                    if (s != 'specific') _selectedEmps = [];
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: sel ? _accent : _white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? _accent : _borderCol),
                    ),
                    child: Text(
                      _scopeLabel(s),
                      style: TextStyle(
                        color: sel ? _white : _textSec,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // ── Scope pickers ──────────────────────────────────────────────
            if (_scope == 'by_department') ...[
              GestureDetector(
                onTap: _depsLoading
                    ? null
                    : () => _showPicker(
                        title: 'Select Departments',
                        items: _departments,
                        labelOf: (d) => d['department_name'] ?? '',
                        keyOf: (d) => d['id'].toString(),
                        selected: _selectedDepts,
                        onDone: (v) => setState(() {
                          _selectedDepts = v;
                          _preview = null;
                        }),
                      ),
                child: _OCard(
                  borderColor: _accent.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.domain_outlined,
                        color: _accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDepts.isEmpty
                              ? 'Tap to select departments...'
                              : '${_selectedDepts.length} department${_selectedDepts.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: _selectedDepts.isEmpty ? _textMut : _textPri,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: _textMut,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
              _tagsRow(
                _selectedDepts,
                (d) => d['department_name'] ?? '',
                (d) => d['id'].toString(),
                (key) =>
                    () => setState(() {
                      _selectedDepts.removeWhere(
                        (d) => d['id'].toString() == key,
                      );
                      _preview = null;
                    }),
              ),
              const SizedBox(height: 10),
            ],

            if (_scope == 'by_role') ...[
              GestureDetector(
                onTap: () => _showPicker(
                  title: 'Select Roles',
                  items: _roles,
                  labelOf: (r) => r['role_name'] ?? '',
                  keyOf: (r) => r['id'].toString(),
                  selected: _selectedRoles,
                  onDone: (v) => setState(() {
                    _selectedRoles = v;
                    _preview = null;
                  }),
                ),
                child: _OCard(
                  borderColor: _accent.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        color: _accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedRoles.isEmpty
                              ? 'Tap to select roles...'
                              : '${_selectedRoles.length} role${_selectedRoles.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: _selectedRoles.isEmpty ? _textMut : _textPri,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: _textMut,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
              _tagsRow(
                _selectedRoles,
                (r) => r['role_name'] ?? '',
                (r) => r['id'].toString(),
                (key) =>
                    () => setState(() {
                      _selectedRoles.removeWhere(
                        (r) => r['id'].toString() == key,
                      );
                      _preview = null;
                    }),
              ),
              const SizedBox(height: 10),
            ],

            if (_scope == 'specific') ...[
              GestureDetector(
                onTap: () => _showPicker(
                  title: 'Select Employees',
                  items: _employees,
                  labelOf: (e) =>
                      '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim(),
                  keyOf: (e) => e['emp_id'].toString(),
                  selected: _selectedEmps,
                  onDone: (v) => setState(() {
                    _selectedEmps = v;
                    _preview = null;
                  }),
                ),
                child: _OCard(
                  borderColor: _accent.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_search_outlined,
                        color: _accent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedEmps.isEmpty
                              ? 'Tap to select employees...'
                              : '${_selectedEmps.length} employee${_selectedEmps.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: _selectedEmps.isEmpty ? _textMut : _textPri,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: _textMut,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),
              _tagsRow(
                _selectedEmps,
                (e) =>
                    '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'.trim(),
                (e) => e['emp_id'].toString(),
                (key) =>
                    () => setState(() {
                      _selectedEmps.removeWhere(
                        (e) => e['emp_id'].toString() == key,
                      );
                      _preview = null;
                    }),
              ),
              const SizedBox(height: 10),
            ],

            // ── Preview audience ───────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _previewing ? null : _doPreview,
                icon: _previewing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.visibility_outlined,
                        color: _accent,
                        size: 16,
                      ),
                label: const Text(
                  'Preview audience',
                  style: TextStyle(color: _accent, fontSize: 13),
                ),
              ),
            ),
            if (_preview != null) ...[
              _OCard(
                borderColor: _accent.withOpacity(0.25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: _accent, size: 18),
                    const SizedBox(width: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: _textSec, fontSize: 13),
                        children: [
                          TextSpan(
                            text:
                                '${_fmt(_preview!.totalEmployees)} employee${_preview!.totalEmployees == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const TextSpan(
                            text: ' will receive this notification',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 8),
            // ── Content ────────────────────────────────────────────────────
            _OSectionHeader('Content', icon: Icons.edit_outlined),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: _textPri, fontSize: 14),
              decoration: _fieldDec(
                'Notification Title *',
                hint: 'e.g. Office Closed Tomorrow',
                icon: Icons.title_outlined,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msgCtrl,
              minLines: 3,
              maxLines: 6,
              style: const TextStyle(color: _textPri, fontSize: 13),
              decoration: _fieldDec(
                'Message *',
                hint: 'Write your notification body here...',
                icon: Icons.notes_outlined,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _imgCtrl,
              style: const TextStyle(color: _textPri, fontSize: 13),
              decoration: _fieldDec(
                'Image / Banner URL (optional)',
                hint: 'https://...',
                icon: Icons.image_outlined,
              ),
            ),
            const SizedBox(height: 16),

            // ── Schedule toggle ────────────────────────────────────────────
            _OCard(
              borderColor: _warning.withOpacity(0.35),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_outlined,
                    color: _warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Schedule for later',
                    style: TextStyle(color: _textPri, fontSize: 13),
                  ),
                  const Spacer(),
                  Switch(
                    value: _schedule,
                    activeThumbColor: _accent,
                    onChanged: (v) => setState(() => _schedule = v),
                  ),
                ],
              ),
            ),
            if (_schedule) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickSchedule,
                child: _OCard(
                  borderColor: _warning.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: _warning,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _scheduledAt != null
                            ? DateFormat(
                                'MMM d, yyyy  h:mm a',
                              ).format(_scheduledAt!)
                            : 'Tap to pick date & time',
                        style: TextStyle(
                          color: _scheduledAt != null ? _textPri : _textMut,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: _textMut,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            if (_type == 'urgent') ...[
              _OCard(
                borderColor: _error.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.priority_high_rounded, color: _error, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Urgent notifications are delivered with high priority and may override DND settings.',
                        style: TextStyle(color: _error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _doSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'urgent' ? _error : _accent,
                  foregroundColor: _white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: _white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _schedule
                            ? Icons.schedule_send_outlined
                            : Icons.send_outlined,
                      ),
                label: Text(
                  _schedule ? 'Schedule Notification' : 'Send Now',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
        if (_sending)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                child: CircularProgressIndicator(
                  color: _accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _msgCtrl, _imgCtrl]) c.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 8 — ANALYTICS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrgAnalyticsScreen extends StatefulWidget {
  final OrgNotifyService svc;
  const _OrgAnalyticsScreen({super.key, required this.svc});

  @override
  State<_OrgAnalyticsScreen> createState() => _OrgAnalyticsScreenState();
}

class _OrgAnalyticsScreenState extends State<_OrgAnalyticsScreen> {
  List<OrgAnalyticsTrend> _trend = [];
  List<OrgTypeBreakdown> _byType = [];
  bool _loading = true;
  String? _errMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errMsg = null;
    });
    try {
      final data = await widget.svc.analytics();
      setState(() {
        _trend = (data['trend'] as List)
            .map((e) => OrgAnalyticsTrend.fromJson(e))
            .toList();
        _byType = (data['by_type'] as List)
            .map((e) => OrgTypeBreakdown.fromJson(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errMsg = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
      );
    if (_errMsg != null) return _OErrorView(message: _errMsg!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OSectionHeader('30-Day Trend', icon: Icons.show_chart_outlined),
          const SizedBox(height: 12),
          _OCard(
            child: _trend.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No data', style: TextStyle(color: _textMut)),
                    ),
                  )
                : _OBarChart(trend: _trend),
          ),
          const SizedBox(height: 20),
          _OSectionHeader('Performance by Type', icon: Icons.pie_chart_outline),
          const SizedBox(height: 12),
          if (_byType.isEmpty)
            const Center(
              child: Text('No data', style: TextStyle(color: _textMut)),
            )
          else
            ..._byType.map((t) {
              final c = _typeColor(t.type);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OCard(
                  borderLeft: c,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _OTypeChip(t.type),
                          const Spacer(),
                          Text(
                            '${_fmt(t.total)} sent',
                            style: const TextStyle(
                              color: _textMut,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _OProgressRow(
                        label: 'Sent',
                        value: t.totalSent,
                        total: t.total > 0 ? t.total : 1,
                        color: _success,
                      ),
                      _OProgressRow(
                        label: 'Failed',
                        value: t.totalFailed,
                        total: (t.totalSent + t.totalFailed) > 0
                            ? t.totalSent + t.totalFailed
                            : 1,
                        color: _error,
                      ),
                      Row(
                        children: [
                          const Text(
                            'Open Rate',
                            style: TextStyle(color: _textSec, fontSize: 12),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _cyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _cyan.withOpacity(0.2)),
                            ),
                            child: Text(
                              '${t.openRate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: _cyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OBarChart extends StatelessWidget {
  final List<OrgAnalyticsTrend> trend;
  const _OBarChart({required this.trend});

  @override
  Widget build(BuildContext context) {
    final maxVal = trend.fold<int>(0, (m, t) => t.sent > m ? t.sent : m);
    final show = trend.length > 14 ? trend.sublist(trend.length - 14) : trend;
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: show.map((t) {
          final sentH = maxVal > 0 ? (t.sent / maxVal) * 100 : 0.0;
          final failH = maxVal > 0 ? (t.failed / maxVal) * 100 : 0.0;
          final day = t.date.length >= 10 ? t.date.substring(8, 10) : t.date;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: sentH.clamp(2.0, 100.0),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                      if (failH > 0)
                        Container(
                          height: failH.clamp(2.0, 100.0),
                          decoration: BoxDecoration(
                            color: _error.withOpacity(0.75),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    day,
                    style: const TextStyle(color: _textMut, fontSize: 9),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 10 — DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _OrgDetailScreen extends StatefulWidget {
  final OrgNotifyService svc;
  final int id;
  const _OrgDetailScreen({required this.svc, required this.id});

  @override
  State<_OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<_OrgDetailScreen>
    with WidgetsBindingObserver {
  OrgNotification? _n;
  List<Map<String, dynamic>> _breakdown = [];
  bool _loading = true;
  String? _errMsg;
  bool _retrying = false;
  Timer? _autoRefresh;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errMsg = null;
    });
    try {
      final data = await widget.svc.detail(widget.id);
      setState(() {
        _n = OrgNotification.fromJson(data['notification']);
        _breakdown = List<Map<String, dynamic>>.from(data['breakdown'] ?? []);
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _errMsg = e.toString();
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final r = await widget.svc.retry(widget.id);
      _snack('Recovered ${r['retried'] ?? 0} deliveries', isSuccess: true);
      _load();
    } catch (e) {
      _snack('Retry failed: $e');
    } finally {
      setState(() => _retrying = false);
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _success : _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: _textPri),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Detail',
              style: TextStyle(
                color: _textPri,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Updated ${DateFormat('h:mm:ss a').format(_lastUpdated)}',
              style: const TextStyle(color: _textMut, fontSize: 10),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAED)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _accent, size: 20),
            onPressed: _loading ? null : _load,
          ),
          if (_n?.status == 'sent' && (_n?.failedCount ?? 0) > 0)
            TextButton.icon(
              onPressed: _retrying ? null : _retry,
              icon: _retrying
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh, color: _accent, size: 16),
              label: const Text(
                'Retry Failed',
                style: TextStyle(color: _accent, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            )
          : _errMsg != null
          ? _OErrorView(message: _errMsg!, onRetry: _load)
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final n = _n!;
    final fmt = DateFormat('MMM d, yyyy  h:mm a');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OCard(
          borderLeft: _typeColor(n.type),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OTypeChip(n.type),
                  const SizedBox(width: 8),
                  _OStatusChip(n.status),
                  const Spacer(),
                  Text(
                    '#${n.id}',
                    style: const TextStyle(color: _textMut, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                n.title,
                style: const TextStyle(
                  color: _textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                n.message,
                style: const TextStyle(
                  color: _textSec,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.people_outline, 'Target', _scopeLabel(n.scope)),
              _infoRow(Icons.person_outline, 'Sent by', n.createdBy),
              _infoRow(
                Icons.calendar_today_outlined,
                'Created',
                fmt.format(n.createdAt),
              ),
              if (n.sentAt != null)
                _infoRow(Icons.send_outlined, 'Sent', fmt.format(n.sentAt!)),
              if (n.scheduledAt != null)
                _infoRow(
                  Icons.schedule_outlined,
                  'Scheduled',
                  fmt.format(n.scheduledAt!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OSectionHeader('Delivery Summary', icon: Icons.analytics_outlined),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OMiniStat('Total', _fmt(n.totalTargets), _textPri),
            ),
            const SizedBox(width: 8),
            Expanded(child: _OMiniStat('Sent', _fmt(n.sentCount), _success)),
            const SizedBox(width: 8),
            Expanded(child: _OMiniStat('Failed', _fmt(n.failedCount), _error)),
            const SizedBox(width: 8),
            Expanded(
              child: _OMiniStat(
                'Opened',
                '${n.openRate.toStringAsFixed(1)}%',
                _cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _OCard(
          child: Column(
            children: [
              _OProgressRow(
                label: 'Sent',
                value: n.sentCount,
                total: n.totalTargets > 0 ? n.totalTargets : 1,
                color: _success,
              ),
              _OProgressRow(
                label: 'Failed',
                value: n.failedCount,
                total: n.totalTargets > 0 ? n.totalTargets : 1,
                color: _error,
              ),
              _OProgressRow(
                label: 'Opened',
                value: n.openedCount,
                total: n.sentCount > 0 ? n.sentCount : 1,
                color: _cyan,
              ),
            ],
          ),
        ),
        if (_breakdown.isNotEmpty) ...[
          const SizedBox(height: 16),
          _OSectionHeader('Status Breakdown', icon: Icons.donut_small_outlined),
          const SizedBox(height: 10),
          _OCard(
            child: Column(
              children: _breakdown.map((b) {
                final st = b['delivery_status'] as String? ?? '';
                final count = b['count'] ?? 0;
                final c = _statusColor(st);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        st.toUpperCase(),
                        style: TextStyle(
                          color: c,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, color: _textMut, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _textMut, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: _textSec, fontSize: 12),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _OMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _OMiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => _OCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(label, style: const TextStyle(color: _textMut, fontSize: 11)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 11 — EMPTY & ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _OEmptyState extends StatelessWidget {
  const _OEmptyState();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Center(
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 48, color: _textMut),
          SizedBox(height: 12),
          Text(
            'No notifications found',
            style: TextStyle(color: _textMut, fontSize: 15),
          ),
        ],
      ),
    ),
  );
}

class _OErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: _textMut),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSec),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
