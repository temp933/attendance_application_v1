import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

// ─── Event model ──────────────────────────────────────────────────────────────

class QueuedEvent {
  final int index; // monotonic counter, used as sort key
  final String type; // "mark_in" | "mark_out" | "end_day"
  final int employeeId;
  final int? siteId; // required for mark_in only
  final String timestamp; // ISO-8601, set at event creation time

  const QueuedEvent({
    required this.index,
    required this.type,
    required this.employeeId,
    this.siteId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'type': type,
    'employee_id': employeeId,
    if (siteId != null) 'site_id': siteId,
    'timestamp': timestamp,
  };

  factory QueuedEvent.fromJson(Map<String, dynamic> j) => QueuedEvent(
    index: j['index'] as int,
    type: j['type'] as String,
    employeeId: j['employee_id'] as int,
    siteId: j['site_id'] as int?,
    timestamp: j['timestamp'] as String,
  );

  /// Shape expected by /attendance/batch-sync
  Map<String, dynamic> toSyncPayload() => {
    'type': type,
    'employee_id': employeeId,
    if (siteId != null) 'site_id': siteId,
    'timestamp': timestamp,
  };
}

// ─── OfflineQueue ─────────────────────────────────────────────────────────────

class OfflineQueue {
  OfflineQueue._();

  static const String _kQueue = 'offline_queue_v1_events';
  static const String _kCounter = 'offline_queue_v1_counter';

  // ── Enqueue ──────────────────────────────────────────────────────────────────

  /// Add an event. Returns immediately — does NOT hit the network.
  static Future<void> enqueue({
    required String type,
    required int employeeId,
    int? siteId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = (prefs.getInt(_kCounter) ?? 0) + 1;
    await prefs.setInt(_kCounter, idx);

    final event = QueuedEvent(
      index: idx,
      type: type,
      employeeId: employeeId,
      siteId: siteId,
      timestamp: DateTime.now().toIso8601String(),
    );

    final events = await _loadAll(prefs);
    events.add(event);
    await _saveAll(prefs, events);
    print('[OfflineQueue] ✚ Enqueued $type (idx=$idx, total=${events.length})');
  }

  // ── Drain ─────────────────────────────────────────────────────────────────────

  /// Send all pending events to the server in one batch call.
  /// Returns true if the queue was fully flushed (or was already empty).
  static Future<bool> drain() async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _loadAll(prefs);
    if (events.isEmpty) return true;

    print('[OfflineQueue] ▶ Draining ${events.length} event(s)…');

    try {
      final payload = events.map((e) => e.toSyncPayload()).toList();
      final result = await ApiService.batchSync(payload);

      // Server returned success — clear all flushed events.
      final processed = result['processed'] as List? ?? [];
      final failedIndices = <int>{};

      for (int i = 0; i < processed.length; i++) {
        final r = processed[i] as Map<String, dynamic>;
        final status = r['status'] as String? ?? '';
        // "error" means the server couldn't handle it — keep those events.
        if (status == 'error') failedIndices.add(i);
      }

      if (failedIndices.isEmpty) {
        // All processed — wipe the queue.
        await _saveAll(prefs, []);
        print('[OfflineQueue] ✅ Queue fully drained.');
        return true;
      } else {
        // Keep only the failed events.
        final remaining = <QueuedEvent>[];
        for (int i = 0; i < events.length; i++) {
          if (failedIndices.contains(i)) remaining.add(events[i]);
        }
        await _saveAll(prefs, remaining);
        print(
          '[OfflineQueue] ⚠️  ${remaining.length} event(s) failed — will retry.',
        );
        return false;
      }
    } catch (e) {
      print('[OfflineQueue] ✗ Drain failed (offline?): $e');
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static Future<List<QueuedEvent>> _loadAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_kQueue);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final events = list
          .map((j) => QueuedEvent.fromJson(j as Map<String, dynamic>))
          .toList();
      // Sort by index so events are replayed in order.
      events.sort((a, b) => a.index.compareTo(b.index));
      return events;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(
    SharedPreferences prefs,
    List<QueuedEvent> events,
  ) async {
    await prefs.setString(
      _kQueue,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  /// How many events are waiting to be synced.
  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _loadAll(prefs)).length;
  }

  /// Clear everything (use only on logout / day-reset).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueue);
    await prefs.remove(_kCounter);
  }
}
