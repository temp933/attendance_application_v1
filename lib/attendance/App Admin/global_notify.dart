// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import '../providers/api_config.dart';
// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 1 — MODELS
// // ─────────────────────────────────────────────────────────────────────────────

// class GnNotification {
//   final int id;
//   final String title;
//   final String message;
//   final String type;
//   final String scope;
//   final String status;
//   final int totalTargets;
//   final int sentCount;
//   final int failedCount;
//   final int deliveredCount;
//   final int openedCount;
//   final String createdBy;
//   final DateTime createdAt;
//   final DateTime? sentAt;
//   final DateTime? scheduledAt;
//   final String? imageUrl;

//   GnNotification({
//     required this.id,
//     required this.title,
//     required this.message,
//     required this.type,
//     required this.scope,
//     required this.status,
//     required this.totalTargets,
//     required this.sentCount,
//     required this.failedCount,
//     required this.deliveredCount,
//     required this.openedCount,
//     required this.createdBy,
//     required this.createdAt,
//     this.sentAt,
//     this.scheduledAt,
//     this.imageUrl,
//   });

//   factory GnNotification.fromJson(Map<String, dynamic> j) => GnNotification(
//     id: j['id'] ?? 0,
//     title: j['title'] ?? '',
//     message: j['message'] ?? '',
//     type: j['type'] ?? 'general',
//     scope: j['scope'] ?? 'all',
//     status: j['status'] ?? 'draft',
//     totalTargets: j['total_targets'] ?? 0,
//     sentCount: j['sent_count'] ?? 0,
//     failedCount: j['failed_count'] ?? 0,
//     deliveredCount: j['delivered_count'] ?? 0,
//     openedCount: j['opened_count'] ?? 0,
//     createdBy: j['created_by'] ?? '',
//     createdAt: j['created_at'] != null
//         ? DateTime.tryParse(j['created_at']) ?? DateTime.now()
//         : DateTime.now(),
//     sentAt: j['sent_at'] != null ? DateTime.tryParse(j['sent_at']) : null,
//     scheduledAt: j['scheduled_at'] != null
//         ? DateTime.tryParse(j['scheduled_at'])
//         : null,
//     imageUrl: j['image_url'],
//   );

//   double get openRate => sentCount > 0 ? (openedCount / sentCount * 100) : 0.0;
//   double get deliveryRate =>
//       totalTargets > 0 ? (sentCount / totalTargets * 100) : 0.0;
// }

// class GnDashboardSummary {
//   final int totalNotifications;
//   final int totalSent;
//   final int totalDelivered;
//   final int totalFailed;
//   final int totalOpened;
//   final int scheduledCount;
//   final int sendingCount;
//   final double openRate;

//   GnDashboardSummary({
//     required this.totalNotifications,
//     required this.totalSent,
//     required this.totalDelivered,
//     required this.totalFailed,
//     required this.totalOpened,
//     required this.scheduledCount,
//     required this.sendingCount,
//     required this.openRate,
//   });

//   factory GnDashboardSummary.fromJson(Map<String, dynamic> j) =>
//       GnDashboardSummary(
//         totalNotifications: j['total_notifications'] ?? 0,
//         totalSent: j['total_sent'] ?? 0,
//         totalDelivered: j['total_delivered'] ?? 0,
//         totalFailed: j['total_failed'] ?? 0,
//         totalOpened: j['total_opened'] ?? 0,
//         scheduledCount: j['scheduled_count'] ?? 0,
//         sendingCount: j['sending_count'] ?? 0,
//         openRate: (j['open_rate'] ?? 0.0).toDouble(),
//       );
// }

// class GnTargetPreview {
//   final int totalEmployees;
//   final int totalOrgs;
//   final List<String> orgIds;

//   GnTargetPreview({
//     required this.totalEmployees,
//     required this.totalOrgs,
//     required this.orgIds,
//   });

//   factory GnTargetPreview.fromJson(Map<String, dynamic> j) => GnTargetPreview(
//     totalEmployees: j['total_employees'] ?? 0,
//     totalOrgs: j['total_orgs'] ?? 0,
//     orgIds: List<String>.from(j['org_ids'] ?? []),
//   );
// }

// class GnAnalyticsTrend {
//   final String date;
//   final int total;
//   final int sent;
//   final int failed;
//   final int opened;

//   GnAnalyticsTrend({
//     required this.date,
//     required this.total,
//     required this.sent,
//     required this.failed,
//     required this.opened,
//   });

//   factory GnAnalyticsTrend.fromJson(Map<String, dynamic> j) => GnAnalyticsTrend(
//     date: j['date'] ?? '',
//     total: j['total'] ?? 0,
//     sent: j['sent'] ?? 0,
//     failed: j['failed'] ?? 0,
//     opened: j['opened'] ?? 0,
//   );
// }

// class GnTypeBreakdown {
//   final String type;
//   final int total;
//   final int totalSent;
//   final int totalFailed;
//   final double openRate;

//   GnTypeBreakdown({
//     required this.type,
//     required this.total,
//     required this.totalSent,
//     required this.totalFailed,
//     required this.openRate,
//   });

//   factory GnTypeBreakdown.fromJson(Map<String, dynamic> j) => GnTypeBreakdown(
//     type: j['type'] ?? '',
//     total: j['total'] ?? 0,
//     totalSent: j['total_sent'] ?? 0,
//     totalFailed: j['total_failed'] ?? 0,
//     openRate: (j['open_rate'] ?? 0.0).toDouble(),
//   );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 2 — SERVICE
// // ─────────────────────────────────────────────────────────────────────────────
// const String baseUrl = ApiConfig.baseUrl;

// class GnService {
//   static const String _base = '$baseUrl/app-admin/notifications';

//   final String authToken;
//   GnService(this.authToken);

//   Map<String, String> get _h => {
//     'Content-Type': 'application/json',
//     'Authorization': 'Bearer $authToken',
//   };

//   Future<T> _get<T>(String path, T Function(dynamic) parse) async {
//     final res = await http.get(Uri.parse('$_base$path'), headers: _h);
//     if (res.statusCode == 200) return parse(json.decode(res.body));
//     throw Exception('GET $path failed: ${res.statusCode}');
//   }

//   Future<T> _post<T>(
//     String path,
//     Map<String, dynamic> body,
//     T Function(dynamic) parse,
//   ) async {
//     final res = await http.post(
//       Uri.parse('$_base$path'),
//       headers: _h,
//       body: json.encode(body),
//     );
//     if (res.statusCode == 200 || res.statusCode == 201) {
//       return parse(json.decode(res.body));
//     }
//     final err = json.decode(res.body);
//     throw Exception(err['message'] ?? 'POST $path failed');
//   }

//   Future<void> _patch(String path, [Map<String, dynamic>? body]) async {
//     final res = await http.patch(
//       Uri.parse('$_base$path'),
//       headers: _h,
//       body: body != null ? json.encode(body) : null,
//     );
//     if (res.statusCode != 200) {
//       final err = json.decode(res.body);
//       throw Exception(err['message'] ?? 'PATCH $path failed');
//     }
//   }

//   // Dashboard
//   Future<Map<String, dynamic>> dashboard() => _get('/dashboard', (d) => d);

//   // History with filters
//   Future<Map<String, dynamic>> history({
//     int page = 1,
//     int limit = 20,
//     String? type,
//     String? status,
//     String? tenantId,
//     String? dateFrom,
//     String? dateTo,
//     String? search,
//   }) async {
//     final q = <String, String>{
//       'page': '$page',
//       'limit': '$limit',
//       if (type != null) 'type': type,
//       if (status != null) 'status': status,
//       if (tenantId != null) 'tenant_id': tenantId,
//       if (dateFrom != null) 'date_from': dateFrom,
//       if (dateTo != null) 'date_to': dateTo,
//       if (search != null) 'search': search,
//     };
//     final uri = Uri.parse('$_base/history').replace(queryParameters: q);
//     final res = await http.get(uri, headers: _h);
//     if (res.statusCode == 200) return json.decode(res.body);
//     throw Exception('history failed: ${res.statusCode}');
//   }

//   // Send notification
//   Future<Map<String, dynamic>> send({
//     required String title,
//     required String message,
//     required String type,
//     required String scope,
//     Map<String, dynamic>? scopeMeta,
//     String? imageUrl,
//     String? scheduledAt,
//   }) => _post('/send', {
//     'title': title,
//     'message': message,
//     'type': type,
//     'scope': scope,
//     if (scopeMeta != null) 'scope_meta': scopeMeta,
//     if (imageUrl != null) 'image_url': imageUrl,
//     if (scheduledAt != null) 'scheduled_at': scheduledAt,
//   }, (d) => d);

//   // Detail
//   Future<Map<String, dynamic>> detail(int id) => _get('/$id', (d) => d);

//   // Cancel
//   Future<void> cancel(int id) => _patch('/$id/cancel');

//   // Reschedule
//   Future<void> reschedule(int id, String scheduledAt) =>
//       _patch('/$id/reschedule', {'scheduled_at': scheduledAt});

//   // Retry failed
//   Future<Map<String, dynamic>> retry(int id) =>
//       _post('/$id/retry', {}, (d) => d);

//   // Upcoming scheduled
//   Future<List<GnNotification>> scheduled() => _get(
//     '/scheduled/upcoming',
//     (d) => (d['data'] as List).map((e) => GnNotification.fromJson(e)).toList(),
//   );

//   // Analytics
//   Future<Map<String, dynamic>> analytics() =>
//       _get('/analytics/summary', (d) => d);

//   // Preview targets
//   Future<GnTargetPreview> previewTargets({
//     required String scope,
//     Map<String, dynamic>? scopeMeta,
//   }) => _post('/preview-targets', {
//     'scope': scope,
//     if (scopeMeta != null) 'scope_meta': scopeMeta,
//   }, (d) => GnTargetPreview.fromJson(d));
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 3 — THEME CONSTANTS (private)
// // ─────────────────────────────────────────────────────────────────────────────

// const _bg = Color(0xFF0A0E1A);
// const _surface = Color(0xFF111827);
// const _surfaceEl = Color(0xFF162032);
// const _border = Color(0xFF1E2D45);
// const _accent = Color(0xFF3B82F6);
// const _success = Color(0xFF10B981);
// const _warning = Color(0xFFF59E0B);
// const _error = Color(0xFFEF4444);
// const _purple = Color(0xFF8B5CF6);
// const _cyan = Color(0xFF06B6D4);
// const _textPri = Color(0xFFF1F5F9);
// const _textSec = Color(0xFF94A3B8);
// const _textMut = Color(0xFF475569);

// Color _statusColor(String s) {
//   switch (s.toLowerCase()) {
//     case 'sent':
//       return _success;
//     case 'sending':
//       return _accent;
//     case 'scheduled':
//       return _warning;
//     case 'failed':
//       return _error;
//     case 'cancelled':
//       return _textMut;
//     case 'draft':
//       return _purple;
//     default:
//       return _textSec;
//   }
// }

// Color _typeColor(String t) {
//   switch (t.toLowerCase()) {
//     case 'general':
//       return _accent;
//     case 'maintenance':
//       return _warning;
//     case 'app_update':
//       return _cyan;
//     case 'billing_reminder':
//       return _purple;
//     case 'emergency_alert':
//       return _error;
//     default:
//       return _textSec;
//   }
// }

// String _typeLabel(String t) {
//   switch (t) {
//     case 'general':
//       return 'General';
//     case 'maintenance':
//       return 'Maintenance';
//     case 'app_update':
//       return 'App Update';
//     case 'billing_reminder':
//       return 'Billing Reminder';
//     case 'emergency_alert':
//       return 'Emergency Alert';
//     default:
//       return t;
//   }
// }

// IconData _typeIcon(String t) {
//   switch (t) {
//     case 'general':
//       return Icons.campaign_outlined;
//     case 'maintenance':
//       return Icons.build_outlined;
//     case 'app_update':
//       return Icons.system_update_alt_outlined;
//     case 'billing_reminder':
//       return Icons.receipt_long_outlined;
//     case 'emergency_alert':
//       return Icons.warning_amber_rounded;
//     default:
//       return Icons.notifications_outlined;
//   }
// }

// String _scopeLabel(String s) {
//   switch (s) {
//     case 'all':
//       return 'All Organizations';
//     case 'selected':
//       return 'Selected Organizations';
//     case 'by_plan':
//       return 'By Plan';
//     case 'trial':
//       return 'Trial Organizations';
//     case 'expired':
//       return 'Expired Subscriptions';
//     case 'by_version':
//       return 'By App Version';
//     default:
//       return s;
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 4 — PRIVATE WIDGETS
// // ─────────────────────────────────────────────────────────────────────────────

// class _Card extends StatelessWidget {
//   final Widget child;
//   final EdgeInsets? padding;
//   final VoidCallback? onTap;
//   final Color? borderColor;
//   final Color? bgColor;

//   const _Card({
//     required this.child,
//     this.padding,
//     this.onTap,
//     this.borderColor,
//     this.bgColor,
//   });

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: padding ?? const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: bgColor ?? _surfaceEl,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: borderColor ?? _border),
//       ),
//       child: child,
//     ),
//   );
// }

// class _StatCard extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color color;
//   final String? sub;

//   const _StatCard({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.color,
//     this.sub,
//   });

//   @override
//   Widget build(BuildContext context) => _Card(
//     borderColor: color.withOpacity(0.25),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(7),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(icon, color: color, size: 16),
//             ),
//             const Spacer(),
//             if (sub != null)
//               Text(
//                 sub!,
//                 style: TextStyle(
//                   color: color,
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         Text(
//           value,
//           style: const TextStyle(
//             color: _textPri,
//             fontSize: 24,
//             fontWeight: FontWeight.w800,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
//       ],
//     ),
//   );
// }

// class _StatusChip extends StatelessWidget {
//   final String status;
//   const _StatusChip(this.status);

//   @override
//   Widget build(BuildContext context) {
//     final c = _statusColor(status);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
//       decoration: BoxDecoration(
//         color: c.withOpacity(0.12),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: c.withOpacity(0.3)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 5,
//             height: 5,
//             decoration: BoxDecoration(color: c, shape: BoxShape.circle),
//           ),
//           const SizedBox(width: 5),
//           Text(
//             status.toUpperCase(),
//             style: TextStyle(
//               color: c,
//               fontSize: 9,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 0.6,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _TypeChip extends StatelessWidget {
//   final String type;
//   const _TypeChip(this.type);

//   @override
//   Widget build(BuildContext context) {
//     final c = _typeColor(type);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color: c.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(_typeIcon(type), color: c, size: 11),
//           const SizedBox(width: 4),
//           Text(
//             _typeLabel(type),
//             style: TextStyle(
//               color: c,
//               fontSize: 11,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SectionHeader extends StatelessWidget {
//   final String title;
//   final Widget? trailing;
//   const _SectionHeader(this.title, {this.trailing});

//   @override
//   Widget build(BuildContext context) => Row(
//     children: [
//       Container(
//         width: 3,
//         height: 16,
//         decoration: BoxDecoration(
//           color: _accent,
//           borderRadius: BorderRadius.circular(2),
//         ),
//       ),
//       const SizedBox(width: 8),
//       Text(
//         title,
//         style: const TextStyle(
//           color: _textPri,
//           fontSize: 14,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//       const Spacer(),
//       if (trailing != null) trailing!,
//     ],
//   );
// }

// class _StatPill extends StatelessWidget {
//   final IconData icon;
//   final String value;
//   final Color color;
//   const _StatPill({
//     required this.icon,
//     required this.value,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) => Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       Icon(icon, color: color, size: 11),
//       const SizedBox(width: 3),
//       Text(
//         value,
//         style: TextStyle(
//           color: color,
//           fontSize: 11,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//     ],
//   );
// }

// class _NotifTile extends StatelessWidget {
//   final GnNotification n;
//   final VoidCallback? onTap;
//   const _NotifTile(this.n, {this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     final fmt = DateFormat('MMM d · h:mm a');
//     return _Card(
//       onTap: onTap,
//       padding: const EdgeInsets.all(14),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   n.title,
//                   style: const TextStyle(
//                     color: _textPri,
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               _StatusChip(n.status),
//             ],
//           ),
//           const SizedBox(height: 5),
//           Text(
//             n.message,
//             style: const TextStyle(color: _textSec, fontSize: 13),
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//           ),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               _TypeChip(n.type),
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: _border,
//                   borderRadius: BorderRadius.circular(5),
//                 ),
//                 child: Text(
//                   _scopeLabel(n.scope),
//                   style: const TextStyle(color: _textMut, fontSize: 10),
//                 ),
//               ),
//               const Spacer(),
//               if (n.status == 'sent') ...[
//                 _StatPill(
//                   icon: Icons.send_outlined,
//                   value: _fmt(n.sentCount),
//                   color: _success,
//                 ),
//                 const SizedBox(width: 8),
//                 _StatPill(
//                   icon: Icons.error_outline,
//                   value: _fmt(n.failedCount),
//                   color: _error,
//                 ),
//                 const SizedBox(width: 8),
//                 _StatPill(
//                   icon: Icons.visibility_outlined,
//                   value: '${n.openRate.toStringAsFixed(1)}%',
//                   color: _cyan,
//                 ),
//               ],
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             n.scheduledAt != null
//                 ? 'Scheduled: ${fmt.format(n.scheduledAt!)}'
//                 : n.sentAt != null
//                 ? 'Sent: ${fmt.format(n.sentAt!)}'
//                 : 'Created: ${fmt.format(n.createdAt)}',
//             style: const TextStyle(color: _textMut, fontSize: 11),
//           ),
//         ],
//       ),
//     );
//   }
// }

// String _fmt(int n) {
//   if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
//   if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
//   return '$n';
// }

// class _ProgressRow extends StatelessWidget {
//   final String label;
//   final int value;
//   final int total;
//   final Color color;
//   const _ProgressRow({
//     required this.label,
//     required this.value,
//     required this.total,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final pct = total > 0 ? value / total : 0.0;
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Text(
//                 label,
//                 style: const TextStyle(color: _textSec, fontSize: 12),
//               ),
//               const Spacer(),
//               Text(
//                 '$value / $total',
//                 style: TextStyle(
//                   color: color,
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 5),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(3),
//             child: LinearProgressIndicator(
//               value: pct.clamp(0.0, 1.0),
//               backgroundColor: _border,
//               valueColor: AlwaysStoppedAnimation<Color>(color),
//               minHeight: 5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 5 — MAIN CONSOLE (entry point)
// // ─────────────────────────────────────────────────────────────────────────────

// /// Drop this widget anywhere in your existing app.
// class GlobalNotifyConsole extends StatefulWidget {
//   final String authToken;
//   const GlobalNotifyConsole({super.key, required this.authToken});

//   @override
//   State<GlobalNotifyConsole> createState() => _GlobalNotifyConsoleState();
// }

// class _GlobalNotifyConsoleState extends State<GlobalNotifyConsole> {
//   late final GnService _svc;
//   int _tab = 0;

//   @override
//   void initState() {
//     super.initState();
//     _svc = GnService(widget.authToken);
//   }

//   static const _tabs = [
//     (icon: Icons.dashboard_outlined, label: 'Overview'),
//     (icon: Icons.send_outlined, label: 'Send'),
//     (icon: Icons.history_outlined, label: 'History'),
//     (icon: Icons.schedule_outlined, label: 'Scheduled'),
//     (icon: Icons.bar_chart_outlined, label: 'Analytics'),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final screens = [
//       _OverviewScreen(svc: _svc),
//       _SendScreen(svc: _svc),
//       _HistoryScreen(svc: _svc),
//       _ScheduledScreen(svc: _svc),
//       _AnalyticsScreen(svc: _svc),
//     ];

//     return Theme(
//       data: _buildTheme(),
//       child: Scaffold(
//         backgroundColor: _bg,
//         appBar: AppBar(
//           backgroundColor: _surface,
//           elevation: 0,
//           title: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: _accent.withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: const Icon(Icons.bolt, color: _accent, size: 16),
//               ),
//               const SizedBox(width: 10),
//               const Text(
//                 'Global Notifications',
//                 style: TextStyle(
//                   color: _textPri,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: _purple.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: const Text(
//                   'SUPER ADMIN',
//                   style: TextStyle(
//                     color: _purple,
//                     fontSize: 9,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           bottom: PreferredSize(
//             preferredSize: const Size.fromHeight(46),
//             child: Container(
//               color: _surface,
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 child: Row(
//                   children: List.generate(_tabs.length, (i) {
//                     final t = _tabs[i];
//                     final sel = _tab == i;
//                     return GestureDetector(
//                       onTap: () => setState(() => _tab = i),
//                       child: Container(
//                         margin: const EdgeInsets.only(right: 4, bottom: 6),
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 14,
//                           vertical: 7,
//                         ),
//                         decoration: BoxDecoration(
//                           color: sel
//                               ? _accent.withOpacity(0.15)
//                               : Colors.transparent,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(
//                             color: sel
//                                 ? _accent.withOpacity(0.4)
//                                 : Colors.transparent,
//                           ),
//                         ),
//                         child: Row(
//                           children: [
//                             Icon(
//                               t.icon,
//                               size: 14,
//                               color: sel ? _accent : _textMut,
//                             ),
//                             const SizedBox(width: 6),
//                             Text(
//                               t.label,
//                               style: TextStyle(
//                                 color: sel ? _accent : _textMut,
//                                 fontSize: 13,
//                                 fontWeight: sel
//                                     ? FontWeight.w600
//                                     : FontWeight.w400,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         body: IndexedStack(index: _tab, children: screens),
//       ),
//     );
//   }
// }

// ThemeData _buildTheme() => ThemeData(
//   scaffoldBackgroundColor: _bg,
//   colorScheme: const ColorScheme.dark(
//     primary: _accent,
//     surface: _surface,
//     error: _error,
//   ),
//   inputDecorationTheme: InputDecorationTheme(
//     filled: true,
//     fillColor: _surfaceEl,
//     border: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(10),
//       borderSide: const BorderSide(color: _border),
//     ),
//     enabledBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(10),
//       borderSide: const BorderSide(color: _border),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(10),
//       borderSide: const BorderSide(color: _accent, width: 1.5),
//     ),
//     labelStyle: const TextStyle(color: _textSec),
//     hintStyle: const TextStyle(color: _textMut),
//     contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
//   ),
//   elevatedButtonTheme: ElevatedButtonThemeData(
//     style: ElevatedButton.styleFrom(
//       backgroundColor: _accent,
//       foregroundColor: Colors.white,
//       elevation: 0,
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//     ),
//   ),
//   dividerColor: _border,
// );

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 6 — OVERVIEW SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _OverviewScreen extends StatefulWidget {
//   final GnService svc;
//   const _OverviewScreen({required this.svc});

//   @override
//   State<_OverviewScreen> createState() => _OverviewScreenState();
// }

// class _OverviewScreenState extends State<_OverviewScreen> {
//   GnDashboardSummary? _summary;
//   List<GnNotification> _recent = [];
//   bool _loading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await widget.svc.dashboard();
//       setState(() {
//         _summary = GnDashboardSummary.fromJson(data['summary']);
//         _recent = (data['recent'] as List)
//             .map((e) => GnNotification.fromJson(e))
//             .toList();
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Center(
//         child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
//       );
//     }
//     if (_error != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(Icons.cloud_off_outlined, color: _textMut, size: 40),
//             const SizedBox(height: 12),
//             Text(
//               _error!,
//               style: const TextStyle(color: _textSec),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(onPressed: _load, child: const Text('Retry')),
//           ],
//         ),
//       );
//     }
//     final s = _summary!;
//     return RefreshIndicator(
//       onRefresh: _load,
//       color: _accent,
//       backgroundColor: _surfaceEl,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // Stats grid
//           GridView.count(
//             crossAxisCount: 2,
//             crossAxisSpacing: 10,
//             mainAxisSpacing: 10,
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             childAspectRatio: 1.55,
//             children: [
//               _StatCard(
//                 label: 'Total Sent',
//                 value: _fmt(s.totalSent),
//                 icon: Icons.send_outlined,
//                 color: _accent,
//               ),
//               _StatCard(
//                 label: 'Delivered',
//                 value: _fmt(s.totalDelivered),
//                 icon: Icons.mark_email_read_outlined,
//                 color: _success,
//               ),
//               _StatCard(
//                 label: 'Failed',
//                 value: _fmt(s.totalFailed),
//                 icon: Icons.error_outline,
//                 color: _error,
//               ),
//               _StatCard(
//                 label: 'Open Rate',
//                 value: '${s.openRate.toStringAsFixed(1)}%',
//                 icon: Icons.visibility_outlined,
//                 color: _cyan,
//                 sub: '${_fmt(s.totalOpened)} opens',
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           // Status row
//           Row(
//             children: [
//               Expanded(
//                 child: _Card(
//                   borderColor: _warning.withOpacity(0.3),
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(7),
//                         decoration: BoxDecoration(
//                           color: _warning.withOpacity(0.15),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Icon(
//                           Icons.schedule_outlined,
//                           color: _warning,
//                           size: 16,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _fmt(s.scheduledCount),
//                             style: const TextStyle(
//                               color: _textPri,
//                               fontSize: 20,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const Text(
//                             'Scheduled',
//                             style: TextStyle(color: _textSec, fontSize: 11),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: _Card(
//                   borderColor: _purple.withOpacity(0.3),
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(7),
//                         decoration: BoxDecoration(
//                           color: _purple.withOpacity(0.15),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: const Icon(
//                           Icons.all_inbox_outlined,
//                           color: _purple,
//                           size: 16,
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             _fmt(s.totalNotifications),
//                             style: const TextStyle(
//                               color: _textPri,
//                               fontSize: 20,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const Text(
//                             'Total Notifs',
//                             style: TextStyle(color: _textSec, fontSize: 11),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           _SectionHeader('Recent Notifications'),
//           const SizedBox(height: 12),
//           if (_recent.isEmpty)
//             const Padding(
//               padding: EdgeInsets.symmetric(vertical: 24),
//               child: Center(
//                 child: Text(
//                   'No notifications yet',
//                   style: TextStyle(color: _textMut),
//                 ),
//               ),
//             )
//           else
//             ..._recent.map(
//               (n) => Padding(
//                 padding: const EdgeInsets.only(bottom: 10),
//                 child: _NotifTile(n, onTap: () => _openDetail(context, n.id)),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   void _openDetail(BuildContext ctx, int id) => Navigator.push(
//     ctx,
//     MaterialPageRoute(
//       builder: (_) => _DetailScreen(svc: widget.svc, id: id),
//     ),
//   );
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 7 — SEND SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _SendScreen extends StatefulWidget {
//   final GnService svc;
//   const _SendScreen({required this.svc});

//   @override
//   State<_SendScreen> createState() => _SendScreenState();
// }

// class _SendScreenState extends State<_SendScreen> {
//   final _titleCtrl = TextEditingController();
//   final _msgCtrl = TextEditingController();
//   final _imgCtrl = TextEditingController();
//   final _tenantCtrl = TextEditingController();
//   final _planCtrl = TextEditingController();
//   final _versionCtrl = TextEditingController();

//   String _type = 'general';
//   String _scope = 'all';
//   bool _schedule = false;
//   DateTime? _scheduledAt;

//   bool _sending = false;
//   GnTargetPreview? _preview;
//   bool _previewing = false;

//   final _types = [
//     'general',
//     'maintenance',
//     'app_update',
//     'billing_reminder',
//     'emergency_alert',
//   ];
//   final _scopes = [
//     'all',
//     'selected',
//     'by_plan',
//     'trial',
//     'expired',
//     'by_version',
//   ];

//   Map<String, dynamic>? get _scopeMeta {
//     switch (_scope) {
//       case 'selected':
//         final ids = _tenantCtrl.text
//             .split(',')
//             .map((e) => e.trim())
//             .where((e) => e.isNotEmpty)
//             .toList();
//         return ids.isEmpty ? null : {'tenant_ids': ids};
//       case 'by_plan':
//         final p = _planCtrl.text.trim();
//         return p.isEmpty ? null : {'plan_id': p};
//       case 'by_version':
//         final v = _versionCtrl.text.trim();
//         return v.isEmpty ? null : {'version_string': v};
//       default:
//         return null;
//     }
//   }

//   Future<void> _doPreview() async {
//     setState(() => _previewing = true);
//     try {
//       final p = await widget.svc.previewTargets(
//         scope: _scope,
//         scopeMeta: _scopeMeta,
//       );
//       setState(() => _preview = p);
//     } catch (e) {
//       _snack('Preview failed: $e');
//     } finally {
//       setState(() => _previewing = false);
//     }
//   }

//   Future<void> _doSend() async {
//     if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
//       _snack('Title and message are required');
//       return;
//     }
//     setState(() => _sending = true);
//     try {
//       await widget.svc.send(
//         title: _titleCtrl.text.trim(),
//         message: _msgCtrl.text.trim(),
//         type: _type,
//         scope: _scope,
//         scopeMeta: _scopeMeta,
//         imageUrl: _imgCtrl.text.trim().isEmpty ? null : _imgCtrl.text.trim(),
//         scheduledAt: _schedule && _scheduledAt != null
//             ? _scheduledAt!.toIso8601String()
//             : null,
//       );
//       _snack(
//         _schedule
//             ? 'Notification scheduled!'
//             : 'Notification queued for sending!',
//         isSuccess: true,
//       );
//       _titleCtrl.clear();
//       _msgCtrl.clear();
//       _imgCtrl.clear();
//       setState(() {
//         _preview = null;
//         _schedule = false;
//         _scheduledAt = null;
//       });
//     } catch (e) {
//       _snack('Failed: $e');
//     } finally {
//       setState(() => _sending = false);
//     }
//   }

//   void _snack(String msg, {bool isSuccess = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: isSuccess ? _success : _error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   Future<void> _pickSchedule() async {
//     final now = DateTime.now();
//     final date = await showDatePicker(
//       context: context,
//       initialDate: now.add(const Duration(hours: 1)),
//       firstDate: now,
//       lastDate: now.add(const Duration(days: 365)),
//       builder: (ctx, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(primary: _accent),
//         ),
//         child: child!,
//       ),
//     );
//     if (date == null) return;
//     final time = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
//       builder: (ctx, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(primary: _accent),
//         ),
//         child: child!,
//       ),
//     );
//     if (time == null) return;
//     setState(
//       () => _scheduledAt = DateTime(
//         date.year,
//         date.month,
//         date.day,
//         time.hour,
//         time.minute,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         ListView(
//           padding: const EdgeInsets.all(16),
//           children: [
//             // ── Type selector ──
//             _SectionHeader('Notification Type'),
//             const SizedBox(height: 10),
//             SizedBox(
//               height: 44,
//               child: ListView.separated(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _types.length,
//                 separatorBuilder: (_, __) => const SizedBox(width: 8),
//                 itemBuilder: (_, i) {
//                   final t = _types[i];
//                   final sel = _type == t;
//                   final c = _typeColor(t);
//                   return GestureDetector(
//                     onTap: () => setState(() => _type = t),
//                     child: AnimatedContainer(
//                       duration: const Duration(milliseconds: 180),
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 14,
//                         vertical: 10,
//                       ),
//                       decoration: BoxDecoration(
//                         color: sel ? c.withOpacity(0.15) : _surfaceEl,
//                         borderRadius: BorderRadius.circular(10),
//                         border: Border.all(
//                           color: sel ? c.withOpacity(0.5) : _border,
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(
//                             _typeIcon(t),
//                             color: sel ? c : _textMut,
//                             size: 14,
//                           ),
//                           const SizedBox(width: 6),
//                           Text(
//                             _typeLabel(t),
//                             style: TextStyle(
//                               color: sel ? c : _textMut,
//                               fontSize: 12,
//                               fontWeight: sel
//                                   ? FontWeight.w600
//                                   : FontWeight.w400,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 18),

//             // ── Scope selector ──
//             _SectionHeader('Target Audience'),
//             const SizedBox(height: 10),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: _scopes.map((s) {
//                 final sel = _scope == s;
//                 return GestureDetector(
//                   onTap: () => setState(() {
//                     _scope = s;
//                     _preview = null;
//                   }),
//                   child: AnimatedContainer(
//                     duration: const Duration(milliseconds: 150),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 7,
//                     ),
//                     decoration: BoxDecoration(
//                       color: sel ? _accent.withOpacity(0.15) : _surfaceEl,
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(
//                         color: sel ? _accent.withOpacity(0.5) : _border,
//                       ),
//                     ),
//                     child: Text(
//                       _scopeLabel(s),
//                       style: TextStyle(
//                         color: sel ? _accent : _textSec,
//                         fontSize: 12,
//                         fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
//                       ),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//             const SizedBox(height: 12),

//             // Scope meta fields
//             if (_scope == 'selected') ...[
//               TextField(
//                 controller: _tenantCtrl,
//                 style: const TextStyle(color: _textPri, fontSize: 13),
//                 decoration: const InputDecoration(
//                   labelText: 'Tenant IDs (comma separated)',
//                   hintText: 'TENANT1, TENANT2, ...',
//                   prefixIcon: Icon(
//                     Icons.business_outlined,
//                     color: _textMut,
//                     size: 18,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],
//             if (_scope == 'by_plan') ...[
//               TextField(
//                 controller: _planCtrl,
//                 style: const TextStyle(color: _textPri, fontSize: 13),
//                 decoration: const InputDecoration(
//                   labelText: 'Plan ID',
//                   hintText: 'e.g. plan-pro-monthly',
//                   prefixIcon: Icon(
//                     Icons.card_membership_outlined,
//                     color: _textMut,
//                     size: 18,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],
//             if (_scope == 'by_version') ...[
//               TextField(
//                 controller: _versionCtrl,
//                 style: const TextStyle(color: _textPri, fontSize: 13),
//                 decoration: const InputDecoration(
//                   labelText: 'App Version',
//                   hintText: 'e.g. 2.4.0',
//                   prefixIcon: Icon(
//                     Icons.phone_android_outlined,
//                     color: _textMut,
//                     size: 18,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],

//             // Preview button
//             Align(
//               alignment: Alignment.centerLeft,
//               child: TextButton.icon(
//                 onPressed: _previewing ? null : _doPreview,
//                 icon: _previewing
//                     ? const SizedBox(
//                         width: 14,
//                         height: 14,
//                         child: CircularProgressIndicator(
//                           color: _accent,
//                           strokeWidth: 2,
//                         ),
//                       )
//                     : const Icon(
//                         Icons.visibility_outlined,
//                         color: _accent,
//                         size: 16,
//                       ),
//                 label: const Text(
//                   'Preview audience',
//                   style: TextStyle(color: _accent, fontSize: 13),
//                 ),
//               ),
//             ),
//             if (_preview != null) ...[
//               _Card(
//                 borderColor: _accent.withOpacity(0.3),
//                 bgColor: _accent.withOpacity(0.06),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 14,
//                   vertical: 10,
//                 ),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.people_outline, color: _accent, size: 18),
//                     const SizedBox(width: 10),
//                     RichText(
//                       text: TextSpan(
//                         style: const TextStyle(color: _textSec, fontSize: 13),
//                         children: [
//                           TextSpan(
//                             text: '${_fmt(_preview!.totalEmployees)} employees',
//                             style: const TextStyle(
//                               color: _accent,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const TextSpan(text: ' across '),
//                           TextSpan(
//                             text: '${_preview!.totalOrgs} organizations',
//                             style: const TextStyle(
//                               color: _accent,
//                               fontWeight: FontWeight.w700,
//                             ),
//                           ),
//                           const TextSpan(text: ' will be targeted'),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],

//             const SizedBox(height: 8),
//             _SectionHeader('Content'),
//             const SizedBox(height: 10),
//             TextField(
//               controller: _titleCtrl,
//               style: const TextStyle(color: _textPri, fontSize: 14),
//               decoration: const InputDecoration(
//                 labelText: 'Notification Title *',
//                 hintText: 'e.g. Scheduled Maintenance Tonight',
//                 prefixIcon: Icon(
//                   Icons.title_outlined,
//                   color: _textMut,
//                   size: 18,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: _msgCtrl,
//               minLines: 3,
//               maxLines: 6,
//               style: const TextStyle(color: _textPri, fontSize: 13),
//               decoration: const InputDecoration(
//                 labelText: 'Message *',
//                 hintText: 'Write your notification body here...',
//                 alignLabelWithHint: true,
//                 prefixIcon: Padding(
//                   padding: EdgeInsets.only(bottom: 40),
//                   child: Icon(Icons.notes_outlined, color: _textMut, size: 18),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             TextField(
//               controller: _imgCtrl,
//               style: const TextStyle(color: _textPri, fontSize: 13),
//               decoration: const InputDecoration(
//                 labelText: 'Image / Banner URL (optional)',
//                 hintText: 'https://...',
//                 prefixIcon: Icon(
//                   Icons.image_outlined,
//                   color: _textMut,
//                   size: 18,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 18),

//             // ── Schedule toggle ──
//             _Card(
//               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//               child: Row(
//                 children: [
//                   const Icon(
//                     Icons.schedule_outlined,
//                     color: _warning,
//                     size: 18,
//                   ),
//                   const SizedBox(width: 10),
//                   const Text(
//                     'Schedule for later',
//                     style: TextStyle(color: _textPri, fontSize: 13),
//                   ),
//                   const Spacer(),
//                   Switch(
//                     value: _schedule,
//                     activeColor: _accent,
//                     onChanged: (v) => setState(() => _schedule = v),
//                   ),
//                 ],
//               ),
//             ),
//             if (_schedule) ...[
//               const SizedBox(height: 8),
//               GestureDetector(
//                 onTap: _pickSchedule,
//                 child: _Card(
//                   borderColor: _warning.withOpacity(0.4),
//                   bgColor: _warning.withOpacity(0.06),
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 14,
//                     vertical: 12,
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.calendar_month_outlined,
//                         color: _warning,
//                         size: 18,
//                       ),
//                       const SizedBox(width: 10),
//                       Text(
//                         _scheduledAt != null
//                             ? DateFormat(
//                                 'MMM d, yyyy  h:mm a',
//                               ).format(_scheduledAt!)
//                             : 'Tap to pick date & time',
//                         style: TextStyle(
//                           color: _scheduledAt != null ? _textPri : _textMut,
//                           fontSize: 13,
//                         ),
//                       ),
//                       const Spacer(),
//                       const Icon(
//                         Icons.arrow_forward_ios,
//                         color: _textMut,
//                         size: 14,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//             const SizedBox(height: 24),

//             // ── Emergency warning ──
//             if (_type == 'emergency_alert')
//               _Card(
//                 borderColor: _error.withOpacity(0.4),
//                 bgColor: _error.withOpacity(0.06),
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 14,
//                   vertical: 10,
//                 ),
//                 child: const Row(
//                   children: [
//                     Icon(Icons.warning_amber_rounded, color: _error, size: 18),
//                     SizedBox(width: 10),
//                     Expanded(
//                       child: Text(
//                         'Emergency alerts are delivered with high priority and may override DND settings.',
//                         style: TextStyle(color: _error, fontSize: 12),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             if (_type == 'emergency_alert') const SizedBox(height: 16),

//             // Send button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 onPressed: _sending ? null : _doSend,
//                 icon: _sending
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(
//                           color: Colors.white,
//                           strokeWidth: 2,
//                         ),
//                       )
//                     : Icon(
//                         _schedule
//                             ? Icons.schedule_send_outlined
//                             : Icons.send_outlined,
//                       ),
//                 label: Text(_schedule ? 'Schedule Notification' : 'Send Now'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _type == 'emergency_alert'
//                       ? _error
//                       : _accent,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//           ],
//         ),
//         if (_sending)
//           Positioned.fill(
//             child: Container(
//               color: Colors.black.withOpacity(0.4),
//               child: const Center(
//                 child: CircularProgressIndicator(
//                   color: _accent,
//                   strokeWidth: 2,
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _titleCtrl.dispose();
//     _msgCtrl.dispose();
//     _imgCtrl.dispose();
//     _tenantCtrl.dispose();
//     _planCtrl.dispose();
//     _versionCtrl.dispose();
//     super.dispose();
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 8 — HISTORY SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _HistoryScreen extends StatefulWidget {
//   final GnService svc;
//   const _HistoryScreen({required this.svc});

//   @override
//   State<_HistoryScreen> createState() => _HistoryScreenState();
// }

// class _HistoryScreenState extends State<_HistoryScreen> {
//   List<GnNotification> _items = [];
//   bool _loading = true;
//   String? _error;
//   int _page = 1;
//   int _total = 0;
//   static const _limit = 20;

//   String? _filterType;
//   String? _filterStatus;
//   final _searchCtrl = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load({bool reset = false}) async {
//     if (reset) _page = 1;
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await widget.svc.history(
//         page: _page,
//         limit: _limit,
//         type: _filterType,
//         status: _filterStatus,
//         search: _searchCtrl.text.trim().isEmpty
//             ? null
//             : _searchCtrl.text.trim(),
//       );
//       setState(() {
//         _total = data['total'] ?? 0;
//         _items = (data['data'] as List)
//             .map((e) => GnNotification.fromJson(e))
//             .toList();
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final totalPages = (_total / _limit).ceil();
//     return Column(
//       children: [
//         // ── Filter bar ──
//         Container(
//           color: _surface,
//           padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
//           child: Column(
//             children: [
//               TextField(
//                 controller: _searchCtrl,
//                 onSubmitted: (_) => _load(reset: true),
//                 style: const TextStyle(color: _textPri, fontSize: 13),
//                 decoration: InputDecoration(
//                   hintText: 'Search by title...',
//                   prefixIcon: const Icon(
//                     Icons.search,
//                     color: _textMut,
//                     size: 18,
//                   ),
//                   suffixIcon: _searchCtrl.text.isNotEmpty
//                       ? IconButton(
//                           icon: const Icon(
//                             Icons.close,
//                             color: _textMut,
//                             size: 16,
//                           ),
//                           onPressed: () {
//                             _searchCtrl.clear();
//                             _load(reset: true);
//                           },
//                         )
//                       : null,
//                   isDense: true,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: Row(
//                   children: [
//                     _FilterChip(
//                       label: 'All Types',
//                       selected: _filterType == null,
//                       onTap: () => setState(() => _filterType = null),
//                     ),
//                     ...[
//                       'general',
//                       'maintenance',
//                       'app_update',
//                       'billing_reminder',
//                       'emergency_alert',
//                     ].map(
//                       (t) => _FilterChip(
//                         label: _typeLabel(t),
//                         selected: _filterType == t,
//                         color: _typeColor(t),
//                         onTap: () => setState(
//                           () => _filterType = _filterType == t ? null : t,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     _FilterChip(
//                       label: 'All Status',
//                       selected: _filterStatus == null,
//                       onTap: () => setState(() => _filterStatus = null),
//                     ),
//                     ...['sent', 'scheduled', 'failed', 'sending'].map(
//                       (s) => _FilterChip(
//                         label: s.capitalize(),
//                         selected: _filterStatus == s,
//                         color: _statusColor(s),
//                         onTap: () => setState(
//                           () => _filterStatus = _filterStatus == s ? null : s,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 6),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => _load(reset: true),
//                   style: ElevatedButton.styleFrom(
//                     padding: const EdgeInsets.symmetric(vertical: 9),
//                     backgroundColor: _surfaceEl,
//                     foregroundColor: _textPri,
//                   ),
//                   child: const Text(
//                     'Apply Filters',
//                     style: TextStyle(fontSize: 13),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // ── List ──
//         Expanded(
//           child: _loading
//               ? const Center(
//                   child: CircularProgressIndicator(
//                     color: _accent,
//                     strokeWidth: 2,
//                   ),
//                 )
//               : _error != null
//               ? Center(
//                   child: Text(_error!, style: const TextStyle(color: _textSec)),
//                 )
//               : _items.isEmpty
//               ? const Center(
//                   child: Text(
//                     'No notifications found',
//                     style: TextStyle(color: _textMut),
//                   ),
//                 )
//               : ListView.separated(
//                   padding: const EdgeInsets.all(14),
//                   itemCount: _items.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 8),
//                   itemBuilder: (ctx, i) => _NotifTile(
//                     _items[i],
//                     onTap: () => Navigator.push(
//                       ctx,
//                       MaterialPageRoute(
//                         builder: (_) =>
//                             _DetailScreen(svc: widget.svc, id: _items[i].id),
//                       ),
//                     ),
//                   ),
//                 ),
//         ),
//         // ── Pagination ──
//         if (!_loading && _total > _limit)
//           Container(
//             color: _surface,
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               children: [
//                 Text(
//                   '$_total results',
//                   style: const TextStyle(color: _textMut, fontSize: 12),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   icon: const Icon(Icons.chevron_left, color: _textSec),
//                   onPressed: _page > 1
//                       ? () {
//                           _page--;
//                           _load();
//                         }
//                       : null,
//                 ),
//                 Text(
//                   '$_page / $totalPages',
//                   style: const TextStyle(color: _textPri, fontSize: 13),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.chevron_right, color: _textSec),
//                   onPressed: _page < totalPages
//                       ? () {
//                           _page++;
//                           _load();
//                         }
//                       : null,
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _searchCtrl.dispose();
//     super.dispose();
//   }
// }

// class _FilterChip extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final Color? color;
//   final VoidCallback? onTap;

//   const _FilterChip({
//     required this.label,
//     required this.selected,
//     this.color,
//     this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final c = color ?? _accent;
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(right: 6),
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//         decoration: BoxDecoration(
//           color: selected ? c.withOpacity(0.15) : _surfaceEl,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(color: selected ? c.withOpacity(0.5) : _border),
//         ),
//         child: Text(
//           label,
//           style: TextStyle(
//             color: selected ? c : _textMut,
//             fontSize: 11,
//             fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
//           ),
//         ),
//       ),
//     );
//   }
// }

// extension _StrExt on String {
//   String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 9 — SCHEDULED SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _ScheduledScreen extends StatefulWidget {
//   final GnService svc;
//   const _ScheduledScreen({required this.svc});

//   @override
//   State<_ScheduledScreen> createState() => _ScheduledScreenState();
// }

// class _ScheduledScreenState extends State<_ScheduledScreen> {
//   List<GnNotification> _items = [];
//   bool _loading = true;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final items = await widget.svc.scheduled();
//       setState(() {
//         _items = items;
//         _loading = false;
//       });
//     } catch (_) {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _cancel(int id) async {
//     final ok = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: _surfaceEl,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         title: const Text(
//           'Cancel Notification',
//           style: TextStyle(color: _textPri, fontSize: 16),
//         ),
//         content: const Text(
//           'Are you sure you want to cancel this scheduled notification?',
//           style: TextStyle(color: _textSec, fontSize: 14),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text('Keep', style: TextStyle(color: _textSec)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(backgroundColor: _error),
//             child: const Text('Cancel Notif'),
//           ),
//         ],
//       ),
//     );
//     if (ok != true) return;
//     try {
//       await widget.svc.cancel(id);
//       _snack('Notification cancelled', isSuccess: true);
//       _load();
//     } catch (e) {
//       _snack('Failed: $e');
//     }
//   }

//   Future<void> _reschedule(GnNotification n) async {
//     DateTime? picked = n.scheduledAt;
//     final date = await showDatePicker(
//       context: context,
//       initialDate: picked ?? DateTime.now().add(const Duration(hours: 1)),
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (ctx, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(primary: _accent),
//         ),
//         child: child!,
//       ),
//     );
//     if (date == null) return;
//     final time = await showTimePicker(
//       context: context,
//       initialTime: picked != null
//           ? TimeOfDay.fromDateTime(picked)
//           : const TimeOfDay(hour: 9, minute: 0),
//       builder: (ctx, child) => Theme(
//         data: ThemeData.dark().copyWith(
//           colorScheme: const ColorScheme.dark(primary: _accent),
//         ),
//         child: child!,
//       ),
//     );
//     if (time == null) return;
//     final newDt = DateTime(
//       date.year,
//       date.month,
//       date.day,
//       time.hour,
//       time.minute,
//     );
//     try {
//       await widget.svc.reschedule(n.id, newDt.toIso8601String());
//       _snack(
//         'Rescheduled to ${DateFormat('MMM d, h:mm a').format(newDt)}',
//         isSuccess: true,
//       );
//       _load();
//     } catch (e) {
//       _snack('Failed: $e');
//     }
//   }

//   void _snack(String msg, {bool isSuccess = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: isSuccess ? _success : _error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Center(
//         child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
//       );
//     }
//     if (_items.isEmpty) {
//       return const Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.schedule_outlined, color: _textMut, size: 40),
//             SizedBox(height: 12),
//             Text(
//               'No scheduled notifications',
//               style: TextStyle(color: _textMut),
//             ),
//           ],
//         ),
//       );
//     }
//     return RefreshIndicator(
//       onRefresh: _load,
//       color: _accent,
//       backgroundColor: _surfaceEl,
//       child: ListView.separated(
//         padding: const EdgeInsets.all(14),
//         itemCount: _items.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 10),
//         itemBuilder: (_, i) {
//           final n = _items[i];
//           final fmt = DateFormat('MMM d, yyyy  ·  h:mm a');
//           return _Card(
//             borderColor: _warning.withOpacity(0.3),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         n.title,
//                         style: const TextStyle(
//                           color: _textPri,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     _TypeChip(n.type),
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   n.message,
//                   style: const TextStyle(color: _textSec, fontSize: 12),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 10),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 10,
//                     vertical: 6,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _warning.withOpacity(0.08),
//                     borderRadius: BorderRadius.circular(7),
//                     border: Border.all(color: _warning.withOpacity(0.25)),
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.schedule_outlined,
//                         color: _warning,
//                         size: 14,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         n.scheduledAt != null
//                             ? fmt.format(n.scheduledAt!)
//                             : '—',
//                         style: const TextStyle(
//                           color: _warning,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 8,
//                         vertical: 4,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _border,
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Text(
//                         _scopeLabel(n.scope),
//                         style: const TextStyle(color: _textSec, fontSize: 11),
//                       ),
//                     ),
//                     const Spacer(),
//                     TextButton.icon(
//                       onPressed: () => _reschedule(n),
//                       icon: const Icon(
//                         Icons.edit_calendar_outlined,
//                         size: 14,
//                         color: _accent,
//                       ),
//                       label: const Text(
//                         'Reschedule',
//                         style: TextStyle(color: _accent, fontSize: 12),
//                       ),
//                       style: TextButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 5,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 4),
//                     TextButton.icon(
//                       onPressed: () => _cancel(n.id),
//                       icon: const Icon(
//                         Icons.cancel_outlined,
//                         size: 14,
//                         color: _error,
//                       ),
//                       label: const Text(
//                         'Cancel',
//                         style: TextStyle(color: _error, fontSize: 12),
//                       ),
//                       style: TextButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 10,
//                           vertical: 5,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 10 — ANALYTICS SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _AnalyticsScreen extends StatefulWidget {
//   final GnService svc;
//   const _AnalyticsScreen({required this.svc});

//   @override
//   State<_AnalyticsScreen> createState() => _AnalyticsScreenState();
// }

// class _AnalyticsScreenState extends State<_AnalyticsScreen> {
//   List<GnAnalyticsTrend> _trend = [];
//   List<GnTypeBreakdown> _byType = [];
//   bool _loading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await widget.svc.analytics();
//       setState(() {
//         _trend = (data['trend'] as List)
//             .map((e) => GnAnalyticsTrend.fromJson(e))
//             .toList();
//         _byType = (data['by_type'] as List)
//             .map((e) => GnTypeBreakdown.fromJson(e))
//             .toList();
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Center(
//         child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
//       );
//     }
//     if (_error != null) {
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(_error!, style: const TextStyle(color: _textSec)),
//             const SizedBox(height: 12),
//             ElevatedButton(onPressed: _load, child: const Text('Retry')),
//           ],
//         ),
//       );
//     }
//     return RefreshIndicator(
//       onRefresh: _load,
//       color: _accent,
//       backgroundColor: _surfaceEl,
//       child: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           // ── 30-day trend chart (bar) ──
//           _SectionHeader('30-Day Trend'),
//           const SizedBox(height: 12),
//           _Card(
//             child: _trend.isEmpty
//                 ? const Padding(
//                     padding: EdgeInsets.symmetric(vertical: 20),
//                     child: Center(
//                       child: Text('No data', style: TextStyle(color: _textMut)),
//                     ),
//                   )
//                 : _BarChart(trend: _trend),
//           ),
//           const SizedBox(height: 20),

//           // ── By type ──
//           _SectionHeader('Performance by Type'),
//           const SizedBox(height: 12),
//           if (_byType.isEmpty)
//             const Center(
//               child: Text('No data', style: TextStyle(color: _textMut)),
//             )
//           else
//             ..._byType.map((t) {
//               final c = _typeColor(t.type);
//               return Padding(
//                 padding: const EdgeInsets.only(bottom: 10),
//                 child: _Card(
//                   borderColor: c.withOpacity(0.2),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           _TypeChip(t.type),
//                           const Spacer(),
//                           Text(
//                             '${_fmt(t.total)} campaigns',
//                             style: const TextStyle(
//                               color: _textMut,
//                               fontSize: 11,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 12),
//                       _ProgressRow(
//                         label: 'Sent',
//                         value: t.totalSent,
//                         total: t.total > 0 ? t.total * 1000 : 1,
//                         color: _success,
//                       ),
//                       _ProgressRow(
//                         label: 'Failed',
//                         value: t.totalFailed,
//                         total: (t.totalSent + t.totalFailed) > 0
//                             ? t.totalSent + t.totalFailed
//                             : 1,
//                         color: _error,
//                       ),
//                       Row(
//                         children: [
//                           const Text(
//                             'Open Rate',
//                             style: TextStyle(color: _textSec, fontSize: 12),
//                           ),
//                           const Spacer(),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 10,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: _cyan.withOpacity(0.12),
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Text(
//                               '${t.openRate.toStringAsFixed(1)}%',
//                               style: const TextStyle(
//                                 color: _cyan,
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }),
//         ],
//       ),
//     );
//   }
// }

// // Simple bar chart widget (no external packages)
// class _BarChart extends StatelessWidget {
//   final List<GnAnalyticsTrend> trend;
//   const _BarChart({required this.trend});

//   @override
//   Widget build(BuildContext context) {
//     final maxVal = trend.fold<int>(0, (m, t) => t.sent > m ? t.sent : m);
//     final show = trend.length > 14 ? trend.sublist(trend.length - 14) : trend;
//     return SizedBox(
//       height: 130,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: show.map((t) {
//           final sentH = maxVal > 0 ? (t.sent / maxVal) * 100 : 0.0;
//           final failH = maxVal > 0 ? (t.failed / maxVal) * 100 : 0.0;
//           final day = t.date.length >= 10 ? t.date.substring(8, 10) : t.date;
//           return Expanded(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 2),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   Stack(
//                     alignment: Alignment.bottomCenter,
//                     children: [
//                       // Sent bar
//                       Container(
//                         height: sentH.clamp(2.0, 100.0),
//                         decoration: BoxDecoration(
//                           color: _accent.withOpacity(0.7),
//                           borderRadius: const BorderRadius.vertical(
//                             top: Radius.circular(2),
//                           ),
//                         ),
//                       ),
//                       // Failed bar
//                       if (failH > 0)
//                         Container(
//                           height: failH.clamp(2.0, 100.0),
//                           decoration: BoxDecoration(
//                             color: _error.withOpacity(0.8),
//                             borderRadius: const BorderRadius.vertical(
//                               top: Radius.circular(2),
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     day,
//                     style: const TextStyle(color: _textMut, fontSize: 9),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // SECTION 11 — DETAIL SCREEN
// // ─────────────────────────────────────────────────────────────────────────────

// class _DetailScreen extends StatefulWidget {
//   final GnService svc;
//   final int id;
//   const _DetailScreen({required this.svc, required this.id});

//   @override
//   State<_DetailScreen> createState() => _DetailScreenState();
// }

// class _DetailScreenState extends State<_DetailScreen> {
//   GnNotification? _n;
//   List<Map<String, dynamic>> _breakdown = [];
//   List<Map<String, dynamic>> _orgStats = [];
//   bool _loading = true;
//   String? _error;
//   bool _retrying = false;

//   @override
//   void initState() {
//     super.initState();
//     _load();
//   }

//   Future<void> _load() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final data = await widget.svc.detail(widget.id);
//       setState(() {
//         _n = GnNotification.fromJson(data['notification']);
//         _breakdown = List<Map<String, dynamic>>.from(data['breakdown'] ?? []);
//         _orgStats = List<Map<String, dynamic>>.from(data['org_stats'] ?? []);
//         _loading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }

//   Future<void> _retry() async {
//     setState(() => _retrying = true);
//     try {
//       final r = await widget.svc.retry(widget.id);
//       _snack('Recovered ${r['retried'] ?? 0} deliveries', isSuccess: true);
//       _load();
//     } catch (e) {
//       _snack('Retry failed: $e');
//     } finally {
//       setState(() => _retrying = false);
//     }
//   }

//   void _snack(String msg, {bool isSuccess = false}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(msg),
//         backgroundColor: isSuccess ? _success : _error,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _bg,
//       appBar: AppBar(
//         backgroundColor: _surface,
//         title: const Text(
//           'Notification Detail',
//           style: TextStyle(color: _textPri, fontSize: 16),
//         ),
//         iconTheme: const IconThemeData(color: _textSec),
//         actions: [
//           if (_n?.status == 'sent' && (_n?.failedCount ?? 0) > 0)
//             TextButton.icon(
//               onPressed: _retrying ? null : _retry,
//               icon: _retrying
//                   ? const SizedBox(
//                       width: 14,
//                       height: 14,
//                       child: CircularProgressIndicator(
//                         color: _accent,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : const Icon(Icons.refresh, color: _accent, size: 16),
//               label: const Text(
//                 'Retry Failed',
//                 style: TextStyle(color: _accent, fontSize: 13),
//               ),
//             ),
//         ],
//       ),
//       body: _loading
//           ? const Center(
//               child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
//             )
//           : _error != null
//           ? Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text(_error!, style: const TextStyle(color: _textSec)),
//                   const SizedBox(height: 12),
//                   ElevatedButton(onPressed: _load, child: const Text('Retry')),
//                 ],
//               ),
//             )
//           : _buildBody(),
//     );
//   }

//   Widget _buildBody() {
//     final n = _n!;
//     final fmt = DateFormat('MMM d, yyyy  h:mm a');
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         // ── Header ──
//         _Card(
//           borderColor: _typeColor(n.type).withOpacity(0.3),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   _TypeChip(n.type),
//                   const SizedBox(width: 8),
//                   _StatusChip(n.status),
//                   const Spacer(),
//                   Text(
//                     '#${n.id}',
//                     style: const TextStyle(color: _textMut, fontSize: 12),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 n.title,
//                 style: const TextStyle(
//                   color: _textPri,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 n.message,
//                 style: const TextStyle(
//                   color: _textSec,
//                   fontSize: 13,
//                   height: 1.5,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               _infoRow(Icons.people_outline, 'Audience', _scopeLabel(n.scope)),
//               _infoRow(Icons.person_outline, 'Created by', n.createdBy),
//               _infoRow(
//                 Icons.calendar_today_outlined,
//                 'Created',
//                 fmt.format(n.createdAt),
//               ),
//               if (n.sentAt != null)
//                 _infoRow(Icons.send_outlined, 'Sent', fmt.format(n.sentAt!)),
//               if (n.scheduledAt != null)
//                 _infoRow(
//                   Icons.schedule_outlined,
//                   'Scheduled',
//                   fmt.format(n.scheduledAt!),
//                 ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),

//         // ── Delivery stats ──
//         _SectionHeader('Delivery Summary'),
//         const SizedBox(height: 10),
//         GridView.count(
//           crossAxisCount: 2,
//           crossAxisSpacing: 10,
//           mainAxisSpacing: 10,
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           childAspectRatio: 2.0,
//           children: [
//             _MiniStat('Total', _fmt(n.totalTargets), _textPri),
//             _MiniStat('Sent', _fmt(n.sentCount), _success),
//             _MiniStat('Failed', _fmt(n.failedCount), _error),
//             _MiniStat('Opened', '${n.openRate.toStringAsFixed(1)}%', _cyan),
//           ],
//         ),
//         const SizedBox(height: 12),

//         // Delivery rate bar
//         _Card(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _ProgressRow(
//                 label: 'Sent',
//                 value: n.sentCount,
//                 total: n.totalTargets > 0 ? n.totalTargets : 1,
//                 color: _success,
//               ),
//               _ProgressRow(
//                 label: 'Failed',
//                 value: n.failedCount,
//                 total: n.totalTargets > 0 ? n.totalTargets : 1,
//                 color: _error,
//               ),
//               _ProgressRow(
//                 label: 'Opened',
//                 value: n.openedCount,
//                 total: n.sentCount > 0 ? n.sentCount : 1,
//                 color: _cyan,
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),

//         // ── Breakdown by status ──
//         if (_breakdown.isNotEmpty) ...[
//           _SectionHeader('Status Breakdown'),
//           const SizedBox(height: 10),
//           _Card(
//             child: Column(
//               children: _breakdown.map((b) {
//                 final status = b['delivery_status'] ?? '';
//                 final count = b['count'] ?? 0;
//                 final c = _statusColor(status);
//                 return Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 8,
//                         height: 8,
//                         decoration: BoxDecoration(
//                           color: c,
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         status.toUpperCase(),
//                         style: TextStyle(
//                           color: c,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w600,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                       const Spacer(),
//                       Text(
//                         '$count',
//                         style: const TextStyle(
//                           color: _textPri,
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],

//         // ── Per-org stats ──
//         if (_orgStats.isNotEmpty) ...[
//           _SectionHeader('Per-Organization Stats'),
//           const SizedBox(height: 10),
//           ..._orgStats.map((o) {
//             final sent = o['sent'] ?? 0;
//             final failed = o['failed'] ?? 0;
//             final opened = o['opened'] ?? 0;
//             final total = o['total'] ?? 1;
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 8),
//               child: _Card(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       o['tenant_id'] ?? '',
//                       style: const TextStyle(
//                         color: _textPri,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     Row(
//                       children: [
//                         _StatPill(
//                           icon: Icons.send_outlined,
//                           value: '$sent/$total',
//                           color: _success,
//                         ),
//                         const SizedBox(width: 12),
//                         _StatPill(
//                           icon: Icons.error_outline,
//                           value: '$failed',
//                           color: _error,
//                         ),
//                         const SizedBox(width: 12),
//                         _StatPill(
//                           icon: Icons.visibility_outlined,
//                           value: '$opened',
//                           color: _cyan,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }),
//         ],
//       ],
//     );
//   }

//   Widget _infoRow(IconData icon, String label, String value) => Padding(
//     padding: const EdgeInsets.only(bottom: 6),
//     child: Row(
//       children: [
//         Icon(icon, color: _textMut, size: 14),
//         const SizedBox(width: 6),
//         Text(label, style: const TextStyle(color: _textMut, fontSize: 12)),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             value,
//             style: const TextStyle(color: _textSec, fontSize: 12),
//             textAlign: TextAlign.right,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// class _MiniStat extends StatelessWidget {
//   final String label;
//   final String value;
//   final Color color;

//   const _MiniStat(this.label, this.value, this.color);

//   @override
//   Widget build(BuildContext context) => _Card(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           value,
//           style: TextStyle(
//             color: color,
//             fontSize: 20,
//             fontWeight: FontWeight.w700,
//           ),
//         ),
//         Text(label, style: const TextStyle(color: _textMut, fontSize: 11)),
//       ],
//     ),
//   );
// }
