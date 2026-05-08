import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:file_saver/file_saver.dart';

import '../providers/api_client.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);
const Color _purple = Color(0xFF7C3AED);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);

// MODELS
class _LeaveRecord {
  final int leaveId;
  final int empId;
  final String employeeName;
  final String leaveType;
  final DateTime leaveStartDate;
  final DateTime leaveEndDate;
  final int numberOfDays;
  final String recommendedBy;
  final String approvedBy;
  final String status;
  final String employee_reason;
  final String cancelReason;
  final String rejectionReason;
  final String createdAt;
  final String updatedAt;

  const _LeaveRecord({
    required this.leaveId,
    required this.empId,
    required this.employeeName,
    required this.leaveType,
    required this.leaveStartDate,
    required this.leaveEndDate,
    required this.numberOfDays,
    required this.recommendedBy,
    required this.approvedBy,
    required this.status,
    required this.employee_reason,
    required this.cancelReason,
    required this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _LeaveRecord.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime(2000);
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime(2000);
      }
    }

    return _LeaveRecord(
      leaveId: j['leave_id'] is num
          ? (j['leave_id'] as num).toInt()
          : int.tryParse(j['leave_id']?.toString() ?? '0') ?? 0,
      empId: j['emp_id'] is num
          ? (j['emp_id'] as num).toInt()
          : int.tryParse(j['emp_id']?.toString() ?? '0') ?? 0,
      employeeName: j['employee_name']?.toString().trim() ?? '—',

      leaveType: j['leave_type']?.toString() ?? '—',
      leaveStartDate: parseDate(j['leave_start_date'] ?? j['from_date']),
      leaveEndDate: parseDate(j['leave_end_date'] ?? j['to_date']),
      numberOfDays: j['total_days'] is num
          ? (j['total_days'] as num).toInt()
          : (double.tryParse(j['total_days']?.toString() ?? '0') ?? 0.0)
                .toInt(),
      recommendedBy:
          j['recommended_by_name']?.toString() ??
          j['recommended_by']?.toString() ??
          '—',

      approvedBy:
          j['approved_by_name']?.toString() ??
          j['approved_by']?.toString() ??
          '—',
      status: j['status']?.toString() ?? '—',
      employee_reason: j['reason']?.toString() ?? '—',
      cancelReason: j['cancel_reason']?.toString() ?? '—',
      rejectionReason: j['rejection_reason']?.toString() ?? '—',
      createdAt: j['created_at']?.toString() ?? '—',
      updatedAt: j['created_at']?.toString() ?? '—',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'Approved':
        return 'Approved';
      case 'Pending_TL':
        return 'Pending TL';
      case 'Pending_Manager':
        return 'Pending Manager';
      case 'Not_Recommended_By_TL':
        return 'Not Recommended';
      case 'Rejected_By_Manager':
        return 'Rejected';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'Approved':
        return _accent;
      case 'Pending_TL':
        return _primary;
      case 'Pending_Manager':
        return _purple;
      case 'Not_Recommended_By_TL':
      case 'Rejected_By_Manager':
        return _red;
      case 'Cancelled':
        return _amber;
      default:
        return _textMid;
    }
  }
}

// SERVICE
class _LeaveReportService {
  static Future<List<_LeaveRecord>> fetchAllHistory() async {
    final res = await ApiClient.get('/leaves/all-history');
    if (res.statusCode != 200) {
      throw Exception('Server error ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Unknown error');
    }
    final List rows = body['data'] ?? [];
    return rows
        .map((r) => _LeaveRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static List<_LeaveRecord> filterByRange(
    List<_LeaveRecord> all,
    DateTime from,
    DateTime to,
  ) {
    final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return all.where((record) {
      final leaveStart = DateTime(
        record.leaveStartDate.year,
        record.leaveStartDate.month,
        record.leaveStartDate.day,
      );
      final leaveEnd = DateTime(
        record.leaveEndDate.year,
        record.leaveEndDate.month,
        record.leaveEndDate.day,
        23,
        59,
        59,
      );

      return !leaveStart.isAfter(toEnd) && !leaveEnd.isBefore(from);
    }).toList();
  }
}

// EXCEL BUILDER
class _LeaveExcelBuilder {
  static xl.CellStyle _hdrStyle({String hex = 'FF1A56DB'}) => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString(hex),
    fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
    bold: true,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    fontSize: 10,
    fontFamily: 'Arial',
    textWrapping: xl.TextWrapping.WrapText,
  );

  static xl.CellStyle _cellStyle({
    bool bold = false,
    bool center = false,
    String? bgHex,
    String? fontHex,
  }) => xl.CellStyle(
    fontSize: 9,
    fontFamily: 'Arial',
    bold: bold,
    backgroundColorHex: bgHex != null
        ? xl.ExcelColor.fromHexString(bgHex)
        : xl.ExcelColor.fromHexString('FFFFFFFF'),
    fontColorHex: fontHex != null
        ? xl.ExcelColor.fromHexString(fontHex)
        : xl.ExcelColor.fromHexString('FF000000'),
    horizontalAlign: center
        ? xl.HorizontalAlign.Center
        : xl.HorizontalAlign.Left,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static xl.CellStyle _statusStyle(String status) {
    switch (status) {
      case 'Approved':
        return _cellStyle(
          center: true,
          bold: true,
          bgHex: 'FFECFDF5',
          fontHex: 'FF0E9F6E',
        );
      case 'Pending_TL':
        return _cellStyle(
          center: true,
          bold: true,
          bgHex: 'FFEEF2FF',
          fontHex: 'FF1A56DB',
        );
      case 'Pending_Manager':
        return _cellStyle(
          center: true,
          bold: true,
          bgHex: 'FFF5F3FF',
          fontHex: 'FF7C3AED',
        );
      case 'Not_Recommended_By_TL':
      case 'Rejected_By_Manager':
        return _cellStyle(
          center: true,
          bold: true,
          bgHex: 'FFFEF2F2',
          fontHex: 'FFEF4444',
        );
      case 'Cancelled':
        return _cellStyle(
          center: true,
          bold: true,
          bgHex: 'FFFFFBEB',
          fontHex: 'FFF59E0B',
        );
      default:
        return _cellStyle(center: true);
    }
  }

  static xl.CellStyle _totalStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFDBEAFE'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static void _set(
    xl.Sheet s,
    int row,
    int col,
    dynamic value, [
    xl.CellStyle? style,
  ]) {
    final cell = s.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    if (value is int) {
      cell.value = xl.IntCellValue(value);
    } else if (value is double) {
      cell.value = xl.DoubleCellValue(value);
    } else {
      cell.value = xl.TextCellValue(value?.toString() ?? '—');
    }
    if (style != null) cell.cellStyle = style;
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_mon(d.month)}-${d.year}';

  static String _mon(int m) => const [
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

  static String _statusLabel(String s) {
    switch (s) {
      case 'Approved':
        return 'Approved';
      case 'Pending_TL':
        return 'Pending TL';
      case 'Pending_Manager':
        return 'Pending Manager';
      case 'Not_Recommended_By_TL':
        return 'Not Recommended';
      case 'Rejected_By_Manager':
        return 'Rejected';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  // ── SHEET 1: Leave Master ───────────────────────────────────────────────────
  static void _buildLeaveMaster(xl.Excel excel, List<_LeaveRecord> records) {
    const name = 'Leave Master';
    excel.rename('Sheet1', name);
    final s = excel[name];

    s.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: 0),
    );
    _set(
      s,
      0,
      0,
      'LEAVE APPROVAL — Master Data (All Records)',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    s.setRowHeight(0, 30);

    final headers = [
      'Leave ID',
      'Emp ID',
      'Employee Name',
      'Leave Type',
      'Start Date',
      'End Date',
      'No. of Days',
      'Recommended By',
      'Approved By',
      'Status',
      ' Employee Reason',
      'Cancel Reason',
      'Rejection Reason',
      'Created At',
      'Updated At',
    ];
    final widths = [
      9.0,
      8.0,
      22.0,
      18.0,
      18.0,
      13.0,
      13.0,
      13.0,
      10.0,
      20.0,
      18.0,
      18.0,
      22.0,
      30.0,
      22.0,
      28.0,
      18.0,
      18.0,
    ];
    for (int c = 0; c < headers.length; c++) {
      _set(s, 1, c, headers[c], _hdrStyle());
      s.setColumnWidth(c, widths[c]);
    }
    s.setRowHeight(1, 24);

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final row = i + 2;
      final bg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';
      final cs = _cellStyle(bgHex: bg);
      final cc = _cellStyle(center: true, bgHex: bg);

      _set(s, row, 0, r.leaveId, cc);
      _set(s, row, 1, r.empId, cc);
      _set(s, row, 2, r.employeeName, cs);
      _set(s, row, 3, r.leaveType, cc);
      _set(s, row, 4, _fmtDate(r.leaveStartDate), cc);
      _set(s, row, 5, _fmtDate(r.leaveEndDate), cc);
      _set(s, row, 6, r.numberOfDays, cc);
      _set(s, row, 7, r.recommendedBy, cs);
      _set(s, row, 8, r.approvedBy, cs);
      _set(s, row, 9, _statusLabel(r.status), _statusStyle(r.status));
      _set(s, row, 10, r.employee_reason, cs);
      _set(s, row, 11, r.cancelReason, cs);
      _set(s, row, 12, r.rejectionReason, cs);
      _set(s, row, 13, r.createdAt, cc);
      _set(s, row, 14, r.updatedAt, cc);
      s.setRowHeight(row, 15);
    }

    final tot = records.length + 2;
    s.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tot),
      xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: tot),
    );
    _set(s, tot, 0, 'TOTAL RECORDS: ${records.length}', _totalStyle());
    _set(
      s,
      tot,
      8,
      records.fold(0, (sum, r) => sum + r.numberOfDays),
      _totalStyle(),
    );
    s.setRowHeight(tot, 20);
  }

  // ── SHEET 2: Summary Dashboard ──────────────────────────────────────────────
  static void _buildSummary(xl.Excel excel, List<_LeaveRecord> records) {
    final s = excel['Summary Dashboard'];

    s.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0),
    );
    _set(
      s,
      0,
      0,
      'LEAVE APPROVAL — Summary Dashboard',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    s.setRowHeight(0, 30);
    s.setColumnWidth(0, 28.0);
    s.setColumnWidth(1, 14.0);
    s.setColumnWidth(2, 4.0);
    s.setColumnWidth(3, 28.0);
    s.setColumnWidth(4, 14.0);
    s.setColumnWidth(5, 18.0);

    void secHeader(int row, String title, String hexBg) {
      s.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      );
      _set(
        s,
        row,
        0,
        title,
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString(hexBg),
          fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
          bold: true,
          fontSize: 10,
          fontFamily: 'Arial',
          horizontalAlign: xl.HorizontalAlign.Left,
        ),
      );
      s.setRowHeight(row, 22);
    }

    void kv(
      int row,
      String key,
      dynamic val, {
      String? fontHex,
      String? bgHex,
    }) {
      _set(s, row, 0, key, _cellStyle(bgHex: bgHex ?? 'FFF8FAFF'));
      _set(
        s,
        row,
        1,
        val,
        _cellStyle(
          center: true,
          bold: true,
          bgHex: bgHex ?? 'FFFFFFFF',
          fontHex: fontHex,
        ),
      );
      s.setRowHeight(row, 18);
    }

    secHeader(2, 'KEY METRICS', 'FF1A56DB');
    kv(3, 'Total Leave Records', records.length);
    kv(4, 'Total Leave Days', records.fold(0, (s, r) => s + r.numberOfDays));
    kv(5, 'Unique Employees', records.map((r) => r.empId).toSet().length);
    kv(
      6,
      'Avg Days per Request',
      records.isEmpty
          ? 0
          : (records.fold(0, (s, r) => s + r.numberOfDays) / records.length)
                .toStringAsFixed(1),
    );
    s.setRowHeight(7, 10);

    secHeader(8, 'STATUS BREAKDOWN', 'FF1E3A8A');

    final statusGroups = <String, int>{};
    for (final r in records) {
      statusGroups[r.statusLabel] = (statusGroups[r.statusLabel] ?? 0) + 1;
    }
    int sr = 9;
    final statusColors = {
      'Approved': 'FF0E9F6E',
      'Pending TL': 'FF1A56DB',
      'Pending Manager': 'FF7C3AED',
      'Not Recommended': 'FFEF4444',
      'Rejected': 'FFEF4444',
      'Cancelled': 'FFF59E0B',
    };
    for (final e in statusGroups.entries) {
      kv(sr, e.key, e.value, fontHex: statusColors[e.key]);
      sr++;
    }
    s.setRowHeight(sr, 10);
    sr++;

    secHeader(sr, 'LEAVE TYPE BREAKDOWN', 'FF0E9F6E');
    sr++;
    final typeGroups = <String, _LeaveStat>{};
    for (final r in records) {
      typeGroups.putIfAbsent(r.leaveType, () => _LeaveStat());
      typeGroups[r.leaveType]!.count++;
      typeGroups[r.leaveType]!.days += r.numberOfDays;
    }
    final typeHdr = _hdrStyle(hex: 'FF0E9F6E');
    _set(s, sr, 0, 'Leave Type', typeHdr);
    _set(s, sr, 1, 'Requests', typeHdr);
    _set(s, sr, 3, 'Total Days', typeHdr);
    s.setRowHeight(sr, 20);
    sr++;
    int ti = 0;
    for (final e in typeGroups.entries) {
      final bg = ti.isEven ? 'FFECFDF5' : 'FFFFFFFF';
      _set(s, sr, 0, e.key, _cellStyle(bgHex: bg));
      _set(
        s,
        sr,
        1,
        e.value.count,
        _cellStyle(center: true, bgHex: bg, bold: true),
      );
      _set(
        s,
        sr,
        3,
        e.value.days,
        _cellStyle(center: true, bgHex: bg, bold: true),
      );
      s.setRowHeight(sr, 16);
      sr++;
      ti++;
    }
    s.setRowHeight(sr, 10);
    sr++;

    secHeader(sr, 'DEPARTMENT BREAKDOWN', 'FF7C3AED');
    sr++;
    final deptGroups = <String, _LeaveStat>{};

    final deptHdr = _hdrStyle(hex: 'FF7C3AED');
    _set(s, sr, 1, 'Requests', deptHdr);
    _set(s, sr, 3, 'Total Days', deptHdr);
    s.setRowHeight(sr, 20);
    sr++;
    int di2 = 0;
    for (final e in deptGroups.entries) {
      final bg = di2.isEven ? 'FFF5F3FF' : 'FFFFFFFF';
      _set(s, sr, 0, e.key, _cellStyle(bgHex: bg));
      _set(
        s,
        sr,
        1,
        e.value.count,
        _cellStyle(center: true, bgHex: bg, bold: true),
      );
      _set(
        s,
        sr,
        3,
        e.value.days,
        _cellStyle(center: true, bgHex: bg, bold: true),
      );
      s.setRowHeight(sr, 16);
      sr++;
      di2++;
    }
  }

  // ── SHEET 3: Employee Summary ───────────────────────────────────────────────
  static void _buildEmployeeSummary(
    xl.Excel excel,
    List<_LeaveRecord> records,
  ) {
    final s = excel['Employee Summary'];

    s.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 0),
    );
    _set(
      s,
      0,
      0,
      'LEAVE APPROVAL — Per Employee Summary',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    s.setRowHeight(0, 30);

    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Approved',
      'Rejected',
      'Pending',
      'Total\nLeave Days',
    ];
    final widths = [7.0, 9.0, 22.0, 12.0, 12.0, 12.0, 13.0];
    for (int c = 0; c < headers.length; c++) {
      _set(s, 1, c, headers[c], _hdrStyle());
      s.setColumnWidth(c, widths[c]);
    }
    s.setRowHeight(1, 28);

    final empMap = <int, _EmpSummary>{};
    for (final r in records) {
      empMap.putIfAbsent(
        r.empId,
        () => _EmpSummary(empId: r.empId, name: r.employeeName),
      );
      final e = empMap[r.empId]!;
      e.total++;
      e.days += r.numberOfDays;
      switch (r.status) {
        case 'Approved':
          e.approved++;
          break;
        case 'Rejected_By_Manager':
        case 'Not_Recommended_By_TL':
          e.rejected++;
          break;
        case 'Pending_TL':
        case 'Pending_Manager':
          e.pending++;
          break;
        default:
          break;
      }
    }

    final sorted = empMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    for (int i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final row = i + 2;
      final bg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';
      final cc = _cellStyle(center: true, bgHex: bg);
      final cs = _cellStyle(bgHex: bg);

      _set(s, row, 0, i + 1, cc); // S.No
      _set(s, row, 1, e.empId, cc); // Emp ID
      _set(s, row, 2, e.name, cs); // Employee Name
      _set(
        // Approved
        s,
        row,
        3,
        e.approved,
        _cellStyle(
          center: true,
          bgHex: bg,
          bold: e.approved > 0,
          fontHex: e.approved > 0 ? 'FF0E9F6E' : null,
        ),
      );
      _set(
        // Rejected
        s,
        row,
        4,
        e.rejected,
        _cellStyle(
          center: true,
          bgHex: bg,
          bold: e.rejected > 0,
          fontHex: e.rejected > 0 ? 'FFEF4444' : null,
        ),
      );
      _set(
        // Pending
        s,
        row,
        5,
        e.pending,
        _cellStyle(
          center: true,
          bgHex: bg,
          bold: e.pending > 0,
          fontHex: e.pending > 0 ? 'FF7C3AED' : null,
        ),
      );
      _set(
        s,
        row,
        6,
        e.days,
        _cellStyle(center: true, bgHex: bg, bold: true),
      ); // Total Leave Days
      s.setRowHeight(row, 16);
    }

    final tot = sorted.length + 2;
    s.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tot),
      xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: tot),
    );
    _set(s, tot, 0, 'TOTALS', _totalStyle());
    _set(s, tot, 3, sorted.fold(0, (a, e) => a + e.approved), _totalStyle());
    _set(s, tot, 4, sorted.fold(0, (a, e) => a + e.rejected), _totalStyle());
    _set(s, tot, 5, sorted.fold(0, (a, e) => a + e.pending), _totalStyle());
    _set(s, tot, 6, sorted.fold(0, (a, e) => a + e.days), _totalStyle());
    s.setRowHeight(tot, 20);
  }

  // ── Build full workbook ──────────────────────────────────────────────────────
  static xl.Excel build(List<_LeaveRecord> records) {
    final excel = xl.Excel.createExcel();
    _buildLeaveMaster(excel, records);

    // Create additional sheets by directly referencing them (auto-creates)
    excel['Summary Dashboard'];
    _buildSummary(excel, records);

    excel['Employee Summary'];
    _buildEmployeeSummary(excel, records);

    return excel;
  }
}

// ── Small stat helpers ─────────────────────────────────────────────────────────
class _LeaveStat {
  int count = 0;
  int days = 0;
}

class _EmpSummary {
  final int empId;
  final String name;
  int total = 0;
  int days = 0;
  int approved = 0;
  int rejected = 0;
  int pending = 0;
  _EmpSummary({required this.empId, required this.name});
}

// SCROLL BEHAVIOR

class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

// MAIN SCREEN

class LeaveReportScreen extends StatefulWidget {
  const LeaveReportScreen({super.key});

  @override
  State<LeaveReportScreen> createState() => _LeaveReportScreenState();
}

class _LeaveReportScreenState extends State<LeaveReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Tab 1: All History ─────────────────────────────────────────────────────
  bool _loadingAll = false;
  bool _fetchedAll = false;
  String? _errorAll;
  List<_LeaveRecord> _allData = [];
  String _searchQuery = '';
  String _filterStatus = 'All';
  String _filterType = 'All';
  bool _sortAsc = false;

  // ── Tab 2: Date Range ──────────────────────────────────────────────────────
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  bool _loadingRange = false;
  bool _fetchedRange = false;
  String? _errorRange;
  List<_LeaveRecord> _rangeData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<_LeaveRecord> get _filteredAll {
    var list = _allData.where((r) {
      final q = _searchQuery.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          r.employeeName.toLowerCase().contains(q) ||
          r.empId.toString().contains(q) ||
          r.leaveType.toLowerCase().contains(q);
      final matchStatus =
          _filterStatus == 'All' || r.statusLabel == _filterStatus;
      final matchType = _filterType == 'All' || r.leaveType == _filterType;
      return matchSearch && matchStatus && matchType;
    }).toList();

    list.sort(
      (a, b) => _sortAsc
          ? a.leaveStartDate.compareTo(b.leaveStartDate)
          : b.leaveStartDate.compareTo(a.leaveStartDate),
    );
    return list;
  }

  List<String> get _allStatuses => [
    'All',
    'Approved',
    'Pending TL',
    'Pending Manager',
    'Not Recommended',
    'Rejected',
    'Cancelled',
  ];

  List<String> get _allLeaveTypes {
    final types = _allData.map((r) => r.leaveType).toSet().toList()..sort();
    return ['All', ...types];
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loadingAll = true;
      _errorAll = null;
      _fetchedAll = false;
    });
    try {
      _allData = await _LeaveReportService.fetchAllHistory();
      if (mounted) {
        setState(() {
          _fetchedAll = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorAll = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _fetchRange() async {
    setState(() {
      _loadingRange = true;
      _errorRange = null;
      _fetchedRange = false;
    });
    try {
      final all = await _LeaveReportService.fetchAllHistory();
      _rangeData = _LeaveReportService.filterByRange(all, _fromDate, _toDate);
      if (mounted) {
        setState(() {
          _fetchedRange = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorRange = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRange = false);
    }
  }

  Future<void> _downloadAll() async {
    if (_allData.isEmpty) {
      _showSnack('No data to export', isError: true);
      return;
    }
    setState(() => _loadingAll = true);
    try {
      final excel = _LeaveExcelBuilder.build(_allData);
      await _saveAndOpen(excel, 'Leave_Report_All.xlsx');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  Future<void> _downloadRange() async {
    if (_rangeData.isEmpty) {
      _showSnack('No data in selected range', isError: true);
      return;
    }
    setState(() => _loadingRange = true);
    try {
      final from = _fromDate;
      final to = _toDate;
      final excel = _LeaveExcelBuilder.build(_rangeData);
      final name =
          'Leave_Report_${from.year}${from.month.toString().padLeft(2, '0')}${from.day.toString().padLeft(2, '0')}'
          '_to_${to.year}${to.month.toString().padLeft(2, '0')}${to.day.toString().padLeft(2, '0')}.xlsx';
      await _saveAndOpen(excel, name);
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loadingRange = false);
    }
  }

  Future<void> _saveAndOpen(xl.Excel excel, String fileName) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel file');

    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: fileName.replaceAll('.xlsx', ''),
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      _showSnack('Download started: $fileName');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      _showSnack('Saved: $fileName');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final init = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate.isBefore(_fromDate)) _toDate = _fromDate;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(_toDate)) _fromDate = _toDate;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [_buildAllHistoryTab(), _buildDateRangeTab()],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(152),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A56DB), Color(0xFF1E3A8A), Color(0xFF1e1b4b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leave Approval Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Export to Excel  ·  4 Sheets',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.history_rounded, size: 16),
                  text: 'All Records',
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_rounded, size: 16),
                  text: 'Date Range',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1 — ALL HISTORY
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildAllHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Button(
                      label: 'Fetch All Data',
                      icon: Icons.refresh_rounded,
                      color: _primary,
                      loading: _loadingAll,
                      onTap: _fetchAll,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: _fetchedAll && !_loadingAll,
                      onTap: _downloadAll,
                    ),
                  ),
                ],
              ),
              if (_errorAll != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(_errorAll!),
              ],
              if (_fetchedAll && !_loadingAll) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.list_alt_rounded,
                      label: 'Total',
                      value: _allData.length.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.check_circle_outline,
                      label: 'Approved',
                      value: _allData
                          .where((r) => r.status == 'Approved')
                          .length
                          .toString(),
                      color: _accent,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.pending_actions,
                      label: 'Pending',
                      value: _allData
                          .where((r) => r.status.startsWith('Pending'))
                          .length
                          .toString(),
                      color: _purple,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.cancel_outlined,
                      label: 'Rejected',
                      value: _allData
                          .where(
                            (r) =>
                                r.status.contains('Reject') ||
                                r.status.contains('Not_'),
                          )
                          .length
                          .toString(),
                      color: _red,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchField(
                        query: _searchQuery,
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final st in _allStatuses) ...[
                              _FilterChip(
                                label: st,
                                selected: _filterStatus == st,
                                color: st == 'Approved'
                                    ? _accent
                                    : st.contains('Reject') ||
                                          st.contains('Not')
                                    ? _red
                                    : st.contains('Pending')
                                    ? _purple
                                    : st == 'Cancelled'
                                    ? _amber
                                    : _primary,
                                onTap: () => setState(() => _filterStatus = st),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField(
                              label: 'All Leave Types',
                              value: _filterType,
                              items: _allLeaveTypes,
                              onChanged: (v) =>
                                  setState(() => _filterType = v ?? 'All'),
                              icon: Icons.category_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => setState(() => _sortAsc = !_sortAsc),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sortAsc
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 13,
                                    color: _textMid,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortAsc ? 'Oldest' : 'Newest',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _textMid,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_filteredAll.length} of ${_allData.length} records',
                        style: const TextStyle(fontSize: 11, color: _textMid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _LeaveTable(records: _filteredAll, fmt: _fmt),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2 — DATE RANGE
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDateRangeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Select Date Range'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickerField(
                            'From',
                            _fromDate,
                            _fmt,
                            () => _pickDate(true),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: _textMid,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: _DatePickerField(
                            'To',
                            _toDate,
                            _fmt,
                            () => _pickDate(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _QuickChip('This Month', () {
                          final now = DateTime.now();
                          setState(() {
                            _fromDate = DateTime(now.year, now.month, 1);
                            _toDate = now;
                          });
                        }),
                        _QuickChip('Last Month', () {
                          final now = DateTime.now();
                          setState(() {
                            _fromDate = DateTime(now.year, now.month - 1, 1);
                            _toDate = DateTime(now.year, now.month, 0);
                          });
                        }),
                        _QuickChip('Last 30 Days', () {
                          setState(() {
                            _fromDate = DateTime.now().subtract(
                              const Duration(days: 29),
                            );
                            _toDate = DateTime.now();
                          });
                        }),
                        _QuickChip('Last 3 Months', () {
                          final now = DateTime.now();
                          setState(() {
                            _fromDate = DateTime(now.year, now.month - 2, 1);
                            _toDate = now;
                          });
                        }),
                        _QuickChip('This Year', () {
                          final now = DateTime.now();
                          setState(() {
                            _fromDate = DateTime(now.year, 1, 1);
                            _toDate = now;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Button(
                      label: 'Fetch Data',
                      icon: Icons.refresh_rounded,
                      color: _primary,
                      loading: _loadingRange,
                      onTap: _fetchRange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: _fetchedRange && !_loadingRange,
                      onTap: _downloadRange,
                    ),
                  ),
                ],
              ),
              if (_errorRange != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(_errorRange!),
              ],
              if (_fetchedRange && !_loadingRange) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.list_alt_rounded,
                      label: 'Total',
                      value: _rangeData.length.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.check_circle_outline,
                      label: 'Approved',
                      value: _rangeData
                          .where((r) => r.status == 'Approved')
                          .length
                          .toString(),
                      color: _accent,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.pending_actions,
                      label: 'Pending',
                      value: _rangeData
                          .where((r) => r.status.startsWith('Pending'))
                          .length
                          .toString(),
                      color: _purple,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.cancel_outlined,
                      label: 'Rejected',
                      value: _rangeData
                          .where(
                            (r) =>
                                r.status.contains('Reject') ||
                                r.status.contains('Not_'),
                          )
                          .length
                          .toString(),
                      color: _red,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_rangeData.isEmpty)
                  _Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 44,
                              color: _textMid.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No leave records in selected date range.',
                              style: TextStyle(color: _textMid, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  _LeaveTable(records: _rangeData, fmt: _fmt),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// LEAVE TABLE

class _LeaveTable extends StatelessWidget {
  final List<_LeaveRecord> records;
  final String Function(DateTime) fmt;
  const _LeaveTable({required this.records, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: _textMid.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No records match the current filter.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final r in records) ...[
          _LeaveCard(record: r, fmt: fmt),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LeaveCard extends StatefulWidget {
  final _LeaveRecord record;
  final String Function(DateTime) fmt;
  const _LeaveCard({required this.record, required this.fmt});

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _anim;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _rotate = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _anim.forward() : _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final sc = r.statusColor;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? sc.withValues(alpha: 0.4) : _border,
          width: _expanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _primary.withValues(alpha: 0.15),
                          _primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        r.employeeName.isNotEmpty
                            ? r.employeeName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.employeeName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${r.empId}  ·  ${r.leaveType}  ·  ${widget.fmt(r.leaveStartDate)} – ${widget.fmt(r.leaveEndDate)}  ·  ${r.numberOfDays}d',
                          style: const TextStyle(fontSize: 11, color: _textMid),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sc.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: sc,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          r.statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sc,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: _rotate,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _expanded ? sc : _textMid,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      Divider(height: 1, color: _border),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _InfoCell(
                                  icon: Icons.badge_outlined,
                                  label: 'Leave ID',
                                  value: '#${r.leaveId}',
                                ),
                                const SizedBox(width: 8),
                                _InfoCell(
                                  icon: Icons.person_outline,
                                  label: 'Emp ID',
                                  value: '${r.empId}',
                                ),
                                const SizedBox(width: 8),
                                _InfoCell(
                                  icon: Icons.category_outlined,
                                  label: 'Leave Type',
                                  value: r.leaveType,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _InfoCell(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'From',
                                  value: widget.fmt(r.leaveStartDate),
                                ),
                                const SizedBox(width: 8),
                                _InfoCell(
                                  icon: Icons.event_outlined,
                                  label: 'To',
                                  value: widget.fmt(r.leaveEndDate),
                                ),
                                const SizedBox(width: 8),
                                _InfoCell(
                                  icon: Icons.today_outlined,
                                  label: 'Days',
                                  value: '${r.numberOfDays} day(s)',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _InfoCell(
                                  icon: Icons.supervisor_account_outlined,
                                  label: 'Recommended By',
                                  value: r.recommendedBy,
                                ),
                              ],
                            ),
                            if (r.employee_reason.isNotEmpty &&
                                r.employee_reason != '—') ...[
                              const SizedBox(height: 8),
                              _ReasonTile(
                                icon: Icons.notes_rounded,
                                label: 'Reason',
                                text: r.employee_reason,
                                color: _primary,
                              ),
                            ],
                            if (r.rejectionReason.isNotEmpty &&
                                r.rejectionReason != '—') ...[
                              const SizedBox(height: 6),
                              _ReasonTile(
                                icon: Icons.cancel_outlined,
                                label: 'Rejection Reason',
                                text: r.rejectionReason,
                                color: _red,
                              ),
                            ],
                            if (r.cancelReason.isNotEmpty &&
                                r.cancelReason != '—') ...[
                              const SizedBox(height: 6),
                              _ReasonTile(
                                icon: Icons.block_outlined,
                                label: 'Cancel Reason',
                                text: r.cancelReason,
                                color: _amber,
                              ),
                            ],
                            if (r.approvedBy.isNotEmpty &&
                                r.approvedBy != '—') ...[
                              const SizedBox(height: 6),
                              _ReasonTile(
                                icon: Icons.verified_outlined,
                                label: 'Processed By',
                                text: r.approvedBy,
                                color: _accent,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// SHARED SMALL WIDGETS

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: _textMid),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: _textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReasonTile extends StatelessWidget {
  final IconData icon;
  final String label, text;
  final Color color;
  const _ReasonTile({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textDark,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SearchField extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search by name, ID, leave type, department…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color : _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _textMid,
        ),
      ),
    ),
  );
}

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: _textMid,
        ),
        style: const TextStyle(fontSize: 12, color: _textDark),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: onChanged,
        hint: Row(
          children: [
            Icon(icon, size: 14, color: _textMid),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: _textMid)),
          ],
        ),
      ),
    ),
  );
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final String Function(DateTime) fmt;
  final VoidCallback onTap;
  const _DatePickerField(this.label, this.date, this.fmt, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 16, color: _primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _textMid),
              ),
              Text(
                fmt(date),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
      ),
    ),
  );
}

class _Button extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading, enabled;
  final VoidCallback onTap;
  const _Button({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: _textMid),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _textDark,
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _red.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _red.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: _red, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _red),
          ),
        ),
      ],
    ),
  );
}
