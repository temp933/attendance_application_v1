import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

class AdminForceCloseScreen extends StatefulWidget {
  final int loginId; // logged-in admin/manager login_id
  const AdminForceCloseScreen({super.key, required this.loginId});

  @override
  State<AdminForceCloseScreen> createState() => _AdminForceCloseScreenState();
}

class _AdminForceCloseScreenState extends State<AdminForceCloseScreen>
    with SingleTickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  // ── State ──────────────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _openSessions = [];

  // Track which cards are closing (loading state per employee)
  final Set<int> _closingIds = {};
  bool _closingAll = false;

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtApi(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _fmtMinutes(int? m) {
    if (m == null || m == 0) return '0m';
    final h = m ~/ 60;
    final min = m % 60;
    return h > 0 ? '${h}h ${min.toString().padLeft(2, '0')}m' : '${min}m';
  }

  String _fmtTimestamp(String? ts) {
    if (ts == null) return '--:--';
    try {
      final t = ts.contains(' ') ? ts.split(' ')[1] : ts;
      return t.length >= 5 ? t.substring(0, 5) : t;
    } catch (_) {
      return '--:--';
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.get('/attendance/open-sessions');

      if (res.statusCode != 200) {
        throw Exception('Server error ${res.statusCode}');
      }

      final body = jsonDecode(res.body);

      if (body['success'] != true) {
        throw Exception(body['message'] ?? 'Error');
      }

      if (!mounted) return;

      setState(() {
        _openSessions = List<Map<String, dynamic>>.from(body['data'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _openSessions = [];
      });
      await _load();
    }
  }

  // ── Force close single employee ────────────────────────────────────────────

  Future<void> _showForceCloseDialog(Map<String, dynamic> session) async {
    final empId = session['employee_id'] as int;
    final empName = session['emp_name'] as String? ?? 'Employee';
    final sessionId = session['session_id'] as int?;

    TimeOfDay closeTime = TimeOfDay.now();
    final reasonCtrl = TextEditingController();
    String? errorText;
    DateTime selectedDate = _selectedDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _card,
          contentPadding: EdgeInsets.zero,
          title: null,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: const BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.lock_clock_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Force Close Session',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  empName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Body ──────────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warning box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: _orange,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'This will mark the checkout time for all '
                                  'open visits and end the session.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMid,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Set Date',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setLocal(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  color: _primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _fmtDisplay(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: _textLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Close time picker
                        const Text(
                          'Set Checkout Time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: closeTime,
                              builder: (c, child) => Theme(
                                data: Theme.of(c).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: _primary,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setLocal(() => closeTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: _primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${closeTime.hour.toString().padLeft(2, '0')}:'
                                  '${closeTime.minute.toString().padLeft(2, '0')}  '
                                  '(${_fmtDisplay(selectedDate)})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _primary,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: _textLight,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Reason
                        const Text(
                          'Reason *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g. Device lost, forgot to checkout...',
                            hintStyle: const TextStyle(
                              color: _textLight,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: _surface,
                            errorText: errorText,
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
                              borderSide: const BorderSide(
                                color: _primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          onChanged: (_) {
                            if (errorText != null)
                              setLocal(() => errorText = null);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ── Footer ────────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: _textMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              if (reasonCtrl.text.trim().isEmpty) {
                                setLocal(
                                  () => errorText = 'Reason is required',
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              await _forceClose(
                                empId: empId,
                                sessionId: sessionId,
                                closeDate: selectedDate,
                                closeTime: closeTime,
                                reason: reasonCtrl.text.trim(),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text(
                              'Force Close',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ], // closes Column children
              ), // closes Column
            ), // closes SingleChildScrollView
          ), // closes ConstrainedBox
        ), // closes AlertDialog
      ), // closes StatefulBuilder builder
    ); // closes showDialog
  }

  Future<void> _forceClose({
    required int empId,
    int? sessionId,
    required DateTime closeDate, // ✅ NEW
    required TimeOfDay closeTime,
    required String reason,
  }) async {
    setState(() => _closingIds.add(empId));
    try {
      // Build datetime string from selected date + time
      final closeDateTime = DateTime(
        closeDate.year,
        closeDate.month,
        closeDate.day,
        closeTime.hour,
        closeTime.minute,
      );
      final offset = closeDateTime.timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final h = offset.inHours.abs().toString().padLeft(2, '0');
      final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final closeIso =
          '${closeDateTime.toIso8601String().split('.')[0]}$sign$h:$m';
      final res = await ApiClient.post('/attendance/admin-force-close', {
        'employee_id': empId,
        'session_id': sessionId,
        'close_time': closeIso,
        'reason': reason,
        'closed_by_login_id': widget.loginId,
        'work_date': _fmtApi(closeDate),
      });

      if (!mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['success'] == true) {
        _showSnack(
          '✓ Session closed — ${body['sessions_closed']} session, '
          '${body['visits_closed']} visit(s) updated',
          success: true,
        );
        await _load();
      } else {
        _showSnack(body['message'] ?? 'Failed to close session');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _closingIds.remove(empId));
    }
  }

  // ── Force close ALL ────────────────────────────────────────────────────────

  Future<void> _showCloseAllDialog() async {
    TimeOfDay closeTime = TimeOfDay.now();
    final reasonCtrl = TextEditingController();
    String? errorText;
    DateTime selectedDate = _selectedDate;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: _card,
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Close All Open Sessions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_openSessions.length} employee(s)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: _red,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This will close ALL ${_openSessions.length} open '
                              'session(s) for ${_fmtDisplay(_selectedDate)}. '
                              'This action cannot be undone.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Affected employees preview
                    const Text(
                      'Affected Employees',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _openSessions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 8, color: _border),
                        itemBuilder: (_, i) {
                          final s = _openSessions[i];
                          return Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s['emp_name'] ?? 'Employee',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _fmtMinutes(
                                  (s['open_minutes'] as num?)?.toInt(),
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _orange,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Close time
                    const Text(
                      'Set Checkout Time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: closeTime,
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _primary,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setLocal(() => closeTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: _primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${closeTime.hour.toString().padLeft(2, '0')}:'
                              '${closeTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: _textLight,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reason
                    const Text(
                      'Reason *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. End of shift bulk closure...',
                        hintStyle: const TextStyle(
                          color: _textLight,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: _surface,
                        errorText: errorText,
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
                          borderSide: const BorderSide(
                            color: _primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onChanged: (_) {
                        if (errorText != null) setLocal(() => errorText = null);
                      },
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: _textMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (reasonCtrl.text.trim().isEmpty) {
                            setLocal(() => errorText = 'Reason is required');
                            return;
                          }
                          Navigator.pop(ctx);
                          await _forceCloseAll(
                            closeDate: selectedDate,
                            closeTime: closeTime,
                            reason: reasonCtrl.text.trim(),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text(
                          'Close All',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
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
    );
  }

  Future<void> _forceCloseAll({
    required DateTime closeDate, // ✅ ADD THIS
    required TimeOfDay closeTime,
    required String reason,
  }) async {
    setState(() => _closingAll = true);
    try {
      final closeDateTime = DateTime(
        closeDate.year, // ✅ now defined
        closeDate.month,
        closeDate.day,
        closeTime.hour,
        closeTime.minute,
      );

      final res = await ApiClient.post('/attendance/admin-force-close-all', {
        'work_date': _fmtApi(_selectedDate),
        'close_time': closeDateTime.toIso8601String(),
        'reason': reason,
        'closed_by_login_id': widget.loginId,
      });
      if (!mounted) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        _showSnack(
          '✓ Closed ${body['sessions_closed']} session(s), '
          '${body['visits_closed']} visit(s)',
          success: true,
        );
        await _load();
      } else {
        _showSnack(body['message'] ?? 'Failed');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _closingAll = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
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

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        16,
      ),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Sessions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Force-close unclosed attendance',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Refresh
              GestureDetector(
                onTap: _loading ? null : _load,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date selector + count pill
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _fmtDisplay(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Colors.white70,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_openSessions.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_openSessions.length} open',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildShimmer();
    if (_error != null) return _buildError();
    if (_openSessions.isEmpty) return _buildEmpty();
    return _buildList();
  }

  // ── Shimmer loading ────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, __) {
        final gradient = LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1 + 2 * _shimmerCtrl.value, 0),
          end: Alignment(1 + 2 * _shimmerCtrl.value, 0),
        );
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: _accent,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'All Sessions Closed!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'No open attendance sessions found.',
          style: TextStyle(fontSize: 13, color: _textMid),
        ),
        const SizedBox(height: 4),
        const Text(
          'Every employee has checked out.',
          style: TextStyle(fontSize: 12, color: _textLight),
        ),
      ],
    ),
  );

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, color: _red, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to load',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _textMid),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Session list ───────────────────────────────────────────────────────────

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Close All banner
          SliverToBoxAdapter(child: _buildCloseAllBanner()),

          // Session cards
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              32 + MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _OpenSessionCard(
                  session: _openSessions[i],
                  isClosing: _closingIds.contains(
                    _openSessions[i]['employee_id'],
                  ),
                  onForceClose: () => _showForceCloseDialog(_openSessions[i]),
                  fmtMinutes: _fmtMinutes,
                  fmtTimestamp: _fmtTimestamp,
                ),
                childCount: _openSessions.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseAllBanner() {
    if (_openSessions.length < 2) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _red.withValues(alpha: 0.08),
              _orange.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_rounded, color: _red, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_openSessions.length} sessions still open',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const Text(
                    'Close all at once with one tap',
                    style: TextStyle(fontSize: 11, color: _textMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _closingAll
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: _red,
                      strokeWidth: 2.5,
                    ),
                  )
                : FilledButton(
                    onPressed: _showCloseAllDialog,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Close All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OpenSessionCard — individual employee card with open session info
// ─────────────────────────────────────────────────────────────────────────────

class _OpenSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool isClosing;
  final VoidCallback onForceClose;
  final String Function(int?) fmtMinutes;
  final String Function(String?) fmtTimestamp;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _red = Color(0xFFEF4444);
  static const Color _orange = Color(0xFFF97316);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  const _OpenSessionCard({
    required this.session,
    required this.isClosing,
    required this.onForceClose,
    required this.fmtMinutes,
    required this.fmtTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final empName = session['emp_name'] as String? ?? 'Employee';
    final empId = session['emp_id'] as int? ?? 0;
    final dept = session['department_name'] as String? ?? '';
    final role = session['role_name'] as String? ?? '';
    final startedAt = session['started_at'] as String?;
    final openMinutes = (session['open_minutes'] as num?)?.toInt() ?? 0;
    final openVisits = (session['open_visits'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final sessNum = session['session_number'] as int? ?? 1;
    final isLate = session['is_late'] == 1;
    final lateText = session['late_hours_text'] as String?;
    final initial = empName.isNotEmpty ? empName[0].toUpperCase() : '?';

    // Urgency: >8h open = critical, >4h = warning, else normal
    final Color urgencyColor = openMinutes > 480
        ? _red
        : openMinutes > 240
        ? _orange
        : _primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Urgency accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [urgencyColor, urgencyColor.withValues(alpha: 0.5)],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                // ── Employee row ───────────────────────────────────────────────
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            urgencyColor,
                            urgencyColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'ID: $empId',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textLight,
                                ),
                              ),
                              if (dept.isNotEmpty) ...[
                                const Text(
                                  ' · ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textLight,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    dept,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (role.isNotEmpty)
                            Text(
                              role,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _textLight,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Open duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: urgencyColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            fmtMinutes(openMinutes),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: urgencyColor,
                            ),
                          ),
                          Text(
                            'open',
                            style: TextStyle(
                              fontSize: 9,
                              color: urgencyColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Session info strip ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Session number
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Session $sessNum',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.login_rounded,
                        size: 13,
                        color: _textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Started ${fmtTimestamp(startedAt)}',
                        style: const TextStyle(fontSize: 12, color: _textMid),
                      ),
                      const Spacer(),
                      if (isLate && lateText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Late $lateText',
                            style: const TextStyle(
                              fontSize: 9,
                              color: _orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Still open indicator
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: urgencyColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: urgencyColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: urgencyColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Open visits ────────────────────────────────────────────────
                if (openVisits.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...openVisits.map(
                    (v) => _VisitChip(
                      visit: v,
                      fmtTimestamp: fmtTimestamp,
                      fmtMinutes: fmtMinutes,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Force close button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: isClosing
                      ? Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: _red,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Closing session...',
                                  style: TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: onForceClose,
                          icon: const Icon(Icons.lock_rounded, size: 16),
                          label: const Text(
                            'Force Close Session',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
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

// ── Open Visit Chip ────────────────────────────────────────────────────────────
class _VisitChip extends StatelessWidget {
  final Map<String, dynamic> visit;
  final String Function(String?) fmtTimestamp;
  final String Function(int?) fmtMinutes;

  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _orange = Color(0xFFF97316);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  const _VisitChip({
    required this.visit,
    required this.fmtTimestamp,
    required this.fmtMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final siteName = visit['site_name'] as String? ?? 'Unknown Site';
    final inTime = visit['in_time'] as String?;
    final openMinutes = (visit['open_minutes'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 14,
              color: _primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siteName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 10, color: _textMid),
                    const SizedBox(width: 3),
                    Text(
                      'In: ${fmtTimestamp(inTime)}',
                      style: const TextStyle(fontSize: 10, color: _textMid),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(fontSize: 10, color: _textMid),
                    ),
                    const Icon(
                      Icons.no_accounts_rounded,
                      size: 10,
                      color: _orange,
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'Not checked out',
                      style: TextStyle(fontSize: 10, color: _orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fmtMinutes(openMinutes),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
