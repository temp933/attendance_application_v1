// lib/screens/comp_off_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/comp_off_service.dart';

class CompOffScreen extends StatefulWidget {
  const CompOffScreen({super.key});

  @override
  State<CompOffScreen> createState() => _CompOffScreenState();
}

class _CompOffScreenState extends State<CompOffScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;

  List<CompOffRecord> _records = [];
  CompOffSummary _summary = CompOffSummary.empty();

  late TabController _tabCtrl;
  final List<String?> _tabFilters = [null, 'earned', 'used', 'expired'];
  final List<String> _tabLabels = ['All', 'Earned', 'Used', 'Expired'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filter = _tabFilters[_tabCtrl.index];
      final result = await CompOffService.getCompOffs(status: filter);
      if (!mounted) return;
      setState(() {
        _records = result.records;
        _summary = result.summary;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(),
            _buildTabBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
  
  // ── Summary cards ─────────────────────────────────────────────────────────
  Widget _buildSummaryRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        _summaryCard(
          'Earned',
          _summary.earned,
          const Color(0xFF2E7D32),
          Icons.savings_rounded,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          'Used',
          _summary.used,
          const Color(0xFF1565C0),
          Icons.check_circle_rounded,
        ),
        const SizedBox(width: 8),
        _summaryCard(
          'Expired',
          _summary.expired,
          const Color(0xFFB71C1C),
          Icons.timer_off_rounded,
        ),
      ],
    ),
  );

  Widget _summaryCard(String label, int count, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // ── Tabs ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
      ],
    ),
    child: TabBar(
      controller: _tabCtrl,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
        ),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.grey.shade500,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
    ),
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading)
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_error != null) return _buildError();
    if (_records.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _CompOffCard(record: _records[i]),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.beach_access_rounded,
          size: 52,
          color: Colors.indigo.shade100,
        ),
        const SizedBox(height: 12),
        Text(
          'No comp-offs found',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Work on a holiday or weekly off to earn one.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CompOffCard widget
// ─────────────────────────────────────────────────────────────────────────────
class _CompOffCard extends StatelessWidget {
  final CompOffRecord record;
  const _CompOffCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record.status;

    final Color accentColor;
    final Color bgColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (status) {
      case CompOffStatus.earned:
        accentColor = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFE8F5E9);
        statusIcon = Icons.savings_rounded;
        statusLabel = 'Earned';
        break;
      case CompOffStatus.used:
        accentColor = const Color(0xFF1565C0);
        bgColor = const Color(0xFFE3F2FD);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Used';
        break;
      case CompOffStatus.expired:
        accentColor = const Color(0xFFB71C1C);
        bgColor = const Color(0xFFFFEBEE);
        statusIcon = Icons.timer_off_rounded;
        statusLabel = 'Expired';
        break;
    }

    final daysLeft = record.expiryDate != null && record.isEarned
        ? record.expiryDate!.difference(DateTime.now()).inDays
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(record.earnedDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.remarks ?? 'Compensatory Off',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.grey.shade100),

          // ── Bottom info row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              children: [
                // Earned date
                _infoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Earned',
                  value: _formatDate(record.earnedDate),
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                // Expiry date
                if (record.expiryDate != null)
                  _infoChip(
                    icon: Icons.event_rounded,
                    label: 'Expires',
                    value: _formatDate(record.expiryDate!),
                    color: record.isExpiringSoon
                        ? Colors.orange.shade700
                        : Colors.grey.shade700,
                  ),
                const Spacer(),
                // Days left / used/expired indicator
                if (daysLeft != null && daysLeft >= 0)
                  _daysLeftBadge(daysLeft)
                else if (record.isUsed)
                  _pill('Used', Colors.blue.shade700, Colors.blue.shade50)
                else if (record.isExpired)
                  _pill('Expired', Colors.red.shade700, Colors.red.shade50),
              ],
            ),
          ),

          // Expiring soon warning strip
          if (record.isExpiringSoon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 13,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Expiring in ${daysLeft} day${daysLeft == 1 ? '' : 's'} — use it before it lapses!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _daysLeftBadge(int days) {
    final Color bg = days <= 3
        ? Colors.red.shade50
        : days <= 7
        ? Colors.orange.shade50
        : Colors.green.shade50;
    final Color fg = days <= 3
        ? Colors.red.shade700
        : days <= 7
        ? Colors.orange.shade700
        : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${days}d left',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _pill(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
    ),
  );

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
}
