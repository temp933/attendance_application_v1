import 'dart:convert';
import 'package:flutter/material.dart';
import '../providers/api_client.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _purple = Color(0xFF7C3AED);
const Color _amber = Color(0xFFF59E0B);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);

class EmpHolidayView extends StatefulWidget {
  const EmpHolidayView({super.key});

  @override
  State<EmpHolidayView> createState() => _EmpHolidayViewState();
}

class _EmpHolidayViewState extends State<EmpHolidayView> {
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _holidays = [];
  bool _loading = true;
  String? _error;
  String _filterType = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedYear = now.month >= 4 ? now.year : now.year - 1;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get('/holidays?year=$_selectedYear');
      if (res.statusCode != 200) throw Exception('Server error');
      final body = jsonDecode(res.body);
      if (mounted) {
        final now = DateTime.now();
        final fyStart = DateTime(_selectedYear, 4, 1); // 1 Apr
        final fyEnd = DateTime(_selectedYear + 1, 3, 31); // 31 Mar

        setState(() {
          _holidays = List<Map<String, dynamic>>.from(body['data'] ?? []).where(
            (h) {
              try {
                final d = DateTime.parse(h['holiday_date']);
                return !d.isBefore(fyStart) && !d.isAfter(fyEnd);
              } catch (_) {
                return false;
              }
            },
          ).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _holidays.where((h) {
    final q = _searchCtrl.text.toLowerCase();
    final matchQ =
        q.isEmpty ||
        (h['holiday_name'] ?? '').toLowerCase().contains(q) ||
        (h['description'] ?? '').toLowerCase().contains(q);
    final matchT = _filterType == 'All' || h['holiday_type'] == _filterType;
    return matchQ && matchT;
  }).toList();

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime _parseDate(String s) => DateTime.parse(s);

  String _fmt(DateTime d) {
    const m = [
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
    ];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
  }

  String _dayName(DateTime d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  String _mon(int m) => [
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isPast(DateTime d) =>
      d.isBefore(DateTime.now()) && !_isSameDay(d, DateTime.now());

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  bool _isSoon(DateTime d) {
    final diff = d.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 7;
  }

  int get _upcomingCount {
    final now = DateTime.now();
    return _holidays.where((h) {
      final d = _parseDate(h['holiday_date']);
      return d.isAfter(now) || _isSameDay(d, now);
    }).length;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _surface,
    appBar: _buildAppBar(),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          )
        : _error != null
        ? _buildError()
        : _buildBody(),
  );

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(118),
    child: Container(
      decoration: const BoxDecoration(
        color: _card,
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
                  // ── Back button ──────────────────────────────────────────
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
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: _amber,
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
                          'View upcoming & past holidays',
                          style: TextStyle(fontSize: 11, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: _textDark),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildYearBar() {
    final years = List.generate(3, (i) => DateTime.now().year - 1 + i);
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
            _load();
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
                onRefresh: _load,
                color: _primary,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _buildCard(_filtered[i]),
                ),
              ),
      ),
    ],
  );

  Widget _buildSummaryRow() {
    final byType = <String, int>{};
    for (final h in _holidays) {
      final t = h['holiday_type'] ?? '';
      byType[t] = (byType[t] ?? 0) + 1;
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
            ..._typeColors.keys.map(
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
              ..._typeColors.keys.map(
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

  Widget _buildCard(Map<String, dynamic> h) {
    final date = _parseDate(h['holiday_date']);
    final type = h['holiday_type'] ?? 'Public';
    final color = _typeColors[type] ?? _primary;
    final icon = _typeIcons[type] ?? Icons.event_rounded;
    final past = _isPast(date);
    final today = _isToday(date);
    final soon = _isSoon(date);
    final recurring = h['is_recurring'] == 1 || h['is_recurring'] == true;
    final desc = h['description'] ?? '';

    return Opacity(
      opacity: past ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: today ? color.withOpacity(0.05) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: today ? color.withOpacity(0.4) : _border,
            width: today ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: today
                  ? color.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: today ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // ── Date column ────────────────────────────────────────────────
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                border: Border(
                  right: BorderSide(color: color.withOpacity(0.2)),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _mon(date.month).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    _dayName(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            h['holiday_name'] ?? '',
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
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 10, color: color),
                              const SizedBox(width: 4),
                              Text(
                                type,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (recurring) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: _textLight,
                          ),
                        ],
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _textMid),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
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
                ? 'No holidays have been added yet.'
                : 'Try a different search or filter.',
            style: const TextStyle(fontSize: 13, color: _textMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.red,
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
            onPressed: _load,
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
}

// ─── Shared micro-widgets ─────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SummaryChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.2)),
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

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
