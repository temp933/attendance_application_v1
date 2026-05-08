import 'package:flutter/material.dart';
import '../services/leave_service.dart';

const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

class RegularizationScreen extends StatefulWidget {
  final int empId;
  const RegularizationScreen({super.key, required this.empId});

  @override
  State<RegularizationScreen> createState() => _RegularizationScreenState();
}

class _RegularizationScreenState extends State<RegularizationScreen> {
  final _service = LeaveService();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _service.getMyRegularizations(widget.empId);
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    if (s.contains('Approved')) return _accent;
    if (s.contains('Rejected')) return _red;
    if (s.contains('Cancelled')) return _amber;
    return _primary;
  }

  String _statusLabel(String s) {
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
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Regularization',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        onPressed: _showSubmitSheet,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Apply',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: _primary,
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _buildCard(_items[i]),
                    ),
            ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history_toggle_off_rounded, size: 48, color: _textLight),
        const SizedBox(height: 12),
        const Text(
          'No regularization requests',
          style: TextStyle(color: _textDark, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap Apply to submit a missed attendance correction',
          style: TextStyle(color: _textMid, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildCard(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? '';
    final color = _statusColor(status);
    final canCancel = status == 'Pending_TL' || status == 'Pending_Manager';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  r['work_date'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (r['expected_in'] != null || r['expected_out'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (r['expected_in'] != null)
                    _chip(
                      Icons.login_rounded,
                      'In: ${r['expected_in']}',
                      _accent,
                    ),
                  if (r['expected_in'] != null && r['expected_out'] != null)
                    const SizedBox(width: 8),
                  if (r['expected_out'] != null)
                    _chip(
                      Icons.logout_rounded,
                      'Out: ${r['expected_out']}',
                      _primary,
                    ),
                ],
              ),
            ],
            if ((r['reason'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                r['reason'],
                style: const TextStyle(fontSize: 12, color: _textMid),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(color: _red.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await _service.cancelRegularization(
                      r['reg_id'] as int,
                      widget.empId,
                    );
                    if (ok && mounted) _load();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  void _showSubmitSheet() {
    final reasonCtrl = TextEditingController();
    final inCtrl = TextEditingController();
    final outCtrl = TextEditingController();
    DateTime? workDate;

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
                'Regularization request',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Correct a missed or wrong attendance entry',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 16),
              // Date picker
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 1),
                    ),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 90),
                    ),
                    lastDate: DateTime.now(),
                  );
                  if (p != null) setLocal(() => workDate = p);
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
                      color: workDate != null
                          ? _primary.withOpacity(0.4)
                          : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: workDate != null ? _primary : _textLight,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        workDate != null
                            ? '${workDate!.day}/${workDate!.month}/${workDate!.year}'
                            : 'Work date *',
                        style: TextStyle(
                          fontSize: 13,
                          color: workDate != null ? _textDark : _textLight,
                          fontWeight: workDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeField(inCtrl, 'Expected IN  (HH:mm)')),
                  const SizedBox(width: 10),
                  Expanded(child: _timeField(outCtrl, 'Expected OUT (HH:mm)')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
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
                    if (workDate == null) return;
                    if (reasonCtrl.text.trim().isEmpty) return;
                    if (inCtrl.text.trim().isEmpty &&
                        outCtrl.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(context);
                    final ok = await _service.submitRegularization(
                      empId: widget.empId,
                      workDate:
                          '${workDate!.year}-${workDate!.month.toString().padLeft(2, '0')}-${workDate!.day.toString().padLeft(2, '0')}',
                      expectedIn: inCtrl.text.trim().isNotEmpty
                          ? inCtrl.text.trim()
                          : null,
                      expectedOut: outCtrl.text.trim().isNotEmpty
                          ? outCtrl.text.trim()
                          : null,
                      reason: reasonCtrl.text.trim(),
                    );
                    if (ok && mounted) _load();
                  },
                  child: const Text(
                    'SUBMIT',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

  Widget _timeField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textLight, fontSize: 12),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border),
      ),
    ),
  );
}
