// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:latlong2/latlong.dart';
// import 'add_location_dialog.dart';
// import '../providers/api_client.dart';
// import '../providers/api_config.dart';

// class ManageLocationPage extends StatefulWidget {
//   const ManageLocationPage({super.key});

//   @override
//   State<ManageLocationPage> createState() => _ManageLocationPageState();
// }

// class _ManageLocationPageState extends State<ManageLocationPage> {
//   List<Map<String, dynamic>> sites = [];
//   bool loading = true;

//   @override
//   void initState() {
//     super.initState();
//     loadSites();
//   }

//   // ─────────────────────────────
//   // Load Sites
//   // ─────────────────────────────
//   Future<void> loadSites() async {
//     try {
//       final res = await ApiClient.get('/sites');
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         setState(() {
//           sites = List<Map<String, dynamic>>.from(data);
//           loading = false;
//         });
//       } else {
//         debugPrint("loadSites error: ${res.statusCode} ${res.body}");
//         setState(() => loading = false);
//       }
//     } catch (e) {
//       debugPrint("loadSites exception: $e");
//       setState(() => loading = false);
//     }
//   }

//   // ─────────────────────────────
//   // Add Site
//   // ─────────────────────────────
//   Future<void> saveSite(
//     String name,
//     List<LatLng> points,
//     DateTime start,
//     DateTime end,
//   ) async {
//     final closedPoints = [...points];
//     if (closedPoints.first != closedPoints.last) {
//       closedPoints.add(closedPoints.first);
//     }
//     try {
//       final res = await ApiClient.post('/sites', {
//         "site_name": name,
//         "polygon_json": closedPoints
//             .map((e) => {"lat": e.latitude, "lng": e.longitude})
//             .toList(),
//         "start_date": start.toIso8601String().split("T")[0],
//         "end_date": end.toIso8601String().split("T")[0],
//       });
//       if (res.statusCode == 200 || res.statusCode == 201) {
//         loadSites();
//       } else {
//         debugPrint("saveSite error: ${res.statusCode} ${res.body}");
//       }
//     } catch (e) {
//       debugPrint("saveSite exception: $e");
//     }
//   }

//   // ─────────────────────────────
//   // Update Site
//   // ─────────────────────────────
//   Future<void> updateSite(
//     int id,
//     String name,
//     List<LatLng> points,
//     DateTime start,
//     DateTime end,
//   ) async {
//     final closedPoints = [...points];
//     if (closedPoints.first != closedPoints.last) {
//       closedPoints.add(closedPoints.first);
//     }
//     try {
//       final res = await ApiClient.put('/sites/$id', {
//         "site_name": name,
//         "polygon_json": closedPoints
//             .map((e) => {"lat": e.latitude, "lng": e.longitude})
//             .toList(),
//         "start_date": start.toIso8601String().split("T")[0],
//         "end_date": end.toIso8601String().split("T")[0],
//       });
//       if (res.statusCode == 200) {
//         loadSites();
//       } else {
//         debugPrint("updateSite error: ${res.statusCode} ${res.body}");
//       }
//     } catch (e) {
//       debugPrint("updateSite exception: $e");
//     }
//   }

//   // ─────────────────────────────
//   void openAddDialog() {
//     showDialog(
//       context: context,
//       builder: (_) => AddLocationDialog(onSave: saveSite),
//     );
//   }

//   void openEditDialog(Map site) {
//     showDialog(
//       context: context,
//       builder: (_) => AddLocationDialog(
//         existingSite: site,
//         onSave: (name, points, start, end) {
//           updateSite(site["id"], name, points, start, end);
//         },
//       ),
//     );
//   }

//   // ─────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       // appBar: AppBar(
//       //   title: const Text("Locations"),
//       //   backgroundColor: Colors.teal,
//       // ),
//       body: loading
//           ? const Center(child: CircularProgressIndicator())
//           : sites.isEmpty
//           ? const Center(child: Text("No locations available"))
//           : ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: sites.length,
//               itemBuilder: (context, i) {
//                 final s = sites[i];

//                 return Card(
//                   child: ListTile(
//                     leading: const Icon(Icons.location_on),
//                     title: Text(s["site_name"]),
//                     subtitle: Text(
//                       "From ${s["start_date"]} → ${s["end_date"]}",
//                     ),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.edit, color: Colors.orange),
//                       onPressed: () => openEditDialog(s),
//                     ),
//                   ),
//                 );
//               },
//             ),

//       floatingActionButton: FloatingActionButton(
//         onPressed: openAddDialog,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/api_client.dart';
import 'responsive_utils.dart';
import 'add_location_dialog.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class SiteModel {
  final int id;
  final String siteName;
  final List<Map<String, double>> polygon;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;

  const SiteModel({
    required this.id,
    required this.siteName,
    required this.polygon,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, double>> polygon = [];
    try {
      final raw = json['polygon_json'];
      final list = raw is String ? jsonDecode(raw) as List : raw as List;
      polygon = list
          .map<Map<String, double>>(
            (pt) => {
              'lat': (pt['lat'] as num).toDouble(),
              'lng': (pt['lng'] as num).toDouble(),
            },
          )
          .toList();
    } catch (_) {}

    return SiteModel(
      id: (json['id'] as num).toInt(),
      siteName: (json['site_name'] as String?) ?? 'Unnamed Site',
      polygon: polygon,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  LatLngCenter? get centroid {
    if (polygon.isEmpty) return null;
    final lat =
        polygon.map((p) => p['lat']!).reduce((a, b) => a + b) / polygon.length;
    final lng =
        polygon.map((p) => p['lng']!).reduce((a, b) => a + b) / polygon.length;
    return LatLngCenter(lat, lng);
  }

  int get daysCount {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }

  Map<String, dynamic> toRawJson() => {
    'id': id,
    'site_name': siteName,
    'polygon_json': polygon,
    'start_date': startDate?.toIso8601String().split('T')[0],
    'end_date': endDate?.toIso8601String().split('T')[0],
    'created_at': createdAt?.toIso8601String(),
  };
}

class LatLngCenter {
  final double lat;
  final double lng;
  const LatLngCenter(this.lat, this.lng);
}

// ─── Unified Screen ───────────────────────────────────────────────────────────

class ManageLocationPage extends StatefulWidget {
  final bool canEdit;

  const ManageLocationPage({super.key, this.canEdit = false});

  @override
  State<ManageLocationPage> createState() => _ManageLocationPageState();
}

class _ManageLocationPageState extends State<ManageLocationPage>
    with SingleTickerProviderStateMixin {
  List<SiteModel> _sites = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF1A56DB);
  static const Color _accent = Color(0xFF0E9F6E);
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
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _fetchSites();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Data ─────────────────────────────────────────────────────────────────

  Future<void> _fetchSites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiClient.get('/sites');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as List;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final sites = raw
            .map((e) => SiteModel.fromJson(e as Map<String, dynamic>))
            .where((s) {
              // In edit mode show all sites; in view mode hide expired ones
              if (widget.canEdit) return true;
              if (s.endDate == null) return true;
              return !s.endDate!.isBefore(today);
            })
            .toList();
        setState(() {
          _sites = sites;
          _isLoading = false;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error (${res.statusCode}). Try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load sites. Check your connection.';
      });
    }
  }

  Future<void> _saveSite(
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closed = [...points];
    if (closed.first != closed.last) closed.add(closed.first);
    try {
      final res = await ApiClient.post('/sites', {
        'site_name': name,
        'polygon_json': closed
            .map((e) => {'lat': e.latitude, 'lng': e.longitude})
            .toList(),
        'start_date': start.toIso8601String().split('T')[0],
        'end_date': end.toIso8601String().split('T')[0],
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _fetchSites();
        _showSnack('Site added successfully', success: true);
      } else {
        _showSnack('Failed to add site (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _updateSite(
    int id,
    String name,
    List<LatLng> points,
    DateTime start,
    DateTime end,
  ) async {
    final closed = [...points];
    if (closed.first != closed.last) closed.add(closed.first);
    try {
      final res = await ApiClient.put('/sites/$id', {
        'site_name': name,
        'polygon_json': closed
            .map((e) => {'lat': e.latitude, 'lng': e.longitude})
            .toList(),
        'start_date': start.toIso8601String().split('T')[0],
        'end_date': end.toIso8601String().split('T')[0],
      });
      if (res.statusCode == 200) {
        _fetchSites();
        _showSnack('Site updated successfully', success: true);
      } else {
        _showSnack('Failed to update site (${res.statusCode})');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(onSave: _saveSite),
    );
  }

  void _openEditDialog(SiteModel site) {
    showDialog(
      context: context,
      builder: (_) => AddLocationDialog(
        existingSite: site.toRawJson(),
        onSave: (name, points, start, end) =>
            _updateSite(site.id, name, points, start, end),
      ),
    );
  }

  // ─── Maps ─────────────────────────────────────────────────────────────────

  Future<void> _openInMaps(SiteModel site) async {
    final center = site.centroid;
    if (center == null) {
      _showSnack('No location data for this site.');
      return;
    }
    final label = Uri.encodeComponent(site.siteName);
    final lat = center.lat;
    final lng = center.lng;
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($label)');
    final webUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat%2C$lng&query_place=$label',
    );
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not open Maps on this device.');
    }
  }

  void _showSnack(String msg, {bool success = false}) {
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
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: success ? _accent : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Status helpers ───────────────────────────────────────────────────────

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  _SiteStatus _getStatus(SiteModel s) {
    final now = _onlyDate(DateTime.now());
    if (s.startDate == null) return _SiteStatus.unknown;
    final start = _onlyDate(s.startDate!);
    final end = s.endDate != null ? _onlyDate(s.endDate!) : null;
    if (end != null && end.isBefore(now)) return _SiteStatus.past;
    if (start.isAfter(now)) return _SiteStatus.upcoming;
    return _SiteStatus.active;
  }

  Color _statusColor(_SiteStatus s) => switch (s) {
    _SiteStatus.active => _accent,
    _SiteStatus.upcoming => _amber,
    _SiteStatus.past => _textLight,
    _ => _textMid,
  };

  String _fmtDate(DateTime? d) =>
      d == null ? '-' : DateFormat('dd MMM yyyy').format(d);

  // ─── Root ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: _surface,
      // FAB only in edit mode
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: _openAddDialog,
              backgroundColor: _primary,
              icon: const Icon(
                Icons.add_location_alt_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Add Site',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null
          ? _buildError(r)
          : RefreshIndicator(
              onRefresh: _fetchSites,
              color: _primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(r),
                  SliverToBoxAdapter(child: _buildSummaryBar(r)),
                  SliverToBoxAdapter(child: _buildListHeader(r)),
                  if (_sites.isEmpty)
                    SliverToBoxAdapter(child: _buildEmpty(r))
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        r.hPad,
                        0,
                        r.hPad,
                        widget.canEdit ? 96 : 32,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: r.contentMaxWidth,
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: r.useTwoColSections
                                  ? _buildGrid(r)
                                  : _buildList(r),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(Responsive r) => SliverToBoxAdapter(
    child: Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(
        r.hPad,
        MediaQuery.of(context).padding.top + 8,
        4,
        12,
      ),
    ),
  );

  // ─── Summary bar ──────────────────────────────────────────────────────────

  Widget _buildSummaryBar(Responsive r) {
    final active = _sites
        .where((s) => _getStatus(s) == _SiteStatus.active)
        .length;
    final upcoming = _sites
        .where((s) => _getStatus(s) == _SiteStatus.upcoming)
        .length;
    final past = widget.canEdit
        ? _sites.where((s) => _getStatus(s) == _SiteStatus.past).length
        : 0;

    return Container(
      color: _primary,
      padding: EdgeInsets.fromLTRB(r.hPad, 0, r.hPad, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                _statItem('${_sites.length}', 'Total', Colors.white),
                _vDiv(),
                _statItem('$active', 'Active', const Color(0xFF6EE7B7)),
                _vDiv(),
                _statItem('$upcoming', 'Upcoming', const Color(0xFFFDE68A)),
                if (widget.canEdit) ...[
                  _vDiv(),
                  _statItem('$past', 'Past', Colors.white54),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String v, String l, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c),
        ),
        const SizedBox(height: 2),
        Text(
          l,
          style: TextStyle(
            fontSize: 10,
            color: c.withOpacity(0.75),
            letterSpacing: 0.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _vDiv() =>
      Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2));

  Widget _buildListHeader(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 20, r.hPad, 12),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.canEdit ? 'Manage Sites' : 'Site List',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: 0.1,
              ),
            ),
            const Spacer(),
            if (_sites.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_sites.length} sites',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  // ─── Grid / List ──────────────────────────────────────────────────────────

  Widget _buildGrid(Responsive r) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = r.isDesktop ? 3 : 2;
        const gap = 12.0;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            _sites.length,
            (i) => SizedBox(width: itemW, child: _buildCard(_sites[i], r)),
          ),
        );
      },
    );
  }

  Widget _buildList(Responsive r) => Column(
    children: List.generate(
      _sites.length,
      (i) => Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
        child: _buildCard(_sites[i], r),
      ),
    ),
  );

  // ─── Card ─────────────────────────────────────────────────────────────────

  Widget _buildCard(SiteModel site, Responsive r) {
    final status = _getStatus(site);
    final color = _statusColor(status);

    return GestureDetector(
      onTap: () => _showSiteDetails(site, r),
      child: Container(
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
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.siteName,
                          style: TextStyle(
                            fontSize: r.sectionTitleSize,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: _textLight,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_fmtDate(site.startDate)}  →  ${_fmtDate(site.endDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit button shown only in canEdit mode
                  if (widget.canEdit)
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: _amber,
                        size: 18,
                      ),
                      tooltip: 'Edit site',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => _openEditDialog(site),
                    )
                  else
                    _statusChip(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom sheet (details) ───────────────────────────────────────────────

  void _showSiteDetails(SiteModel site, Responsive r) {
    final status = _getStatus(site);
    final center = site.centroid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: r.isMobile ? 0.55 : 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              site.siteName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _statusChip(status),
                          ],
                        ),
                      ),
                      // Edit button in sheet header (canEdit mode)
                      if (widget.canEdit)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openEditDialog(site);
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: _primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        _dateBlock(
                          'Start Date',
                          _fmtDate(site.startDate),
                          _accent,
                        ),
                        const Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: _textLight,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        _dateBlock('End Date', _fmtDate(site.endDate), _red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.today_rounded,
                          color: _primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${site.daysCount} days total',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${site.polygon.length} boundary points',
                          style: const TextStyle(fontSize: 12, color: _textMid),
                        ),
                      ],
                    ),
                  ),
                  if (center != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: _textMid,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Centre coordinates',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${center.lat.toStringAsFixed(6)}, ${center.lng.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (center != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openInMaps(site);
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Navigate to Site'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            color: _red,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No polygon data — cannot navigate',
                            style: TextStyle(fontSize: 13, color: _red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Reusable widgets ─────────────────────────────────────────────────────

  Widget _statusChip(_SiteStatus s) {
    final label = switch (s) {
      _SiteStatus.active => 'Active',
      _SiteStatus.upcoming => 'Upcoming',
      _SiteStatus.past => 'Past',
      _ => 'Unknown',
    };
    final color = _statusColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBlock(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  // ─── Error / Empty ────────────────────────────────────────────────────────

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
              'Failed to load sites',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _fetchSites,
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

  Widget _buildEmpty(Responsive r) => Padding(
    padding: EdgeInsets.fromLTRB(r.hPad, 60, r.hPad, 60),
    child: Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: _textLight,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.canEdit ? 'No sites added yet' : 'No active sites',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.canEdit
                ? 'Tap + Add Site to create your first site'
                : 'Pull down to refresh',
            style: const TextStyle(color: _textMid, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

enum _SiteStatus { active, upcoming, past, unknown }
