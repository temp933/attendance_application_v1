import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens — identical to EmployeeProfileScreen & LeaveApprovalScreen
// ─────────────────────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

//  LIST PAGE
class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  List _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/admin/pending-requests');
      if (res.statusCode == 200) {
        
        setState(() => _requests = jsonDecode(res.body));
      } else {
        setState(() => _error = 'Server error (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
          ? _buildError()
          : _requests.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              color: _primary,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    itemCount: _requests.length,
                    itemBuilder: (_, i) => _RequestCard(
                      request: _requests[i],
                      onRefresh: _fetchRequests,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 253, 253, 253),
              Color.fromARGB(255, 255, 255, 255),
              Color.fromARGB(255, 255, 255, 255),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x401A56DB),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pending Requests',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 0, 0, 0),
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Review & approve employee requests',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color.fromARGB(131, 5, 5, 5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => RefreshIndicator(
    onRefresh: _fetchRequests,
    color: _primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: _red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 15,
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
                onPressed: _fetchRequests,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => RefreshIndicator(
    onRefresh: _fetchRequests,
    color: _primary,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'All clear!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No pending requests right now.',
                style: TextStyle(fontSize: 13, color: _textMid),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _fetchRequests,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Card (list item) - NOW WITH PHOTO
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final Map request;
  final VoidCallback onRefresh;
  const _RequestCard({required this.request, required this.onRefresh});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late final Future<http.Response> _photoFuture;

  @override
  void initState() {
    super.initState();
    final requestId = widget.request['request_id'];
    final empId = widget.request['emp_id'];
    final isUpdate = widget.request['request_type'] == 'UPDATE';

    _photoFuture = _resolvePhoto(requestId, empId, isUpdate);
  }

  Future<http.Response> _resolvePhoto(
    dynamic requestId,
    dynamic empId,
    bool isUpdate,
  ) async {
    if (requestId != null) {
      final res = await ApiClient.get('/pending-request/$requestId/photo');
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res;
    }
    // Fallback to master table for UPDATE requests
    if (isUpdate && empId != null) {
      return ApiClient.get('/employees/$empId/photo');
    }
    return http.Response('', 404);
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.request['first_name'] ?? ''} ${widget.request['last_name'] ?? ''}'
            .trim();
    final isNew = widget.request['request_type'] == 'NEW';
    final typeColor = isNew ? _accent : _primary;
    final typeBg = isNew ? const Color(0xFFECFDF5) : const Color(0xFFEEF2FF);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalDetailPage(request: widget.request),
            ),
          );
          if (result == true) widget.onRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with photo support
              FutureBuilder<http.Response>(
                future: _photoFuture,
                builder: (context, snap) {
                  final hasPhoto =
                      snap.hasData &&
                      snap.data!.statusCode == 200 &&
                      snap.data!.bodyBytes.isNotEmpty;

                  return Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: hasPhoto
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: hasPhoto
                          ? Image.memory(
                              snap.data!.bodyBytes,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unknown' : name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                            widget.request['department_name'],
                            widget.request['role_name'],
                          ]
                          .where((e) => e != null && e.toString().isNotEmpty)
                          .join('  ·  '),
                      style: const TextStyle(fontSize: 12, color: _textMid),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.request['email_id'] ?? '',
                      style: const TextStyle(fontSize: 12, color: _textLight),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Type badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: typeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: typeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.request['request_type']?.toString() ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _textLight,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAIL / APPROVAL PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ApprovalDetailPage extends StatefulWidget {
  final Map request;
  const ApprovalDetailPage({super.key, required this.request});
  @override
  State<ApprovalDetailPage> createState() => _ApprovalDetailPageState();
}

class _ApprovalDetailPageState extends State<ApprovalDetailPage> {
  late final Future<http.Response> _photoFuture;

  @override
  void initState() {
    super.initState();
    final requestId = widget.request['request_id'];
    final empId = widget.request['emp_id'];
    final isUpdate = widget.request['request_type'] == 'UPDATE';

    _photoFuture = _resolvePhoto(requestId, empId, isUpdate);
  }

  Future<http.Response> _resolvePhoto(
    dynamic requestId,
    dynamic empId,
    bool isUpdate,
  ) async {
    if (requestId != null) {
      final res = await ApiClient.get('/pending-request/$requestId/photo');
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res;
    }
    if (isUpdate && empId != null) {
      return ApiClient.get('/employees/$empId/photo');
    }
    return http.Response('', 404);
  }

  // ... all existing methods moved here, replacing `request` with `widget.request`
  // ── Helpers ──────────────────────────────────────────────────────────────
  String _fmt(dynamic date) {
    if (date == null || date.toString().isEmpty) return '-';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day.toString().padLeft(2, '0')} '
          '${_mon(d.month)} ${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  String _mon(int m) => const [
    '',
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
  ][m];

  // ── Section card (same style as EmployeeProfile) ──────────────────────────
  Widget _sectionCard({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(
    IconData icon,
    String title,
    Color color,
    Color bgColor,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: _border),
      ],
    );
  }

  // ── Info row — label + value tiles matching EmployeeProfile style ──────────
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 4,
    Color? valueColor,
  }) {
    final isEmpty = value.isEmpty || value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Icon(icon, size: 14, color: _textMid),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textMid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? '-' : value,
              maxLines: maxLines,
              overflow: TextOverflow.visible,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: isEmpty ? _textLight : (valueColor ?? _textDark),
                fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerRow() =>
      const Divider(height: 1, thickness: 1, color: _border);

  // ── Hero card ─────────────────────────────────────────────────────────────
  Widget _profileHero() {
    final name = [
      widget.request['first_name'],
      widget.request['mid_name'],
      widget.request['last_name'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    final isNew = widget.request['request_type'] == 'NEW';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Photo-aware avatar ──────────────────────────────
                    FutureBuilder<http.Response>(
                      future: _photoFuture,
                      builder: (context, snap) {
                        final hasPhoto =
                            snap.hasData &&
                            snap.data!.statusCode == 200 &&
                            snap.data!.bodyBytes.isNotEmpty;
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: hasPhoto
                                ? Image.memory(
                                    snap.data!.bodyBytes,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Unknown' : name,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.request['role_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            widget.request['department_name'] ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isNew
                                      ? Icons.person_add_rounded
                                      : Icons.edit_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isNew
                                      ? 'New Employee Request'
                                      : 'Update Request',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.12)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _heroStat(
                      widget.request['request_type'] == 'NEW'
                          ? 'NEW'
                          : (widget.request['emp_id']?.toString() ?? '-'),
                      widget.request['request_type'] == 'NEW'
                          ? 'REQUEST'
                          : 'EMP ID',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      _shorten(widget.request['employment_type']?.toString()),
                      'TYPE',
                    ),
                    _heroVDiv(),
                    _heroStat(
                      _shorten(widget.request['work_type']?.toString()),
                      'WORK',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shorten(String? v) {
    if (v == null || v.isEmpty) return '-';
    // "Full Time" → "Full Time", "Permanent" → "Perm", "Contract" → "Contract"
    const map = {
      'Full Time': 'Full Time',
      'Part Time': 'Part Time',
      'Permanent': 'Permanent',
      'Contract': 'Contract',
      'Intern': 'Intern',
    };
    return map[v] ?? v;
  }

  Widget _heroStat(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis, // ← ADD THIS
          style: const TextStyle(
            fontSize: 13, // ← reduce from 14 to 13
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
  Widget _heroVDiv() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.12));

  // ── Education ─────────────────────────────────────────────────────────────
  Widget _educationSection(List educations) {
    const levelColors = {
      '10': Color(0xFF6366F1),
      '12': Color(0xFF8B5CF6),
      'Diploma': Color(0xFFF59E0B),
      'UG': Color(0xFF0E9F6E),
      'PG': Color(0xFF1A56DB),
      'PhD': Color(0xFFEF4444),
    };
    const levelLabels = {
      '10': 'Class 10 (SSLC)',
      '12': 'Class 12 (HSC)',
      'Diploma': 'Diploma',
      'UG': 'Under Graduate',
      'PG': 'Post Graduate',
      'PhD': 'Doctorate (PhD)',
    };

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.school_rounded,
            'Education Details',
            _accent,
            const Color(0xFFECFDF5),
          ),
          if (educations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No education records',
                style: TextStyle(color: _textMid, fontSize: 13),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: educations.map<Widget>((e) {
                  final level = e['education_level']?.toString() ?? '';
                  final color = levelColors[level] ?? _textMid;
                  final label = levelLabels[level] ?? level;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                level,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e['stream']?.toString().trim().isNotEmpty ==
                                        true
                                    ? e['stream'].toString()
                                    : label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (e['score'] != null)
                              _eduChip(
                                Icons.percent_rounded,
                                '${e['score']}%',
                                color,
                              ),
                            if (e['year_of_passout'] != null)
                              _eduChip(
                                Icons.calendar_today_rounded,
                                e['year_of_passout'].toString(),
                                _purple,
                              ),
                            if (e['college_name']
                                    ?.toString()
                                    .trim()
                                    .isNotEmpty ==
                                true)
                              _eduChip(
                                Icons.account_balance_rounded,
                                e['college_name'].toString(),
                                _primary,
                              ),
                            if (e['university']?.toString().trim().isNotEmpty ==
                                true)
                              _eduChip(
                                Icons.school_outlined,
                                e['university'].toString(),
                                _amber,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eduChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
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

  // ── Auto-reject dialog ────────────────────────────────────────────────────
  Future<void> _showAutoRejectedDialog(BuildContext context, String reason) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.block_rounded,
                color: Colors.orange[800],
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Auto-Rejected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEA580C),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This request was automatically rejected due to duplicate data:',
              style: TextStyle(fontSize: 13, color: _textMid),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A3412),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The requester must fix the duplicate data and resubmit.',
              style: TextStyle(fontSize: 12, color: _textLight),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text(
              'OK, Go Back',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Approve ───────────────────────────────────────────────────────────────
  Future<void> _approve(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
      ),
    );
    final res = await ApiClient.post('/admin/approve-request', {
      'request_id': widget.request['request_id'],
    });
    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;

    final data = jsonDecode(res.body);

    if (res.statusCode == 409) {
      await _showAutoRejectedDialog(
        context,
        data['error'] ?? 'Duplicate data. Request auto-rejected.',
      );
      return;
    }
    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                data['message'] ?? 'Approved successfully',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.pop(context, true);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Approval Failed',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Text(
          data['error'] ?? 'Something went wrong. Please try again.',
          style: const TextStyle(fontSize: 13, color: _textMid),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  void _reject(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.do_not_disturb_on_rounded,
                color: _red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Request',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for rejection',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textMid,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _textDark),
              decoration: InputDecoration(
                hintText: 'Briefly describe the reason…',
                hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMid,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ApiClient.post('/admin/reject-request', {
                'request_id': widget.request['request_id'],
                'reject_reason': ctrl.text,
              });
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              'Reject',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRejectReason =
        widget.request['reject_reason'] != null &&
        widget.request['reject_reason'].toString().isNotEmpty;
    final hasEditReason =
        widget.request['edit_reason'] != null &&
        widget.request['edit_reason'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: _surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x401A56DB),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Request Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Review employee information',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero ────────────────────────────────────────────
                _profileHero(),
                const SizedBox(height: 14),

                // ── Previous rejection banner ────────────────────────
                if (hasRejectReason) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: _red,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Previous Rejection Reason',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.request['reject_reason'].toString(),
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Personal Info ────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.person_outline_rounded,
                        'Personal Information',
                        _primary,
                        const Color(0xFFEEF2FF),
                      ),
                      _infoTile(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: widget.request['emp_id']?.toString() ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.wc_rounded,
                        label: 'Gender',
                        value: widget.request['gender'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.cake_outlined,
                        label: 'Date of Birth',
                        value: _fmt(widget.request['date_of_birth']),
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Father Name',
                        value: widget.request['father_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.phone_android_rounded,
                        label: 'Emergency Contact',
                        value: widget.request['emergency_contact'] ?? '-',
                      ),
                      _infoTile(
                        icon: Icons.phone_android_rounded,
                        label: 'Emergency Contact relation ',
                        value:
                            widget.request['emergency_contact_relation'] ?? '-',
                      ),
                    ],
                  ),
                ),

                // ── Contact ──────────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.contact_mail_outlined,
                        'Contact Information',
                        _purple,
                        const Color(0xFFF5F3FF),
                      ),
                      _infoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: widget.request['email_id'] ?? '-',
                        valueColor: _primary,
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: widget.request['phone_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.home_outlined,
                        label: 'Permanent Address',
                        value: widget.request['permanent_address'] ?? '-',
                        maxLines: 4,
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Communication Address',
                        value: widget.request['communication_address'] ?? '-',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),

                // ── Employment ───────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.work_outline_rounded,
                        'Employment Information',
                        _amber,
                        const Color(0xFFFFFBEB),
                      ),
                      _infoTile(
                        icon: Icons.business_outlined,
                        label: 'Department',
                        value: widget.request['department_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: widget.request['role_name'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date of Joining',
                        value: _fmt(widget.request['date_of_joining']),
                      ),
                      if (widget.request['date_of_relieving'] != null &&
                          widget.request['date_of_relieving']
                              .toString()
                              .isNotEmpty) ...[
                        _dividerRow(),
                        _infoTile(
                          icon: Icons.event_busy_outlined,
                          label: 'Date of Relieving',
                          value: _fmt(widget.request['date_of_relieving']),
                        ),
                      ],
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.category_outlined,
                        label: 'Employment Type',
                        value: widget.request['employment_type'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.access_time_outlined,
                        label: 'Work Type',
                        value: widget.request['work_type'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.timeline_rounded,
                        label: 'Experience',
                        value:
                            '${widget.request['years_experience'] ?? '-'} yrs',
                      ),
                    ],
                  ),
                ),

                // ── Education ────────────────────────────────────────
                _educationSection(
                  (widget.request['education_list'] as List?) ?? [],
                ),

                // ── Documents ────────────────────────────────────────
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(
                        Icons.description_outlined,
                        'Documents & Statutory',
                        _red,
                        const Color(0xFFFFF1F2),
                      ),
                      _infoTile(
                        icon: Icons.credit_card_outlined,
                        label: 'Aadhar Number',
                        value: widget.request['aadhar_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.assignment_outlined,
                        label: 'PAN Number',
                        value: widget.request['pan_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.airplanemode_active_outlined,
                        label: 'Passport Number',
                        value: widget.request['passport_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.account_balance_rounded,
                        label: 'PF Number',
                        value: widget.request['pf_number'] ?? '-',
                      ),
                      _dividerRow(),
                      _infoTile(
                        icon: Icons.health_and_safety_outlined,
                        label: 'ESIC Number',
                        value: widget.request['esic_number'] ?? '-',
                      ),
                    ],
                  ),
                ),

                // ── Edit Reason (UPDATE only) ────────────────────────
                if (hasEditReason)
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          Icons.edit_note_rounded,
                          'Edit Reason',
                          _primary,
                          const Color(0xFFEEF2FF),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFBFD0FF),
                              ),
                            ),
                            child: Text(
                              widget.request['edit_reason'].toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _textDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Action buttons ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'APPROVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () => _approve(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text(
                          'REJECT',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () => _reject(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
