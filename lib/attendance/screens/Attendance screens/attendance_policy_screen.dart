import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const Color _primary   = Color(0xFF1A56DB);
const Color _accent    = Color(0xFF0E9F6E);
const Color _purple    = Color(0xFF7C3AED);
const Color _amber     = Color(0xFFF59E0B);
const Color _red       = Color(0xFFEF4444);
const Color _surface   = Color(0xFFF0F4FF);
const Color _cardWhite = Colors.white;   // renamed from _card to avoid clash with _cardWidget method
const Color _textDark  = Color(0xFF0F172A);
const Color _textMid   = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border    = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class AttendancePolicy {
  String officeInTime;
  String officeOutTime;
  int    lateAfterMinutes;
  int    halfdayAfterMinutes;
  int    overtimeAfterMinutes;
  bool   multipleInOutAllowed;
  bool   autoCheckoutEnabled;

  AttendancePolicy({
    required this.officeInTime,
    required this.officeOutTime,
    this.lateAfterMinutes      = 0,
    this.halfdayAfterMinutes   = 0,
    this.overtimeAfterMinutes  = 0,
    this.multipleInOutAllowed  = true,
    this.autoCheckoutEnabled   = false,
  });

  factory AttendancePolicy.defaults() =>
      AttendancePolicy(officeInTime: '09:00', officeOutTime: '18:00');

  factory AttendancePolicy.fromJson(Map<String, dynamic> j) => AttendancePolicy(
    officeInTime         : _trimTime(j['office_in_time']  ?? '09:00'),
    officeOutTime        : _trimTime(j['office_out_time'] ?? '18:00'),
    lateAfterMinutes     : _parseInt(j['late_after_minutes']),
    halfdayAfterMinutes  : _parseInt(j['halfday_after_minutes']),
    overtimeAfterMinutes : _parseInt(j['overtime_after_minutes']),
    multipleInOutAllowed : _parseBool(j['multiple_in_out_allowed'], def: true),
    autoCheckoutEnabled  : _parseBool(j['auto_checkout_enabled'],   def: false),
  );

  Map<String, dynamic> toJson() => {
    'office_in_time'         : officeInTime,
    'office_out_time'        : officeOutTime,
    'late_after_minutes'     : lateAfterMinutes,
    'halfday_after_minutes'  : halfdayAfterMinutes,
    'overtime_after_minutes' : overtimeAfterMinutes,
    'multiple_in_out_allowed': multipleInOutAllowed ? 1 : 0,
    'auto_checkout_enabled'  : autoCheckoutEnabled  ? 1 : 0,
  };

  // MySQL TIME arrives as "09:00:00" — keep only "HH:MM"
  static String _trimTime(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return t;
  }

  static int  _parseInt (dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  static bool _parseBool(dynamic v, {required bool def}) {
    if (v == null) return def;
    if (v is bool) return v;
    return v == 1 || v == '1';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AttendancePolicyService {
  static const String _base = '${ApiConfig.baseUrl}/attendance';

  static Future<AttendancePolicy?> fetchPolicy({
    required String authToken,
    required String tenantId,
  }) async {
    final res = await http.get(
      Uri.parse('$_base/policy'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'x-tenant-id'  : tenantId,
      },
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final raw  = body['policy'];
      if (raw == null) return null;
      return AttendancePolicy.fromJson(raw as Map<String, dynamic>);
    }
    throw Exception('Failed to load policy (${res.statusCode})');
  }

  static Future<AttendancePolicy> savePolicy({
    required String           authToken,
    required String           tenantId,
    required AttendancePolicy policy,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/policy'),
      headers: {
        'Authorization': 'Bearer $authToken',
        'x-tenant-id'  : tenantId,
        'Content-Type' : 'application/json',
      },
      body: jsonEncode(policy.toJson()),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return AttendancePolicy.fromJson(body['policy'] as Map<String, dynamic>);
    }
    final msg =
        (jsonDecode(res.body) as Map<String, dynamic>)['message'] ??
        'Failed to save policy';
    throw Exception(msg);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AttendancePolicyScreen extends StatefulWidget {
  final String authToken;
  final String tenantId;

  const AttendancePolicyScreen({
    super.key,
    required this.authToken,
    required this.tenantId,
  });

  @override
  State<AttendancePolicyScreen> createState() => _AttendancePolicyScreenState();
}

class _AttendancePolicyScreenState extends State<AttendancePolicyScreen> {
  bool    _loading = true;
  bool    _saving  = false;
  String? _error;
  String? _successMsg;

  late AttendancePolicy _policy;

  final _lateCtrl     = TextEditingController();
  final _halfdayCtrl  = TextEditingController();
  final _overtimeCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  @override
  void dispose() {
    _lateCtrl.dispose();
    _halfdayCtrl.dispose();
    _overtimeCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadPolicy() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await AttendancePolicyService.fetchPolicy(
        authToken: widget.authToken,
        tenantId : widget.tenantId,
      );
      _policy = p ?? AttendancePolicy.defaults();
      _syncControllers();
    } catch (e) {
      _policy = AttendancePolicy.defaults();
      _syncControllers();
      _error  = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncControllers() {
    _lateCtrl    .text = _policy.lateAfterMinutes    .toString();
    _halfdayCtrl .text = _policy.halfdayAfterMinutes .toString();
    _overtimeCtrl.text = _policy.overtimeAfterMinutes.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _policy.lateAfterMinutes     = int.tryParse(_lateCtrl.text)     ?? 0;
    _policy.halfdayAfterMinutes  = int.tryParse(_halfdayCtrl.text)  ?? 0;
    _policy.overtimeAfterMinutes = int.tryParse(_overtimeCtrl.text) ?? 0;

    setState(() { _saving = true; _successMsg = null; _error = null; });
    try {
      final saved = await AttendancePolicyService.savePolicy(
        authToken: widget.authToken,
        tenantId : widget.tenantId,
        policy   : _policy,
      );
      setState(() { _policy = saved; _successMsg = 'Policy saved successfully!'; });
      _syncControllers();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Time picker ───────────────────────────────────────────────────────────

  Future<void> _pickTime({
    required String current,
    required void Function(String) onPicked,
  }) async {
    final parts = current.split(':');
    final init  = TimeOfDay(
      hour  : int.tryParse(parts[0])                           ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context    : context,
      initialTime: init,
      builder    : (ctx, child) => Theme(
        data : Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final h = picked.hour  .toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      onPicked('$h:$m');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar         : _buildAppBar(),
      body           : _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
            )
          : Form(
              key  : _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (_error      != null) _banner(_error!,      isError: true),
                        if (_successMsg != null) _banner(_successMsg!, isError: false),

                        const SizedBox(height: 16),

                        // ── Office Hours ──────────────────────────────────
                        _sectionHeader(
                          icon : Icons.access_time_filled_rounded,
                          color: _primary,
                          label: 'Office Hours',
                        ),
                        _cardWidget(
                          child: Row(
                            children: [
                              Expanded(
                                child: _timeTile(
                                  label : 'Office In Time',
                                  value : _policy.officeInTime,
                                  icon  : Icons.login_rounded,
                                  color : _accent,
                                  onTap : () => _pickTime(
                                    current : _policy.officeInTime,
                                    onPicked: (t) =>
                                        setState(() => _policy.officeInTime = t),
                                  ),
                                ),
                              ),
                              Container(
                                width : 1,
                                height: 60,
                                color : _border,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              Expanded(
                                child: _timeTile(
                                  label : 'Office Out Time',
                                  value : _policy.officeOutTime,
                                  icon  : Icons.logout_rounded,
                                  color : _red,
                                  onTap : () => _pickTime(
                                    current : _policy.officeOutTime,
                                    onPicked: (t) =>
                                        setState(() => _policy.officeOutTime = t),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Thresholds ────────────────────────────────────
                        _sectionHeader(
                          icon : Icons.timer_outlined,
                          color: _amber,
                          label: 'Thresholds (minutes after office-in)',
                        ),
                        _cardWidget(
                          child: Column(
                            children: [
                              _minuteField(
                                ctrl  : _lateCtrl,
                                label : 'Mark Late After',
                                hint  : 'e.g. 15',
                                icon  : Icons.watch_later_outlined,
                                color : _amber,
                                suffix: 'min',
                              ),
                              _divider(),
                              _minuteField(
                                ctrl  : _halfdayCtrl,
                                label : 'Mark Half-Day After',
                                hint  : 'e.g. 240',
                                icon  : Icons.wb_sunny_outlined,
                                color : _purple,
                                suffix: 'min',
                              ),
                              _divider(),
                              _minuteField(
                                ctrl  : _overtimeCtrl,
                                label : 'Overtime After (extra beyond out-time)',
                                hint  : 'e.g. 30',
                                icon  : Icons.bolt_outlined,
                                color : _accent,
                                suffix: 'min',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Rules ─────────────────────────────────────────
                        _sectionHeader(
                          icon : Icons.rule_rounded,
                          color: _purple,
                          label: 'Rules',
                        ),
                        _cardWidget(
                          child: Column(
                            children: [
                              _switchTile(
                                icon     : Icons.repeat_rounded,
                                color    : _primary,
                                label    : 'Multiple check-in / check-out',
                                sub      : 'Allow employees to check in more than once per day',
                                value    : _policy.multipleInOutAllowed,
                                onChanged: (v) =>
                                    setState(() => _policy.multipleInOutAllowed = v),
                              ),
                              _divider(),
                              _switchTile(
                                icon     : Icons.alarm_off_rounded,
                                color    : _red,
                                label    : 'Auto checkout at office out-time',
                                sub      : 'System will check out any active sessions at end of day',
                                value    : _policy.autoCheckoutEnabled,
                                onChanged: (v) =>
                                    setState(() => _policy.autoCheckoutEnabled = v),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed      : _saving ? null : _save,
              backgroundColor: _primary,
              shape          : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              label: _saving
                  ? const SizedBox(
                      width : 20,
                      height: 20,
                      child : CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Row(
                      children: [
                        Icon(Icons.save_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Save Policy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(60),
    child: Container(
      decoration: const BoxDecoration(
        color    : Colors.white,
        boxShadow: [
          BoxShadow(
            color     : Color(0x301A56DB),
            blurRadius: 14,
            offset    : Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child  : Row(
            children: [
              IconButton(
                icon     : const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _textDark,
                  size : 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 2),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment : MainAxisAlignment.center,
                children: [
                  Text(
                    'Attendance Policy',
                    style: TextStyle(
                      fontSize  : 15,
                      fontWeight: FontWeight.w700,
                      color     : _textDark,
                    ),
                  ),
                  Text(
                    'Configure office hours & rules',
                    style: TextStyle(fontSize: 11, color: _textMid),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip  : 'Reload',
                icon     : const Icon(Icons.refresh_rounded, color: _textMid),
                onPressed: _loadPolicy,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // ── Reusable widgets ───────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required Color    color,
    required String   label,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child  : Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize  : 13,
                fontWeight: FontWeight.w700,
                color     : color,
              ),
            ),
          ],
        ),
      );

  // Named _cardWidget (not _card) to avoid the top-level Color constant collision
  Widget _cardWidget({required Widget child}) => Container(
    margin    : const EdgeInsets.symmetric(horizontal: 16),
    padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color       : _cardWhite,
      borderRadius: BorderRadius.circular(14),
      border      : Border.all(color: _border),
      boxShadow   : const [
        BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
    child: child,
  );

  Widget _timeTile({
    required String       label,
    required String       value,
    required IconData     icon,
    required Color        color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap   : onTap,
        behavior: HitTestBehavior.opaque,
        child   : Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color   : color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding   : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color       : color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border      : Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize     : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _to12h(value),
                    style: TextStyle(
                      fontSize     : 22,
                      fontWeight   : FontWeight.w800,
                      color        : color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_rounded,
                    size : 13,
                    color: color.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _minuteField({
    required TextEditingController ctrl,
    required String                label,
    required String                hint,
    required IconData              icon,
    required Color                 color,
    required String                suffix,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child  : Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color       : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
                      color     : _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller     : ctrl,
                    keyboardType   : TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                      fontSize  : 14,
                      fontWeight: FontWeight.w700,
                      color     : _textDark,
                    ),
                    decoration: InputDecoration(
                      hintText      : hint,
                      hintStyle     : const TextStyle(color: _textLight, fontSize: 13),
                      suffixText    : suffix,
                      suffixStyle   : const TextStyle(color: _textMid, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      filled       : true,
                      fillColor    : _surface,
                      border       : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide  : const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide  : const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide  : BorderSide(color: color, width: 1.5),
                      ),
                      errorBorder  : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide  : const BorderSide(color: _red),
                      ),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Enter a valid number';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _switchTile({
    required IconData            icon,
    required Color               color,
    required String              label,
    required String              sub,
    required bool                value,
    required void Function(bool) onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child  : Row(
          children: [
            Container(
              padding   : const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color       : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize  : 13,
                      fontWeight: FontWeight.w600,
                      color     : _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(fontSize: 11, color: _textMid)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value           : value,
              onChanged       : onChanged,
              activeTrackColor: color,          // colors the track bar
              activeThumbColor: Colors.white,   // replaces deprecated activeColor
            ),
          ],
        ),
      );

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child  : Divider(height: 1, thickness: 1, color: _border),
  );

  Widget _banner(String msg, {required bool isError}) {
    final color = isError ? _red : _accent;
    final icon  = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;
    return Container(
      margin    : const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding   : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color       : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border      : Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize  : 13,
                color     : color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() { _error = null; _successMsg = null; }),
            child: Icon(Icons.close_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  // "09:00" → "9:00 AM"
  String _to12h(String hhmm) {
    try {
      final p  = hhmm.split(':');
      int   h  = int.parse(p[0]);
      final m  = p[1].padLeft(2, '0');
      final am = h < 12 ? 'AM' : 'PM';
      if (h == 0)  { h = 12; }
      if (h > 12)  { h -= 12; }
      return '$h:$m $am';
    } catch (_) {
      return hhmm;
    }
  }
}