import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/normal_attendance_service.dart';
import 'att_history.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
class AttendancePolicy {
  final String? officeInTime;
  final String? officeOutTime;
  final int lateAfterMinutes;
  final bool multipleInOutAllowed;

  const AttendancePolicy({
    this.officeInTime,
    this.officeOutTime,
    this.lateAfterMinutes = 0,
    this.multipleInOutAllowed = true,
  });

  factory AttendancePolicy.fromJson(Map<String, dynamic> j) => AttendancePolicy(
    officeInTime: j['office_in_time'] as String?,
    officeOutTime: j['office_out_time'] as String?,
    lateAfterMinutes: (j['late_after_minutes'] as num?)?.toInt() ?? 0,
    multipleInOutAllowed: (j['multiple_in_out_allowed'] as num?)?.toInt() == 1,
  );

  // "HH:MM:SS" → "hh:mm AM/PM"
  String? get officeInDisplay => _fmtPolicyTime(officeInTime);
  String? get officeOutDisplay => _fmtPolicyTime(officeOutTime);

  static String? _fmtPolicyTime(String? t) {
    if (t == null) return null;
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('hh:mm a').format(dt);
  }
}

class NormalAttendanceRecord {
  final int attendanceId;
  final String mode;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final String status;
  final String? totalWorkTime;
  final bool isLate;
  final int lateMinutes;

  const NormalAttendanceRecord({
    required this.attendanceId,
    required this.mode,
    this.checkinTime,
    this.checkoutTime,
    required this.status,
    this.totalWorkTime,
    this.isLate = false,
    this.lateMinutes = 0,
  });

  factory NormalAttendanceRecord.fromJson(Map<String, dynamic> j) =>
      NormalAttendanceRecord(
        attendanceId: (j['attendance_id'] as num).toInt(),
        mode: j['attendance_mode'] as String? ?? 'normal',
        checkinTime: j['checkin_time'] != null
            ? DateTime.tryParse(j['checkin_time'] as String)
            : null,
        checkoutTime: j['checkout_time'] != null
            ? DateTime.tryParse(j['checkout_time'] as String)
            : null,
        status: j['status'] as String? ?? 'active',
        totalWorkTime: j['total_work_time'] as String?,
        isLate: (j['is_late'] as num?)?.toInt() == 1,
        lateMinutes: (j['late_minutes'] as num?)?.toInt() ?? 0,
      );

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class NormalAttendanceScreen extends StatefulWidget {
  const NormalAttendanceScreen({super.key});

  @override
  State<NormalAttendanceScreen> createState() => _NormalAttendanceScreenState();
}

class _NormalAttendanceScreenState extends State<NormalAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _actionLoading = false;
  NormalAttendanceRecord? _record;
  AttendancePolicy? _policy;

  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _init();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _init() async {
    setState(() => _loading = true);
    await Future.wait([_fetchToday(), _fetchHistory()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchToday() async {
    try {
      final result = await AttendanceService.getTodayFull();

      if (!mounted) return;

      // NULL SAFETY CHECK
      if (result == null) {
        setState(() {
          _record = null;
          _policy = null;
        });
        return;
      }

      setState(() {
        _record = result['record'] != null
            ? NormalAttendanceRecord.fromJson(
                result['record'] as Map<String, dynamic>,
              )
            : null;

        _policy = result['policy'] != null
            ? AttendancePolicy.fromJson(
                result['policy'] as Map<String, dynamic>,
              )
            : null;
      });
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString(), isError: true);
      }
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _historyLoading = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final list = await AttendanceService.getHistory(limit: 10);
      if (mounted) {
        setState(() {
          _history = list.where((r) {
            final d = r['work_date'] as String? ?? '';
            return d.startsWith(today);
          }).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _historyLoading = false);
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _checkIn() async {
    setState(() => _actionLoading = true);
    try {
      final result = await AttendanceService.checkInFull();
      final rec = NormalAttendanceRecord.fromJson(result);
      setState(() => _record = rec);
      if (rec.isLate && rec.lateMinutes > 0) {
        _showSnack(
          'Checked in — ${_fmtLate(rec.lateMinutes)} late 🕐',
          isError: false,
          color: Colors.orange.shade700,
        );
      } else {
        _showSnack('Checked in on time! 👋', isError: false);
      }
      await _fetchHistory();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkOut() async {
    final confirm = await _showConfirmDialog(
      title: 'Check Out',
      message: 'Are you sure you want to check out?',
      confirmLabel: 'Check Out',
      icon: Icons.logout_rounded,
      iconColor: const Color(0xFFE65100),
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      final result = await AttendanceService.checkOutFull();
      setState(() => _record = NormalAttendanceRecord.fromJson(result));
      _showSnack('Checked out. Have a great day! ✅', isError: false);
      await _fetchHistory();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(DateTime? dt) =>
      dt == null ? '--:--' : DateFormat('hh:mm a').format(dt);

  String _elapsed(DateTime from) {
    final d = _now.difference(from);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}m'
        : '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _parseTotalWork(String? t) {
    if (t == null) return '--';
    final parts = t.split(':').map(int.parse).toList();
    final h = parts[0];
    final m = parts.length > 1 ? parts[1] : 0;
    if (h == 0 && m == 0) return '--';
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String _fmtLate(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  void _showSnack(String msg, {required bool isError, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            color ?? (isError ? Colors.red.shade700 : const Color(0xFF2E7D32)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    required Color iconColor,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: iconColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _init,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader(),
                          const SizedBox(height: 14),
                          if (_policy != null) ...[
                            _buildPolicyBanner(),
                            const SizedBox(height: 14),
                          ],
                          _buildStatusCard(),
                          const SizedBox(height: 14),
                          _buildTimingsRow(),
                          const SizedBox(height: 14),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildHistorySection(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEE, d MMM yyyy').format(_now),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Attendance',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AttendanceHistoryScreen(mode: 'normal'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: Color(0xFF5C6BC0),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: Color(0xFF5C6BC0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('hh:mm:ss a').format(_now),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Policy banner ──────────────────────────────────────────────────────────
  Widget _buildPolicyBanner() {
    final p = _policy!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.corporate_fare_rounded,
            size: 16,
            color: Colors.indigo.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            'Office Hours',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.indigo.shade400,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: Colors.grey.shade300),
          const SizedBox(width: 10),
          Icon(Icons.login_rounded, size: 13, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            p.officeInDisplay ?? '--',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.logout_rounded, size: 13, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text(
            p.officeOutDisplay ?? '--',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          if (p.lateAfterMinutes > 0) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Grace ${p.lateAfterMinutes}m',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final bool isActive = _record?.isActive ?? false;
    final bool isCompleted = _record?.isCompleted ?? false;

    final LinearGradient gradient;
    final IconData icon;
    final String label;
    final String sublabel;

    if (isActive) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.sensors_rounded;
      label = 'Currently Checked In';
      sublabel = _elapsed(_record!.checkinTime!);
    } else if (isCompleted) {
      gradient = const LinearGradient(
        colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.check_circle_rounded;
      label = 'Day Complete';
      sublabel = 'Worked ${_parseTotalWork(_record!.totalWorkTime)} today';
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFF37474F), Color(0xFF607D8B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.fingerprint_rounded;
      label = 'Not Checked In';
      sublabel = 'Tap CHECK IN to start your session';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              // Label + sublabel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sublabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Pulse dot / static dot
              if (isActive)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFA5D6A7),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFA5D6A7,
                            ).withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),

          // ── Late badge (shown when late) ───────────────────────────────────
          if (_record != null &&
              _record!.isLate &&
              _record!.lateMinutes > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),

                  const Spacer(),
                  if (_policy?.officeInDisplay != null)
                    Text(
                      'Expected ${_policy!.officeInDisplay}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Timings row — 4 blocks ─────────────────────────────────────────────────
  Widget _buildTimingsRow() {
    final bool isActive = _record?.isActive ?? false;

    final String totalLabel = isActive
        ? _elapsed(_record!.checkinTime!)
        : _parseTotalWork(_record?.totalWorkTime);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _timingBlock(
              icon: Icons.login_rounded,
              iconBg: Colors.green.shade50,
              iconColor: Colors.green.shade700,
              label: 'Check In',
              value: _fmtTime(_record?.checkinTime),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _timingBlock(
              icon: Icons.logout_rounded,
              iconBg: Colors.red.shade50,
              iconColor: Colors.red.shade400,
              label: 'Check Out',
              value: _fmtTime(_record?.checkoutTime),
            ),
          ),
          _vDivider(),
          Expanded(
            child: _timingBlock(
              icon: Icons.timelapse_rounded,
              iconBg: Colors.indigo.shade50,
              iconColor: Colors.indigo.shade500,
              label: 'Total Work',
              value: totalLabel,
              valueColor: isActive ? Colors.indigo.shade700 : null,
            ),
          ),
          _vDivider(),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 44, color: Colors.grey.shade200);

  Widget _timingBlock({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor ?? const Color(0xFF1A1A2E),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  // ── Buttons ────────────────────────────────────────────────────────────────
  Widget _buildActionButtons() {
    // FIX: was "_record == null" which blocked re-check-in after checkout.
    // Now allows CHECK IN when no record exists OR when last session is completed.
    // The backend enforces multiple_in_out_allowed policy — it will reject if
    // the policy doesn't allow it and show the error in the snackbar.
    final bool canCheckIn = _record == null || _record!.isCompleted;
    final bool canCheckOut = _record?.isActive == true;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'CHECK IN',
            icon: Icons.login_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            enabled: canCheckIn && !_actionLoading,
            loading: _actionLoading && canCheckIn,
            onTap: _checkIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'CHECK OUT',
            icon: Icons.logout_rounded,
            gradient: const LinearGradient(
              colors: [Color(0xFFBF360C), Color(0xFFE64A19)],
            ),
            enabled: canCheckOut && !_actionLoading,
            loading: _actionLoading && canCheckOut,
            onTap: _checkOut,
          ),
        ),
      ],
    );
  }

  // ── History ────────────────────────────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 17,
                  color: Colors.indigo.shade400,
                ),
                const SizedBox(width: 7),
                Text(
                  'Recent Attendance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AttendanceHistoryScreen(mode: 'normal'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: Colors.indigo.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_historyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_history.isEmpty)
          _emptyHistory()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildHistoryRow(_history[i]),
          ),
      ],
    );
  }

  Widget _emptyHistory() => Container(
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 36,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 10),
        Text(
          'No history yet',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildHistoryRow(Map<String, dynamic> row) {
    final status = row['status'] as String? ?? 'completed';
    final isActive = status == 'active';
    final isLate = (row['is_late'] as num?)?.toInt() == 1;
    final lateMin = (row['late_minutes'] as num?)?.toInt() ?? 0;
    final workDate = row['work_date'] as String? ?? '';
    final checkin = row['checkin_time'] != null
        ? DateTime.tryParse(row['checkin_time'] as String)
        : null;
    final checkout = row['checkout_time'] != null
        ? DateTime.tryParse(row['checkout_time'] as String)
        : null;
    final totalWork = row['total_work_time'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.green.shade200
              : isLate
              ? Colors.orange.shade200
              : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date block
          SizedBox(
            width: 42,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workDate.isNotEmpty
                      ? DateFormat('EEE').format(DateTime.parse(workDate))
                      : '--',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  workDate.isNotEmpty
                      ? DateFormat('d MMM').format(DateTime.parse(workDate))
                      : '--',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey.shade200,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Times + late tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _historyTag(
                      icon: Icons.login_rounded,
                      label: _fmtTime(checkin),
                      color: Colors.green.shade700,
                      bg: Colors.green.shade50,
                    ),
                    _historyTag(
                      icon: Icons.logout_rounded,
                      label: isActive ? 'Active' : _fmtTime(checkout),
                      color: isActive
                          ? Colors.orange.shade700
                          : Colors.red.shade400,
                      bg: isActive ? Colors.orange.shade50 : Colors.red.shade50,
                    ),
                  ],
                ),
                if (isLate && lateMin > 0) ...[
                  const SizedBox(height: 5),
                  _historyTag(
                    icon: Icons.schedule_rounded,
                    label: '${_fmtLate(lateMin)} late',
                    color: Colors.orange.shade800,
                    bg: Colors.orange.shade50,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                    )
                  : LinearGradient(
                      colors: [Colors.grey.shade200, Colors.grey.shade300],
                    ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _parseTotalWork(totalWork),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTag({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled ? gradient : null,
          color: enabled ? null : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: gradient.colors.last.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
