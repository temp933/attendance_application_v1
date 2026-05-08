import 'dart:convert';
import 'package:flutter/material.dart';
import 'responsive_utils.dart';
import 'package:http/http.dart' as http;
import '../providers/api_client.dart';

class EmployeeProfileScreen extends StatefulWidget {
  final String employeeId;
  const EmployeeProfileScreen({super.key, required this.employeeId});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? employeeData;
  List<Map<String, dynamic>> educationList = [];
  bool isLoading = true;
  String? errorMessage;
  Future<http.Response>? _photoFuture;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ─── Design Tokens ───────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _red = Color(0xFFEF4444);
  static const Color _surface = Color(0xFFF0F4FF);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMid = Color(0xFF64748B);
  static const Color _textLight = Color(0xFF94A3B8);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _fetchAll();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiClient.get('/employees/${widget.employeeId}'),
        ApiClient.get('/employees/${widget.employeeId}/education'),
      ]);
      if (results[0].statusCode == 200) {
        setState(() => employeeData = jsonDecode(results[0].body));
      } else {
        setState(
          () => errorMessage = 'Employee not found (${results[0].statusCode})',
        );
      }
      if (results[1].statusCode == 200) {
        final edu = jsonDecode(results[1].body);
        if (edu['success'] == true) {
          setState(
            () => educationList = List<Map<String, dynamic>>.from(edu['data']),
          );
        }
      }
    } catch (e) {
      setState(
        () => errorMessage = 'Unable to load profile. Check your connection.',
      );
    } finally {
      setState(() => isLoading = false);
      if (employeeData != null) _animCtrl.forward();
      if (employeeData != null) {
        _animCtrl.forward();
        _photoFuture = ApiClient.get('/employees/${widget.employeeId}/photo');
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _fmt(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  String _fmtDate(dynamic v) {
    if (v == null) return '-';
    final s = v.toString().trim();
    if (s.isEmpty || s == '-') return '-';
    try {
      final dt = DateTime.parse(s);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return s;
    }
  }

  String _fullName() => [
    employeeData?['first_name'],
    employeeData?['mid_name'],
    employeeData?['last_name'],
  ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');

  String _initials() {
    final fn = employeeData?['first_name']?.toString().trim() ?? '';
    final ln = employeeData?['last_name']?.toString().trim() ?? '';
    final a = fn.isNotEmpty ? fn[0].toUpperCase() : '';
    final b = ln.isNotEmpty ? ln[0].toUpperCase() : '';
    final result = '$a$b';
    return result.isNotEmpty ? result : 'E';
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'active':
        return _accent;
      case 'inactive':
        return _amber;
      case 'relieved':
        return _red;
      default:
        return _textMid;
    }
  }

  String _eduLabel(String? l) =>
      const {
        '10': 'Class 10 (SSLC)',
        '12': 'Class 12 (HSC)',
        'Diploma': 'Diploma',
        'UG': 'Under Graduate',
        'PG': 'Post Graduate',
        'PhD': 'Doctorate (PhD)',
      }[l] ??
      (l ?? '-');

  Color _eduColor(String? l) =>
      const {
        '10': Color(0xFF6366F1),
        '12': Color(0xFF8B5CF6),
        'Diploma': Color(0xFFF59E0B),
        'UG': Color(0xFF0E9F6E),
        'PG': Color(0xFF1A56DB),
        'PhD': Color(0xFFEF4444),
      }[l] ??
      _textMid;

  // ─── Root ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : errorMessage != null
          ? _buildError(r)
          : employeeData == null
          ? const Center(child: Text('No data found'))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                onRefresh: _fetchAll,
                color: _primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            8,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 32),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: r.contentMaxWidth,
                            ),
                            child: _buildBody(r),
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

  Widget _buildBody(Responsive r) {
    final personalSection = _buildSection(
      r,
      icon: Icons.person_outline_rounded,
      title: 'Personal Information',
      color: _primary,
      bgColor: const Color(0xFFEEF2FF),
      rows: _personalRows(),
    );
    final workSection = _buildSection(
      r,
      icon: Icons.work_outline_rounded,
      title: 'Work Information',
      color: _purple,
      bgColor: const Color(0xFFF5F3FF),
      rows: _workRows(),
    );
    final addressSection = _buildSection(
      r,
      icon: Icons.location_on_outlined,
      title: 'Address',
      color: _amber,
      bgColor: const Color(0xFFFFFBEB),
      rows: _addressRows(),
    );
    final docsSection = _buildSection(
      r,
      icon: Icons.badge_outlined,
      title: 'Documents & Statutory',
      color: _red,
      bgColor: const Color(0xFFFFF1F2),
      rows: _documentRows(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(r),
        const SizedBox(height: 16),
        if (r.useTwoColSections) ...[
          _twoCol(personalSection, workSection),
          const SizedBox(height: 12),
          _twoCol(addressSection, docsSection),
          const SizedBox(height: 12),
        ] else ...[
          personalSection,
          const SizedBox(height: 12),
          workSection,
          const SizedBox(height: 12),
          addressSection,
          const SizedBox(height: 12),
          docsSection,
          const SizedBox(height: 12),
        ],
        _buildEducationSection(r),
      ],
    );
  }

  Widget _twoCol(Widget a, Widget b) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    ),
  );

  List<_Row> _personalRows() => [
    _Row('Employee ID', _fmt(employeeData!['emp_id'])),
    _Row('Full Name', _fullName()),
    _Row('Gender', _fmt(employeeData!['gender'])),
    _Row('Date of Birth', _fmtDate(employeeData!['date_of_birth'])),
    _Row('Father Name', _fmt(employeeData!['father_name'])),
    _Row('Email', _fmt(employeeData!['email_id']), highlight: true),
    _Row('Phone', _fmt(employeeData!['phone_number'])),
    _Row('Emergency Contact', _fmt(employeeData!['emergency_contact'])),
    _Row(
      'Emergency Contact Relation',
      _fmt(employeeData!['emergency_contact_relation']),
    ),
  ];
  List<_Row> _workRows() => [
    _Row('Department', _fmt(employeeData!['department_name'])),
    _Row('Role', _fmt(employeeData!['role_name'])),
    _Row('TL Name', _fmt(employeeData!['tl_name'])),
    _Row(
      'Employment Type',
      _fmt(employeeData!['employment_type']),
      pill: true,
      pillColor: _primary,
    ),
    _Row(
      'Work Type',
      _fmt(employeeData!['work_type']),
      pill: true,
      pillColor: _accent,
    ),
    _Row(
      'Years of Experience',
      employeeData!['years_experience'] != null
          ? '${employeeData!['years_experience']} yrs'
          : '-',
    ),
    _Row('Date of Joining', _fmtDate(employeeData!['date_of_joining'])),
    _Row('Date of Relieving', _fmtDate(employeeData!['date_of_relieving'])),
  ];
  List<_Row> _addressRows() => [
    _Row('Permanent Address', _fmt(employeeData!['permanent_address'])),
    _Row('Communication Address', _fmt(employeeData!['communication_address'])),
  ];
  List<_Row> _documentRows() => [
    _Row('Aadhar Number', _fmt(employeeData!['aadhar_number'])),
    _Row('PAN Number', _fmt(employeeData!['pan_number'])),
    _Row('Passport Number', _fmt(employeeData!['passport_number'])),
    _Row('PF Number', _fmt(employeeData!['pf_number'])),
    _Row('ESIC Number', _fmt(employeeData!['esic_number'])),
  ];

  PreferredSizeWidget _buildAppBar() => AppBar(
    // backgroundColor: _primary,
    foregroundColor: const Color.fromARGB(255, 5, 5, 5),
    elevation: 0,
    // title: const Text(
    //   'Employee Profile',
    //   style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    // ),
    actions: [
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _fetchAll,
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _buildError(Responsive r) => Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: r.hPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ─── Hero Card ────────────────────────────────────────────────────────────────
  Widget _buildHeroCard(Responsive r) {
    final status = _fmt(employeeData!['status']);
    final exp = employeeData!['years_experience'];
    final joined = _fmtDate(employeeData!['date_of_joining']);
    final empType = _fmt(employeeData!['employment_type']);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              r.isDesktop
                  ? 28
                  : r.isTablet
                  ? 24
                  : 20,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    // Avatar with photo
                    FutureBuilder<http.Response>(
                      future: ApiClient.get(
                        '/employees/${widget.employeeId}/photo',
                      ),
                      builder: (context, snap) {
                        final hasPhoto =
                            snap.hasData &&
                            snap.data!.statusCode == 200 &&
                            snap.data!.bodyBytes.isNotEmpty;
                        return Container(
                          width: r.avatarSize,
                          height: r.avatarSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              r.isDesktop ? 22 : 18,
                            ),
                            color: Colors.white.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              r.isDesktop ? 20 : 16,
                            ),
                            child: hasPhoto
                                ? Image.memory(
                                    snap.data!.bodyBytes,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      _initials(),
                                      style: TextStyle(
                                        fontSize: r.avatarSize * 0.35,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: r.isDesktop ? 20 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fullName(),
                            style: TextStyle(
                              fontSize: r.heroNameSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _fmt(employeeData!['role_name']),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: r.bodyTextSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _fmt(employeeData!['department_name']),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: r.labelTextSize,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _statusBadge(status),
                              _idBadge('ID: ${_fmt(employeeData!['emp_id'])}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (exp != null || joined != '-' || empType != '-') ...[
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _heroStat(exp != null ? '$exp yrs' : '-', 'Experience'),
                      _heroVDiv(),
                      _heroStat(
                        joined != '-' ? joined.split('/').last : '-',
                        'Joined',
                      ),
                      _heroVDiv(),
                      _heroStat(empType, 'Type'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _statusColor(s),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          s,
          style: TextStyle(
            color: _statusColor(s),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _idBadge(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.15)),
    ),
    child: Text(
      t,
      style: TextStyle(
        color: Colors.white.withOpacity(0.65),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _heroStat(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l.toUpperCase(),
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
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.12));

  // ─── Section Card ─────────────────────────────────────────────────────────────
  Widget _buildSection(
    Responsive r, {
    required IconData icon,
    required String title,
    required Color color,
    required Color bgColor,
    required List<_Row> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(r.cardRadius),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  style: TextStyle(
                    fontSize: r.sectionTitleSize,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              children: rows.map((row) => _buildInfoRow(r, row)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(Responsive r, _Row row) {
    final isEmpty = row.value == '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.infoLabelWidth,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: r.labelTextSize,
                color: _textMid,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: row.pill && !isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: row.pillColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        row.value,
                        style: TextStyle(
                          fontSize: r.bodyTextSize - 1,
                          color: row.pillColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : Text(
                    row.value,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: r.bodyTextSize,
                      color: isEmpty
                          ? _textLight
                          : row.highlight
                          ? _primary
                          : _textDark,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Education Section ────────────────────────────────────────────────────────
  Widget _buildEducationSection(Responsive r) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(r.cardRadius),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: _accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Education',
                  style: TextStyle(
                    fontSize: r.sectionTitleSize,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const Spacer(),
                if (educationList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${educationList.length} record${educationList.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _border),
          if (educationList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.school_outlined, color: _textLight, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'No education records found',
                    style: TextStyle(color: _textMid, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (r.isDesktop)
            // Desktop: 2-column grid for education tiles
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final tileWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: educationList
                        .map(
                          (edu) => SizedBox(
                            width: tileWidth,
                            child: _buildEduTile(r, edu),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: educationList.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 1, color: _border),
              itemBuilder: (_, i) => _buildEduTile(r, educationList[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildEduTile(Responsive r, Map<String, dynamic> edu) {
    final level = edu['education_level']?.toString() ?? '';
    final stream = edu['stream']?.toString().trim() ?? '';
    final score = edu['score'] != null ? '${edu['score']}%' : '-';
    final year = edu['year_of_passout']?.toString().trim() ?? '-';
    final college = edu['college_name']?.toString().trim() ?? '-';
    final uni = edu['university']?.toString().trim() ?? '-';
    final color = _eduColor(level);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                level,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: level.length > 2 ? 10 : 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _eduLabel(level),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.bodyTextSize,
                    color: _textDark,
                  ),
                ),
                if (stream.isNotEmpty && stream != '-') ...[
                  const SizedBox(height: 3),
                  Text(
                    stream,
                    style: TextStyle(
                      fontSize: r.labelTextSize,
                      color: _textMid,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (score != '-')
                      _chip(Icons.percent_rounded, score, _accent, r),
                    if (year.isNotEmpty && year != '-')
                      _chip(Icons.calendar_today_rounded, year, _purple, r),
                    if (college.isNotEmpty && college != '-')
                      _chip(
                        Icons.account_balance_rounded,
                        college,
                        _primary,
                        r,
                      ),
                    if (uni.isNotEmpty && uni != '-')
                      _chip(Icons.school_outlined, uni, _amber, r),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color, Responsive r) =>
      Container(
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
            Flexible(
              child: Text(
                label,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.chipTextSize,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Row {
  final String label, value;
  final bool highlight, pill;
  final Color pillColor;
  const _Row(
    this.label,
    this.value, {
    this.highlight = false,
    this.pill = false,
    this.pillColor = const Color(0xFF1A56DB),
  });
}
