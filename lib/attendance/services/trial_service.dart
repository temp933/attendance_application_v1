// lib/services/trial_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// TrialService  — fetches trial status once per session and caches it.
// TrialBanner   — a dismissible top banner shown in UserDashboardScreen
//                 when trial is active or expired.
// ─────────────────────────────────────────────────────────────────────────────
//
// HOW TO USE IN user_dashboard_screen.dart
// ─────────────────────────────────────────
// 1. Import this file.
// 2. Add  TrialStatus? _trialStatus;  field to _UserDashboardScreenState.
// 3. In initState(), after _buildPages():
//      _loadTrialStatus();
// 4. Add the method:
//      Future<void> _loadTrialStatus() async {
//        final status = await TrialService.fetch();
//        if (mounted) setState(() => _trialStatus = status);
//      }
// 5. In build(), wrap the body's Column (or add to AppBar bottom) like:
//      Column(children: [
//        if (_trialStatus != null)
//          TrialBanner(status: _trialStatus!,
//                      onDismiss: () => setState(() => _trialStatus = null)),
//        Expanded(child: <existing body>),
//      ])

import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class TrialStatus {
  final String status; // 'trial' | 'active' | 'expired' | 'suspended'
  final String? trialEndsAt; // 'YYYY-MM-DD'
  final int? daysRemaining;
  final bool isTrialActive;
  final bool requiresPayment;

  const TrialStatus({
    required this.status,
    this.trialEndsAt,
    this.daysRemaining,
    required this.isTrialActive,
    required this.requiresPayment,
  });

  factory TrialStatus.fromJson(Map<String, dynamic> j) => TrialStatus(
    status: j['status'] as String? ?? 'active',
    trialEndsAt: j['trial_ends_at'] as String?,
    daysRemaining: j['days_remaining'] as int?,
    isTrialActive: j['is_trial_active'] as bool? ?? false,
    requiresPayment: j['requires_payment'] as bool? ?? false,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class TrialService {
  TrialService._();

  static Future<TrialStatus?> fetch() async {
    try {
      final res = await ApiClient.get('/tenant/trial-status');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return TrialStatus.fromJson(body);
        }
      }
    } catch (e) {
      debugPrint('[TrialService] fetch error: $e');
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner widget
// ─────────────────────────────────────────────────────────────────────────────
class TrialBanner extends StatelessWidget {
  final TrialStatus status;
  final VoidCallback onDismiss;

  const TrialBanner({super.key, required this.status, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Don't show for fully active (paid) orgs
    if (status.status == 'active' && !status.requiresPayment) {
      return const SizedBox.shrink();
    }

    final bool expired = status.requiresPayment;

    final Color bg = expired
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFFFFBEB);
    final Color border = expired
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFFDE68A);
    final Color text = expired
        ? const Color(0xFF991B1B)
        : const Color(0xFF92400E);
    final Color icon = expired
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    final String message = expired
        ? 'Trial expired. Upgrade your plan to continue using the app.'
        : 'Trial active — ${status.daysRemaining ?? 0} day${(status.daysRemaining ?? 0) == 1 ? '' : 's'} remaining. Upgrade before ${status.trialEndsAt ?? '—'}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.lock_outline_rounded : Icons.hourglass_top_rounded,
            size: 16,
            color: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: text,
                height: 1.4,
              ),
            ),
          ),
          if (!expired) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: text),
            ),
          ],
        ],
      ),
    );
  }
}
