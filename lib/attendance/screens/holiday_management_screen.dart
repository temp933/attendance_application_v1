import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

// ─── Design tokens (same palette as LeaveApprovalScreen) ─────────────────────
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

// ─── Model ────────────────────────────────────────────────────────────────────
class HolidayModel {
  final int holidayId;
  final String holidayName;
  final DateTime holidayDate;
  final String holidayType;
  final String? description;
  final bool isRecurring;

  HolidayModel({
    required this.holidayId,
    required this.holidayName,
    required this.holidayDate,
    required this.holidayType,
    this.description,
    required this.isRecurring,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> j) => HolidayModel(
    holidayId: j['holiday_id'] as int,
    holidayName: j['holiday_name'] as String,
    holidayDate: DateTime.parse(j['holiday_date'] as String),
    holidayType: j['holiday_type'] as String,
    description: j['description'] as String?,
    isRecurring: (j['is_recurring'] == 1 || j['is_recurring'] == true),
  );
}

// ─── Service ──────────────────────────────────────────────────────────────────
class HolidayService {
  Future<List<HolidayModel>> fetchHolidays(int year) async {
    final res = await ApiClient.get('/holidays?year=$year');
    if (res.statusCode != 200) throw Exception('Failed to load holidays');
    final body = jsonDecode(res.body);
    return (body['data'] as List).map((e) => HolidayModel.fromJson(e)).toList();
  }

  Future<void> addHoliday({
    required String name,
    required String date,
    required String type,
    required String? description,
    required bool isRecurring,
    required int loginId,
  }) async {
    final res = await ApiClient.post('/holidays', {
      'holiday_name': name,
      'holiday_date': date,
      'holiday_type': type,
      'description': description,
      'is_recurring': isRecurring,
      'login_id': loginId,
    });
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) throw Exception(body['message'] ?? 'Add failed');
  }

  Future<void> updateHoliday({
    required int id,
    required String name,
    required String date,
    required String type,
    required String? description,
    required bool isRecurring,
  }) async {
    final res = await ApiClient.put('/holidays/$id', {
      'holiday_name': name,
      'holiday_date': date,
      'holiday_type': type,
      'description': description,
      'is_recurring': isRecurring,
    });
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Update failed');
    }
  }

  Future<void> deleteHoliday(int id) async {
    final res = await ApiClient.delete('/holidays/$id');
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Delete failed');
    }
  }

  Future<Map<String, dynamic>> bulkImport(int year, int loginId) async {
    // Build the preset holidays list for the selected year
    final List<Map<String, dynamic>> holidays = [
      {
        'holiday_name': "New Year's Day",
        'holiday_date': '$year-01-01',
        'holiday_type': 'National',
        'description': 'First day of the year',
        'is_recurring': true,
      },
      {
        'holiday_name': 'Pongal',
        'holiday_date': '$year-01-14',
        'holiday_type': 'Public',
        'description': 'Tamil harvest festival',
        'is_recurring': true,
      },
      {
        'holiday_name': 'Pongal Holiday',
        'holiday_date': '$year-01-15',
        'holiday_type': 'Public',
        'description': 'Day after Pongal',
        'is_recurring': true,
      },
      {
        'holiday_name': 'Republic Day',
        'holiday_date': '$year-01-26',
        'holiday_type': 'National',
        'description': "India's Republic Day",
        'is_recurring': true,
      },
      {
        'holiday_name': 'Maha Shivaratri',
        'holiday_date': '$year-02-26',
        'holiday_type': 'Public',
        'description': 'Festival of Lord Shiva',
        'is_recurring': false,
      },
      {
        'holiday_name': 'Holi',
        'holiday_date': '$year-03-14',
        'holiday_type': 'Public',
        'description': 'Festival of colours',
        'is_recurring': false,
      },
      {
        'holiday_name': 'Tamil New Year',
        'holiday_date': '$year-04-14',
        'holiday_type': 'Public',
        'description': 'Puthandu – Tamil New Year',
        'is_recurring': true,
      },
      {
        'holiday_name': 'Good Friday',
        'holiday_date': '$year-04-18',
        'holiday_type': 'Public',
        'description': 'Crucifixion of Jesus Christ',
        'is_recurring': false,
      },
      {
        'holiday_name': 'May Day',
        'holiday_date': '$year-05-01',
        'holiday_type': 'National',
        'description': "International Workers' Day",
        'is_recurring': true,
      },
      {
        'holiday_name': 'Independence Day',
        'holiday_date': '$year-08-15',
        'holiday_type': 'National',
        'description': "India's Independence Day",
        'is_recurring': true,
      },
      {
        'holiday_name': 'Gandhi Jayanti',
        'holiday_date': '$year-10-02',
        'holiday_type': 'National',
        'description': 'Birthday of Mahatma Gandhi',
        'is_recurring': true,
      },
      {
        'holiday_name': 'Christmas',
        'holiday_date': '$year-12-25',
        'holiday_type': 'National',
        'description': 'Christmas Day',
        'is_recurring': true,
      },
    ];

    final res = await ApiClient.post('/holidays/bulk', {'holidays': holidays});
    return jsonDecode(res.body);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class HolidayManagementScreen extends StatefulWidget {
  final int loginId;
  const HolidayManagementScreen({super.key, required this.loginId});

  @override
  State<HolidayManagementScreen> createState() =>
      _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  final HolidayService _svc = HolidayService();

  int _selectedYear = DateTime.now().year;
  List<HolidayModel> _holidays = [];
  bool _loading = true;
  String? _error;

  String _filterType = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _types = [
    'Public',
    'National',
    'Optional',
    'Office',
  ];
  static const Map<String, Color> _typeColors = {
    'Public': _primary,
    'National': _accent,
    'Optional': _purple,
    'Office': _amber,
  };
  static const Map<String, IconData> _typeIcons = {
    'Public': Icons.celebration_rounded,
    'National': Icons.flag_rounded,
    'Optional': Icons.stars_rounded,
    'Office': Icons.apartment_rounded,
  };

  // 19 common Indian / TN presets (name, MM-DD, type, description)
  static const List<(String, String, String, String)> _presets = [
    ("New Year's Day", '01-01', 'National', 'First day of the year'),
    ('Pongal', '01-14', 'Public', 'Tamil harvest festival'),
    ('Pongal Holiday', '01-15', 'Public', 'Day after Pongal'),
    ('Republic Day', '01-26', 'National', "India's Republic Day"),
    ('Maha Shivaratri', '02-26', 'Public', 'Festival of Lord Shiva'),
    ('Holi', '03-14', 'Public', 'Festival of colours'),
    ('Eid al-Fitr (Ramzan)', '03-31', 'Public', 'End of Ramadan fasting'),
    ('Tamil New Year', '04-14', 'Public', 'Puthandu – Tamil New Year'),
    ('Good Friday', '04-18', 'Public', 'Crucifixion of Jesus Christ'),
    ('May Day', '05-01', 'National', "International Workers' Day"),
    ('Eid al-Adha (Bakrid)', '06-07', 'Public', 'Festival of Sacrifice'),
    ('Independence Day', '08-15', 'National', "India's Independence Day"),
    ('Gandhi Jayanti', '10-02', 'National', 'Birthday of Mahatma Gandhi'),
    ('Dussehra', '10-02', 'Public', 'Vijayadasami'),
    ('Diwali', '10-20', 'Public', 'Festival of lights'),
    ('Diwali Holiday', '10-21', 'Public', 'Diwali holiday'),
    ('Christmas', '12-25', 'National', 'Christmas Day'),
    ('Office Outing', '00-00', 'Office', 'Company team outing'),
    ('Company Anniversary', '00-00', 'Office', 'Company founding anniversary'),
  ];

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHolidays() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.fetchHolidays(_selectedYear);
      if (mounted) setState(() => _holidays = data);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<HolidayModel> get _filtered => _holidays.where((h) {
    final q = _searchCtrl.text.toLowerCase();
    final matchQ =
        q.isEmpty ||
        h.holidayName.toLowerCase().contains(q) ||
        (h.description?.toLowerCase().contains(q) ?? false);
    final matchT = _filterType == 'All' || h.holidayType == _filterType;
    return matchQ && matchT;
  }).toList();

  int get _upcomingCount {
    final now = DateTime.now();
    return _holidays
        .where(
          (h) => h.holidayDate.isAfter(now) || _isSameDay(h.holidayDate, now),
        )
        .length;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}';
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
  String _dayName(DateTime d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
  bool _isPast(DateTime d) =>
      d.isBefore(DateTime.now()) && !_isSameDay(d, DateTime.now());
  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());
  bool _isSoon(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 7;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: _buildAppBar(),
    floatingActionButton: _buildFab(),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          )
        : _error != null
        ? _buildErrorState()
        : _buildBody(),
  );

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(118),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x401A56DB),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _textDark,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: _primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Holiday Calendar',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        Text(
                          'Manage public & office holidays',
                          style: TextStyle(fontSize: 11, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Import common holidays',
                    child: IconButton(
                      onPressed: _showBulkImportDialog,
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _purple.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.upload_rounded,
                          color: _purple,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: _textDark),
                    onPressed: _loadHolidays,
                  ),
                ],
              ),
            ),
            SizedBox(height: 36, child: _buildYearBar()),
          ],
        ),
      ),
    ),
  );

  Widget _buildYearBar() {
    final years = List.generate(5, (i) => DateTime.now().year - 1 + i);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: years.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final y = years[i];
        final sel = y == _selectedYear;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedYear = y);
            _loadHolidays();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _primary : _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _primary : _border),
            ),
            child: Text(
              '$y',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : _textMid,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() => Column(
    children: [
      _buildSummaryRow(),
      _buildSearchBar(),
      Expanded(
        child: _filtered.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
                onRefresh: _loadHolidays,
                color: _primary,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _HolidayCard(
                    holiday: _filtered[i],
                    fmt: _fmt,
                    mon: _mon,
                    dayName: _dayName,
                    isPast: _isPast,
                    isToday: _isToday,
                    isSoon: _isSoon,
                    typeColors: _typeColors,
                    typeIcons: _typeIcons,
                    onEdit: () => _showAddEditDialog(holiday: _filtered[i]),
                    onDelete: () => _confirmDelete(_filtered[i]),
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _buildSummaryRow() {
    final byType = <String, int>{};
    for (final h in _holidays) {
      byType[h.holidayType] = (byType[h.holidayType] ?? 0) + 1;
    }
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryChip(
              '${_holidays.length} Total',
              Icons.calendar_month_rounded,
              _primary,
            ),
            const SizedBox(width: 8),
            _SummaryChip(
              '$_upcomingCount Upcoming',
              Icons.upcoming_rounded,
              _accent,
            ),
            ..._types.map(
              (t) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _SummaryChip(
                  '${byType[t] ?? 0} $t',
                  _typeIcons[t]!,
                  _typeColors[t]!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() => Container(
    color: _card,
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 13, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Search holiday name or description…',
            hintStyle: const TextStyle(color: _textLight, fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 18,
              color: _textMid,
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _textMid,
                    ),
                    onPressed: () => setState(() => _searchCtrl.clear()),
                  )
                : null,
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _TypeChip(
                'All',
                null,
                _filterType == 'All',
                _textMid,
                () => setState(() => _filterType = 'All'),
              ),
              ..._types.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _TypeChip(
                    t,
                    _typeIcons[t],
                    _filterType == t,
                    _typeColors[t]!,
                    () => setState(() => _filterType = t),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_filtered.length} of ${_holidays.length} holidays',
          style: const TextStyle(fontSize: 11, color: _textLight),
        ),
      ],
    ),
  );

  Widget _buildFab() => FloatingActionButton.extended(
    onPressed: () => _showAddEditDialog(),
    backgroundColor: _primary,
    foregroundColor: Colors.white,
    elevation: 4,
    icon: const Icon(Icons.add_rounded),
    label: const Text(
      'Add Holiday',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 36,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _filterType == 'All' && _searchCtrl.text.isEmpty
                ? 'No holidays for $_selectedYear'
                : 'No results found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _filterType == 'All' && _searchCtrl.text.isEmpty
                ? 'Tap + to add holidays or use Bulk Import.'
                : 'Try a different search or filter.',
            style: const TextStyle(fontSize: 13, color: _textMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: _red, size: 28),
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
            onPressed: _loadHolidays,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Add / Edit Dialog ─────────────────────────────────────────────────────
  void _showAddEditDialog({HolidayModel? holiday}) {
    final isEdit = holiday != null;
    final nameCtrl = TextEditingController(text: holiday?.holidayName ?? '');
    final descCtrl = TextEditingController(text: holiday?.description ?? '');
    String selType = holiday?.holidayType ?? 'Public';
    bool isRecurring = holiday?.isRecurring ?? false;
    DateTime selDate = holiday?.holidayDate ?? DateTime.now();

    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, si) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  color: _primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Holiday' : 'Add Holiday',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Quick-fill presets (add mode only) ─────────────────
                  if (!isEdit) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Quick Fill',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textMid,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final (name, mmdd, type, desc) = _presets[i];
                          return GestureDetector(
                            onTap: () {
                              nameCtrl.text = name;
                              descCtrl.text = desc;
                              si(() {
                                selType = type;
                                if (mmdd != '00-00') {
                                  final p = mmdd.split('-');
                                  selDate = DateTime(
                                    selDate.year,
                                    int.parse(p[0]),
                                    int.parse(p[1]),
                                  );
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _border),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _textDark,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: _border),
                  ],
                  const SizedBox(height: 14),

                  // Name
                  const _FL('Holiday Name'),
                  const SizedBox(height: 6),
                  _DTF(
                    controller: nameCtrl,
                    hint: 'e.g. Pongal, Diwali, Ramzan…',
                  ),
                  const SizedBox(height: 14),

                  // Date
                  const _FL('Date'),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: selDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: _primary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (p != null) si(() => selDate = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
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
                            _fmt(selDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _dayName(selDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Type
                  const _FL('Holiday Type'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final sel = selType == t;
                      final c = _typeColors[t]!;
                      return GestureDetector(
                        onTap: () => si(() => selType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? c : _surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? c : _border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _typeIcons[t],
                                size: 12,
                                color: sel ? Colors.white : c,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _textMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  const _FL('Description (optional)'),
                  const SizedBox(height: 6),
                  _DTF(
                    controller: descCtrl,
                    hint: 'Brief description…',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Recurring toggle
                  GestureDetector(
                    onTap: () => si(() => isRecurring = !isRecurring),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isRecurring
                            ? _primary.withValues(alpha: 0.05)
                            : _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isRecurring
                              ? _primary.withValues(alpha: 0.3)
                              : _border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 16,
                            color: isRecurring ? _primary : _textLight,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recurring Annually',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isRecurring ? _primary : _textDark,
                                  ),
                                ),
                                const Text(
                                  'Applies every year on the same date',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _textMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isRecurring,
                            onChanged: (v) => si(() => isRecurring = v),
                            activeThumbColor: _primary,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textMid,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  _snack('Holiday name required', isError: true);
                  return;
                }
                final dateStr =
                    '${selDate.year}-${selDate.month.toString().padLeft(2, '0')}'
                    '-${selDate.day.toString().padLeft(2, '0')}';
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _svc.updateHoliday(
                      id: holiday.holidayId,
                      name: name,
                      date: dateStr,
                      type: selType,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      isRecurring: isRecurring,
                    );
                    _snack('Holiday updated');
                  } else {
                    await _svc.addHoliday(
                      name: name,
                      date: dateStr,
                      type: selType,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                      isRecurring: isRecurring,
                      loginId: widget.loginId,
                    );
                    _snack('Holiday added');
                  }
                  _loadHolidays();
                } catch (e) {
                  _snack('$e', isError: true);
                }
              },
              child: Text(
                isEdit ? 'Update' : 'Add Holiday',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bulk Import Dialog ────────────────────────────────────────────────────
  void _showBulkImportDialog() {
    int importYear = _selectedYear;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, si) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.upload_rounded,
                  color: _purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Bulk Import',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  'Imports common Indian national holidays for the selected year. '
                  'Existing entries will be skipped automatically.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _textDark,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _FL('Year'),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => si(() => importYear--),
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: _textMid,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        '$importYear',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => si(() => importYear++),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: _textMid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textMid,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final res = await _svc.bulkImport(importYear, widget.loginId);
                  _snack(
                    res['message'] ??
                        (res['success'] == true
                            ? 'Import complete'
                            : 'Import failed'),
                    isError: res['success'] != true,
                  );
                  if (res['success'] == true) {
                    setState(() => _selectedYear = importYear);
                    _loadHolidays();
                  }
                } catch (e) {
                  _snack('Import failed: $e', isError: true);
                }
              },
              child: const Text(
                'Import',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ────────────────────────────────────────────────────────
  void _confirmDelete(HolidayModel h) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                color: _red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: _red,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Holiday',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${h.holidayName}" (${_fmt(h.holidayDate)})? '
          'This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: _textMid, height: 1.5),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMid,
              side: const BorderSide(color: _border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Cancel'),
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
              Navigator.pop(ctx);
              try {
                await _svc.deleteHoliday(h.holidayId);
                _snack('Holiday deleted');
                _loadHolidays();
              } catch (e) {
                _snack('Delete failed: $e', isError: true);
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
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
        backgroundColor: isError ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Holiday Card widget ──────────────────────────────────────────────────────
class _HolidayCard extends StatelessWidget {
  final HolidayModel holiday;
  final String Function(DateTime) fmt;
  final String Function(int) mon;
  final String Function(DateTime) dayName;
  final bool Function(DateTime) isPast;
  final bool Function(DateTime) isToday;
  final bool Function(DateTime) isSoon;
  final Map<String, Color> typeColors;
  final Map<String, IconData> typeIcons;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HolidayCard({
    required this.holiday,
    required this.fmt,
    required this.mon,
    required this.dayName,
    required this.isPast,
    required this.isToday,
    required this.isSoon,
    required this.typeColors,
    required this.typeIcons,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final h = holiday;
    final color = typeColors[h.holidayType] ?? _primary;
    final icon = typeIcons[h.holidayType] ?? Icons.event_rounded;
    final past = isPast(h.holidayDate);
    final today = isToday(h.holidayDate);
    final soon = isSoon(h.holidayDate);

    return Opacity(
      opacity: past ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: today ? color.withValues(alpha: 0.05) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: today ? color.withValues(alpha: 0.4) : _border,
            width: today ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: today
                  ? color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: today ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Date column
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                border: Border(
                  right: BorderSide(color: color.withValues(alpha: 0.2)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mon(h.holidayDate.month).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${h.holidayDate.day}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    dayName(h.holidayDate),
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  h.holidayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                              if (today) _Pill('Today', color),
                              if (soon && !today) _Pill('Soon', _amber),
                              if (past) _Pill('Past', _textLight),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 10, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      h.holidayType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (h.isRecurring) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Recurring annually',
                                  child: const Icon(
                                    Icons.repeat_rounded,
                                    size: 13,
                                    color: _textLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (h.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 5),
                            Text(
                              h.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMid,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Action buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionBtn(Icons.edit_rounded, _primary, onEdit),
                        const SizedBox(height: 6),
                        _ActionBtn(
                          Icons.delete_outline_rounded,
                          _red,
                          onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    constraints: const BoxConstraints(),
    padding: EdgeInsets.zero,
    icon: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: color),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeChip(this.label, this.icon, this.selected, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color : _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: selected ? Colors.white : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _textMid,
            ),
          ),
        ],
      ),
    ),
  );
}

// Short alias widgets for dialog form
class _FL extends StatelessWidget {
  final String text;
  const _FL(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _textMid,
    ),
  );
}

class _DTF extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _DTF({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: _textDark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textLight, fontSize: 13),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    ),
  );
}
