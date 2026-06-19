 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'org_notify.dart';
import '../services/notify.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  final _notifService = NotifyService.instance;
  final List<NotificationItem> _items = [];
  final ScrollController _scrollCtrl = ScrollController();

  bool _isLoading = false;
  bool _hasMore = true;
  bool _isRefresh = false;
  int _page = 1;
  int _unreadCount = 0;
  String? _error;

  String _activeFilter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('attendance', 'Attendance'),
    ('comp_off', 'Comp off'),
    ('leave', 'Leave'),
    ('general', 'General'),
  ];

  static const _limit = 20;

  // ── Filtered view ──────────────────────────────────────────────────────────

  List<NotificationItem> get _filteredItems {
    if (_activeFilter == 'all') return _items;
    if (_activeFilter == 'attendance') {
      return _items
          .where(
            (n) =>
                n.reminderType == 'before_30_min' ||
                n.reminderType == 'before_10_min',
          )
          .toList();
    }
    return _items.where((n) => n.reminderType == _activeFilter).toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data Fetching ──────────────────────────────────────────────────────────

  Future<void> _load({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _isRefresh = true;
        _page = 1;
        _hasMore = true;
        _items.clear();
        _error = null;
      }
    });

    try {
      final result = await _notifService.fetchNotificationHistory(
        page: _page,
        limit: _limit,
      );

      setState(() {
        _unreadCount = result.unreadCount;
        _items.addAll(result.items);
        _hasMore = result.items.length == _limit;
        _page++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _isRefresh = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _load();
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    await _notifService.markNotificationRead(item.id);
    setState(() {
      final idx = _items.indexWhere((n) => n.id == item.id);
      if (idx != -1) {
        _items[idx] = item.copyWith(isRead: true, readAt: DateTime.now());
      }
      if (_unreadCount > 0) _unreadCount--;
    });
  }

  Future<void> _markAllRead() async {
    await _notifService.markAllNotificationsRead();
    setState(() {
      for (int i = 0; i < _items.length; i++) {
        if (!_items[i].isRead) {
          _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
        }
      }
      _unreadCount = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Date section label ─────────────────────────────────────────────────────

  String _sectionLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDay = DateTime(dt.year, dt.month, dt.day);

    if (itemDay == today) return 'Today';
    if (itemDay == yesterday) return 'Yesterday';
    return DateFormat('d MMM').format(dt);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount unread',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3B6FE8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1, color: Color(0xFFEEEFF4)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: _filters.map((f) {
                    final isActive = _activeFilter == f.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _activeFilter = f.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF3B6FE8)
                                : const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF3B6FE8)
                                  : const Color(0xFFEEEFF4),
                            ),
                          ),
                          child: Text(
                            f.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        color: const Color(0xFF3B6FE8),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // ── Error state ──────────────────────────────────────────────────────────
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFFB0B7C3),
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _load(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B6FE8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty state (after first load, or filter has no results) ─────────────
    if (!_isLoading && _filteredItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: Color(0xFFB0B7C3),
              ),
              const SizedBox(height: 16),
              Text(
                _activeFilter == 'all'
                    ? 'No notifications yet'
                    : 'No ${_filters.firstWhere((f) => f.$1 == _activeFilter).$2.toLowerCase()} notifications',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your notifications will appear here.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ],
      );
    }

    // ── Grouped list ─────────────────────────────────────────────────────────
    final filtered = _filteredItems;
    final List<Widget> rows = [];
    String? lastLabel;

    for (final item in filtered) {
      final label = _sectionLabel(item.createdAt);
      if (label != lastLabel) {
        lastLabel = label;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.4,
              ),
            ),
          ),
        );
      }
      rows.add(_NotificationCard(item: item, onTap: () => _markRead(item)));
    }

    if (_hasMore) {
      rows.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return ListView(
      controller: _scrollCtrl,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      children: rows,
    );
  }
}

// ─── Notification Card ────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  // ── Per-type helpers ───────────────────────────────────────────────────────

  String _notifTag(String type) {
    const tags = {
      'before_30_min': '30 min before',
      'before_10_min': '10 min before',
      'comp_off': 'Comp off',
      'leave': 'Leave',
      'general': 'General',
    };
    return tags[type] ?? type;
  }

  IconData _notifIcon(String type) {
    if (type == 'comp_off') return Icons.card_giftcard_rounded;
    if (type == 'leave') return Icons.beach_access_rounded;
    if (type == 'general') return Icons.info_outline_rounded;
    return Icons.access_time_rounded;
  }

  Color _notifColor(String type) {
    if (type == 'comp_off') return const Color(0xFF0F6E56);
    if (type == 'leave') return const Color(0xFF854F0B);
    if (type == 'general') return const Color(0xFF534AB7);
    return const Color(0xFF3B6FE8);
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final delta = now.difference(dt);

    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';

    return DateFormat('d MMM, hh:mm a').format(dt);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    final timeLabel = _formatTime(item.createdAt);
    final color = _notifColor(item.reminderType);
    final icon = _notifIcon(item.reminderType);
    final tag = _notifTag(item.reminderType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: color.withOpacity(0.25), width: 1.4)
              : Border.all(color: const Color(0xFFEEEFF4)),
          boxShadow: [
            if (isUnread)
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              )
            else
              const BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUnread
                      ? color.withOpacity(0.10)
                      : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isUnread ? color : const Color(0xFFB0B7C3),
                ),
              ),

              const SizedBox(width: 12),

              // ── Content ───────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isUnread
                                  ? const Color(0xFF1A1D2E)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Body
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Footer: tag + time
                    Row(
                      children: [
                        _Chip(
                          label: tag,
                          color: isUnread ? color : const Color(0xFF9CA3AF),
                        ),
                        const Spacer(),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
