import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/api_client.dart'; 

// ─── Palette (matches maintenance screen) ────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _border = Color(0xFFE2E8F0);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _green = Color(0xFF10B981);
const Color _yellow = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);
const Color _orange = Color(0xFFF97316);
const Color _surface = Color(0xFFF8FAFC);

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _OrgService {
  static const _appAdminBase = '/app-admin/maintenance/organizations';
  static const _tenantBase = '/tenant/my-org';

  static Future<Map<String, dynamic>> fetchOrg(
    String tenantId, {
    bool isAppAdmin = false,
  }) async {
    final url = isAppAdmin ? '$_appAdminBase/$tenantId' : _tenantBase;
    final res = await ApiClient.get(url);
    final decoded = jsonDecode(res.body);
    if (decoded == null || decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response from server');
    }
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Failed to fetch organization');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> updateStatus(
    String tenantId,
    String status,
  ) async {
    final res = await ApiClient.patch(
      '$_appAdminBase/$tenantId/status',
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateLogo(
    String tenantId,
    String base64Logo,
    String mimeType,
  ) async {
    final res = await ApiClient.patch(
      '$_appAdminBase/$tenantId/logo',
      body: jsonEncode({
        'company_logo': base64Logo,
        'company_logo_type': mimeType,
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resetPassword(
    String tenantId,
    String newPassword,
  ) async {
    final res = await ApiClient.post(
      '$_appAdminBase/$tenantId/reset-password',
      {'new_password': newPassword},
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateDetails(
    String tenantId,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.patch(
      '$_appAdminBase/$tenantId/details',
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OrgProfileScreen extends StatefulWidget {
  final String tenantId;
  final bool canEdit;
  final bool isAppAdmin;
  const OrgProfileScreen({
    super.key,
    required this.tenantId,
    this.canEdit = false,
    this.isAppAdmin = false,
  });

  @override
  State<OrgProfileScreen> createState() => _OrgProfileScreenState();
}

class _OrgProfileScreenState extends State<OrgProfileScreen> {
  Map<String, dynamic>? _org;
  bool _loading = true;
  String? _error;
  bool _editing = false;
  bool _saving = false;

  // Edit controllers
  final _contactPersonCtrl = TextEditingController();
  final _contactNumberCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _hrEmailCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _maxUsersCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contactPersonCtrl.dispose();
    _contactNumberCtrl.dispose();
    _adminEmailCtrl.dispose();
    _hrEmailCtrl.dispose();
    _domainCtrl.dispose();
    _gstCtrl.dispose();
    _timezoneCtrl.dispose();
    _addressCtrl.dispose();
    _maxUsersCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _OrgService.fetchOrg(
        widget.tenantId,
        isAppAdmin: widget.isAppAdmin,
      );
      if (!mounted) return;
      final data = res['data'];
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Organization data not found');
      }

      setState(() {
        _org = data;
        _loading = false;
        _populateControllers(data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _populateControllers(Map<String, dynamic> data) {
    _contactPersonCtrl.text = data['contact_person'] ?? '';
    _contactNumberCtrl.text = data['contact_number'] ?? '';
    _adminEmailCtrl.text = data['admin_email'] ?? '';
    _hrEmailCtrl.text = data['hr_email'] ?? '';
    _domainCtrl.text = data['domain_name'] ?? '';
    _gstCtrl.text = data['gst_number'] ?? '';
    _timezoneCtrl.text = data['timezone'] ?? '';
    _addressCtrl.text = data['company_address'] ?? '';
    _maxUsersCtrl.text = '${data['max_users'] ?? ''}';
    _companyNameCtrl.text = data['company_name'] ?? '';
  }

  void _enterEdit() => setState(() => _editing = true);

  void _cancelEdit() {
    _populateControllers(_org!);
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    if (_companyNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company name cannot be empty'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!widget.isAppAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Editing is only wired up for App Admin right now'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final maxUsers = int.tryParse(_maxUsersCtrl.text) ?? _org!['max_users'];

    setState(() => _saving = true);
    try {
      await _OrgService.updateDetails(widget.tenantId, {
        'company_name': _companyNameCtrl.text,
        'contact_person': _contactPersonCtrl.text,
        'contact_number': _contactNumberCtrl.text,
        'admin_email': _adminEmailCtrl.text,
        'hr_email': _hrEmailCtrl.text,
        'domain_name': _domainCtrl.text,
        'gst_number': _gstCtrl.text,
        'timezone': _timezoneCtrl.text,
        'company_address': _addressCtrl.text,
        'max_users': maxUsers,
      });

      if (!mounted) return;
      setState(() {
        _org!['company_name'] = _companyNameCtrl.text;
        _org!['contact_person'] = _contactPersonCtrl.text;
        _org!['contact_number'] = _contactNumberCtrl.text;
        _org!['admin_email'] = _adminEmailCtrl.text;
        _org!['hr_email'] = _hrEmailCtrl.text;
        _org!['domain_name'] = _domainCtrl.text;
        _org!['gst_number'] = _gstCtrl.text;
        _org!['timezone'] = _timezoneCtrl.text;
        _org!['company_address'] = _addressCtrl.text;
        _org!['max_users'] = maxUsers;
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _loading
        ? const Center(child: CircularProgressIndicator(color: _primary))
        : _error != null
        ? _ErrorView(message: _error!, onRetry: _load)
        : RefreshIndicator(
            color: _primary,
            onRefresh: _load,
            child: _OrgProfileBody(
              org: _org!,
              canEdit: widget.canEdit,
              editing: _editing,
              isAppAdmin: widget.isAppAdmin,
              companyNameCtrl: _companyNameCtrl,
              contactPersonCtrl: _contactPersonCtrl,
              contactNumberCtrl: _contactNumberCtrl,
              adminEmailCtrl: _adminEmailCtrl,
              hrEmailCtrl: _hrEmailCtrl,
              domainCtrl: _domainCtrl,
              gstCtrl: _gstCtrl,
              timezoneCtrl: _timezoneCtrl,
              addressCtrl: _addressCtrl,
              maxUsersCtrl: _maxUsersCtrl,
              onStatusChanged: (newStatus) {
                setState(() => _org!['status'] = newStatus);
              },
              onLogoChanged: (bytes, mime) {
                setState(() {
                  _org!['_logoBytes'] = bytes;
                  _org!['company_logo_type'] = mime;
                });
              },
              onRefresh: _load,
            ),
          );

    if (!widget.isAppAdmin) return bodyContent;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A56DB),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color.fromARGB(255, 254, 254, 255),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _org?['company_name'] ?? 'Organisation Profile',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_org != null && !_editing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _StatusBadge(status: _org!['status'] ?? 'unknown'),
            ),
          if (widget.canEdit && _org != null) ...[
            if (_editing) ...[
              TextButton(
                onPressed: _cancelEdit,
                child: const Text('Cancel', style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
              ),
              TextButton(
                onPressed: _saving ? null : _saveEdit,
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ] else
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _enterEdit,
                tooltip: 'Edit',
              ),
          ],
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: bodyContent,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────
class _OrgProfileBody extends StatelessWidget {
  final Map<String, dynamic> org;
  final bool canEdit;
  final bool editing;
  final bool isAppAdmin;
  final TextEditingController companyNameCtrl;
  final TextEditingController contactPersonCtrl;
  final TextEditingController contactNumberCtrl;
  final TextEditingController adminEmailCtrl;
  final TextEditingController hrEmailCtrl;
  final TextEditingController domainCtrl;
  final TextEditingController gstCtrl;
  final TextEditingController timezoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController maxUsersCtrl;
  final void Function(String) onStatusChanged;
  final void Function(Uint8List, String) onLogoChanged;
  final VoidCallback onRefresh;

  const _OrgProfileBody({
    required this.org,
    required this.canEdit,
    required this.editing,
    required this.isAppAdmin,
    required this.companyNameCtrl,
    required this.contactPersonCtrl,
    required this.contactNumberCtrl,
    required this.adminEmailCtrl,
    required this.hrEmailCtrl,
    required this.domainCtrl,
    required this.gstCtrl,
    required this.timezoneCtrl,
    required this.addressCtrl,
    required this.maxUsersCtrl,
    required this.onStatusChanged,
    required this.onLogoChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Hero card ────────────────────────────────────────────────────
        _HeroCard(
          org: org,
          canEdit: canEdit,
          editing: editing,
          nameController: companyNameCtrl,
          onLogoChanged: onLogoChanged,
        ),
        const SizedBox(height: 16),

        // ── Health score bar ─────────────────────────────────────────────
        _HealthScoreCard(score: (org['health_score'] as num?)?.toInt() ?? 100),
        const SizedBox(height: 16),

        // ── Plan & subscription ──────────────────────────────────────────
        _SectionCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Plan & Subscription',
          children: [
            _InfoRow(label: 'Plan', value: org['plan_id'] ?? 'free-trial'),
            _InfoRow(
              label: 'Status',
              value: (org['status'] ?? '').toString().toUpperCase(),
              valueColor: _statusColor(org['status'] ?? ''),
            ),
            _InfoRow(label: 'Trial Ends', value: _fmt(org['trial_ends_at'])),
            _InfoRow(label: 'Plan Starts', value: _fmt(org['plan_starts_at'])),
            _InfoRow(label: 'Plan Ends', value: _fmt(org['plan_ends_at'])),
            _InfoRow(
              label: 'Days Remaining',
              value: org['days_remaining'] != null
                  ? '${org['days_remaining']} days'
                  : '—',
              valueColor: _daysColor(org['days_remaining']),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Organisation details ─────────────────────────────────────────
        _SectionCard(
          icon: Icons.business_outlined,
          title: 'Organisation Details',
          children: [
            _InfoRow(label: 'Tenant ID', value: org['tenant_id'] ?? '—'),
            _InfoRow(label: 'Company Code', value: org['company_code'] ?? '—'),
            _EditableRow(
              label: 'Domain',
              controller: domainCtrl,
              editing: editing,
              staticValue: org['domain_name'] ?? '—',
            ),
            _EditableRow(
              label: 'GST Number',
              controller: gstCtrl,
              editing: editing,
              staticValue: org['gst_number'] ?? '—',
            ),
            _EditableRow(
              label: 'Timezone',
              controller: timezoneCtrl,
              editing: editing,
              staticValue: org['timezone'] ?? '—',
            ),
            _EditableRow(
              label: 'Address',
              controller: addressCtrl,
              editing: editing,
              staticValue: org['company_address'] ?? '—',
              maxLines: 2,
            ),
            _InfoRow(label: 'Registered On', value: _fmt(org['created_at'])),
            _InfoRow(label: 'Last Updated', value: _fmt(org['updated_at'])),
          ],
        ),
        const SizedBox(height: 16),

        // ── Contact info ─────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.contact_phone_outlined,
          title: 'Contact Information',
          children: [
            _EditableRow(
              label: 'Contact Person',
              controller: contactPersonCtrl,
              editing: editing,
              staticValue: org['contact_person'] ?? '—',
            ),
            _EditableRow(
              label: 'Contact Number',
              controller: contactNumberCtrl,
              editing: editing,
              staticValue: org['contact_number'] ?? '—',
              keyboardType: TextInputType.phone,
            ),
            _EditableRow(
              label: 'Admin Email',
              controller: adminEmailCtrl,
              editing: editing,
              staticValue: org['admin_email'] ?? '—',
              keyboardType: TextInputType.emailAddress,
            ),
            _EditableRow(
              label: 'HR Email',
              controller: hrEmailCtrl,
              editing: editing,
              staticValue: org['hr_email'] ?? '—',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Workforce ────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.people_outline,
          title: 'Workforce',
          children: [
            _InfoRow(
              label: 'Active Employees',
              value: '${org['employee_count'] ?? 0}',
            ),
            _EditableRow(
              label: 'Max Users',
              controller: maxUsersCtrl,
              editing: editing,
              staticValue: '${org['max_users'] ?? 0}',
              keyboardType: TextInputType.number,
            ),
            _InfoRow(
              label: 'Utilisation',
              value: org['max_users'] != null && org['max_users'] != 0
                  ? '${((org['employee_count'] ?? 0) / org['max_users'] * 100).toStringAsFixed(0)}%'
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Block info (only if blocked) ─────────────────────────────────
        if (org['block_reason'] != null) ...[
          _SectionCard(
            icon: Icons.block_outlined,
            title: 'Block Information',
            iconColor: _red,
            children: [
              _InfoRow(label: 'Reason', value: org['block_reason'] ?? '—'),
              _InfoRow(label: 'Blocked At', value: _fmt(org['blocked_at'])),
              _InfoRow(label: 'Blocked By', value: org['blocked_by'] ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Quick actions ────────────────────────────────────────────────
        if (canEdit && !editing && isAppAdmin)
          _ActionsCard(
            org: org,
            onStatusChanged: onStatusChanged,
            onRefresh: onRefresh,
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO CARD  (logo + name + code)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatefulWidget {
  final Map<String, dynamic> org;
  final bool canEdit;
  final bool editing;
  final TextEditingController nameController;
  final void Function(Uint8List, String) onLogoChanged;
  const _HeroCard({
    required this.org,
    required this.canEdit,
    required this.editing,
    required this.nameController,
    required this.onLogoChanged,
  });
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _uploading = false;

  Uint8List? get _localBytes => widget.org['_logoBytes'] as Uint8List?;

  Uint8List? _decodeServerLogo() {
    final raw = widget.org['company_logo'];
    if (raw == null) return null;
    try {
      // Case 1: Node.js Buffer serialized as { "type": "Buffer", "data": [...] }
      if (raw is Map && raw['type'] == 'Buffer' && raw['data'] is List) {
        return Uint8List.fromList(
          (raw['data'] as List).map((e) => (e as num).toInt()).toList(),
        );
      }
      // Case 2: Plain List<dynamic> of ints
      if (raw is List) {
        return Uint8List.fromList(raw.map((e) => (e as num).toInt()).toList());
      }
      // Case 3: Base64 string
      if (raw is String && raw.isNotEmpty) return base64Decode(raw);
    } catch (e) {
      debugPrint('[_decodeServerLogo] error: $e');
    }
    return null;
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
        ? 'image/webp'
        : 'image/jpeg';

    setState(() => _uploading = true);
    try {
      await _OrgService.updateLogo(
        widget.org['tenant_id'],
        base64Encode(bytes),
        mime,
      );
      if (!mounted) return;
      widget.onLogoChanged(bytes, mime);
      _showSnack('Logo updated successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to update logo: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logoBytes = _localBytes ?? _decodeServerLogo();
    final name = widget.org['company_name'] ?? '—';
    final code = widget.org['company_code'] ?? '';
    final empCount = widget.org['employee_count'] ?? 0;
    final maxUsers = widget.org['max_users'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.editing && widget.canEdit) {
                    _pickAndUpload();
                  } else if (logoBytes != null) {
                    // View full-screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _LogoViewerScreen(logoBytes: logoBytes, name: name),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoBytes != null
                      ? Image.memory(logoBytes, fit: BoxFit.contain)
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: _primary,
                            ),
                          ),
                        ),
                ),
              ),
              if (widget.canEdit && widget.editing)
                IgnorePointer(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _uploading ? _textMid : _primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _uploading
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Name & code ──────────────────────────────────────────────────
          widget.editing && widget.canEdit
              ? TextField(
                  controller: widget.nameController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: _primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: _primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                )
              : Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
          if (code.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── Stat row ─────────────────────────────────────────────────────
          Row(
            children: [
              _HeroStat(
                label: 'Employees',
                value: '$empCount',
                icon: Icons.people_outline,
                color: _primary,
              ),
              _Divider(),
              _HeroStat(
                label: 'Max Users',
                value: '$maxUsers',
                icon: Icons.group_add_outlined,
                color: _green,
              ),
              _Divider(),
              _HeroStat(
                label: 'Health',
                value: '${widget.org['health_score'] ?? 100}%',
                icon: Icons.favorite_outline,
                color: _healthColor(
                  (widget.org['health_score'] as num?)?.toInt() ?? 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 36,
    color: _border,
    margin: const EdgeInsets.symmetric(horizontal: 12),
  );
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: _textMid)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH SCORE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _HealthScoreCard extends StatelessWidget {
  final int score;
  const _HealthScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, color: color, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Health Score',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const Spacer(),
              Text(
                '$score / 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: _border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _healthLabel(score),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color iconColor;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor = _primary,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        // Rows
        ...children.map(
          (c) => Column(
            children: [
              c,
              if (c != children.last)
                const Divider(
                  height: 1,
                  color: _border,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO ROW
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool copyable;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _textMid),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onLongPress: copyable || true
                ? () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                : null,
            child: Text(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _textDark,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIONS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsCard extends StatefulWidget {
  final Map<String, dynamic> org;
  final void Function(String) onStatusChanged;
  final VoidCallback onRefresh;
  const _ActionsCard({
    required this.org,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  @override
  State<_ActionsCard> createState() => _ActionsCardState();
}

class _ActionsCardState extends State<_ActionsCard> {
  bool _statusLoading = false;
  bool _resetLoading = false;

  Future<void> _changeStatus(String newStatus) async {
    final confirmed = await _confirm(
      context,
      title: 'Change Status',
      message:
          'Set ${widget.org['company_name']} to ${newStatus.toUpperCase()}?',
      confirmLabel: newStatus.toUpperCase(),
      danger: newStatus == 'suspended' || newStatus == 'expired',
    );
    if (!confirmed) return;

    setState(() => _statusLoading = true);
    try {
      await _OrgService.updateStatus(widget.org['tenant_id'], newStatus);
      if (!mounted) return;
      widget.onStatusChanged(newStatus);
      _showSnack('Status updated to $newStatus');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final ctrl = TextEditingController();
    bool hidePass = true;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          
          content: TextField(
            controller: ctrl,
            obscureText: hidePass,
            decoration: InputDecoration(
              labelText: 'New Password',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                  hidePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setS(() => hidePass = !hidePass),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == null || confirmed.length < 6) {
      if (confirmed != null) {
        _showSnack('Password must be at least 6 characters', error: true);
      }
      return;
    }

    setState(() => _resetLoading = true);
    try {
      await _OrgService.resetPassword(widget.org['tenant_id'], confirmed);
      if (!mounted) return;
      _showSnack('Admin password reset successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _resetLoading = false);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.org['status'] ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.tune_outlined,
                    color: _primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Status buttons ──────────────────────────────────────
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (status != 'active')
                      _ActionBtn(
                        label: 'Activate',
                        icon: Icons.check_circle_outline,
                        color: _green,
                        loading: _statusLoading,
                        onTap: () => _changeStatus('active'),
                      ),
                    if (status != 'trial')
                      _ActionBtn(
                        label: 'Set Trial',
                        icon: Icons.timer_outlined,
                        color: _yellow,
                        loading: _statusLoading,
                        onTap: () => _changeStatus('trial'),
                      ),
                    if (status != 'suspended')
                      _ActionBtn(
                        label: 'Suspend',
                        icon: Icons.pause_circle_outline,
                        color: _orange,
                        loading: _statusLoading,
                        onTap: () => _changeStatus('suspended'),
                      ),
                    if (status != 'expired')
                      _ActionBtn(
                        label: 'Expire',
                        icon: Icons.cancel_outlined,
                        color: _red,
                        loading: _statusLoading,
                        onTap: () => _changeStatus('expired'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),

                ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: loading ? null : onTap,
    icon: Icon(icon, size: 14),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _red, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMid),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITABLE ROW
// ─────────────────────────────────────────────────────────────────────────────
class _EditableRow extends StatelessWidget {
  final String label;
  final String staticValue;
  final TextEditingController controller;
  final bool editing;
  final TextInputType keyboardType;
  final int maxLines;

  const _EditableRow({
    required this.label,
    required this.staticValue,
    required this.controller,
    required this.editing,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return _InfoRow(label: label, value: staticValue);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _textMid),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: _primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGO FULL-SCREEN VIEWER
// ─────────────────────────────────────────────────────────────────────────────
class _LogoViewerScreen extends StatelessWidget {
  final Uint8List logoBytes;
  final String name;
  const _LogoViewerScreen({required this.logoBytes, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(logoBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
      return _green;
    case 'trial':
      return _yellow;
    case 'suspended':
      return _orange;
    case 'expired':
      return _red;
    default:
      return _textMid;
  }
}

Color _daysColor(dynamic days) {
  if (days == null) return _textMid;
  final d = (days as num).toInt();
  if (d < 0) return _red;
  if (d < 7) return _orange;
  if (d < 30) return _yellow;
  return _green;
}

Color _healthColor(int score) {
  if (score >= 80) return _green;
  if (score >= 50) return _yellow;
  return _red;
}

String _healthLabel(int score) {
  if (score >= 80) return 'Good standing';
  if (score >= 50) return 'Needs attention';
  return 'Critical — action required';
}

String _fmt(dynamic raw) {
  if (raw == null) return '—';
  try {
    final dt = DateTime.parse(raw.toString()).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return raw.toString();
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13, color: _textMid),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? _red : _primary,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
