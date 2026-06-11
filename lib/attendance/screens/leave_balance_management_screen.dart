import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/api_client.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

// ─── Colors (same palette) ────────────────────────────────────────────────────
const _primary = Color(0xFF1A56DB);
const _accent = Color(0xFF0E9F6E);
const _red = Color(0xFFEF4444);
const _amber = Color(0xFFF59E0B);
const _surface = Color(0xFFF0F4FF);
const _textDark = Color(0xFF0F172A);
const _textMid = Color(0xFF64748B);
const _textLight = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);

// ═══════════════════════════════════════════════════════════════════════════════
// LeaveBalanceManagementScreen
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveBalanceManagementScreen extends StatefulWidget {
  const LeaveBalanceManagementScreen({super.key});

  @override
  State<LeaveBalanceManagementScreen> createState() =>
      _LeaveBalanceManagementScreenState();
}

class _LeaveBalanceManagementScreenState
    extends State<LeaveBalanceManagementScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _leaveTypes = [];
  bool _loading = true;
  bool _uploading = false;
  String _search = '';
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _uploadResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _uploadResult = null;
    });
    try {
      final resp = await ApiClient.get(
        '/leave/balance/list?search=${Uri.encodeComponent(_search)}',
      );
      if (!mounted) return;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        setState(() {
          _leaveTypes = List<Map<String, dynamic>>.from(
            body['leave_types'] ?? [],
          );
          _employees = List<Map<String, dynamic>>.from(body['data'] ?? []);
        });
      } else {
        _snack(body['message'] ?? 'Failed to load');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadTemplate() async {
    _snack('Preparing template…', success: true);
    try {
      final resp = await ApiClient.get('/leave/balance/template');
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/leave_balance_template.xlsx');
        await file.writeAsBytes(bytes);

        final result = await OpenFilex.open(file.path);
        if (result.type != ResultType.done) {
          _snack('Saved to: ${file.path}');
        }
      } else {
        _snack('Download failed (${resp.statusCode})');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _showCsvDialog(String csv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Template CSV',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy this CSV content, paste into Excel or Google Sheets, '
                'fill the balance columns, then upload.',
                style: TextStyle(fontSize: 12, color: _textMid),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: SelectableText(
                  csv,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(ctx);
              _snack('Copied to clipboard', success: true);
            },
            child: const Text('Copy', style: TextStyle(color: _primary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Upload: admin pastes CSV text back
  void _openUploadDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Upload Balances',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the filled CSV content below:',
              style: TextStyle(fontSize: 12, color: _textMid),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 8,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText:
                    'emp_id,emp_name,Casual Leave,Earned Leave\n'
                    '1001,Ravi Kumar,7,3\n1002,Priya,5,2',
                hintStyle: const TextStyle(color: _textLight, fontSize: 10),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _textMid)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final csv = ctrl.text.trim();
              if (csv.isEmpty) return;
              Navigator.pop(ctx);
              await _processAndUploadCsv(csv);
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _processAndUploadCsv(String csv) async {
    setState(() => _uploading = true);
    try {
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length < 2) {
        _snack('CSV must have header + at least one data row');
        return;
      }

      // Parse header
      final headers = lines[0].split(',').map((h) => h.trim()).toList();
      final empIdIdx = headers.indexWhere((h) => h.toLowerCase() == 'emp_id');
      if (empIdIdx == -1) {
        _snack('CSV missing emp_id column');
        return;
      }

      // Leave type columns = everything after emp_name
      final leaveStartIdx = 2; // skip emp_id, emp_name

      // Parse rows
      final rows = <Map<String, dynamic>>[];
      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length <= empIdIdx) continue;
        final empId = cols[empIdIdx].trim().replaceAll('"', '');
        if (empId.isEmpty) continue;

        final balances = <String, dynamic>{};
        for (int j = leaveStartIdx; j < headers.length; j++) {
          if (j >= cols.length) continue;
          final val = cols[j].trim().replaceAll('"', '');
          if (val.isNotEmpty) {
            balances[headers[j]] = val;
          }
        }
        rows.add({'emp_id': empId, 'balances': balances});
      }

      if (rows.isEmpty) {
        _snack('No valid rows found in CSV');
        return;
      }

      final resp = await ApiClient.post('/leave/balance/bulk-upload', {
        'rows': rows,
      });
      if (!mounted) return;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        setState(() => _uploadResult = body);
        _snack('Upload complete', success: true);
        _load();
      } else {
        _snack(body['message'] ?? 'Upload failed');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openEditSheet(Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBalanceSheet(
        emp: emp,
        leaveTypes: _leaveTypes,
        onSaved: () {
          _snack('Balance updated', success: true);
          _load();
        },
        onError: (msg) => _snack(msg),
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
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
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          if (_uploadResult != null) _buildUploadResult(),
          _buildSearchBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : _employees.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: _primary,
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _employees.length,
                      itemBuilder: (ctx, i) => _EmployeeBalanceCard(
                        emp: _employees[i],
                        leaveTypes: _leaveTypes,
                        onEdit: () => _openEditSheet(_employees[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 8,
        8,
        16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Leave Balance Setup',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: _uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _uploading ? null : _load,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: _HeaderBtn(
                  icon: Icons.download_rounded,
                  label: 'Download Template',
                  onTap: _downloadTemplate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderBtn(
                  icon: Icons.upload_rounded,
                  label: 'Upload CSV',
                  onTap: _openUploadDialog,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadResult() {
    final r = _uploadResult!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Summary',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ResultChip('✅ ${r['updated']} updated', _accent),
              const SizedBox(width: 6),
              _ResultChip('⚠️ ${r['skipped_employees']} skipped emp', _amber),
              const SizedBox(width: 6),
              _ResultChip('❌ ${r['errors']} errors', _red),
            ],
          ),
          if ((r['error_details'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            ...((r['error_details'] as List)
                .take(3)
                .map(
                  (e) => Text(
                    '• $e',
                    style: const TextStyle(fontSize: 11, color: _red),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) {
          _search = v;
          if (v.isEmpty) _load();
        },
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: 'Search employee…',
          hintStyle: const TextStyle(color: _textLight, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _textMid,
            size: 18,
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 16,
                    color: _textMid,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    _search = '';
                    _load();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
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
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            size: 44,
            color: _textLight,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No employees found',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Try a different search',
          style: TextStyle(color: _textMid, fontSize: 13),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// Employee Balance Card
// ═══════════════════════════════════════════════════════════════════════════════

class _EmployeeBalanceCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final List<Map<String, dynamic>> leaveTypes;
  final VoidCallback onEdit;

  const _EmployeeBalanceCard({
    required this.emp,
    required this.leaveTypes,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final balances = List<Map<String, dynamic>>.from(emp['balances'] ?? []);
    final hasAnyBalance = balances.any((b) => b['allocated_days'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      (emp['emp_name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp['emp_name'] ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        emp['employee_code'] ?? '',
                        style: const TextStyle(fontSize: 11, color: _textMid),
                      ),
                    ],
                  ),
                ),
                // Not set badge
                if (!hasAnyBalance)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Not set',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _amber,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 13, color: _primary),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Balance chips row
          if (hasAnyBalance) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: balances
                    .where((b) => b['allocated_days'] != null)
                    .map((b) {
                      final alloc =
                          double.tryParse(b['allocated_days'].toString()) ?? 0;
                      final used =
                          double.tryParse(b['used_days'].toString()) ?? 0;
                      final remaining = alloc - used;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['leave_type'] ?? '',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _textMid,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: remaining.toStringAsFixed(
                                      remaining % 1 == 0 ? 0 : 1,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _primary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/$alloc',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Edit Balance Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _EditBalanceSheet extends StatefulWidget {
  final Map<String, dynamic> emp;
  final List<Map<String, dynamic>> leaveTypes;
  final VoidCallback onSaved;
  final void Function(String) onError;

  const _EditBalanceSheet({
    required this.emp,
    required this.leaveTypes,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_EditBalanceSheet> createState() => _EditBalanceSheetState();
}

class _EditBalanceSheetState extends State<_EditBalanceSheet> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final balances = List<Map<String, dynamic>>.from(
      widget.emp['balances'] ?? [],
    );
    for (final lt in widget.leaveTypes) {
      final name = lt['leave_name'] as String;
      final existing = balances.firstWhere(
        (b) => b['leave_type'] == name,
        orElse: () => {},
      );
      final val = existing['allocated_days'];
      _ctrls[name] = TextEditingController(
        text: val != null ? val.toString() : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final balances = _ctrls.entries
          .map(
            (e) => {
              'leave_type': e.key,
              'allocated_days': double.tryParse(e.value.text.trim()) ?? 0,
            },
          )
          .toList();

      final resp = await ApiClient.post('/leave/balance/set', {
        'emp_id': widget.emp['emp_id'],
        'balances': balances,
      });
      if (!mounted) return;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        widget.onError(body['message'] ?? 'Save failed');
      }
    } catch (e) {
      widget.onError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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

            // Employee info
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (widget.emp['emp_name'] as String? ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.emp['emp_name'] ?? '-',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    Text(
                      widget.emp['employee_code'] ?? '',
                      style: const TextStyle(fontSize: 12, color: _textMid),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Set opening balance for each leave type',
              style: TextStyle(fontSize: 12, color: _textMid),
            ),
            const SizedBox(height: 20),

            // Leave type fields
            ...widget.leaveTypes.map((lt) {
              final name = lt['leave_name'] as String;
              final ctrl = _ctrls[name]!;
              // Find used days for reference
              final balances = List<Map<String, dynamic>>.from(
                widget.emp['balances'] ?? [],
              );
              final existing = balances.firstWhere(
                (b) => b['leave_type'] == name,
                orElse: () => {},
              );
              final used = existing['used_days'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMid,
                          ),
                        ),
                        if (used != null) ...[
                          const Spacer(),
                          Text(
                            'Used: $used days',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(fontSize: 14, color: _textDark),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: const TextStyle(
                          color: _textLight,
                          fontSize: 13,
                        ),
                        suffixText: 'days',
                        suffixStyle: const TextStyle(
                          color: _textMid,
                          fontSize: 12,
                        ),
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
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _primary,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Save button
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SAVE BALANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Micro widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _HeaderBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: filled ? Colors.white : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: filled ? _primary : Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: filled ? _primary : Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ResultChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ResultChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
