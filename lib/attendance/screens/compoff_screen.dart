import 'package:flutter/material.dart';
import '../services/leave_service.dart';

class CompoffScreen extends StatefulWidget {
  final int empId;
  const CompoffScreen({super.key, required this.empId});

  @override
  State<CompoffScreen> createState() => _CompoffScreenState();
}

class _CompoffScreenState extends State<CompoffScreen>
    with SingleTickerProviderStateMixin {
  final _service = LeaveService();
  late TabController _tabCtrl;

  List<dynamic> _earned = [];
  List<dynamic> _availed = [];
  Map<String, dynamic>? _balance;
  bool _loading = true;

  // Same design tokens
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _card = Colors.white;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getMyCompoffEarned(widget.empId),
      _service.getMyCompoffAvailed(widget.empId),
      _service.getCompoffBalance(widget.empId),
    ]);
    if (mounted) {
      setState(() {
        _earned = results[0] as List;
        _availed = results[1] as List;
        _balance = results[2] as Map<String, dynamic>?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Comp-off',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Earned'),
            Tab(text: 'Availed'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          if (_balance != null) _buildBalanceBar(),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildEarnedTab(), _buildAvailedTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: _tabCtrl.index == 0 ? _showEarnSheet : _showAvailSheet,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabCtrl.index == 0 ? 'Log worked day' : 'Request day off',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceBar() {
    final bal = _balance!['balance'] as Map<String, dynamic>? ?? {};
    final avail = (bal['available'] as num?)?.toDouble() ?? 0;
    final earned = (bal['totalEarned'] as num?)?.toDouble() ?? 0;
    final used = (bal['totalUsed'] as num?)?.toDouble() ?? 0;

    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            _statItem(avail.toStringAsFixed(1), 'Available', Colors.white),
            _divider(),
            _statItem(
              earned.toStringAsFixed(1),
              'Earned',
              const Color(0xFF6EE7B7),
            ),
            _divider(),
            _statItem(
              used.toStringAsFixed(1),
              'Used',
              const Color(0xFFFDE68A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) {
    return Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l,
            style: TextStyle(
              fontSize: 10,
              color: c.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildEarnedTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_earned.isEmpty) {
      return _empty(
        'No comp-off earned yet',
        'Log days you worked on weekends or holidays',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _earned.length,
        itemBuilder: (_, i) {
          final r = _earned[i] as Map<String, dynamic>;
          final status = r['status'] as String? ?? '';
          final color = _compoffStatusColor(status);
          final canCancel =
              status == 'Pending_TL' || status == 'Pending_Manager';

          return _buildCard(
            leading: Icon(Icons.work_history_rounded, color: color),
            title: r['worked_date'] ?? '',
            subtitle:
                '${r['day_type'] ?? ''} · ${r['days_earned'] ?? 1} day(s) · ${r['reason'] ?? ''}',
            status: status,
            color: color,
            trailing: canCancel
                ? _cancelBtn(() async {
                    await _service.cancelCompoffEarn(
                      r['compoff_id'] as int,
                      widget.empId,
                    );
                    _load();
                  })
                : null,
          );
        },
      ),
    );
  }

  Widget _buildAvailedTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_availed.isEmpty) {
      return _empty(
        'No comp-off availed yet',
        'Request a day off using your earned comp-off',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _availed.length,
        itemBuilder: (_, i) {
          final r = _availed[i] as Map<String, dynamic>;
          final status = r['status'] as String? ?? '';
          final color = _compoffStatusColor(status);
          final canCancel =
              status == 'Pending_TL' || status == 'Pending_Manager';

          return _buildCard(
            leading: Icon(Icons.beach_access_rounded, color: color),
            title: r['avail_date'] ?? '',
            subtitle:
                'Worked on ${r['worked_date'] ?? ''} · ${r['day_type'] ?? ''} · ${r['days_used'] ?? 1} day(s)',
            status: status,
            color: color,
            trailing: canCancel
                ? _cancelBtn(() async {
                    await _service.cancelCompoffAvail(
                      r['avail_id'] as int,
                      widget.empId,
                    );
                    _load();
                  })
                : null,
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required Widget leading,
    required String title,
    required String subtitle,
    required String status,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              _statusBadge(status, color),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: _textMid)),
          if (trailing != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String s, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        _compoffStatusLabel(s),
        style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _cancelBtn(VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: _red,
        side: BorderSide(color: _red.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.close_rounded, size: 14),
      label: const Text('Cancel', style: TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }

  Widget _empty(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.free_cancellation_rounded,
            size: 48,
            color: _textLight,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 13, color: _textMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Sheets ──

  void _showEarnSheet() {
    final reasonCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    DateTime? date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log worked holiday/weekend',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 1),
                    ),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setLocal(() => date = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: date != null
                          ? _primary.withValues(alpha: 0.4)
                          : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: date != null ? _primary : _textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date != null
                            ? '${date!.day}/${date!.month}/${date!.year}'
                            : 'Date worked *',
                        style: TextStyle(
                          fontSize: 13,
                          color: date != null ? _textDark : _textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Hours worked (optional)',
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for working *',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    if (date == null || reasonCtrl.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    final h = double.tryParse(hoursCtrl.text.trim());
                    await _service.submitCompoffEarn(
                      empId: widget.empId,
                      workedDate:
                          '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                      workedHours: h,
                      reason: reasonCtrl.text.trim(),
                    );
                    _load();
                  },
                  child: const Text(
                    'SUBMIT',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvailSheet() {
    final reasonCtrl = TextEditingController();
    DateTime? date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Request comp-off day',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Balance: ${((_balance?['balance'] as Map?)?['available'] ?? 0).toStringAsFixed(1)} day(s)',
                style: const TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime(DateTime.now().year + 1),
                  );
                  if (p != null) setLocal(() => date = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: date != null
                          ? _primary.withValues(alpha: 0.4)
                          : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 15,
                        color: date != null ? _primary : _textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        date != null
                            ? '${date!.day}/${date!.month}/${date!.year}'
                            : 'Day off date *',
                        style: TextStyle(
                          fontSize: 13,
                          color: date != null ? _textDark : _textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason (optional)',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    if (date == null) return;
                    Navigator.pop(context);
                    await _service.submitCompoffAvail(
                      empId: widget.empId,
                      availDate:
                          '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
                      reason: reasonCtrl.text.trim().isNotEmpty
                          ? reasonCtrl.text.trim()
                          : null,
                    );
                    _load();
                  },
                  child: const Text(
                    'REQUEST',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _compoffStatusColor(String s) {
    if (s == 'Approved') return _accent;
    if (s.contains('Rejected') || s == 'Expired') return _red;
    if (s == 'Cancelled') return _amber;
    return _primary;
  }

  String _compoffStatusLabel(String s) {
    switch (s) {
      case 'Pending_TL':
        return 'Awaiting TL';
      case 'Pending_Manager':
        return 'Awaiting Manager';
      case 'Approved':
        return 'Approved';
      case 'Rejected_By_TL':
        return 'Rejected by TL';
      case 'Rejected_By_Manager':
        return 'Rejected';
      case 'Cancelled':
        return 'Cancelled';
      case 'Expired':
        return 'Expired';
      default:
        return s;
    }
  }
}
