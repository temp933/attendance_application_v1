import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens
// ─────────────────────────────────────────────────────────────────────────────
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

// Google Maps blue dot color
const Color _locationBlue = Color(0xFF4285F4);

InputDecoration _inputDec(
  String label, {
  String? hint,
  Widget? prefix,
  Widget? suffix,
}) => InputDecoration(
  labelText: label.isEmpty ? null : label,
  hintText: hint,
  hintStyle: const TextStyle(color: _textLight, fontSize: 13),
  labelStyle: const TextStyle(color: _textMid, fontSize: 13),
  prefixIcon: prefix,
  suffixIcon: suffix,
  filled: true,
  fillColor: _surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: _red.withOpacity(0.6)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _red, width: 1.5),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// AddLocationDialog
// ─────────────────────────────────────────────────────────────────────────────
class AddLocationDialog extends StatefulWidget {
  final Function(String, List<LatLng>, DateTime, DateTime) onSave;
  final Map? existingSite;

  const AddLocationDialog({super.key, required this.onSave, this.existingSite});

  @override
  State<AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<AddLocationDialog>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _manualCtrl = TextEditingController();
  final _mapCtrl = MapController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _startDate;
  DateTime? _endDate;
  List<LatLng> _points = [];
  bool _isManualMode = false;
  bool _previewReady = false;
  bool _searching = false;
  String? _manualError;

  // ── Live location state
  LatLng? _myLocation;
  double? _myAccuracy; // metres
  StreamSubscription<Position>? _locationSub;
  bool _locationLoading = false;
  bool _locationEnabled = false; // toggled by user

  late AnimationController _modeAnim;

  @override
  void initState() {
    super.initState();
    _modeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    if (widget.existingSite != null) {
      final s = widget.existingSite!;
      _nameCtrl.text = s['site_name'] ?? '';
      _startDate = DateTime.tryParse(s['start_date'] ?? '');
      _endDate = DateTime.tryParse(s['end_date'] ?? '');
      final raw = s['polygon_json'];
      if (raw != null) {
        try {
          final poly = jsonDecode(raw is String ? raw : jsonEncode(raw));
          _points = (poly as List)
              .map<LatLng>(
                (e) => LatLng(
                  double.parse(e['lat'].toString()),
                  double.parse(e['lng'].toString()),
                ),
              )
              .toList();
        } catch (_) {}
      }
    }

    // Auto-start location on open
    _startLiveLocation();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _modeAnim.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _manualCtrl.dispose();
    super.dispose();
  }

  // ── Live location ─────────────────────────────────────────────────────────

  /// Start streaming live GPS — called on init and when user taps the button
  Future<void> _startLiveLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _showSnack('Location permission denied', error: true);
        setState(() => _locationLoading = false);
        return;
      }

      // Get a quick first fix to centre map immediately
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
      _updateLocation(pos);

      // Stream updates every 5 seconds
      _locationSub?.cancel();
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // update only if moved 5m
        ),
      ).listen(_updateLocation);

      setState(() {
        _locationEnabled = true;
        _locationLoading = false;
      });
    } catch (e) {
      setState(() => _locationLoading = false);
      _showSnack('Could not get location', error: true);
    }
  }

  void _updateLocation(Position pos) {
    setState(() {
      _myLocation = LatLng(pos.latitude, pos.longitude);
      _myAccuracy = pos.accuracy;
    });
  }

  /// Centre map on current location
  void _goToCurrent() async {
    if (_myLocation != null) {
      _mapCtrl.move(_myLocation!, 18);
    } else {
      await _startLiveLocation();
      if (_myLocation != null) _mapCtrl.move(_myLocation!, 18);
    }
  }

  // ── Date pickers ──────────────────────────────────────────────────────────
  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _startDate ?? DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _startDate = d);
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _endDate = d);
  }

  // ── Place search ──────────────────────────────────────────────────────────
  Future<void> _searchPlace() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}&format=json&limit=1',
      );
      final res = await http.get(
        url,
        headers: {
          'User-Agent': 'com.kavidhanglobaltech.employee_attendance_system',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          _mapCtrl.move(LatLng(lat, lon), 17);
        } else {
          _showSnack('Place not found', error: true);
        }
      }
    } catch (_) {
      _showSnack('Search failed', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Map tap ───────────────────────────────────────────────────────────────
  void _onMapTap(TapPosition _, LatLng ll) {
    if (_isManualMode) return;
    setState(() => _points.add(ll));
  }

  void _undoLast() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clearPoints() => setState(() {
    _points.clear();
    _previewReady = false;
    _manualCtrl.clear();
    _manualError = null;
  });

  // ── Manual preview ────────────────────────────────────────────────────────
  void _previewManual() {
    final raw = _manualCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _manualError = 'Enter at least 3 points');
      return;
    }
    try {
      final parts = raw
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length < 3) {
        setState(() => _manualError = 'Need at least 3 points');
        return;
      }
      final parsed = parts.map((p) {
        final coords = p.split(',');
        if (coords.length != 2) throw const FormatException('bad format');
        final lat = double.parse(coords[0].trim());
        final lng = double.parse(coords[1].trim());
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          throw const FormatException('out of range');
        }
        return LatLng(lat, lng);
      }).toList();

      setState(() {
        _points = parsed;
        _manualError = null;
        _previewReady = true;
      });

      if (parsed.isNotEmpty) {
        final lats = parsed.map((e) => e.latitude);
        final lngs = parsed.map((e) => e.longitude);
        final center = LatLng(
          lats.reduce((a, b) => a + b) / parsed.length,
          lngs.reduce((a, b) => a + b) / parsed.length,
        );
        _mapCtrl.move(center, 16);
      }
    } catch (_) {
      setState(() => _manualError = 'Invalid format. Use: lat,lng; lat,lng; …');
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startDate == null || _endDate == null) {
      _showSnack('Select both start and end dates', error: true);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showSnack('End date must be after start date', error: true);
      return;
    }
    if (_points.length < 3) {
      _showSnack('Mark at least 3 points on the map', error: true);
      return;
    }
    widget.onSave(_nameCtrl.text.trim(), _points, _startDate!, _endDate!);
    Navigator.pop(context);
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 16,
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
        backgroundColor: error ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} '
      '${const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month]} '
      '${d.year}';

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSite != null;
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW >= 720;

    return Dialog(
      backgroundColor: _card,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? screenW * 0.08 : 12,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isWide ? 720 : double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isEditing),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const _SectionLabel(
                        icon: Icons.place_rounded,
                        label: 'Site Information',
                        color: _primary,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(fontSize: 14, color: _textDark),
                        decoration: _inputDec(
                          'Site Name',
                          hint: 'e.g. Head Office – Chennai',
                          prefix: const Icon(
                            Icons.business_rounded,
                            size: 18,
                            color: _textMid,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Site name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _SectionLabel(
                        icon: Icons.date_range_rounded,
                        label: 'Active Period',
                        color: _accent,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DateTile(
                              label: 'Start Date',
                              date: _startDate,
                              icon: Icons.calendar_today_rounded,
                              color: _primary,
                              onTap: _pickStart,
                              fmtDate: _fmtDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateTile(
                              label: 'End Date',
                              date: _endDate,
                              icon: Icons.event_rounded,
                              color: _accent,
                              onTap: _pickEnd,
                              fmtDate: _fmtDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(
                        icon: Icons.map_rounded,
                        label: 'Define Polygon',
                        color: _amber,
                      ),
                      const SizedBox(height: 10),
                      _ModeToggle(
                        isManual: _isManualMode,
                        onChanged: (manual) {
                          setState(() {
                            _isManualMode = manual;
                            _previewReady = false;
                            _points.clear();
                            _manualCtrl.clear();
                            _manualError = null;
                          });
                          manual ? _modeAnim.forward() : _modeAnim.reverse();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSearchBar(),
                      const SizedBox(height: 10),
                      if (_isManualMode) ...[
                        _buildManualInput(),
                        const SizedBox(height: 10),
                      ],
                      _buildMap(isWide),
                      const SizedBox(height: 8),

                      // ── Location accuracy badge
                      if (_myLocation != null) _buildLocationBadge(),

                      const SizedBox(height: 8),
                      _buildPointsBar(),
                      const SizedBox(height: 20),
                      _buildSaveButton(isEditing),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location accuracy badge ───────────────────────────────────────────────
  Widget _buildLocationBadge() {
    final acc = _myAccuracy;
    final isGood = acc != null && acc <= 20;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isGood ? _accent.withOpacity(0.07) : _amber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGood ? _accent.withOpacity(0.3) : _amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _locationBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(color: _locationBlue.withOpacity(0.4), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            acc != null
                ? 'Your location • ±${acc.toStringAsFixed(0)}m accuracy'
                : 'Your location detected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isGood ? _accent : _amber,
            ),
          ),
          const Spacer(),
          Icon(
            isGood ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
            size: 14,
            color: isGood ? _accent : _amber,
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isEditing) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isEditing
                ? Icons.edit_location_rounded
                : Icons.add_location_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Site Location' : 'Add New Site',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                isEditing
                    ? 'Update polygon boundary & details'
                    : 'Define the geofence boundary on the map',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.close_rounded,
            color: Colors.white60,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    ),
  );

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 13, color: _textDark),
          onFieldSubmitted: (_) => _searchPlace(),
          decoration: _inputDec(
            '',
            hint: 'Search location…',
            prefix: const Icon(
              Icons.search_rounded,
              size: 18,
              color: _textLight,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),

      // ✅ My Location button — centres map + shows blue dot
      _locationLoading
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.25)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
            )
          : _IconBtn(
              icon: _locationEnabled
                  ? Icons.gps_fixed_rounded
                  : Icons.my_location_rounded,
              tooltip: 'Centre on my location',
              color: _locationEnabled ? _locationBlue : _primary,
              onTap: _goToCurrent,
            ),
      const SizedBox(width: 6),
      _IconBtn(
        icon: _searching
            ? Icons.hourglass_top_rounded
            : Icons.travel_explore_rounded,
        tooltip: 'Search',
        color: _accent,
        onTap: _searching ? null : _searchPlace,
      ),
    ],
  );

  // ── Manual input ──────────────────────────────────────────────────────────
  Widget _buildManualInput() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _amber.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _amber.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: _amber.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Enter coordinates separated by semicolons.\n'
                'Format: lat,lng; lat,lng; lat,lng',
                style: TextStyle(fontSize: 12, color: _textMid, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _manualCtrl,
        maxLines: 3,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(
          fontSize: 13,
          color: _textDark,
          fontFamily: 'monospace',
        ),
        decoration: _inputDec(
          '',
          hint: '13.0827, 80.2707; 13.0850, 80.2730; 13.0810, 80.2750',
        ),
        onChanged: (_) => setState(() => _manualError = null),
      ),
      if (_manualError != null) ...[
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 13, color: _red),
            const SizedBox(width: 5),
            Text(
              _manualError!,
              style: const TextStyle(fontSize: 12, color: _red),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _previewManual,
          style: OutlinedButton.styleFrom(
            foregroundColor: _primary,
            side: const BorderSide(color: _primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          icon: const Icon(Icons.visibility_rounded, size: 16),
          label: const Text(
            'Preview on Map',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (_previewReady) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: _accent),
              const SizedBox(width: 7),
              Text(
                '${_points.length} points parsed — polygon previewed below',
                style: const TextStyle(
                  fontSize: 12,
                  color: _accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  // ── Map ───────────────────────────────────────────────────────────────────
  Widget _buildMap(bool isWide) {
    final mapH = isWide ? 320.0 : 260.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: mapH,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter:
                    _myLocation ??
                    (_points.isNotEmpty
                        ? _points.first
                        : const LatLng(13.0827, 80.2707)),
                initialZoom: 17,
                onTap: _isManualMode ? null : _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.kavidhanglobaltech.employee_attendance_system',
                ),

                // ── Polygon layer
                if (_points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _points,
                        color: _primary.withOpacity(0.18),
                        borderColor: _primary,
                        borderStrokeWidth: 2.5,
                      ),
                    ],
                  ),

                // ── Polygon point markers
                MarkerLayer(
                  markers: List.generate(
                    _points.length,
                    (i) => Marker(
                      point: _points[i],
                      width: 44,
                      height: 44,
                      child: _isManualMode
                          ? _mapPin(i)
                          : GestureDetector(
                              onPanUpdate: (details) {
                                final sp = _mapCtrl.camera.latLngToScreenPoint(
                                  _points[i],
                                );
                                final np = CustomPoint<double>(
                                  sp.x + details.delta.dx,
                                  sp.y + details.delta.dy,
                                );
                                setState(
                                  () => _points[i] = _mapCtrl.camera
                                      .pointToLatLng(np),
                                );
                              },
                              child: _mapPin(i),
                            ),
                    ),
                  ),
                ),

                // ✅ Live location layer — Google Maps style blue dot
                if (_myLocation != null)
                  MarkerLayer(
                    markers: [
                      // Accuracy circle (pulsing ring)
                      if (_myAccuracy != null)
                        Marker(
                          point: _myLocation!,
                          width: _accuracyToPixels(_myAccuracy!),
                          height: _accuracyToPixels(_myAccuracy!),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _locationBlue.withOpacity(0.15),
                              border: Border.all(
                                color: _locationBlue.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                          ),
                        ),

                      // Blue dot
                      Marker(
                        point: _myLocation!,
                        width: 22,
                        height: 22,
                        child: _MyLocationDot(),
                      ),
                    ],
                  ),
              ],
            ),

            // Tap hint
            if (!_isManualMode && _points.isEmpty)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tap on the map to place polygon points',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            // Manual lock overlay
            if (_isManualMode && !_previewReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter coordinates above\nand tap Preview',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Point counter badge
            if (_points.isNotEmpty)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_points.length} pts',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ✅ Centre-on-me FAB (bottom right of map)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _goToCurrent,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _locationEnabled
                        ? Icons.gps_fixed_rounded
                        : Icons.my_location_rounded,
                    size: 20,
                    color: _locationEnabled ? _locationBlue : _textMid,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convert GPS accuracy (metres) to approximate pixel diameter on screen
  double _accuracyToPixels(double accuracyMetres) {
    // Rough approximation at zoom 17: ~1m ≈ 0.75px
    final px = accuracyMetres * 0.75 * 2;
    return px.clamp(30.0, 200.0);
  }

  Widget _mapPin(int index) {
    final isFirst = index == 0;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          color: isFirst ? _accent : _red,
          size: 36,
          shadows: [
            Shadow(
              color: (isFirst ? _accent : _red).withOpacity(0.5),
              blurRadius: 6,
            ),
          ],
        ),
        Positioned(
          top: 4,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isFirst ? _accent : _red,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Points bar ────────────────────────────────────────────────────────────
  Widget _buildPointsBar() {
    final canSave = _points.length >= 3;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: canSave
                  ? _accent.withOpacity(0.07)
                  : _red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: canSave
                    ? _accent.withOpacity(0.3)
                    : _red.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canSave
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: canSave ? _accent : _red,
                ),
                const SizedBox(width: 7),
                Text(
                  canSave
                      ? '${_points.length} points — polygon ready'
                      : _points.isEmpty
                      ? 'No points yet (min 3)'
                      : '${_points.length}/3 points placed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: canSave ? _accent : _red,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!_isManualMode) ...[
          _IconBtn(
            icon: Icons.undo_rounded,
            tooltip: 'Remove last point',
            color: _amber,
            onTap: _points.isNotEmpty ? _undoLast : null,
          ),
          const SizedBox(width: 6),
        ],
        _IconBtn(
          icon: Icons.delete_outline_rounded,
          tooltip: 'Clear all points',
          color: _red,
          onTap: _points.isNotEmpty ? _clearPoints : null,
        ),
      ],
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _buildSaveButton(bool isEditing) {
    final canSave =
        _points.length >= 3 && _startDate != null && _endDate != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: canSave ? _primary : _textLight,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(
          isEditing ? Icons.update_rounded : Icons.save_rounded,
          size: 18,
        ),
        label: Text(
          isEditing ? 'Update Location' : 'Confirm & Save Location',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        onPressed: canSave ? _save : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Maps-style animated blue dot widget
// ─────────────────────────────────────────────────────────────────────────────
class _MyLocationDot extends StatefulWidget {
  @override
  State<_MyLocationDot> createState() => _MyLocationDotState();
}

class _MyLocationDotState extends State<_MyLocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing ring
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _locationBlue.withOpacity(_opacity.value * 0.4),
                border: Border.all(
                  color: _locationBlue.withOpacity(_opacity.value),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // White border ring
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),

        // Blue filled dot
        Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _locationBlue,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final bool isManual;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.isManual, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        _ToggleOption(
          label: 'Tap on Map',
          icon: Icons.touch_app_rounded,
          selected: !isManual,
          onTap: () => onChanged(false),
        ),
        _ToggleOption(
          label: 'Enter Manually',
          icon: Icons.edit_rounded,
          selected: isManual,
          onTap: () => onChanged(true),
        ),
      ],
    ),
  );
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : _textMid),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : _textMid,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String Function(DateTime) fmtDate;
  const _DateTile({
    required this.label,
    required this.date,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasDate ? color.withOpacity(0.05) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasDate ? color.withOpacity(0.3) : _border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: hasDate ? color : _textLight),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: hasDate ? color.withOpacity(0.8) : _textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    hasDate ? fmtDate(date!) : 'Tap to select',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasDate ? color : _textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: hasDate ? color.withOpacity(0.5) : _textLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    ],
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(0.08) : _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? color.withOpacity(0.25) : _border,
            ),
          ),
          child: Icon(icon, size: 18, color: enabled ? color : _textLight),
        ),
      ),
    );
  }
}
