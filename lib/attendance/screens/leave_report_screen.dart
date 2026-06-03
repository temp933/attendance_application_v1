// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

// // ─── Models ───────────────────────────────────────────────────────────────────

// class DailyRecord {
//   final String date;
//   final String status;
//   final String? checkIn;
//   final String? checkOut;
//   final String? totalHours;
//   final bool isLate;
//   final int lateMinutes;
//   final bool isHalfday;
//   final int overtimeMinutes;
//   final String? workLocation;
//   final String? leaveName;

//   DailyRecord.fromJson(Map<String, dynamic> j)
//       : date = j['date'] ?? '',
//         status = j['status'] ?? '',
//         checkIn = j['check_in_time'],
//         checkOut = j['check_out_time'],
//         totalHours = j['total_hours']?.toString(),
//         isLate = j['is_late'] ?? false,
//         lateMinutes = j['late_minutes'] ?? 0,
//         isHalfday = j['is_halfday'] ?? false,
//         overtimeMinutes = j['overtime_minutes'] ?? 0,
//         workLocation = j['work_location'],
//         leaveName = j['leave_name'];
// }

// class EmployeeRangeSummary {
//   final int totalDays;
//   final int workingDays;
//   final int holidays;
//   final int weekoffs;
//   final int present;
//   final int absent;
//   final int onLeave;
//   final int late;
//   final int halfday;
//   final int overtimeDays;
//   final int totalOvertimeMinutes;

//   EmployeeRangeSummary.fromJson(Map<String, dynamic> j)
//       : totalDays = j['total_days'] ?? 0,
//         workingDays = j['working_days'] ?? 0,
//         holidays = j['holidays'] ?? 0,
//         weekoffs = j['weekoffs'] ?? 0,
//         present = j['present'] ?? 0,
//         absent = j['absent'] ?? 0,
//         onLeave = j['on_leave'] ?? 0,
//         late = j['late'] ?? 0,
//         halfday = j['halfday'] ?? 0,
//         overtimeDays = j['overtime_days'] ?? 0,
//         totalOvertimeMinutes = j['total_overtime_minutes'] ?? 0;
// }

// class EmployeeReport {
//   final String empId;
//   final String employeeCode;
//   final String employeeName;
//   final String department;
//   final String designation;
//   final EmployeeRangeSummary summary;
//   final List<DailyRecord> daily;

//   EmployeeReport.fromJson(Map<String, dynamic> j)
//       : empId = j['emp_id']?.toString() ?? '',
//         employeeCode = j['employee_code'] ?? '',
//         employeeName = j['employee_name'] ?? '',
//         department = j['department'] ?? '-',
//         designation = j['designation'] ?? '-',
//         summary = EmployeeRangeSummary.fromJson(j['summary'] ?? {}),
//         daily = (j['daily'] as List? ?? [])
//             .map((d) => DailyRecord.fromJson(d))
//             .toList();
// }

// // ─── Service ──────────────────────────────────────────────────────────────────

// class ReportService {
//   static const String baseUrl = 'https://your-api.com/api/report';
//   static const String authToken = 'YOUR_TOKEN_HERE';

//   static Future<List<EmployeeReport>> fetchRangeReport({
//     required String start,
//     required String end,
//     String? empId,
//     String? departmentId,
//   }) async {
//     final params = {
//       'start': start,
//       'end': end,
//       if (empId != null) 'emp_id': empId,
//       if (departmentId != null) 'department_id': departmentId,
//     };
//     final uri = Uri.parse('$baseUrl/range').replace(queryParameters: params);
//     final res = await http.get(uri, headers: {
//       'Authorization': 'Bearer $authToken',
//       'Content-Type': 'application/json',
//     });
//     if (res.statusCode != 200) throw Exception('Failed to fetch report');
//     final body = jsonDecode(res.body);
//     if (body['ok'] != true) throw Exception(body['message']);
//     return (body['data'] as List)
//         .map((e) => EmployeeReport.fromJson(e))
//         .toList();
//   }
// }

// // ─── CSV Export ───────────────────────────────────────────────────────────────

// class CsvExporter {
//   static String buildCsv(List<EmployeeReport> reports) {
//     final sb = StringBuffer();
//     sb.writeln(
//         'Employee Code,Employee Name,Department,Designation,Date,Status,Check In,Check Out,Total Hours,Late,Late Minutes,Half Day,Overtime Minutes,Work Location,Leave');
//     for (final emp in reports) {
//       for (final d in emp.daily) {
//         sb.writeln([
//           emp.employeeCode,
//           emp.employeeName,
//           emp.department,
//           emp.designation,
//           d.date,
//           d.status,
//           d.checkIn ?? '',
//           d.checkOut ?? '',
//           d.totalHours ?? '',
//           d.isLate ? 'Yes' : 'No',
//           d.lateMinutes,
//           d.isHalfday ? 'Yes' : 'No',
//           d.overtimeMinutes,
//           d.workLocation ?? '',
//           d.leaveName ?? '',
//         ].map((v) => '"$v"').join(','));
//       }
//     }
//     return sb.toString();
//   }

//   static Future<String> saveAndShare(
//       String csvContent, String fileName) async {
//     final dir = await getTemporaryDirectory();
//     final file = File('${dir.path}/$fileName');
//     await file.writeAsString(csvContent);
//     await Share.shareXFiles([XFile(file.path)],
//         subject: 'Attendance Report');
//     return file.path;
//   }
// }

// // ─── Main Screen ──────────────────────────────────────────────────────────────

// class AttendanceReportScreen extends StatefulWidget {
//   const AttendanceReportScreen({super.key});

//   @override
//   State<AttendanceReportScreen> createState() =>
//       _AttendanceReportScreenState();
// }

// class _AttendanceReportScreenState extends State<AttendanceReportScreen>
//     with SingleTickerProviderStateMixin {
//   DateTimeRange? _selectedRange;
//   String? _empId;
//   String? _departmentId;
//   bool _loading = false;
//   String? _error;
//   List<EmployeeReport> _reports = [];
//   late TabController _tabController;

//   final _empIdCtrl = TextEditingController();
//   final _deptIdCtrl = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     final now = DateTime.now();
//     _selectedRange = DateTimeRange(
//       start: DateTime(now.year, now.month, 1),
//       end: now,
//     );
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _empIdCtrl.dispose();
//     _deptIdCtrl.dispose();
//     super.dispose();
//   }

//   String _fmt(DateTime dt) =>
//       '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

//   Future<void> _pickRange() async {
//     final picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       initialDateRange: _selectedRange,
//       builder: (ctx, child) => Theme(
//         data: Theme.of(ctx).copyWith(
//           colorScheme: ColorScheme.light(
//             primary: const Color(0xFF3B5BDB),
//             onPrimary: Colors.white,
//             surface: Colors.white,
//           ),
//         ),
//         child: child!,
//       ),
//     );
//     if (picked != null) setState(() => _selectedRange = picked);
//   }

//   Future<void> _fetchReport() async {
//     if (_selectedRange == null) return;
//     setState(() {
//       _loading = true;
//       _error = null;
//       _reports = [];
//     });
//     try {
//       final data = await ReportService.fetchRangeReport(
//         start: _fmt(_selectedRange!.start),
//         end: _fmt(_selectedRange!.end),
//         empId: _empId?.isNotEmpty == true ? _empId : null,
//         departmentId: _departmentId?.isNotEmpty == true ? _departmentId : null,
//       );
//       setState(() => _reports = data);
//     } catch (e) {
//       setState(() => _error = e.toString());
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _downloadCsv() async {
//     if (_reports.isEmpty) return;
//     try {
//       final csv = CsvExporter.buildCsv(_reports);
//       final fileName =
//           'attendance_${_fmt(_selectedRange!.start)}_${_fmt(_selectedRange!.end)}.csv';
//       await CsvExporter.saveAndShare(csv, fileName);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Export failed: $e')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F6FA),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF3B5BDB),
//         foregroundColor: Colors.white,
//         elevation: 0,
//         title: const Text('Attendance Report',
//             style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
//         actions: [
//           if (_reports.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.download_rounded),
//               tooltip: 'Download CSV',
//               onPressed: _downloadCsv,
//             ),
//         ],
//         bottom: TabBar(
//           controller: _tabController,
//           indicatorColor: Colors.white,
//           indicatorWeight: 3,
//           labelColor: Colors.white,
//           unselectedLabelColor: Colors.white60,
//           tabs: const [
//             Tab(text: 'Filters'),
//             Tab(text: 'Results'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildFiltersTab(),
//           _buildResultsTab(),
//         ],
//       ),
//     );
//   }

//   // ── Filters Tab ──────────────────────────────────────────────────────────

//   Widget _buildFiltersTab() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _sectionLabel('Date Range'),
//           const SizedBox(height: 8),
//           _dateRangeTile(),
//           const SizedBox(height: 20),
//           _sectionLabel('Filters (optional)'),
//           const SizedBox(height: 8),
//           _inputCard(
//             controller: _empIdCtrl,
//             label: 'Employee ID',
//             icon: Icons.badge_outlined,
//             onChanged: (v) => _empId = v,
//           ),
//           const SizedBox(height: 12),
//           _inputCard(
//             controller: _deptIdCtrl,
//             label: 'Department ID',
//             icon: Icons.business_outlined,
//             onChanged: (v) => _departmentId = v,
//           ),
//           const SizedBox(height: 32),
//           SizedBox(
//             width: double.infinity,
//             height: 52,
//             child: ElevatedButton.icon(
//               onPressed: _loading
//                   ? null
//                   : () {
//                       _fetchReport();
//                       _tabController.animateTo(1);
//                     },
//               icon: _loading
//                   ? const SizedBox(
//                       width: 18,
//                       height: 18,
//                       child: CircularProgressIndicator(
//                           strokeWidth: 2, color: Colors.white),
//                     )
//                   : const Icon(Icons.search_rounded),
//               label:
//                   Text(_loading ? 'Fetching...' : 'Generate Report',
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.w600)),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF3B5BDB),
//                 foregroundColor: Colors.white,
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12)),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _dateRangeTile() {
//     final start = _selectedRange != null
//         ? _fmt(_selectedRange!.start)
//         : 'Start date';
//     final end = _selectedRange != null
//         ? _fmt(_selectedRange!.end)
//         : 'End date';

//     return GestureDetector(
//       onTap: _pickRange,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: const Color(0xFFE2E8F0)),
//         ),
//         child: Row(
//           children: [
//             const Icon(Icons.calendar_today_outlined,
//                 color: Color(0xFF3B5BDB), size: 22),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text('Selected Range',
//                       style: TextStyle(
//                           fontSize: 12, color: Color(0xFF718096))),
//                   const SizedBox(height: 2),
//                   Text('$start  →  $end',
//                       style: const TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.w600,
//                           color: Color(0xFF1A202C))),
//                 ],
//               ),
//             ),
//             const Icon(Icons.chevron_right_rounded,
//                 color: Color(0xFF718096)),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _inputCard({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     required ValueChanged<String> onChanged,
//   }) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: TextField(
//         controller: controller,
//         onChanged: onChanged,
//         decoration: InputDecoration(
//           icon: Icon(icon, color: const Color(0xFF3B5BDB), size: 20),
//           labelText: label,
//           labelStyle: const TextStyle(color: Color(0xFF718096)),
//           border: InputBorder.none,
//         ),
//       ),
//     );
//   }

//   Widget _sectionLabel(String text) => Text(
//         text,
//         style: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF718096),
//             letterSpacing: 0.5),
//       );

//   // ── Results Tab ──────────────────────────────────────────────────────────

//   Widget _buildResultsTab() {
//     if (_loading) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(color: Color(0xFF3B5BDB)),
//             SizedBox(height: 16),
//             Text('Fetching report...',
//                 style: TextStyle(color: Color(0xFF718096))),
//           ],
//         ),
//       );
//     }

//     if (_error != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline_rounded,
//                   color: Color(0xFFE53E3E), size: 48),
//               const SizedBox(height: 12),
//               Text(_error!,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(color: Color(0xFFE53E3E))),
//               const SizedBox(height: 16),
//               TextButton(
//                 onPressed: _fetchReport,
//                 child: const Text('Retry'),
//               )
//             ],
//           ),
//         ),
//       );
//     }

//     if (_reports.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.insert_chart_outlined_rounded,
//                 size: 64, color: Colors.grey[300]),
//             const SizedBox(height: 16),
//             const Text('No data yet',
//                 style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF718096))),
//             const SizedBox(height: 8),
//             const Text('Set filters and tap Generate Report',
//                 style:
//                     TextStyle(fontSize: 14, color: Color(0xFFA0AEC0))),
//           ],
//         ),
//       );
//     }

//     return Column(
//       children: [
//         _buildOverallBanner(),
//         Expanded(
//           child: ListView.separated(
//             padding:
//                 const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             itemCount: _reports.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 12),
//             itemBuilder: (ctx, i) => _EmployeeReportCard(
//               report: _reports[i],
//             ),
//           ),
//         ),
//         _buildDownloadBar(),
//       ],
//     );
//   }

//   Widget _buildOverallBanner() {
//     final total = _reports.length;
//     final totalPresent =
//         _reports.fold(0, (s, r) => s + r.summary.present);
//     final totalAbsent = _reports.fold(0, (s, r) => s + r.summary.absent);
//     final totalLeave = _reports.fold(0, (s, r) => s + r.summary.onLeave);

//     return Container(
//       color: const Color(0xFF3B5BDB),
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _bannerStat('Employees', '$total'),
//           _bannerDivider(),
//           _bannerStat('Present', '$totalPresent'),
//           _bannerDivider(),
//           _bannerStat('Absent', '$totalAbsent'),
//           _bannerDivider(),
//           _bannerStat('On Leave', '$totalLeave'),
//         ],
//       ),
//     );
//   }

//   Widget _bannerStat(String label, String value) => Column(
//         children: [
//           Text(value,
//               style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 20,
//                   fontWeight: FontWeight.w700)),
//           Text(label,
//               style: const TextStyle(
//                   color: Colors.white70, fontSize: 11)),
//         ],
//       );

//   Widget _bannerDivider() => Container(
//         height: 30,
//         width: 1,
//         color: Colors.white24,
//       );

//   Widget _buildDownloadBar() {
//     return Container(
//       padding:
//           const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: ElevatedButton.icon(
//               onPressed: _downloadCsv,
//               icon: const Icon(Icons.download_rounded, size: 18),
//               label: const Text('Download CSV',
//                   style: TextStyle(fontWeight: FontWeight.w600)),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF3B5BDB),
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10)),
//                 elevation: 0,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─── Employee Report Card ─────────────────────────────────────────────────────

// class _EmployeeReportCard extends StatefulWidget {
//   final EmployeeReport report;
//   const _EmployeeReportCard({required this.report});

//   @override
//   State<_EmployeeReportCard> createState() =>
//       _EmployeeReportCardState();
// }

// class _EmployeeReportCardState extends State<_EmployeeReportCard> {
//   bool _expanded = false;

//   Color _statusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'present':
//         return const Color(0xFF38A169);
//       case 'absent':
//         return const Color(0xFFE53E3E);
//       case 'on leave':
//       case 'half day leave':
//         return const Color(0xFFDD6B20);
//       case 'holiday':
//         return const Color(0xFF3B5BDB);
//       case 'week off':
//         return const Color(0xFF718096);
//       default:
//         return const Color(0xFF718096);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final r = widget.report;
//     final s = r.summary;

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Column(
//         children: [
//           // ── Header ──
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 22,
//                       backgroundColor: const Color(0xFFEBF4FF),
//                       child: Text(
//                         r.employeeName.isNotEmpty
//                             ? r.employeeName[0].toUpperCase()
//                             : '?',
//                         style: const TextStyle(
//                             color: Color(0xFF3B5BDB),
//                             fontWeight: FontWeight.w700,
//                             fontSize: 17),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(r.employeeName,
//                               style: const TextStyle(
//                                   fontWeight: FontWeight.w700,
//                                   fontSize: 15,
//                                   color: Color(0xFF1A202C))),
//                           Text(
//                               '${r.employeeCode} • ${r.department}',
//                               style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Color(0xFF718096))),
//                         ],
//                       ),
//                     ),
//                     GestureDetector(
//                       onTap: () =>
//                           setState(() => _expanded = !_expanded),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 6),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFF7FAFC),
//                           borderRadius: BorderRadius.circular(8),
//                           border:
//                               Border.all(color: const Color(0xFFE2E8F0)),
//                         ),
//                         child: Row(
//                           children: [
//                             Text(
//                                 _expanded
//                                     ? 'Hide'
//                                     : 'Details',
//                                 style: const TextStyle(
//                                     fontSize: 12,
//                                     color: Color(0xFF3B5BDB),
//                                     fontWeight: FontWeight.w600)),
//                             const SizedBox(width: 4),
//                             Icon(
//                                 _expanded
//                                     ? Icons.keyboard_arrow_up_rounded
//                                     : Icons.keyboard_arrow_down_rounded,
//                                 size: 16,
//                                 color: const Color(0xFF3B5BDB)),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 14),
//                 // ── Summary chips ──
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: [
//                     _chip('${s.present}', 'Present',
//                         const Color(0xFFE6FFFA),
//                         const Color(0xFF2C7A7B)),
//                     _chip('${s.absent}', 'Absent',
//                         const Color(0xFFFFF5F5),
//                         const Color(0xFFC53030)),
//                     _chip('${s.onLeave}', 'Leave',
//                         const Color(0xFFFEEBC8),
//                         const Color(0xFFC05621)),
//                     _chip('${s.late}', 'Late',
//                         const Color(0xFFEBF8FF),
//                         const Color(0xFF2C5282)),
//                     _chip('${s.holidays}', 'Holiday',
//                         const Color(0xFFEBF4FF),
//                         const Color(0xFF3B5BDB)),
//                     _chip('${s.weekoffs}', 'Weekoff',
//                         const Color(0xFFEDF2F7),
//                         const Color(0xFF4A5568)),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           // ── Daily breakdown ──
//           if (_expanded) ...[
//             const Divider(height: 1, color: Color(0xFFEDF2F7)),
//             ListView.separated(
//               physics: const NeverScrollableScrollPhysics(),
//               shrinkWrap: true,
//               itemCount: r.daily.length,
//               separatorBuilder: (_, __) => const Divider(
//                   height: 1, indent: 16, color: Color(0xFFEDF2F7)),
//               itemBuilder: (ctx, i) {
//                 final d = r.daily[i];
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 16, vertical: 10),
//                   child: Row(
//                     children: [
//                       SizedBox(
//                         width: 90,
//                         child: Text(d.date,
//                             style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Color(0xFF718096))),
//                       ),
//                       Container(
//                         width: 8,
//                         height: 8,
//                         decoration: BoxDecoration(
//                           color: _statusColor(d.status),
//                           shape: BoxShape.circle,
//                         ),
//                       ),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(d.status,
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.w500,
//                                 color: _statusColor(d.status))),
//                       ),
//                       if (d.checkIn != null)
//                         Text(
//                             '${d.checkIn!.substring(0, 5)} – ${d.checkOut?.substring(0, 5) ?? '--'}',
//                             style: const TextStyle(
//                                 fontSize: 12,
//                                 color: Color(0xFF718096))),
//                       if (d.isLate)
//                         Container(
//                           margin: const EdgeInsets.only(left: 6),
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFFFF3CD),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: Text('+${d.lateMinutes}m',
//                               style: const TextStyle(
//                                   fontSize: 10,
//                                   color: Color(0xFF7D5A00),
//                                   fontWeight: FontWeight.w600)),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _chip(
//       String value, String label, Color bg, Color fg) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//       decoration: BoxDecoration(
//           color: bg, borderRadius: BorderRadius.circular(8)),
//       child: RichText(
//         text: TextSpan(
//           children: [
//             TextSpan(
//                 text: '$value ',
//                 style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w700,
//                     color: fg)),
//             TextSpan(
//                 text: label,
//                 style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w500,
//                     color: fg.withOpacity(0.75))),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─── Entry point ──────────────────────────────────────────────────────────────

// void main() => runApp(const _App());

// class _App extends StatelessWidget {
//   const _App();
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Attendance Reports',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         fontFamily: 'Inter',
//         colorScheme:
//             ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB)),
//       ),
//       home: const AttendanceReportScreen(),
//     );
//   }
// }
