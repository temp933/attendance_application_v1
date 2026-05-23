import 'dart:convert';
import 'package:flutter/material.dart';
import '../../providers/api_client.dart'; // adjust import to your project structure

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _orange = Color(0xFFF97316);
const Color _purple = Color(0xFF7C3AED);
const Color _teal = Color(0xFF0891B2);
const Color _surface = Color(0xFFF0F4FF);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
// Attendance mode helpers
// ─────────────────────────────────────────────────────────────────────────────
enum AttendanceMode { normal, gps, gpsFace }

AttendanceMode _parseMode(String? raw) {
  switch (raw) {
    case 'gps':
      return AttendanceMode.gps;
    case 'gps_face':
      return AttendanceMode.gpsFace;
    default:
      return AttendanceMode.normal;
  }
}

bool _isLocationMode(AttendanceMode m) =>
    m == AttendanceMode.gps || m == AttendanceMode.gpsFace;

String _modeLabel(AttendanceMode m) {
  switch (m) {
    case AttendanceMode.gps:
      return 'GPS';
    case AttendanceMode.gpsFace:
      return 'GPS + Face';
    case AttendanceMode.normal:
      return 'Normal';
  }
}

Color _modeColor(AttendanceMode m) {
  switch (m) {
    case AttendanceMode.gps:
      return _teal;
    case AttendanceMode.gpsFace:
      return _purple;
    case AttendanceMode.normal:
      return _primary;
  }
}

IconData _modeIcon(AttendanceMode m) {
  switch (m) {
    case AttendanceMode.gps:
      return Icons.location_on_outlined;
    case AttendanceMode.gpsFace:
      return Icons.face_outlined;
    case AttendanceMode.normal:
      return Icons.fingerprint;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────
class _OpenSession {
  final int sessionId;
  final int employeeId;
  final String empName;
  final String departmentName;
  final String startedAt;
  final int openMinutes;
  final bool isLate;
  final int lateMinutes;
  final int? sessionNumber;
  final AttendanceMode mode;

  // Location fields (null for normal mode)
  final double? checkinLatitude;
  final double? checkinLongitude;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final String? lastLocationUpdatedAt;

  _OpenSession({
    required this.sessionId,
    required this.employeeId,
    required this.empName,
    required this.departmentName,
    required this.startedAt,
    required this.openMinutes,
    required this.isLate,
    required this.lateMinutes,
    required this.mode,
    this.sessionNumber,
    this.checkinLatitude,
    this.checkinLongitude,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastLocationUpdatedAt,
  });

  factory _OpenSession.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return _OpenSession(
      sessionId: toInt(j['session_id']),
      employeeId: toInt(j['employee_id']),
      empName: j['emp_name'] as String? ?? '',
      departmentName: j['department_name'] as String? ?? '',
      startedAt: j['started_at'] as String? ?? '',
      openMinutes: toInt(j['open_minutes']),
      isLate: (j['is_late'] == 1 || j['is_late'] == true),
      lateMinutes: toInt(j['late_minutes']),
      sessionNumber: j['session_number'] != null
          ? toInt(j['session_number'])
          : null,
      mode: _parseMode(j['attendance_mode'] as String?),

      checkinLatitude: toDouble(j['checkin_latitude']),
      checkinLongitude: toDouble(j['checkin_longitude']),
      lastKnownLatitude: toDouble(j['last_known_latitude']),
      lastKnownLongitude: toDouble(j['last_known_longitude']),

      lastLocationUpdatedAt: j['last_location_updated_at'] as String?,
    );
  }

  /// Returns true if this GPS session has a last-known location synced.
  bool get hasLastLocation =>
      _isLocationMode(mode) &&
      lastKnownLatitude != null &&
      lastKnownLongitude != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final dow = days[d.weekday - 1];
  return '$dow, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtMinutes(int? m) {
  if (m == null || m <= 0) return '0m';
  final h = m ~/ 60;
  final min = m % 60;
  if (h == 0) return '${min}m';
  if (min == 0) return '${h}h';
  return '${h}h ${min}m';
}

String _fmtTimestamp(String? ts) {
  if (ts == null || ts.isEmpty) return '--:--';
  final parts = ts.split(' ');
  if (parts.length < 2) return '--:--';
  final timeParts = parts[1].split(':');
  if (timeParts.length < 2) return '--:--';
  return '${timeParts[0]}:${timeParts[1]}';
}

String _fmtCoord(double? lat, double? lng) {
  if (lat == null || lng == null) return 'No location';
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

Color _urgencyColor(int minutes) {
  if (minutes > 480) return _red;
  if (minutes > 240) return _orange;
  return _primary;
}

/// Build the ISO string with IST offset that the backend expects.
String _isoWithOffset(DateTime date, TimeOfDay time) {
  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  const offset = '+05:30';
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '${y}-${mo}-${d}T${h}:${mi}:00$offset';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AdminForceCloseScreen extends StatefulWidget {
  const AdminForceCloseScreen({
    super.key,
    required this.loginId,
    required this.mode, // 'normal' | 'gps' | 'gps_face'
  });
  final int loginId;
  final String mode;

  @override
  State<AdminForceCloseScreen> createState() => _AdminForceCloseScreenState();
}

enum _LoadState { loading, error, empty, data }

class _AdminForceCloseScreenState extends State<AdminForceCloseScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  DateTime _selectedDate = DateTime.now();
  List<_OpenSession> _openSessions = [];
  _LoadState _loadState = _LoadState.loading;
  String _errorMsg = '';

  final Set<int> _closingIds = {};
  bool _closingAll = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnim = Tween<double>(
      begin: -1,
      end: 2,
    ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
    _load();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── API calls ───────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final resp = await ApiClient.get(
        '/attendance_sessions/open-sessions?date=${_fmtApi(_selectedDate)}&mode=${widget.mode}',
      );

      // ApiClient.get returns http.Response — always decode the body string
      final Map<String, dynamic> body =
          jsonDecode(resp.body) as Map<String, dynamic>;

      if (body['success'] == true) {
        final raw = body['data'];
        final List<_OpenSession> list = raw is List
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .map((e) => _OpenSession.fromJson(e))
                  .toList()
            : <_OpenSession>[];

        setState(() {
          _openSessions = list;
          _loadState = list.isEmpty ? _LoadState.empty : _LoadState.data;
        });
      } else {
        setState(() {
          _loadState = _LoadState.error;
          _errorMsg = body['message']?.toString() ?? 'Unknown error';
        });
      }
    } catch (e) {
      setState(() {
        _loadState = _LoadState.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _forceClose(
    _OpenSession s,
    DateTime closeDate,
    TimeOfDay closeTime,
    String reason,
  ) async {
    setState(() => _closingIds.add(s.employeeId));
    try {
      final body = <String, dynamic>{
        'employee_id': s.employeeId,
        'session_id': s.sessionId,
        'close_time': _isoWithOffset(closeDate, closeTime),
        'reason': reason,
        'closed_by_login_id': widget.loginId,
        'work_date': _fmtApi(_selectedDate),
      };

      // For GPS modes: pass last-known location as checkout coords
      if (_isLocationMode(s.mode) && s.hasLastLocation) {
        body['checkout_latitude'] = s.lastKnownLatitude;
        body['checkout_longitude'] = s.lastKnownLongitude;
      }

      final resp = await ApiClient.post(
        '/attendance_sessions/admin-force-close',
        body,
      );

      final Map<String, dynamic> json =
          jsonDecode(resp.body) as Map<String, dynamic>;

      if (json['success'] == true) {
        _showSnack('Session closed for ${s.empName}', success: true);

        await _load();
      } else {
        _showSnack(
          json['message']?.toString() ?? 'Failed to close session',
          success: false,
        );
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _closingIds.remove(s.employeeId));
    }
  }

  Future<void> _forceCloseAll(
    DateTime closeDate,
    TimeOfDay closeTime,
    String reason,
  ) async {
    setState(() => _closingAll = true);

    try {
      final body = {
        'work_date': _fmtApi(_selectedDate),
        'close_time': _isoWithOffset(closeDate, closeTime),
        'reason': reason,
        'closed_by_login_id': widget.loginId,
      };

      final resp = await ApiClient.post(
        '/attendance_sessions/admin-force-close-all',
        body,
      );

      final Map<String, dynamic> json =
          jsonDecode(resp.body) as Map<String, dynamic>;

      if (json['success'] == true) {
        final n = json['sessions_closed'] ?? 0;

        _showSnack('$n session(s) closed successfully', success: true);

        await _load();
      } else {
        _showSnack(
          json['message']?.toString() ?? 'Failed to close all',
          success: false,
        );
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      if (mounted) {
        setState(() => _closingAll = false);
      }
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: success ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<void> _showForceCloseDialog(_OpenSession s) async {
    DateTime closeDate = _selectedDate;
    TimeOfDay closeTime = TimeOfDay.now();
    String reason = '';
    String? reasonError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: _red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Force Close Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.empName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Warning ────────────────────────────────────────
                    _WarningBox(
                      message:
                          'This will mark the session as completed and cannot be undone.',
                    ),
                    const SizedBox(height: 12),

                    // ── GPS location info ──────────────────────────────
                    if (_isLocationMode(s.mode)) ...[
                      _LocationInfoBox(session: s),
                      const SizedBox(height: 12),
                    ],

                    // ── Date picker ────────────────────────────────────
                    const _FieldLabel('Close Date'),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      date: closeDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: closeDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDlg(() => closeDate = picked);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Time picker ────────────────────────────────────
                    const _FieldLabel('Close Time'),
                    const SizedBox(height: 6),
                    _TimePickerField(
                      time: closeTime,
                      context: ctx,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: closeTime,
                        );
                        if (picked != null) setDlg(() => closeTime = picked);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Reason ─────────────────────────────────────────
                    const _FieldLabel('Reason'),
                    const SizedBox(height: 6),
                    _ReasonField(
                      hint: 'Enter reason for force close…',
                      errorText: reasonError,
                      onChanged: (v) => setDlg(() {
                        reason = v;
                        if (v.trim().isNotEmpty) reasonError = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── Buttons ────────────────────────────────────────
                    _DialogButtons(
                      onCancel: () => Navigator.pop(ctx),
                      onConfirm: () {
                        if (reason.trim().isEmpty) {
                          setDlg(() => reasonError = 'Reason is required');
                          return;
                        }
                        Navigator.pop(ctx);
                        _forceClose(s, closeDate, closeTime, reason.trim());
                      },
                      confirmLabel: 'Force Close',
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

  Future<void> _showCloseAllDialog() async {
    DateTime closeDate = _selectedDate;
    TimeOfDay closeTime = TimeOfDay.now();
    String reason = '';
    String? reasonError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient header ────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C3AED), _red],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Close All Sessions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_openSessions.length} sessions will be closed',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WarningBox(
                          message:
                              'All open sessions will be force-closed. GPS checkout location will be set from last known position. This cannot be undone.',
                        ),
                        const SizedBox(height: 14),

                        // ── Affected employees ──────────────────────────
                        const _FieldLabel('Affected Employees'),
                        const SizedBox(height: 8),
                        ..._openSessions.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                _AvatarCircle(
                                  name: s.empName,
                                  size: 28,
                                  fontSize: 11,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.empName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _textDark,
                                    ),
                                  ),
                                ),
                                // Mode chip
                                _ModeChip(mode: s.mode, compact: true),
                                const SizedBox(width: 6),
                                // Duration chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _urgencyColor(
                                      s.openMinutes,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _fmtMinutes(s.openMinutes),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _urgencyColor(s.openMinutes),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Date picker ─────────────────────────────────
                        const _FieldLabel('Close Date'),
                        const SizedBox(height: 6),
                        _DatePickerField(
                          date: closeDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: closeDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setDlg(() => closeDate = picked);
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Time picker ─────────────────────────────────
                        const _FieldLabel('Close Time'),
                        const SizedBox(height: 6),
                        _TimePickerField(
                          time: closeTime,
                          context: ctx,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: closeTime,
                            );
                            if (picked != null)
                              setDlg(() => closeTime = picked);
                          },
                        ),
                        const SizedBox(height: 12),

                        // ── Reason ──────────────────────────────────────
                        const _FieldLabel('Reason'),
                        const SizedBox(height: 6),
                        _ReasonField(
                          hint: 'Enter reason…',
                          errorText: reasonError,
                          onChanged: (v) => setDlg(() {
                            reason = v;
                            if (v.trim().isNotEmpty) reasonError = null;
                          }),
                        ),
                        const SizedBox(height: 20),

                        // ── Buttons ─────────────────────────────────────
                        _DialogButtons(
                          onCancel: () => Navigator.pop(ctx),
                          onConfirm: () {
                            if (reason.trim().isEmpty) {
                              setDlg(() => reasonError = 'Reason is required');
                              return;
                            }
                            Navigator.pop(ctx);
                            _forceCloseAll(closeDate, closeTime, reason.trim());
                          },
                          confirmLabel: 'Close All',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: _primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open Sessions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Force-close unclosed attendance',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _load,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.refresh, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date selector pill
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _load(); // reload on date change
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmtDisplay(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      if (_isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_openSessions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_openSessions.length} open',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shimmer ──────────────────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (_shimmerAnim.value - 0.3).clamp(0.0, 1.0),
                  _shimmerAnim.value.clamp(0.0, 1.0),
                  (_shimmerAnim.value + 0.3).clamp(0.0, 1.0),
                ],
                colors: const [
                  Color(0xFFE2E8F0),
                  Color(0xFFF0F4FF),
                  Color(0xFFE2E8F0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 60, color: _textLight),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty ────────────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 68,
            color: _accent,
          ),
          const SizedBox(height: 14),
          const Text(
            'All Sessions Closed!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No open attendance sessions for this date.',
            style: TextStyle(fontSize: 13, color: _textMid),
          ),
        ],
      ),
    );
  }

  // ── Close All banner ─────────────────────────────────────────────────────────
  Widget _buildCloseAllBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: _red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_openSessions.length} sessions still open',
              style: const TextStyle(
                color: _red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _closingAll
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _red,
                  ),
                )
              : ElevatedButton(
                  onPressed: _showCloseAllDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Close All',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: switch (_loadState) {
              _LoadState.loading => _buildShimmer(),
              _LoadState.error => _buildError(),
              _LoadState.empty => _buildEmpty(),
              _LoadState.data => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_openSessions.length >= 2) _buildCloseAllBanner(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _openSessions.length,
                      itemBuilder: (_, i) {
                        final s = _openSessions[i];
                        return _OpenSessionCard(
                          session: s,
                          isClosing: _closingIds.contains(s.employeeId),
                          onForceClose: () => _showForceCloseDialog(s),
                        );
                      },
                    ),
                  ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OpenSessionCard
// ─────────────────────────────────────────────────────────────────────────────
class _OpenSessionCard extends StatefulWidget {
  const _OpenSessionCard({
    required this.session,
    required this.isClosing,
    required this.onForceClose,
  });

  final _OpenSession session;
  final bool isClosing;
  final VoidCallback onForceClose;

  @override
  State<_OpenSessionCard> createState() => _OpenSessionCardState();
}

class _OpenSessionCardState extends State<_OpenSessionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final urgency = _urgencyColor(s.openMinutes);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colored accent bar (urgency)
          Container(height: 4, color: urgency),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Employee info row ────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AvatarCircle(name: s.empName, size: 44, fontSize: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.empName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${s.employeeId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMid,
                            ),
                          ),
                          if (s.departmentName.isNotEmpty)
                            Text(
                              s.departmentName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Duration badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: urgency.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _fmtMinutes(s.openMinutes),
                        style: TextStyle(
                          color: urgency,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Mode + session strip ─────────────────────────────────
                Row(
                  children: [
                    _ModeChip(mode: s.mode),
                    if (s.sessionNumber != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          'Session #${s.sessionNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textMid,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Pulsing "Open" indicator
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accent.withOpacity(
                            0.5 + 0.5 * _pulseCtrl.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 11,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 8),

                // ── Check-in time row ────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 14, color: _textMid),
                    const SizedBox(width: 4),
                    Text(
                      'In: ${_fmtTimestamp(s.startedAt)}',
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                    if (s.isLate) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.schedule, size: 13, color: _orange),
                      const SizedBox(width: 3),
                      Text(
                        'Late ${_fmtMinutes(s.lateMinutes)}',
                        style: const TextStyle(fontSize: 11, color: _orange),
                      ),
                    ],
                  ],
                ),

                // ── GPS location row (only for gps / gps_face) ───────────
                if (_isLocationMode(s.mode)) ...[
                  const SizedBox(height: 6),
                  _LocationRow(session: s),
                ],

                const SizedBox(height: 12),

                // ── Force Close button ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.isClosing ? null : widget.onForceClose,
                    icon: widget.isClosing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_outline, size: 16),
                    label: Text(
                      widget.isClosing ? 'Closing…' : 'Force Close Session',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      disabledBackgroundColor: _red.withOpacity(0.6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Mode badge chip shown on the card and in the close-all list.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, this.compact = false});
  final AttendanceMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _modeColor(mode);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_modeIcon(mode), size: compact ? 10 : 12, color: color),
          const SizedBox(width: 4),
          Text(
            _modeLabel(mode),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows last known GPS location on the card.
class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.session});
  final _OpenSession session;

  @override
  Widget build(BuildContext context) {
    final hasLoc = session.hasLastLocation;
    return Row(
      children: [
        Icon(
          hasLoc ? Icons.my_location : Icons.location_off_outlined,
          size: 13,
          color: hasLoc ? _teal : _textLight,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            hasLoc
                ? _fmtCoord(
                    session.lastKnownLatitude,
                    session.lastKnownLongitude,
                  )
                : 'No location synced yet',
            style: TextStyle(fontSize: 11, color: hasLoc ? _teal : _textLight),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasLoc && session.lastLocationUpdatedAt != null) ...[
          const SizedBox(width: 6),
          Text(
            _fmtTimestamp(session.lastLocationUpdatedAt),
            style: const TextStyle(fontSize: 10, color: _textLight),
          ),
        ],
      ],
    );
  }
}

/// Info box shown inside the force-close dialog for GPS modes.
class _LocationInfoBox extends StatelessWidget {
  const _LocationInfoBox({required this.session});
  final _OpenSession session;

  @override
  Widget build(BuildContext context) {
    final hasLoc = session.hasLastLocation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _teal.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _teal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            hasLoc ? Icons.my_location : Icons.location_off_outlined,
            color: _teal,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checkout location (${_modeLabel(session.mode)})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLoc
                      ? _fmtCoord(
                          session.lastKnownLatitude,
                          session.lastKnownLongitude,
                        )
                      : 'No location synced — checkout coords will be null',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasLoc ? _teal : _orange,
                    fontWeight: FontWeight.w600,
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

/// Warning box used in both dialogs.
class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(10),
          color: _surface,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: _textMid,
            ),
            const SizedBox(width: 8),
            Text(
              _fmtDisplay(date),
              style: const TextStyle(fontSize: 14, color: _textDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.time,
    required this.context,
    required this.onTap,
  });
  final TimeOfDay time;
  final BuildContext context;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext ctx) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(10),
          color: _surface,
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_outlined, size: 16, color: _textMid),
            const SizedBox(width: 8),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 14, color: _textDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({
    required this.hint,
    required this.onChanged,
    this.errorText,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 13),
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
      ),
    );
  }
}

class _DialogButtons extends StatelessWidget {
  const _DialogButtons({
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
  });
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel', style: TextStyle(color: _textMid)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AvatarCircle
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.name,
    required this.size,
    required this.fontSize,
  });

  final String name;
  final double size;
  final double fontSize;

  static const _palette = [
    Color(0xFF1A56DB),
    Color(0xFF0E9F6E),
    Color(0xFFF97316),
    Color(0xFFEF4444),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
  ];

  Color _colorFor(String n) =>
      _palette[(n.isNotEmpty ? n.codeUnitAt(0) : 0) % _palette.length];

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _colorFor(name)),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
