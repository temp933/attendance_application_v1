import 'dart:convert';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';

// ─── RESULT ───────────────────────────────────────────────────────────────────

class SiteCheckResult {
  final bool inside;
  final int? siteId;
  final String? siteName;
  const SiteCheckResult({required this.inside, this.siteId, this.siteName});
  static const outside = SiteCheckResult(inside: false);
}

// ─── INTERNAL ENTRY ───────────────────────────────────────────────────────────

class _SiteEntry {
  final int id;
  final String name;
  final List<Map<String, double>> polygon;
  const _SiteEntry(this.id, this.name, this.polygon);
}

 
class SiteCache {
  SiteCache._();

  static final List<_SiteEntry> _sites = [];
  static Database? _db;

  static int get siteCount => _sites.length;

  // ── DB ──────────────────────────────────────────────────────────────────────

  static Future<Database> _openDb() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'site_cache.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE IF NOT EXISTS sites (
          id           INTEGER PRIMARY KEY,
          site_name    TEXT    NOT NULL,
          polygon_json TEXT    NOT NULL,
          start_date   TEXT    NOT NULL DEFAULT '',
          end_date     TEXT    NOT NULL DEFAULT ''
        )
      '''),
    );
    return _db!;
  }

  // ── INIT (called once when employee presses START) ───────────────────────────
  //
  // Network-first: fetch fresh list → persist to SQLite → load memory.
  // Network-fail : load whatever is already in SQLite (cached from a prior session).

  static Future<void> init() async {
    final db = await _openDb();
    bool fromServer = false;

    try {
      final raw = await ApiService.getSites();
      await db.delete('sites');
      final batch = db.batch();
      for (final site in raw) {
        final polygonRaw = site['polygon_json'];
        batch.insert('sites', {
          'id': site['id'] as int,
          'site_name': (site['site_name'] as String?) ?? '',
          'polygon_json': polygonRaw is String
              ? polygonRaw
              : jsonEncode(polygonRaw),
          'start_date': (site['start_date'] as String?) ?? '',
          'end_date': (site['end_date'] as String?) ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      fromServer = true;
      print('[SiteCache] Fetched ${raw.length} site(s) from server → SQLite');
    } catch (e) {
      print('[SiteCache] Server unavailable, falling back to local cache: $e');
    }

    await _loadMemory(db);
    print(
      '[SiteCache] ${_sites.length} active site(s) in memory '
      '(${fromServer ? "server" : "local"})',
    );
  }

  // ── SYNC (background periodic refresh, ~every 30 min) ───────────────────────

  static Future<void> sync() async {
    try {
      final raw = await ApiService.getSites();
      final db = await _openDb();
      await db.delete('sites');
      final batch = db.batch();
      for (final site in raw) {
        final polygonRaw = site['polygon_json'];
        batch.insert('sites', {
          'id': site['id'] as int,
          'site_name': (site['site_name'] as String?) ?? '',
          'polygon_json': polygonRaw is String
              ? polygonRaw
              : jsonEncode(polygonRaw),
          'start_date': (site['start_date'] as String?) ?? '',
          'end_date': (site['end_date'] as String?) ?? '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      await _loadMemory(db);
      print('[SiteCache] Synced → ${_sites.length} active site(s)');
    } catch (e) {
      print('[SiteCache] Sync skipped (non-fatal): $e');
    }
  }

  // ── CLEAR (called when employee presses END) ─────────────────────────────────
  //
  // Wipes all site rows from SQLite and clears memory.
  // The next START will re-fetch a fresh list from the server.

  static Future<void> clear() async {
    _sites.clear();
    try {
      final db = await _openDb();
      final deleted = await db.delete('sites');
      print('[SiteCache] Cleared $deleted site row(s) from SQLite');
    } catch (e) {
      print('[SiteCache] Clear error (non-fatal): $e');
    }
  }

  // ── DISPOSE (free memory only; SQLite untouched) ─────────────────────────────

  static void dispose() {
    _sites.clear();
  }

  // ── CHECK LOCATION ───────────────────────────────────────────────────────────
  //
  // Called on every GPS update. Pure in-memory: zero I/O.

  static SiteCheckResult checkLocation(double lat, double lng) {
    for (final site in _sites) {
      if (_isInsideSite(lat, lng, site.polygon)) {
        return SiteCheckResult(
          inside: true,
          siteId: site.id,
          siteName: site.name,
        );
      }
    }
    return SiteCheckResult.outside;
  }

  // ── INTERNAL: load active sites from SQLite → memory ─────────────────────────

  static Future<void> _loadMemory(Database db) async {
    _sites.clear();
    final rows = await db.query('sites');
    final today = _todayStr();

    for (final row in rows) {
      final startDate = (row['start_date'] as String?) ?? '';
      final endDate = (row['end_date'] as String?) ?? '';

      // Skip sites not active today
      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        if (today.compareTo(startDate) < 0 || today.compareTo(endDate) > 0) {
          continue;
        }
      }

      try {
        final raw = jsonDecode(row['polygon_json'] as String) as List<dynamic>;
        final polygon = raw
            .map<Map<String, double>>(
              (pt) => {
                'lat': (pt['lat'] as num).toDouble(),
                'lng': (pt['lng'] as num).toDouble(),
              },
            )
            .toList();
        _sites.add(
          _SiteEntry(row['id'] as int, row['site_name'] as String, polygon),
        );
      } catch (e) {
        print('[SiteCache] Parse error for "${row['site_name']}": $e');
      }
    }
  }

  // ── GEOMETRY ─────────────────────────────────────────────────────────────────

  static bool _isInsideSite(
    double lat,
    double lng,
    List<Map<String, double>> polygon,
  ) {
    return _pointInPolygon(lat, lng, polygon) ||
        _isNearPolygon(lat, lng, polygon, bufferMeters: 35);
  }

  static bool _pointInPolygon(
    double lat,
    double lng,
    List<Map<String, double>> poly,
  ) {
    final pts = List<Map<String, double>>.from(poly);
    if (pts.isEmpty) return false;
    if (pts.first['lat'] != pts.last['lat'] ||
        pts.first['lng'] != pts.last['lng']) {
      pts.add(Map<String, double>.from(pts.first));
    }
    int crossings = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final p1Lng = pts[i]['lng']!;
      final p2Lng = pts[i + 1]['lng']!;
      if ((p1Lng > lng) != (p2Lng > lng)) {
        final xAtLng =
            ((pts[i + 1]['lat']! - pts[i]['lat']!) * (lng - p1Lng)) /
                (p2Lng - p1Lng) +
            pts[i]['lat']!;
        if (lat < xAtLng) crossings++;
      }
    }
    return crossings % 2 == 1;
  }

  static bool _isNearPolygon(
    double lat,
    double lng,
    List<Map<String, double>> polygon, {
    double bufferMeters = 35,
  }) {
    final pts = List<Map<String, double>>.from(polygon);
    if (pts.isEmpty) return false;
    if (pts.first['lat'] != pts.last['lat'] ||
        pts.first['lng'] != pts.last['lng']) {
      pts.add(Map<String, double>.from(pts.first));
    }
    for (int i = 0; i < pts.length - 1; i++) {
      if (_dist(lat, lng, pts[i]['lat']!, pts[i]['lng']!) <= bufferMeters) {
        return true;
      }
      if (_distToSegment(lat, lng, pts[i], pts[i + 1]) <= bufferMeters) {
        return true;
      }
    }
    return false;
  }

  static double _distToSegment(
    double lat,
    double lng,
    Map<String, double> p1,
    Map<String, double> p2,
  ) {
    final dx = p2['lat']! - p1['lat']!;
    final dy = p2['lng']! - p1['lng']!;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0.0) return _dist(lat, lng, p1['lat']!, p1['lng']!);
    final t = ((lat - p1['lat']!) * dx + (lng - p1['lng']!) * dy) / lenSq;
    final tC = t.clamp(0.0, 1.0);
    return _dist(lat, lng, p1['lat']! + tC * dx, p1['lng']! + tC * dy);
  }

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return r *
        2 *
        math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}'
        '-${n.day.toString().padLeft(2, '0')}';
  }
}
