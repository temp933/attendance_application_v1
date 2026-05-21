import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
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
const Color _hdr1 = Color(0xFF1E3A8A);
const Color _hdr2 = Color(0xFF2563EB);
const Color _divCol = Color(0xFF93C5FD);

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _EmpSummary {
  final int empId;
  final String name;
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final double leaveDays;
  final int lateDays;
  final int lateMinutes;
  final int compOffDays;
  final double leaveBalance;
  final double percentage;

  const _EmpSummary({
    required this.empId,
    required this.name,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.lateDays,
    required this.lateMinutes,
    required this.compOffDays,
    required this.leaveBalance,
    required this.percentage,
  });

  factory _EmpSummary.fromJson(Map<String, dynamic> j) => _EmpSummary(
    empId: _i(j['emp_id']),
    name: j['name']?.toString() ?? '',
    totalWorkingDays: _i(j['total_working_days']),
    presentDays: _i(j['present_days']),
    absentDays: _i(j['absent_days']),
    leaveDays: _d(j['leave_days']),
    lateDays: _i(j['late_days']),
    lateMinutes: _i(j['late_minutes']),
    compOffDays: _i(j['comp_off_days']),
    leaveBalance: _d(j['leave_balance']),
    percentage: _d(j['percentage']),
  );

  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
  static double _d(dynamic v) => v == null
      ? 0
      : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  String get lateHrsFormatted {
    final h = lateMinutes ~/ 60;
    final m = lateMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _EmpDaily {
  final int empId;
  final String name;
  final String? checkIn;
  final String? checkOut;
  final int workedMinutes;
  final String status; // Present | Absent | Leave | Holiday | Weekend
  final bool isLate;
  final int lateMinutes;
  final bool compOffEarned;
  final String? holidayName;

  const _EmpDaily({
    required this.empId,
    required this.name,
    this.checkIn,
    this.checkOut,
    required this.workedMinutes,
    required this.status,
    required this.isLate,
    required this.lateMinutes,
    required this.compOffEarned,
    this.holidayName,
  });

  factory _EmpDaily.fromJson(Map<String, dynamic> j) => _EmpDaily(
    empId: _i(j['emp_id']),
    name: j['name']?.toString() ?? '',
    checkIn: j['check_in']?.toString(),
    checkOut: j['check_out']?.toString(),
    workedMinutes: _i(j['worked_minutes']),
    status: j['status']?.toString() ?? 'Absent',
    isLate: j['is_late'] == true,
    lateMinutes: _i(j['late_minutes']),
    compOffEarned: j['comp_off_earned'] == true,
    holidayName: j['holiday_name']?.toString(),
  );

  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  String get workedFormatted {
    if (workedMinutes <= 0) return '-';
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get lateFormatted {
    if (lateMinutes <= 0) return '-';
    final h = lateMinutes ~/ 60;
    final m = lateMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _MatrixDate {
  final String date;
  final int day; // 0=Sun, 6=Sat
  final bool isHoliday, isWeekend;
  final String? holidayName;

  const _MatrixDate({
    required this.date,
    required this.day,
    required this.isHoliday,
    required this.isWeekend,
    this.holidayName,
  });

  factory _MatrixDate.fromJson(Map<String, dynamic> j) => _MatrixDate(
    date: j['date']?.toString() ?? '',
    day: _i(j['day']),
    isHoliday: j['is_holiday'] == true,
    isWeekend: j['is_weekend'] == true,
    holidayName: j['holiday_name']?.toString(),
  );

  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

  String get dayLabel => ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'][day];
}

class _MatrixEmp {
  final int empId;
  final String name;
  final List<String> days; // P / A / L / H / W per date
  final int presentDays, absentDays, leaveDays, totalWorkingDays;
  final double percentage;

  const _MatrixEmp({
    required this.empId,
    required this.name,
    required this.days,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.totalWorkingDays,
    required this.percentage,
  });

  factory _MatrixEmp.fromJson(Map<String, dynamic> j) => _MatrixEmp(
    empId: _i(j['emp_id']),
    name: j['name']?.toString() ?? '',
    days: List<String>.from(j['days'] ?? []),
    presentDays: _i(j['present_days']),
    absentDays: _i(j['absent_days']),
    leaveDays: _i(j['leave_days']),
    totalWorkingDays: _i(j['total_working_days']),
    percentage: _d(j['percentage']),
  );

  static int _i(dynamic v) =>
      v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
  static double _d(dynamic v) => v == null
      ? 0
      : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────
class _ReportService {
  static Future<Map<String, dynamic>> fetchMatrix(
    DateTime from,
    DateTime to,
  ) async {
    final res = await ApiClient.get(
      '/attendance/report/matrix?from=${_fmt(from)}&to=${_fmt(to)}',
    );
    if (res.statusCode != 200)
      throw Exception('Server error ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<List<_EmpSummary>> fetchSummary(
    DateTime from,
    DateTime to,
  ) async {
    final res = await ApiClient.get(
      '/attendance/report/summary?from=${_fmt(from)}&to=${_fmt(to)}',
    );
    if (res.statusCode != 200)
      throw Exception('Server error ${res.statusCode}');
    final body = jsonDecode(res.body);
    final List rows = body['data'] ?? [];
    return rows
        .map((r) => _EmpSummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchDaily(DateTime date) async {
    final res = await ApiClient.get(
      '/attendance/report/daily?date=${_fmt(date)}',
    );
    if (res.statusCode != 200)
      throw Exception('Server error ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Excel Builders
// ─────────────────────────────────────────────────────────────────────────────
class _ExcelBuilder {
  static xl.Excel buildMatrix(
    List<_MatrixEmp> data,
    List<_MatrixDate> dates,
    DateTime from,
    DateTime to,
  ) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Matrix Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final fromStr = _fmtDisp(from);
    final toStr = _fmtDisp(to);

    // Title row
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 4 + dates.length, rowIndex: 0),
    );
    _set(
      sheet,
      0,
      0,
      'Attendance Matrix Report  |  $fromStr  to  $toStr',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 28);

    // Legend row
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xl.CellIndex.indexByColumnRow(columnIndex: 4 + dates.length, rowIndex: 1),
    );
    _set(
      sheet,
      1,
      0,
      'P = Present   A = Absent   L = Leave   H = Holiday   W = Weekend/Week-off',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FFE8F0FE'),
        fontColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontSize: 9,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(1, 16);

    // Day-name sub-header (Su Mo Tu …)
    _set(sheet, 2, 0, '', _hdr());
    _set(sheet, 2, 1, '', _hdr());
    _set(sheet, 2, 2, '', _hdr());
    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final bg = d.isHoliday
          ? 'FF1D4ED8'
          : d.isWeekend
          ? 'FF7C3AED'
          : 'FF1E3A8A';
      _set(
        sheet,
        2,
        3 + i,
        d.dayLabel,
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString(bg),
          fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
          fontSize: 8,
          bold: true,
          fontFamily: 'Arial',
          horizontalAlign: xl.HorizontalAlign.Center,
          verticalAlign: xl.VerticalAlign.Center,
        ),
      );
    }
    _set(sheet, 2, 3 + dates.length, '', _hdr());
    _set(sheet, 2, 4 + dates.length, '', _hdr());
    _set(sheet, 2, 5 + dates.length, '', _hdr());
    _set(sheet, 2, 6 + dates.length, '', _hdr());
    sheet.setRowHeight(2, 16);

    // Column headers
    _set(sheet, 3, 0, 'S.No', _hdr());
    _set(sheet, 3, 1, 'Emp ID', _hdr());
    _set(sheet, 3, 2, 'Employee Name', _hdr());
    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final day = int.parse(d.date.split('-')[2]);
      final bg = d.isHoliday
          ? 'FF1D4ED8'
          : d.isWeekend
          ? 'FF7C3AED'
          : 'FF2563EB';
      _set(
        sheet,
        3,
        3 + i,
        '$day',
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString(bg),
          fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
          fontSize: 9,
          bold: true,
          fontFamily: 'Arial',
          horizontalAlign: xl.HorizontalAlign.Center,
          verticalAlign: xl.VerticalAlign.Center,
        ),
      );
    }
    _set(sheet, 3, 3 + dates.length, 'Present', _hdr());
    _set(sheet, 3, 4 + dates.length, 'Absent', _hdr());
    _set(sheet, 3, 5 + dates.length, 'Leave', _hdr());
    _set(sheet, 3, 6 + dates.length, 'Att %', _hdr());
    sheet.setRowHeight(3, 22);

    // Column widths
    sheet.setColumnWidth(0, 5.0);
    sheet.setColumnWidth(1, 9.0);
    sheet.setColumnWidth(2, 22.0);
    for (int i = 0; i < dates.length; i++) sheet.setColumnWidth(3 + i, 4.2);
    sheet.setColumnWidth(3 + dates.length, 9.0);
    sheet.setColumnWidth(4 + dates.length, 9.0);
    sheet.setColumnWidth(5 + dates.length, 9.0);
    sheet.setColumnWidth(6 + dates.length, 9.0);

    // Cell color map
    final Map<String, (String, String)> cellColor = {
      'P': ('FFECFDF5', 'FF16A34A'),
      'A': ('FFFEF2F2', 'FFDC2626'),
      'L': ('FFFFE4E6', 'FFBE123C'),
      'H': ('FFE0F2FE', 'FF0369A1'),
      'W': ('FFF5F3FF', 'FF7C3AED'),
    };

    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final row = i + 4;
      final rowBg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';

      _set(sheet, row, 0, i + 1, _cell(center: true, bg: rowBg));
      _set(sheet, row, 1, emp.empId, _cell(center: true, bg: rowBg));
      _set(sheet, row, 2, emp.name, _cell(bg: rowBg));

      for (int j = 0; j < emp.days.length; j++) {
        final s = emp.days[j];
        final c = cellColor[s] ?? (rowBg, '000000');
        _set(
          sheet,
          row,
          3 + j,
          s,
          _cell(center: true, bg: c.$1, fg: c.$2, bold: s == 'P'),
        );
      }

      _set(
        sheet,
        row,
        3 + dates.length,
        emp.presentDays,
        _cell(center: true, bg: 'FFECFDF5', fg: 'FF16A34A', bold: true),
      );
      _set(
        sheet,
        row,
        4 + dates.length,
        emp.absentDays,
        _cell(
          center: true,
          bg: emp.absentDays > 0 ? 'FFFEF2F2' : rowBg,
          fg: emp.absentDays > 0 ? 'FFDC2626' : null,
        ),
      );
      _set(
        sheet,
        row,
        5 + dates.length,
        emp.leaveDays > 0 ? emp.leaveDays.toString() : '0',
        _cell(
          center: true,
          bg: emp.leaveDays > 0 ? 'FFFFE4E6' : rowBg,
          fg: emp.leaveDays > 0 ? 'FFBE123C' : null,
        ),
      );
      _set(
        sheet,
        row,
        6 + dates.length,
        '${emp.percentage}%',
        _cell(
          center: true,
          bg: emp.percentage >= 90
              ? 'FFDCFCE7'
              : emp.percentage >= 75
              ? 'FFE0F2FE'
              : emp.percentage >= 50
              ? 'FFFEF3C7'
              : 'FFFEE2E2',
          fg: emp.percentage >= 90
              ? 'FF16A34A'
              : emp.percentage >= 75
              ? 'FF0369A1'
              : emp.percentage >= 50
              ? 'FFB45309'
              : 'FFDC2626',
          bold: true,
        ),
      );
      sheet.setRowHeight(row, 18);
    }

    return excel;
  }

  static xl.CellStyle _hdr({String hex = 'FF1E3A8A'}) => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString(hex),
    fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
    bold: true,
    fontSize: 10,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
  );

  static xl.CellStyle _cell({
    bool bold = false,
    bool center = false,
    String? bg,
    String? fg,
  }) => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString(bg ?? '#FFFFFF'),
    fontColorHex: xl.ExcelColor.fromHexString(fg ?? '#000000'),
    fontSize: 9,
    fontFamily: 'Arial',
    bold: bold,
    horizontalAlign: center
        ? xl.HorizontalAlign.Center
        : xl.HorizontalAlign.Left,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static void _set(
    xl.Sheet s,
    int row,
    int col,
    dynamic val, [
    xl.CellStyle? style,
  ]) {
    final cell = s.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = val is int
        ? xl.IntCellValue(val)
        : val is double
        ? xl.DoubleCellValue(val)
        : xl.TextCellValue(val?.toString() ?? '');
    if (style != null) cell.cellStyle = style;
  }

  // ── Summary Excel ──────────────────────────────────────────────────────────
  static xl.Excel buildSummary(
    List<_EmpSummary> data,
    DateTime from,
    DateTime to,
  ) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Attendance Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final fromStr = _fmtDisp(from);
    final toStr = _fmtDisp(to);

    // Title
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 0),
    );
    _set(
      sheet,
      0,
      0,
      'Attendance Summary Report  |  $fromStr  to  $toStr',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 30);

    // Date range sub-header
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xl.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 1),
    );
    _set(
      sheet,
      1,
      0,
      'Period: $fromStr  →  $toStr   (Mode: Normal attendance only)',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FFE8F0FE'),
        fontColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        bold: false,
        fontSize: 9,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(1, 18);

    // Column headers
    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Total\nWorking Days',
      'Present\nDays',
      'Absent\nDays',
      'Leave\nDays',
      'Late\nDays',
      'Late\nHrs',
      'Comp-Off\nDays',
      'Leave\nBalance',
      'Attendance\n%',
      'Status',
    ];
    for (int c = 0; c < headers.length; c++) {
      _set(sheet, 2, c, headers[c], _hdr());
    }
    sheet.setRowHeight(2, 28);

    final widths = [
      6.0,
      9.0,
      24.0,
      12.0,
      10.0,
      10.0,
      10.0,
      10.0,
      10.0,
      11.0,
      12.0,
      12.0,
      12.0,
    ];
    for (int c = 0; c < widths.length; c++) sheet.setColumnWidth(c, widths[c]);

    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final row = i + 3;
      final rowBg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';

      String statusLabel;
      String statusBg;
      String statusFg;
      if (emp.percentage >= 90) {
        statusLabel = 'Excellent';
        statusBg = 'FFDCFCE7';
        statusFg = 'FF16A34A';
      } else if (emp.percentage >= 75) {
        statusLabel = 'Good';
        statusBg = 'FFE0F2FE';
        statusFg = 'FF0369A1';
      } else if (emp.percentage >= 50) {
        statusLabel = 'Average';
        statusBg = 'FFFEF3C7';
        statusFg = 'FFB45309';
      } else {
        statusLabel = 'Low';
        statusBg = 'FFFEE2E2';
        statusFg = 'FFDC2626';
      }

      _set(sheet, row, 0, i + 1, _cell(center: true, bg: rowBg));
      _set(sheet, row, 1, emp.empId, _cell(center: true, bg: rowBg));
      _set(sheet, row, 2, emp.name, _cell(bg: rowBg));
      _set(sheet, row, 3, emp.totalWorkingDays, _cell(center: true, bg: rowBg));
      _set(
        sheet,
        row,
        4,
        emp.presentDays,
        _cell(
          center: true,
          bg: emp.presentDays > 0 ? 'FFECFDF5' : rowBg,
          fg: emp.presentDays > 0 ? 'FF16A34A' : null,
          bold: emp.presentDays > 0,
        ),
      );
      _set(
        sheet,
        row,
        5,
        emp.absentDays,
        _cell(
          center: true,
          bg: emp.absentDays > 0 ? 'FFFEF2F2' : rowBg,
          fg: emp.absentDays > 0 ? 'FFDC2626' : null,
          bold: emp.absentDays > 0,
        ),
      );
      _set(
        sheet,
        row,
        6,
        emp.leaveDays.toString(),
        _cell(
          center: true,
          bg: emp.leaveDays > 0 ? 'FFFFE4E6' : rowBg,
          fg: emp.leaveDays > 0 ? 'FFBE123C' : null,
        ),
      );
      _set(
        sheet,
        row,
        7,
        emp.lateDays,
        _cell(
          center: true,
          bg: emp.lateDays > 0 ? 'FFFEF3C7' : rowBg,
          fg: emp.lateDays > 0 ? 'FFB45309' : null,
        ),
      );
      _set(
        sheet,
        row,
        8,
        emp.lateMinutes > 0 ? emp.lateHrsFormatted : '-',
        _cell(
          center: true,
          bg: emp.lateMinutes > 0 ? 'FFFEF3C7' : rowBg,
          fg: emp.lateMinutes > 0 ? 'FFB45309' : null,
        ),
      );
      _set(
        sheet,
        row,
        9,
        emp.compOffDays,
        _cell(
          center: true,
          bg: emp.compOffDays > 0 ? 'FFFFFBEB' : rowBg,
          fg: emp.compOffDays > 0 ? 'FF92400E' : null,
        ),
      );
      _set(
        sheet,
        row,
        10,
        emp.leaveBalance.toString(),
        _cell(center: true, bg: 'FFE0F2FE', fg: 'FF0369A1', bold: true),
      );
      _set(
        sheet,
        row,
        11,
        '${emp.percentage}%',
        _cell(
          center: true,
          bg: emp.percentage >= 90
              ? 'FFDCFCE7'
              : emp.percentage >= 75
              ? 'FFE0F2FE'
              : emp.percentage >= 50
              ? 'FFFEF3C7'
              : 'FFFEE2E2',
          fg: emp.percentage >= 90
              ? 'FF16A34A'
              : emp.percentage >= 75
              ? 'FF0369A1'
              : emp.percentage >= 50
              ? 'FFB45309'
              : 'FFDC2626',
          bold: true,
        ),
      );
      _set(
        sheet,
        row,
        12,
        statusLabel,
        _cell(center: true, bg: statusBg, fg: statusFg, bold: true),
      );
      sheet.setRowHeight(row, 20);
    }

    // Totals row
    if (data.isNotEmpty) {
      final summaryRow = data.length + 3;
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow),
        xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow),
      );
      final ts = _cell(
        center: true,
        bg: 'FF1D4ED8',
        fg: 'FFFFFFFF',
        bold: true,
      );

      sheet.setRowHeight(summaryRow, 22);
    }
    return excel;
  }

  // ── Daily Excel ────────────────────────────────────────────────────────────
  static xl.Excel buildDaily(List<_EmpDaily> data, DateTime date) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Daily Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final dateStr = _fmtDisp(date);

    // Title
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0),
    );
    _set(
      sheet,
      0,
      0,
      'Day-Wise Attendance Report  |  $dateStr',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 13,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 30);

    // Date sub-header
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 1),
    );
    _set(
      sheet,
      1,
      0,
      'Date: $dateStr   (Mode: Normal attendance only)',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FFE8F0FE'),
        fontColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        bold: false,
        fontSize: 9,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(1, 18);

    // Column headers
    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Check In',
      'Check Out',
      'Worked Hrs',
      'Status',
      'Late',
      'Late By',
      'Comp-Off\nEarned',
      'Holiday',
    ];
    for (int c = 0; c < headers.length; c++)
      _set(sheet, 2, c, headers[c], _hdr());
    sheet.setRowHeight(2, 28);

    final widths = [
      6.0,
      9.0,
      24.0,
      10.0,
      10.0,
      10.0,
      12.0,
      8.0,
      10.0,
      12.0,
      18.0,
    ];
    for (int c = 0; c < widths.length; c++) sheet.setColumnWidth(c, widths[c]);

    // Status → color map
    Map<String, (String, String)> statusColors = {
      'Present': ('FFECFDF5', 'FF16A34A'),
      'Absent': ('FFFEF2F2', 'FFDC2626'),
      'Leave': ('FFFFE4E6', 'FFBE123C'),
      'Holiday': ('FFE0F2FE', 'FF0369A1'),
      'Weekend': ('FFF5F3FF', 'FF7C3AED'),
    };

    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final row = i + 3;
      final rowBg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';
      final sc = statusColors[emp.status] ?? (rowBg, '000000');

      _set(sheet, row, 0, i + 1, _cell(center: true, bg: rowBg));
      _set(sheet, row, 1, emp.empId, _cell(center: true, bg: rowBg));
      _set(sheet, row, 2, emp.name, _cell(bg: rowBg));
      _set(sheet, row, 3, emp.checkIn ?? '-', _cell(center: true, bg: rowBg));
      _set(sheet, row, 4, emp.checkOut ?? '-', _cell(center: true, bg: rowBg));
      _set(sheet, row, 5, emp.workedFormatted, _cell(center: true, bg: rowBg));
      _set(
        sheet,
        row,
        6,
        emp.status,
        _cell(center: true, bg: sc.$1, fg: sc.$2, bold: true),
      );
      _set(
        sheet,
        row,
        7,
        emp.isLate ? 'Yes' : 'No',
        _cell(
          center: true,
          bg: emp.isLate ? 'FFFEF3C7' : rowBg,
          fg: emp.isLate ? 'FFB45309' : null,
        ),
      );
      _set(
        sheet,
        row,
        8,
        emp.lateFormatted,
        _cell(
          center: true,
          bg: emp.lateMinutes > 0 ? 'FFFEF3C7' : rowBg,
          fg: emp.lateMinutes > 0 ? 'FFB45309' : null,
        ),
      );
      _set(
        sheet,
        row,
        9,
        emp.compOffEarned ? 'Yes' : 'No',
        _cell(
          center: true,
          bg: emp.compOffEarned ? 'FFFFFBEB' : rowBg,
          fg: emp.compOffEarned ? 'FF92400E' : null,
        ),
      );
      _set(
        sheet,
        row,
        10,
        emp.holidayName ?? '-',
        _cell(bg: rowBg, fg: '440369A1'),
      );
      sheet.setRowHeight(row, 20);
    }

    // Totals row
    if (data.isNotEmpty) {
      final tr = data.length + 3;
      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: tr),
        xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: tr),
      );
      final ts = _cell(
        center: true,
        bg: 'FF1D4ED8',
        fg: 'FFFFFFFF',
        bold: true,
      );
      _set(
        sheet,
        tr,
        0,
        'TOTALS',
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString('FF1D4ED8'),
          fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
          bold: true,
          fontSize: 9,
          fontFamily: 'Arial',
          horizontalAlign: xl.HorizontalAlign.Center,
        ),
      );
      final present = data.where((e) => e.status == 'Present').length;
      final absent = data.where((e) => e.status == 'Absent').length;
      final onLeave = data.where((e) => e.status == 'Leave').length;
      final late = data.where((e) => e.isLate).length;
      _set(sheet, tr, 3, '-', ts);
      _set(sheet, tr, 4, '-', ts);
      _set(sheet, tr, 5, '-', ts);
      _set(sheet, tr, 6, 'P:$present  A:$absent  L:$onLeave', ts);
      _set(sheet, tr, 7, late.toString(), ts);
      _set(sheet, tr, 8, '-', ts);
      _set(sheet, tr, 9, '-', ts);
      _set(sheet, tr, 10, '${data.length} Emp', ts);
      sheet.setRowHeight(tr, 22);
    }
    return excel;
  }

  static String _fmtDisp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MatrixTab extends StatefulWidget {
  const _MatrixTab();
  @override
  State<_MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<_MatrixTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<_MatrixEmp> _data = [];
  List<_MatrixDate> _dates = [];
  String _search = '';

  String _fmtDisp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtFile(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
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

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await _ReportService.fetchMatrix(_fromDate, _toDate);
      final List rawDates = body['dates'] ?? [];
      final List rawData = body['data'] ?? [];
      setState(() {
        _dates = rawDates
            .map((d) => _MatrixDate.fromJson(d as Map<String, dynamic>))
            .toList();
        _data = rawData
            .map((e) => _MatrixEmp.fromJson(e as Map<String, dynamic>))
            .toList();
        _fetched = true;
        _search = '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_data.isEmpty) {
      _snack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final excel = _ExcelBuilder.buildMatrix(
        _data,
        _dates,
        _fromDate,
        _toDate,
      );
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel');
      final name =
          'Attendance_Matrix_${_fmtFile(_fromDate)}_to_${_fmtFile(_toDate)}';
      await _saveExcel(bytes, name);
      _snack('Downloaded: $name.xlsx');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
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

  List<_MatrixEmp> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.name.toLowerCase().contains(_search.toLowerCase()) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Date range picker ──────────────────────────────────────
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              'From',
                              _fromDate,
                              _fmtDisp,
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
                            child: _DateField(
                              'To',
                              _toDate,
                              _fmtDisp,
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
                            final n = DateTime.now();
                            setState(() {
                              _fromDate = DateTime(n.year, n.month, 1);
                              _toDate = n;
                            });
                          }),
                          _QuickChip('Last Month', () {
                            final n = DateTime.now();
                            setState(() {
                              _fromDate = DateTime(n.year, n.month - 1, 1);
                              _toDate = DateTime(n.year, n.month, 0);
                            });
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _Btn(
                        label: 'Fetch Data',
                        icon: Icons.refresh_rounded,
                        color: _primary,
                        loading: _loading,
                        onTap: _fetch,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Btn(
                        label: 'Download Excel',
                        icon: Icons.download_rounded,
                        color: _accent,
                        loading: false,
                        enabled: _fetched && !_loading,
                        onTap: _download,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _red,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 12, color: _red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_fetched && !_loading) ...[
                  const SizedBox(height: 14),
                  // ── Period banner ─────────────────────────────────────────
                  _DateBanner(
                    label: 'Report Period',
                    value: '${_fmtDisp(_fromDate)}  →  ${_fmtDisp(_toDate)}',
                    icon: Icons.grid_on_rounded,
                    color: _primary,
                  ),
                  const SizedBox(height: 10),
                  // ── Legend chips ──────────────────────────────────────────
                  _legendRow(),
                  const SizedBox(height: 12),
                  // ── Search ────────────────────────────────────────────────
                  _Card(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 13, color: _textDark),
                      decoration: const InputDecoration(
                        hintText: 'Search employee…',
                        hintStyle: TextStyle(color: _textMid, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _textMid,
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Matrix table ──────────────────────────────────────────
                  _matrixTable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendRow() => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: const [
      _LegendChip('P', 'Present', Color(0xFFECFDF5), Color(0xFF16A34A)),
      _LegendChip('A', 'Absent', Color(0xFFFEF2F2), Color(0xFFDC2626)),
      _LegendChip('L', 'Leave', Color(0xFFFFE4E6), Color(0xFFBE123C)),
      _LegendChip('H', 'Holiday', Color(0xFFE0F2FE), Color(0xFF0369A1)),
      _LegendChip('W', 'Week-off', Color(0xFFF5F3FF), Color(0xFF7C3AED)),
    ],
  );

  Widget _matrixTable() {
    final rows = _filtered;
    if (rows.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: _textMid.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No records found.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const empIdW = 70.0;
    const nameW = 170.0;
    const snoW = 44.0;
    const dayW = 28.0; // each date cell
    const summaryW = 62.0; // Present/Absent/Leave/% columns

    final totalW =
        snoW +
        empIdW +
        nameW +
        (_dates.length * dayW) +
        (4 * summaryW) +
        (_dates.length + 5); // dividers

    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);

    // ── Day-name row ──────────────────────────────────────────────────────
    Widget dayNameHdr(int i) {
      final d = _dates[i];
      final bg = d.isHoliday
          ? const Color(0xFF1D4ED8)
          : d.isWeekend
          ? _purple
          : _hdr2;
      return Container(
        width: dayW,
        height: 18,
        color: bg,
        alignment: Alignment.center,
        child: Text(
          d.dayLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // ── Date number header ────────────────────────────────────────────────
    Widget dateHdr(int i) {
      final d = _dates[i];
      final day = int.parse(d.date.split('-')[2]);
      final bg = d.isHoliday
          ? const Color(0xFF1D4ED8)
          : d.isWeekend
          ? _purple
          : _hdr2;
      return Container(
        width: dayW,
        height: 22,
        color: bg,
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // ── Status cell ───────────────────────────────────────────────────────
    final Map<String, (Color, Color)> statusColor = {
      'P': (const Color(0xFFECFDF5), const Color(0xFF16A34A)),
      'A': (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
      'L': (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
      'H': (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
      'W': (const Color(0xFFF5F3FF), _purple),
    };

    Widget statusCell(String s, Color rowBg) {
      final c = statusColor[s] ?? (rowBg, _textDark);
      return Container(
        width: dayW,
        height: 28,
        color: c.$1,
        alignment: Alignment.center,
        child: Text(
          s,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: c.$2,
          ),
        ),
      );
    }

    Widget summaryHdr(String label) => Container(
      width: summaryW,
      height: 40,
      color: _hdr2,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );

    Widget summaryCell(String val, Color bg, Color fg, Color rowBg) =>
        Container(
          width: summaryW,
          height: 28,
          color: bg,
          alignment: Alignment.center,
          child: Text(
            val,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table header bar
        Container(
          decoration: const BoxDecoration(
            color: _hdr1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                'Attendance Matrix',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rows.length} employees',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _divCol),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            color: Colors.white,
          ),
          child: ScrollConfiguration(
            behavior: _DragScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  // Day-name sub-row
                  Row(
                    children: [
                      Container(width: snoW, height: 18, color: _hdr1),
                      div(),
                      Container(width: empIdW, height: 18, color: _hdr1),
                      div(),
                      Container(width: nameW, height: 18, color: _hdr1),
                      div(),
                      for (int i = 0; i < _dates.length; i++) ...[
                        dayNameHdr(i),
                        if (i < _dates.length - 1) div(),
                      ],
                      div(),
                      Container(width: summaryW, height: 18, color: _hdr1),
                      div(),
                      Container(width: summaryW, height: 18, color: _hdr1),
                      div(),
                      Container(width: summaryW, height: 18, color: _hdr1),
                      div(),
                      Container(width: summaryW, height: 18, color: _hdr1),
                    ],
                  ),
                  hdiv(totalW),
                  // Date number header row
                  Row(
                    children: [
                      Container(
                        width: snoW,
                        height: 22,
                        color: _hdr2,
                        alignment: Alignment.center,
                        child: const Text(
                          'S.No',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      div(),
                      Container(
                        width: empIdW,
                        height: 22,
                        color: _hdr2,
                        alignment: Alignment.center,
                        child: const Text(
                          'Emp ID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      div(),
                      Container(
                        width: nameW,
                        height: 22,
                        color: _hdr2,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 8),
                        child: const Text(
                          'Employee Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      div(),
                      for (int i = 0; i < _dates.length; i++) ...[
                        dateHdr(i),
                        if (i < _dates.length - 1) div(),
                      ],
                      div(),
                      summaryHdr('Present'),
                      div(),
                      summaryHdr('Absent'),
                      div(),
                      summaryHdr('Leave'),
                      div(),
                      summaryHdr('Att %'),
                    ],
                  ),
                  hdiv(totalW),
                  // Employee rows
                  for (int idx = 0; idx < rows.length; idx++) ...[
                    _buildMatrixRow(
                      rows[idx],
                      idx,
                      statusCell,
                      summaryCell,
                      div,
                      snoW,
                      empIdW,
                      nameW,
                      dayW,
                      summaryW,
                    ),
                    hdiv(totalW),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixRow(
    _MatrixEmp emp,
    int idx,
    Widget Function(String, Color) statusCell,
    Widget Function(String, Color, Color, Color) summaryCell,
    Widget Function() div,
    double snoW,
    double empIdW,
    double nameW,
    double dayW,
    double summaryW,
  ) {
    final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);
    const rowH = 28.0;

    Color pctBg, pctFg;
    if (emp.percentage >= 90) {
      pctBg = const Color(0xFFDCFCE7);
      pctFg = const Color(0xFF16A34A);
    } else if (emp.percentage >= 75) {
      pctBg = const Color(0xFFE0F2FE);
      pctFg = const Color(0xFF0369A1);
    } else if (emp.percentage >= 50) {
      pctBg = const Color(0xFFFEF3C7);
      pctFg = const Color(0xFFB45309);
    } else {
      pctBg = const Color(0xFFFEE2E2);
      pctFg = const Color(0xFFDC2626);
    }

    return Row(
      children: [
        // S.No
        Container(
          width: snoW,
          height: rowH,
          color: rowBg,
          alignment: Alignment.center,
          child: Text(
            '${idx + 1}',
            style: const TextStyle(fontSize: 10, color: _textMid),
          ),
        ),
        div(),
        // Emp ID
        Container(
          width: empIdW,
          height: rowH,
          color: rowBg,
          alignment: Alignment.center,
          child: Text(
            emp.empId.toString(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ),
        div(),
        // Name
        Container(
          width: nameW,
          height: rowH,
          color: rowBg,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            emp.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        div(),
        // Day cells
        for (int j = 0; j < emp.days.length; j++) ...[
          statusCell(emp.days[j], rowBg),
          if (j < emp.days.length - 1) div(),
        ],
        div(),
        // Summary
        summaryCell(
          '${emp.presentDays}',
          const Color(0xFFECFDF5),
          const Color(0xFF16A34A),
          rowBg,
        ),
        div(),
        summaryCell(
          '${emp.absentDays}',
          emp.absentDays > 0 ? const Color(0xFFFEF2F2) : rowBg,
          emp.absentDays > 0 ? const Color(0xFFDC2626) : _textMid,
          rowBg,
        ),
        div(),
        summaryCell(
          emp.leaveDays > 0 ? '${emp.leaveDays}' : '0',
          emp.leaveDays > 0 ? const Color(0xFFFFE4E6) : rowBg,
          emp.leaveDays > 0 ? const Color(0xFFBE123C) : _textMid,
          rowBg,
        ),
        div(),
        summaryCell(
          '${emp.percentage.toStringAsFixed(1)}%',
          pctBg,
          pctFg,
          rowBg,
        ),
      ],
    );
  }
}

// Legend chip widget
class _LegendChip extends StatelessWidget {
  final String code, label;
  final Color bg, fg;
  const _LegendChip(this.code, this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: fg.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: fg)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll behaviour
// ─────────────────────────────────────────────────────────────────────────────
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Root Screen — tabbed (Summary | Day-Wise)
// ─────────────────────────────────────────────────────────────────────────────
class AdminAttendanceReportScreen extends StatefulWidget {
  const AdminAttendanceReportScreen({super.key});
  @override
  State<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

class _AdminAttendanceReportScreenState
    extends State<AdminAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tab,
          children: const [_SummaryTab(), _DailyTab()],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(130),
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
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 4),
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
                  const SizedBox(width: 6),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Normal mode only  ·  Export to Excel',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.bar_chart_rounded, size: 16),
                  text: 'Monthly Summary',
                ),
                Tab(
                  icon: Icon(Icons.today_rounded, size: 16),
                  text: 'Day-Wise',
                ),
                Tab(
                  icon: Icon(Icons.grid_on_rounded, size: 16),
                  text: 'Matrix',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Monthly Summary
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryTab extends StatefulWidget {
  const _SummaryTab();
  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<_EmpSummary> _data = [];
  String _search = '';

  String _fmtDisp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
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

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final list = await _ReportService.fetchSummary(_fromDate, _toDate);
      setState(() {
        _data = list;
        _fetched = true;
        _search = '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_data.isEmpty) {
      _snack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final excel = _ExcelBuilder.buildSummary(_data, _fromDate, _toDate);
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel');
      final name =
          'Attendance_Summary_${_fmtFile(_fromDate)}_to_${_fmtFile(_toDate)}';
      await _saveExcel(bytes, name);
      _snack('Downloaded: $name.xlsx');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  String _fmtFile(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  void _snack(String msg, {bool isError = false}) {
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

  List<_EmpSummary> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.name.toLowerCase().contains(_search.toLowerCase()) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterCard(),
                const SizedBox(height: 12),
                _actionRow(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(),
                ],
                if (_fetched && !_loading) ...[
                  const SizedBox(height: 14),
                  // ── Date range display banner ──────────────────────────────
                  _DateBanner(
                    label: 'Report Period',
                    value: '${_fmtDisp(_fromDate)}  →  ${_fmtDisp(_toDate)}',
                    icon: Icons.date_range_rounded,
                    color: _primary,
                  ),
                  const SizedBox(height: 10),
                  _summaryStrip(),
                  const SizedBox(height: 12),
                  _searchBar(),
                  const SizedBox(height: 12),
                  _table(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Date Range',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateField(
                'From',
                _fromDate,
                _fmtDisp,
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
              child: _DateField(
                'To',
                _toDate,
                _fmtDisp,
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
              final n = DateTime.now();
              setState(() {
                _fromDate = DateTime(n.year, n.month, 1);
                _toDate = n;
              });
            }),
            _QuickChip('Last Month', () {
              final n = DateTime.now();
              setState(() {
                _fromDate = DateTime(n.year, n.month - 1, 1);
                _toDate = DateTime(n.year, n.month, 0);
              });
            }),
            _QuickChip(
              'Last 30 Days',
              () => setState(() {
                _toDate = DateTime.now();
                _fromDate = _toDate.subtract(const Duration(days: 29));
              }),
            ),
            _QuickChip('Last 3 Months', () {
              final n = DateTime.now();
              setState(() {
                _fromDate = DateTime(n.year, n.month - 2, 1);
                _toDate = n;
              });
            }),
          ],
        ),
      ],
    ),
  );

  Widget _actionRow() => Row(
    children: [
      Expanded(
        child: _Btn(
          label: 'Fetch Data',
          icon: Icons.refresh_rounded,
          color: _primary,
          loading: _loading,
          onTap: _fetch,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Btn(
          label: 'Download Excel',
          icon: Icons.download_rounded,
          color: _accent,
          loading: false,
          enabled: _fetched && !_loading,
          onTap: _download,
        ),
      ),
    ],
  );

  Widget _summaryStrip() {
    final totalPresent = _data.fold(0, (s, e) => s + e.presentDays);
    final totalAbsent = _data.fold(0, (s, e) => s + e.absentDays);
    final totalLate = _data.fold(0, (s, e) => s + e.lateDays);
    final avgPct = _data.isEmpty
        ? 0.0
        : _data.fold(0.0, (s, e) => s + e.percentage) / _data.length;
    return Row(
      children: [
        _StatChip(
          icon: Icons.people_alt_rounded,
          label: 'Employees',
          value: '${_data.length}',
          color: _primary,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.check_circle_rounded,
          label: 'Total Present',
          value: '$totalPresent',
          color: _accent,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.cancel_rounded,
          label: 'Total Absent',
          value: '$totalAbsent',
          color: _red,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.timelapse_rounded,
          label: 'Late Days',
          value: '$totalLate',
          color: _amber,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.percent_rounded,
          label: 'Avg %',
          value: '${avgPct.toStringAsFixed(1)}%',
          color: _purple,
        ),
      ],
    );
  }

  Widget _searchBar() => _Card(
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search employee by name or ID…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );

  Widget _errorCard() => Container(
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
            _error!,
            style: const TextStyle(fontSize: 12, color: _red),
          ),
        ),
      ],
    ),
  );

  Widget _table() {
    final rows = _filtered;
    if (rows.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: _textMid.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No records found.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: _hdr1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                'Employee Attendance Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rows.length} employee${rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _divCol),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            color: Colors.white,
          ),
          child: ScrollConfiguration(
            behavior: _DragScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTableContent(rows),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableContent(List<_EmpSummary> rows) {
    const cols = [
      ('S.No', 55.0, true),
      ('Emp ID', 88.0, true),
      ('Employee Name', 210.0, false),
      ('Working\nDays', 92.0, true),
      ('Present', 92.0, true),
      ('Absent', 92.0, true),
      ('Leave', 82.0, true),
      ('Late\nDays', 84.0, true),
      ('Late\nHrs', 84.0, true),
      ('Comp\nOff', 84.0, true),
      ('Leave\nBal', 90.0, true),
      ('Att %', 82.0, true),
      ('Status', 108.0, true),
    ];
    Widget hdrCell(String label, double w, bool center) => Container(
      width: w,
      height: 50,
      color: _hdr2,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
        maxLines: 2,
      ),
    );
    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);
    final totalW = cols.fold(0.0, (s, c) => s + c.$2) + (cols.length - 1);
    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < cols.length; i++) ...[
              hdrCell(cols[i].$1, cols[i].$2, cols[i].$3),
              if (i < cols.length - 1) div(),
            ],
          ],
        ),
        hdiv(totalW),
        for (int idx = 0; idx < rows.length; idx++) ...[
          _summaryRow(rows[idx], idx, cols),
          hdiv(totalW),
        ],
      ],
    );
  }

  Widget _summaryRow(
    _EmpSummary emp,
    int idx,
    List<(String, double, bool)> cols,
  ) {
    final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);
    const rowH = 44.0;
    Widget div() => Container(width: 1, color: _divCol);
    Widget cell(
      String text,
      double w, {
      Color? bg,
      Color? fg,
      bool bold = false,
      bool center = true,
    }) => Container(
      width: w,
      height: rowH,
      color: bg ?? rowBg,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: fg ?? _textDark,
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );

    Color pctBg, pctFg;
    String statusLabel;
    Color statusBg, statusFg;
    if (emp.percentage >= 90) {
      pctBg = const Color(0xFFDCFCE7);
      pctFg = const Color(0xFF16A34A);
      statusLabel = 'Excellent';
      statusBg = pctBg;
      statusFg = pctFg;
    } else if (emp.percentage >= 75) {
      pctBg = const Color(0xFFE0F2FE);
      pctFg = const Color(0xFF0369A1);
      statusLabel = 'Good';
      statusBg = pctBg;
      statusFg = pctFg;
    } else if (emp.percentage >= 50) {
      pctBg = const Color(0xFFFEF3C7);
      pctFg = const Color(0xFFB45309);
      statusLabel = 'Average';
      statusBg = pctBg;
      statusFg = pctFg;
    } else {
      pctBg = const Color(0xFFFEE2E2);
      pctFg = const Color(0xFFDC2626);
      statusLabel = 'Low';
      statusBg = pctBg;
      statusFg = pctFg;
    }

    return Row(
      children: [
        cell('${idx + 1}', cols[0].$2),
        div(),
        cell(emp.empId.toString(), cols[1].$2, fg: _primary, bold: true),
        div(),
        cell(emp.name, cols[2].$2, center: false, bold: true),
        div(),
        cell('${emp.totalWorkingDays}', cols[3].$2),
        div(),
        cell(
          '${emp.presentDays}',
          cols[4].$2,
          bg: emp.presentDays > 0 ? const Color(0xFFECFDF5) : null,
          fg: emp.presentDays > 0 ? const Color(0xFF16A34A) : _textMid,
          bold: emp.presentDays > 0,
        ),
        div(),
        cell(
          '${emp.absentDays}',
          cols[5].$2,
          bg: emp.absentDays > 0 ? const Color(0xFFFEF2F2) : null,
          fg: emp.absentDays > 0 ? const Color(0xFFDC2626) : _textMid,
          bold: emp.absentDays > 0,
        ),
        div(),
        cell(
          emp.leaveDays > 0 ? emp.leaveDays.toStringAsFixed(1) : '0',
          cols[6].$2,
          bg: emp.leaveDays > 0 ? const Color(0xFFFFE4E6) : null,
          fg: emp.leaveDays > 0 ? const Color(0xFFBE123C) : _textMid,
        ),
        div(),
        cell(
          '${emp.lateDays}',
          cols[7].$2,
          bg: emp.lateDays > 0 ? const Color(0xFFFEF3C7) : null,
          fg: emp.lateDays > 0 ? const Color(0xFFB45309) : _textMid,
        ),
        div(),
        cell(
          emp.lateMinutes > 0 ? emp.lateHrsFormatted : '-',
          cols[8].$2,
          bg: emp.lateMinutes > 0 ? const Color(0xFFFEF3C7) : null,
          fg: emp.lateMinutes > 0 ? const Color(0xFFB45309) : _textMid,
        ),
        div(),
        cell(
          '${emp.compOffDays}',
          cols[9].$2,
          bg: emp.compOffDays > 0 ? const Color(0xFFFFFBEB) : null,
          fg: emp.compOffDays > 0 ? const Color(0xFF92400E) : _textMid,
        ),
        div(),
        cell(
          emp.leaveBalance.toStringAsFixed(1),
          cols[10].$2,
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF0369A1),
          bold: true,
        ),
        div(),
        cell(
          '${emp.percentage.toStringAsFixed(1)}%',
          cols[11].$2,
          bg: pctBg,
          fg: pctFg,
          bold: true,
        ),
        div(),
        cell(statusLabel, cols[12].$2, bg: statusBg, fg: statusFg, bold: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Day-Wise
// ─────────────────────────────────────────────────────────────────────────────
class _DailyTab extends StatefulWidget {
  const _DailyTab();
  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _date = DateTime.now();

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<_EmpDaily> _data = [];
  bool _isHoliday = false;
  bool _isWeekend = false;
  String? _holidayName;
  String _search = '';

  String _fmtDisp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtFile(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  String _dayName(DateTime d) => [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ][d.weekday % 7];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await _ReportService.fetchDaily(_date);
      final List rows = body['data'] ?? [];
      setState(() {
        _data = rows
            .map((r) => _EmpDaily.fromJson(r as Map<String, dynamic>))
            .toList();
        _isHoliday = body['is_holiday'] == true;
        _isWeekend = body['is_weekend'] == true;
        _holidayName = body['holiday_name']?.toString();
        _fetched = true;
        _search = '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_data.isEmpty) {
      _snack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final excel = _ExcelBuilder.buildDaily(_data, _date);
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel');
      final name = 'Attendance_Daily_${_fmtFile(_date)}';
      await _saveExcel(bytes, name);
      _snack('Downloaded: $name.xlsx');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
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

  List<_EmpDaily> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.name.toLowerCase().contains(_search.toLowerCase()) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker card
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              'Date',
                              _date,
                              _fmtDisp,
                              _pickDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Quick nav arrows
                          _NavBtn(
                            Icons.chevron_left_rounded,
                            () => setState(
                              () => _date = _date.subtract(
                                const Duration(days: 1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _NavBtn(Icons.chevron_right_rounded, () {
                            final next = _date.add(const Duration(days: 1));
                            if (!next.isAfter(DateTime.now()))
                              setState(() => _date = next);
                          }),
                          const SizedBox(width: 6),
                          _NavBtn(
                            Icons.today_rounded,
                            () => setState(() => _date = DateTime.now()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Action row
                Row(
                  children: [
                    Expanded(
                      child: _Btn(
                        label: 'Fetch Data',
                        icon: Icons.refresh_rounded,
                        color: _primary,
                        loading: _loading,
                        onTap: _fetch,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Btn(
                        label: 'Download Excel',
                        icon: Icons.download_rounded,
                        color: _accent,
                        loading: false,
                        enabled: _fetched && !_loading,
                        onTap: _download,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _red,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 12, color: _red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_fetched && !_loading) ...[
                  const SizedBox(height: 14),
                  // ── Date banner (with day name) ──────────────────────────
                  _DateBanner(
                    label: _dayName(_date),
                    value: _fmtDisp(_date),
                    icon: Icons.event_rounded,
                    color: _isHoliday
                        ? const Color(0xFF0369A1)
                        : _isWeekend
                        ? _purple
                        : _primary,
                    suffix: _isHoliday
                        ? '  🎉 ${_holidayName ?? 'Holiday'}'
                        : _isWeekend
                        ? '  🏖 Weekend'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  // Stats
                  _dailyStrip(),
                  const SizedBox(height: 12),
                  // Search
                  _Card(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 13, color: _textDark),
                      decoration: const InputDecoration(
                        hintText: 'Search employee by name or ID…',
                        hintStyle: TextStyle(color: _textMid, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _textMid,
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dailyTable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dailyStrip() {
    final present = _data.where((e) => e.status == 'Present').length;
    final absent = _data.where((e) => e.status == 'Absent').length;
    final onLeave = _data.where((e) => e.status == 'Leave').length;
    final late = _data.where((e) => e.isLate).length;
    final compOff = _data.where((e) => e.compOffEarned).length;
    return Row(
      children: [
        _StatChip(
          icon: Icons.people_alt_rounded,
          label: 'Total',
          value: '${_data.length}',
          color: _primary,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.check_circle_rounded,
          label: 'Present',
          value: '$present',
          color: _accent,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.cancel_rounded,
          label: 'Absent',
          value: '$absent',
          color: _red,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.beach_access_rounded,
          label: 'On Leave',
          value: '$onLeave',
          color: const Color(0xFFBE123C),
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.timelapse_rounded,
          label: 'Late',
          value: '$late',
          color: _amber,
        ),
        const SizedBox(width: 8),
        _StatChip(
          icon: Icons.star_rounded,
          label: 'Comp-Off',
          value: '$compOff',
          color: _purple,
        ),
      ],
    );
  }

  Widget _dailyTable() {
    final rows = _filtered;
    if (rows.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: _textMid.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No records found.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const cols = [
      ('S.No', 52.0, true),
      ('Emp ID', 70.0, true),
      ('Employee Name', 190.0, false),
      ('Check In', 80.0, true),
      ('Check Out', 80.0, true),
      ('Worked Hrs', 80.0, true),
      ('Status', 90.0, true),
      ('Late', 55.0, true),
      ('Late By', 75.0, true),
      ('Comp-Off', 75.0, true),
      ('Holiday', 140.0, false),
    ];

    Widget hdrCell(String label, double w, bool center) => Container(
      width: w,
      height: 44,
      color: _hdr2,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
        textAlign: center ? TextAlign.center : TextAlign.left,
        maxLines: 2,
      ),
    );
    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);
    final totalW = cols.fold(0.0, (s, c) => s + c.$2) + (cols.length - 1);

    Widget rowW(_EmpDaily emp, int idx) {
      final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);
      const rowH = 38.0;
      Widget cell(
        String text,
        double w, {
        Color? bg,
        Color? fg,
        bool bold = false,
        bool center = true,
      }) => Container(
        width: w,
        height: rowH,
        color: bg ?? rowBg,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: fg ?? _textDark,
          ),
          textAlign: center ? TextAlign.center : TextAlign.left,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      );

      final Map<String, (Color, Color)> statusBg = {
        'Present': (const Color(0xFFECFDF5), const Color(0xFF16A34A)),
        'Absent': (const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
        'Leave': (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
        'Holiday': (const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
        'Weekend': (const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
      };
      final sc = statusBg[emp.status] ?? (rowBg, _textDark);

      return Row(
        children: [
          cell('${idx + 1}', cols[0].$2),
          div(),
          cell(emp.empId.toString(), cols[1].$2, fg: _primary, bold: true),
          div(),
          cell(emp.name, cols[2].$2, center: false, bold: true),
          div(),
          cell(
            emp.checkIn ?? '-',
            cols[3].$2,
            fg: emp.checkIn != null ? _accent : _textMid,
          ),
          div(),
          cell(
            emp.checkOut ?? '-',
            cols[4].$2,
            fg: emp.checkOut != null ? _accent : _textMid,
          ),
          div(),
          cell(emp.workedFormatted, cols[5].$2),
          div(),
          cell(emp.status, cols[6].$2, bg: sc.$1, fg: sc.$2, bold: true),
          div(),
          cell(
            emp.isLate ? 'Yes' : 'No',
            cols[7].$2,
            bg: emp.isLate ? const Color(0xFFFEF3C7) : null,
            fg: emp.isLate ? const Color(0xFFB45309) : _textMid,
            bold: emp.isLate,
          ),
          div(),
          cell(
            emp.lateFormatted,
            cols[8].$2,
            fg: emp.lateMinutes > 0 ? const Color(0xFFB45309) : _textMid,
          ),
          div(),
          cell(
            emp.compOffEarned ? '✓ Yes' : '-',
            cols[9].$2,
            fg: emp.compOffEarned ? const Color(0xFF92400E) : _textMid,
            bold: emp.compOffEarned,
          ),
          div(),
          cell(
            emp.holidayName ?? '-',
            cols[10].$2,
            center: false,
            fg: const Color(0xFF0369A1),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: _hdr1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text(
                'Day-Wise Attendance Register',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${rows.length} employee${rows.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _divCol),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            color: Colors.white,
          ),
          child: ScrollConfiguration(
            behavior: _DragScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < cols.length; i++) ...[
                        hdrCell(cols[i].$1, cols[i].$2, cols[i].$3),
                        if (i < cols.length - 1) div(),
                      ],
                    ],
                  ),
                  hdiv(totalW),
                  for (int idx = 0; idx < rows.length; idx++) ...[
                    rowW(rows[idx], idx),
                    hdiv(totalW),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Excel save helper
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _saveExcel(List<int> bytes, String name) async {
  if (kIsWeb) {
    await FileSaver.instance.saveFile(
      name: name,
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  } else {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
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

class _DateBanner extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? suffix;
  const _DateBanner({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value + (suffix ?? ''),
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final String Function(DateTime) fmt;
  final VoidCallback onTap;
  const _DateField(this.label, this.date, this.fmt, this.onTap);
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Icon(icon, size: 18, color: _primary),
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

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading, enabled;
  final VoidCallback onTap;
  const _Btn({
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
