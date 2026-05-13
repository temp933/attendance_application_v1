import 'package:flutter/material.dart';

// ─── Design Tokens (single source of truth) ───────────────────────────────────
const kDeptPrimary = Color(0xFF1A56DB);
const kDeptPrimaryLight = Color(0xFFEEF2FF);
const kDeptSurface = Color(0xFFF8FAFF);
const kDeptCard = Colors.white;
const kDeptTextDark = Color(0xFF0F172A);
const kDeptTextMid = Color(0xFF64748B);
const kDeptTextLight = Color(0xFF94A3B8);
const kDeptSuccess = Color(0xFF10B981);
const kDeptDanger = Color(0xFFEF4444);
const kDeptBorder = Color(0xFFE2E8F0);

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class DeptStatusBadge extends StatelessWidget {
  final String status;
  const DeptStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? kDeptSuccess.withValues(alpha: 0.1)
            : kDeptTextLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? kDeptSuccess : kDeptTextLight,
        ),
      ),
    );
  }
}

class DeptPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const DeptPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: ElevatedButton.styleFrom(
      backgroundColor: kDeptPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class DeptAppDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final Future<void> Function() onConfirm;
  final String confirmLabel;

  const DeptAppDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.onConfirm,
    required this.confirmLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: kDeptPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kDeptTextMid)),
        ),
        ElevatedButton(
          onPressed: () {
            final nav = Navigator.of(context); // ✅ capture before async gap
            onConfirm().then((_) {
              if (context.mounted) nav.pop();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kDeptPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class DeptAppTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const DeptAppTextField({super.key, required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    autofocus: true,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kDeptPrimary, width: 1.5),
      ),
    ),
  );
}

class DeptEmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  const DeptEmptyView({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: kDeptTextLight),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: kDeptTextMid, fontSize: 14),
        ),
      ],
    ),
  );
}

class DeptErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const DeptErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: kDeptDanger),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kDeptTextMid, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kDeptPrimary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}
