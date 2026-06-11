import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/api_client.dart';
import '../models/report_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Date helpers
// ─────────────────────────────────────────────────────────────────────────────

String fmtApi(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtDisplay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtFile(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────────────────────────────────────────────────────────
// Report Service — API calls
// ─────────────────────────────────────────────────────────────────────────────

class ReportService {
  // ── Departments ────────────────────────────────────────────────────────────

  static Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await ApiClient.get('/departments');
    _assertOk(res, 'departments');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final List rows = body['data'] ?? [];
    return rows
        .map((r) => DepartmentModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Matrix (monthly grid) ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchMatrix(
    DateTime from,
    DateTime to, {
    int? departmentId,
    String mode = 'normal',
  }) async {
    final dept = departmentId != null ? '&department_id=$departmentId' : '';
    final res = await ApiClient.get(
      '/attendance/report/matrix?from=${fmtApi(from)}&to=${fmtApi(to)}$dept&mode=$mode',
    );
    _assertOk(res, 'matrix');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Daily ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchDaily(
    DateTime date, {
    int? departmentId,
    String mode = 'normal',
  }) async {
    final dept = departmentId != null ? '&department_id=$departmentId' : '';
    final res = await ApiClient.get(
      '/attendance/report/daily?date=${fmtApi(date)}$dept&mode=$mode',
    );
    _assertOk(res, 'daily');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Excel exports ──────────────────────────────────────────────────────────

  static Future<void> exportMatrix(
    List<MatrixEmp> data,
    List<MatrixDate> dates,
    DateTime from,
    DateTime to,
  ) async {
    final excel = MatrixExcelBuilder.build(data, dates, from, to);
    final name = 'Attendance_Matrix_${fmtFile(from)}_to_${fmtFile(to)}';
    await _saveExcel(excel, name);
  }

  // ── Normal daily export (existing logic, renamed) ─────────────────────────

  static Future<void> _exportDailyNormal(
    List<EmpDaily> data,
    DateTime date,
  ) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Daily Report'];
    excel.delete('Sheet1');

    // ── Title row ─────────────────────────────────────────────────────────
    const lastCol = 10;
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = xl.TextCellValue(
      'Daily Attendance Report  |  ${fmtDisplay(date)}',
    );
    titleCell.cellStyle = xl.CellStyle(
      bold: true,
      fontSize: 13,
      fontFamily: 'Arial',
      backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
      fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: xl.HorizontalAlign.Center,
      verticalAlign: xl.VerticalAlign.Center,
    );
    sheet.setRowHeight(0, 28);

    // ── Header row ────────────────────────────────────────────────────────
    const headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Department',
      'Check In',
      'Check Out',
      'Worked\nHrs',
      'Status',
      'Late',
      'Late By',
      'Comp-Off\nEarned',
    ];
    const headerColors = [
      'FF1E3A8A', // S.No
      'FF1E3A8A', // Emp ID
      'FF1E3A8A', // Employee Name
      'FF1D4ED8', // Department
      'FF0369A1', // Check In
      'FF0369A1', // Check Out
      'FF16A34A', // Worked Hrs
      'FF1E3A8A', // Status
      'FFB45309', // Late
      'FFB45309', // Late By
      'FFD97706', // Comp-Off Earned
    ];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
      );
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 9,
        fontFamily: 'Arial',
        backgroundColorHex: xl.ExcelColor.fromHexString(headerColors[c]),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
        textWrapping: xl.TextWrapping.WrapText,
      );
    }
    sheet.setRowHeight(1, 30);

    // ── Data rows ─────────────────────────────────────────────────────────
    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final rowIdx = i + 2;
      final rowBg = i.isEven ? 'FFFFFF' : 'F8FAFF';
      final statusColors = {
        'Present': ('FFECFDF5', 'FF16A34A'),
        'Absent': ('FFFEF2F2', 'FFDC2626'),
        'Leave': ('FFFFE4E6', 'FFBE123C'),
        'Holiday': ('FFE0F2FE', 'FF0369A1'),
        'Weekend': ('FFF5F3FF', 'FF7C3AED'),
        'Comp-Off': ('FFFFF7ED', 'FFD97706'),
      };
      final sc = statusColors[emp.status] ?? (rowBg, 'FF000000');

      final cellDefs = [
        // (value, bgHex, fgHex, bold, leftAlign)
        ('${i + 1}', rowBg, 'FF000000', false, false),
        ('${emp.empId}', rowBg, 'FF1A56DB', true, false),
        (emp.name, rowBg, 'FF0F172A', true, true),
        (emp.department, rowBg, 'FF0F172A', false, true),
        (
          _fmtTimeForExcel(emp.checkIn),
          rowBg,
          emp.checkIn != null ? 'FF0369A1' : 'FF94A3B8',
          false,
          false,
        ),
        (
          _fmtTimeForExcel(emp.checkOut),
          rowBg,
          emp.checkOut != null ? 'FF0369A1' : 'FF94A3B8',
          false,
          false,
        ),
        (
          emp.workedFormatted,
          rowBg,
          emp.workedMinutes > 0 ? 'FF16A34A' : 'FF94A3B8',
          false,
          false,
        ),
        (emp.status, sc.$1, sc.$2, true, false),
        (
          emp.isLate ? 'Yes' : 'No',
          emp.isLate ? 'FFFEF3C7' : rowBg,
          emp.isLate ? 'FFB45309' : 'FF94A3B8',
          emp.isLate,
          false,
        ),
        (
          emp.lateFormatted,
          emp.lateMinutes > 0 ? 'FFFEF3C7' : rowBg,
          emp.lateMinutes > 0 ? 'FFB45309' : 'FF94A3B8',
          false,
          false,
        ),
        (
          emp.compOffEarned ? 'Yes' : 'No',
          emp.compOffEarned ? 'FFFFFBEB' : rowBg,
          emp.compOffEarned ? 'FF92400E' : 'FF94A3B8',
          emp.compOffEarned,
          false,
        ),
      ];

      for (int c = 0; c < cellDefs.length; c++) {
        final def = cellDefs[c];
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        );
        cell.value = xl.TextCellValue(def.$1);
        cell.cellStyle = xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString(def.$2),
          fontColorHex: xl.ExcelColor.fromHexString(def.$3),
          bold: def.$4,
          fontSize: 9,
          fontFamily: 'Arial',
          verticalAlign: xl.VerticalAlign.Center,
          horizontalAlign: def.$5
              ? xl.HorizontalAlign.Left
              : xl.HorizontalAlign.Center,
        );
      }
    }

    // ── Column widths ─────────────────────────────────────────────────────
    final widths = [
      8.0,
      10.0,
      24.0,
      20.0,
      12.0,
      12.0,
      14.0,
      14.0,
      8.0,
      16.0,
      20.0,
    ];
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    await _saveExcel(excel, 'Daily_Report_${fmtFile(date)}.xlsx');
  }

  // ── Site-entry daily export ───────────────────────────────────────────────

  static Future<void> _exportDailySiteEntry(
    List<EmpDaily> data,
    DateTime date,
  ) async {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Site Attendance'];
    excel.delete('Sheet1');

    // ── Column definitions (order matches your spec) ──────────────────────
    // S.No | Emp ID | Name | Dept | Status | Session | Site Name |
    // Check In | Check Out | Worked | Pause | Session Status |
    // Comp-Off | Late | Total Worked
    const headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Department',
      'Status',
      'Session\n#',
      'Site Name',
      'Check In',
      'Check Out',
      'Work Time',
      'Pause',
      'Session\nStatus',
      'Comp-Off\nEarned',
      'Late /\nLate By',
      'Total\nWorked',
    ];
    const widths = [
      6.0, // S.No
      10.0, // Emp ID
      24.0, // Name
      18.0, // Department
      12.0, // Status
      9.0, // Session #
      22.0, // Site Name
      14.0, // Check In
      14.0, // Check Out
      13.0, // Work Time
      10.0, // Pause
      13.0, // Session Status
      12.0, // Comp-Off
      14.0, // Late / Late By
      14.0, // Total Worked
    ];

    // ── Title row ─────────────────────────────────────────────────────────
    final lastCol = headers.length - 1;
    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: 0),
    );
    final titleCell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = xl.TextCellValue(
      'Site Attendance Report  |  ${fmtDisplay(date)}',
    );
    titleCell.cellStyle = xl.CellStyle(
      bold: true,
      fontSize: 13,
      fontFamily: 'Arial',
      backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
      fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
      horizontalAlign: xl.HorizontalAlign.Center,
      verticalAlign: xl.VerticalAlign.Center,
    );
    sheet.setRowHeight(0, 28);

    // ── Header row ────────────────────────────────────────────────────────
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1),
      );
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = xl.CellStyle(
        bold: true,
        fontSize: 9,
        fontFamily: 'Arial',
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        horizontalAlign: xl.HorizontalAlign.Center,
        verticalAlign: xl.VerticalAlign.Center,
        textWrapping: xl.TextWrapping.WrapText,
      );
    }
    sheet.setRowHeight(1, 30);

    // ── Column widths ─────────────────────────────────────────────────────
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    // ── Data ──────────────────────────────────────────────────────────────
    int rowIdx = 2;
    int sno = 1;

    for (final emp in data) {
      final sessions = emp.siteSessions;
      final totalWork = _sumWorkForExport(sessions);

      // Late info (shared across all session rows for this employee)
      final lateStr = emp.isLate ? 'Yes / ${emp.lateFormatted}' : 'No';

      // Comp-off (shared)
      final coStr = emp.compOffEarned ? 'Yes' : 'No';

      if (sessions.isEmpty) {
        // ── No sessions — single absent/no-checkin row ──────────────────
        final values = [
          '$sno',
          '${emp.empId}',
          emp.name,
          emp.department,
          emp.status,
          '-', // Session #
          '-', // Site Name
          '-', // Check In
          '-', // Check Out
          '-', // Work Time
          '-', // Pause
          '-', // Session Status
          coStr,
          lateStr,
          '-', // Total Worked
        ];
        for (int c = 0; c < values.length; c++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
          );
          cell.value = xl.TextCellValue(values[c]);
          cell.cellStyle = xl.CellStyle(
            fontSize: 9,
            fontFamily: 'Arial',
            backgroundColorHex: xl.ExcelColor.fromHexString('FFFEF2F2'),
            fontColorHex: xl.ExcelColor.fromHexString('FF000000'),
            horizontalAlign: c == 2 || c == 3 || c == 6
                ? xl.HorizontalAlign.Left
                : xl.HorizontalAlign.Center,
            verticalAlign: xl.VerticalAlign.Center,
          );
        }
        rowIdx++;
        sno++;
        continue;
      }

      // ── Employee has sessions ──────────────────────────────────────────
      for (int si = 0; si < sessions.length; si++) {
        final s = sessions[si];
        final isFirst = si == 0;
        final rowBg = isFirst
            ? 'FFEEF2FF'
            : (si.isEven ? 'FFFFFFFF' : 'FFF8FAFF');

        // Pause formatted
        String pauseStr = '-';
        if (s.totalPauseSecs > 0) {
          final ph = s.totalPauseSecs ~/ 3600;
          final pm = (s.totalPauseSecs % 3600) ~/ 60;
          final ps = s.totalPauseSecs % 60;
          if (ph > 0) {
            pauseStr = pm > 0 ? '${ph}h ${pm}m' : '${ph}h';
          } else if (pm > 0) {
            pauseStr = ps > 0 ? '${pm}m ${ps}s' : '${pm}m';
          } else {
            pauseStr = '${ps}s';
          }
        }

        final values = [
          isFirst ? '$sno' : '',
          isFirst ? '${emp.empId}' : '',
          isFirst ? emp.name : '',
          isFirst ? emp.department : '',
          isFirst ? emp.status : '',
          '${si + 1}', // Session #
          s.siteName ?? 'Unknown Site',
          _fmtTimeForExcel(s.checkIn),
          _fmtTimeForExcel(s.checkOut),
          _fmtWorkTimeForExcel(s.totalWorkTime), // Work Time
          pauseStr,
          s.status == 'active' ? 'Active' : 'Completed',
          '', // Comp-Off — shown in footer only
          '', // Late — shown in footer only
          '',
        ];

        for (int c = 0; c < values.length; c++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
          );
          cell.value = xl.TextCellValue(values[c]);
          cell.cellStyle = xl.CellStyle(
            fontSize: 9,
            fontFamily: 'Arial',
            backgroundColorHex: xl.ExcelColor.fromHexString(rowBg),
            bold: isFirst && c < 5,
            fontColorHex: xl.ExcelColor.fromHexString(
              _siteCellColor(c, s, emp, isFirst),
            ),
            horizontalAlign: c == 2 || c == 3 || c == 6
                ? xl.HorizontalAlign.Left
                : xl.HorizontalAlign.Center,
            verticalAlign: xl.VerticalAlign.Center,
          );
        }
        rowIdx++;
      }

      // ── Per-employee summary footer row ───────────────────────────────
      final footerValues = List.filled(headers.length, '');
      footerValues[2] =
          '${sessions.length} session${sessions.length == 1 ? '' : 's'}';
      footerValues[12] = coStr;
      footerValues[13] = lateStr;
      footerValues[14] = totalWork;

      for (int c = 0; c < footerValues.length; c++) {
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        );
        cell.value = xl.TextCellValue(footerValues[c]);
        cell.cellStyle = xl.CellStyle(
          fontSize: 9,
          fontFamily: 'Arial',
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('FFF0F4FF'),
          fontColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
          horizontalAlign: c == 2
              ? xl.HorizontalAlign.Left
              : xl.HorizontalAlign.Center,
          verticalAlign: xl.VerticalAlign.Center,
          topBorder: xl.Border(
            borderStyle: xl.BorderStyle.Thin,
            borderColorHex: xl.ExcelColor.fromHexString('FF93C5FD'),
          ),
        );
      }
      rowIdx++;
      sno++;
    }

    await _saveExcel(excel, 'Site_Attendance_${fmtFile(date)}.xlsx');
  }

  /// Returns font color hex for site-entry cells based on column semantics
  static String _siteCellColor(
    int c,
    SiteSession s,
    EmpDaily emp,
    bool isFirst,
  ) {
    if (c == 7 || c == 8) return 'FF0369A1'; // Check In / Out — blue
    if (c == 9) return 'FF16A34A'; // Work Time — green
    if (c == 10 && s.totalPauseSecs > 0) return 'FFB45309'; // Pause — amber
    if (c == 11)
      return s.status == 'active' ? 'FF16A34A' : 'FF6B7280'; // Session status
    if (c == 12 && isFirst)
      return emp.compOffEarned ? 'FF92400E' : 'FF6B7280'; // CO
    if (c == 13 && isFirst) return emp.isLate ? 'FFDC2626' : 'FF6B7280'; // Late
    if (c == 14 && isFirst) return 'FF1E3A8A'; // Total worked — dark blue
    return 'FF000000';
  }
  // ── Excel-specific helpers ────────────────────────────────────────────────

  static String _fmtTimeForExcel(String? dt) {
    if (dt == null) return '-';
    try {
      final p = dt.split(' ');
      if (p.length < 2) return dt;
      final tp = p[1].split(':');
      final h = int.parse(tp[0]);
      final m = int.parse(tp[1]);
      final s = tp.length >= 3 ? int.parse(tp[2]) : 0;
      final hh = h % 12 == 0 ? 12 : h % 12;
      final mm = m.toString().padLeft(2, '0');
      final ss = s.toString().padLeft(2, '0');
      return '$hh:$mm:$ss ${h < 12 ? 'AM' : 'PM'}';
    } catch (_) {
      return dt.length >= 19 ? dt.substring(11, 19) : dt;
    }
  }

  static String _fmtWorkTimeForExcel(String? t) {
    if (t == null) return '-';
    final p = t.split(':');
    if (p.length < 2) return t;
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    final s = p.length >= 3 ? (int.tryParse(p[2]) ?? 0) : 0;
    if (h == 0 && m == 0 && s == 0) return '-';
    if (h == 0 && m == 0) return '${s}s';
    if (h == 0) return '${m}m ${s}s';
    if (m == 0 && s == 0) return '${h}h';
    if (s == 0) return '${h}h ${m}m';
    return '${h}h ${m}m ${s}s';
  }

  static String _sumWorkForExport(List<SiteSession> sessions) {
    int totalSecs = 0;
    for (final s in sessions) {
      if (s.totalWorkTime != null) {
        final p = s.totalWorkTime!.split(':');
        if (p.length >= 2) {
          totalSecs += (int.tryParse(p[0]) ?? 0) * 3600;
          totalSecs += (int.tryParse(p[1]) ?? 0) * 60;
          if (p.length >= 3) totalSecs += int.tryParse(p[2]) ?? 0;
        }
      }
    }
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h == 0 && m == 0 && s == 0) return '-';
    if (h == 0 && m == 0) return '${s}s';
    if (h == 0) return '${m}m ${s}s';
    if (m == 0 && s == 0) return '${h}h';
    if (s == 0) return '${h}h ${m}m';
    return '${h}h ${m}m ${s}s';
  }

  static Future<void> exportDaily(
    List<EmpDaily> data,
    DateTime date, {
    String mode = 'normal',
  }) async {
    if (mode == 'site_entry') {
      await _exportDailySiteEntry(data, date);
    } else {
      await _exportDailyNormal(data, date);
    }
  }
  // ── Internal ───────────────────────────────────────────────────────────────

  static void _assertOk(dynamic res, String label) {
    if (res.statusCode != 200) {
      throw Exception('$label: server error ${res.statusCode}');
    }
  }

  static Future<void> _saveExcel(xl.Excel excel, String name) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel');
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
      await OpenFilex.open(file.path);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Excel style helpers
// ─────────────────────────────────────────────────────────────────────────────

xl.CellStyle _hdrStyle({String hex = 'FF1E3A8A'}) => xl.CellStyle(
  backgroundColorHex: xl.ExcelColor.fromHexString(hex),
  fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
  bold: true,
  fontSize: 10,
  fontFamily: 'Arial',
  horizontalAlign: xl.HorizontalAlign.Center,
  verticalAlign: xl.VerticalAlign.Center,
  textWrapping: xl.TextWrapping.WrapText,
);

xl.CellStyle _cellStyle({
  bool bold = false,
  bool center = false,
  String bg = 'FFFFFFFF',
  String fg = 'FF000000',
}) => xl.CellStyle(
  backgroundColorHex: xl.ExcelColor.fromHexString(bg),
  fontColorHex: xl.ExcelColor.fromHexString(fg),
  fontSize: 9,
  fontFamily: 'Arial',
  bold: bold,
  horizontalAlign: center ? xl.HorizontalAlign.Center : xl.HorizontalAlign.Left,
  verticalAlign: xl.VerticalAlign.Center,
);

xl.CellStyle _titleStyle() => xl.CellStyle(
  backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
  fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
  bold: true,
  fontSize: 13,
  fontFamily: 'Arial',
  horizontalAlign: xl.HorizontalAlign.Center,
  verticalAlign: xl.VerticalAlign.Center,
);

xl.CellStyle _subtitleStyle() => xl.CellStyle(
  backgroundColorHex: xl.ExcelColor.fromHexString('FFE8F0FE'),
  fontColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
  fontSize: 9,
  fontFamily: 'Arial',
  horizontalAlign: xl.HorizontalAlign.Center,
  verticalAlign: xl.VerticalAlign.Center,
);

/// Percentage-based color pair (bg, fg)
(String, String) _pctColor(double pct) {
  if (pct >= 90) return ('FFDCFCE7', 'FF16A34A');
  if (pct >= 75) return ('FFE0F2FE', 'FF0369A1');
  if (pct >= 50) return ('FFFEF3C7', 'FFB45309');
  return ('FFFEE2E2', 'FFDC2626');
}

void _setCell(
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

void _mergeRow(xl.Sheet s, int row, int fromCol, int toCol) {
  s.merge(
    xl.CellIndex.indexByColumnRow(columnIndex: fromCol, rowIndex: row),
    xl.CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
  );
}

// Status cell colors for matrix: P A L H W C
const Map<String, (String, String)> _statusColors = {
  'P': ('FFECFDF5', 'FF16A34A'),
  'A': ('FFFEF2F2', 'FFDC2626'),
  'L': ('FFFFE4E6', 'FFBE123C'),
  'H': ('FFE0F2FE', 'FF0369A1'),
  'W': ('FFF5F3FF', 'FF7C3AED'),
  'C': ('FFFFF7ED', 'FFD97706'), // ← NEW: amber/orange tint
};

// ─────────────────────────────────────────────────────────────────────────────
// Matrix Excel Builder
// ─────────────────────────────────────────────────────────────────────────────

class MatrixExcelBuilder {
  static xl.Excel build(
    List<MatrixEmp> data,
    List<MatrixDate> dates,
    DateTime from,
    DateTime to,
  ) {
    final excel = xl.Excel.createExcel();
    const sheet = 'Matrix Report';
    excel.rename('Sheet1', sheet);
    final s = excel[sheet];

    // Cols: S.No | EmpID | Name | [dates] | P | A | L | CO | COE | COU | COX | LvA | LvR | Att%
    // index:  0      1      2       3..N    N+3  N+4  N+5  N+6  N+7  N+8  N+9  N+10  N+11  N+12
    final n = dates.length;
    final lastCol = 2 + n + 11; // 0-based

    // Row 0 — title
    _mergeRow(s, 0, 0, lastCol);
    _setCell(
      s,
      0,
      0,
      'Attendance Matrix Report  |  ${fmtDisplay(from)}  to  ${fmtDisplay(to)}',
      _titleStyle(),
    );
    s.setRowHeight(0, 28);

    // Row 1 — legend
    _mergeRow(s, 1, 0, lastCol);
    _setCell(
      s,
      1,
      0,
      'P=Present  A=Absent  L=Leave  H=Holiday  W=Weekend  C=Comp-Off  '
      'COE=CO Earned  COU=CO Used  COX=CO Expired  LvA=Lv Approved  LvR=Lv Rejected',
      _subtitleStyle(),
    );
    s.setRowHeight(1, 16);

    // Row 2 — day-name sub-header
    _setCell(s, 2, 0, '', _hdrStyle());
    _setCell(s, 2, 1, '', _hdrStyle());
    _setCell(s, 2, 2, '', _hdrStyle());
    for (int i = 0; i < n; i++) {
      final d = dates[i];
      final bg = d.isHoliday
          ? 'FF1D4ED8'
          : d.isWeekend
          ? 'FF7C3AED'
          : 'FF1E3A8A';
      _setCell(s, 2, 3 + i, d.dayLabel, _hdrStyle(hex: bg));
    }
    for (int c = 0; c < 10; c++) _setCell(s, 2, 3 + n + c, '', _hdrStyle());
    s.setRowHeight(2, 16);

    // Row 3 — column headers
    _setCell(s, 3, 0, 'S.No', _hdrStyle());
    _setCell(s, 3, 1, 'Emp ID', _hdrStyle());
    _setCell(s, 3, 2, 'Employee Name', _hdrStyle());
    for (int i = 0; i < n; i++) {
      final d = dates[i];
      final bg = d.isHoliday
          ? 'FF1D4ED8'
          : d.isWeekend
          ? 'FF7C3AED'
          : 'FF2563EB';
      _setCell(s, 3, 3 + i, '${d.dayOfMonth}', _hdrStyle(hex: bg));
    }
    _setCell(s, 3, 3 + n, 'Present', _hdrStyle());
    _setCell(s, 3, 4 + n, 'Absent', _hdrStyle());
    _setCell(s, 3, 5 + n, 'Leave', _hdrStyle());
    _setCell(s, 3, 7 + n, 'CO Earned', _hdrStyle(hex: 'FFD97706'));
    _setCell(s, 3, 8 + n, 'CO Used', _hdrStyle(hex: 'FFB45309'));
    _setCell(s, 3, 9 + n, 'CO Expired', _hdrStyle(hex: 'FFDC2626'));
    _setCell(s, 3, 10 + n, 'Lv App', _hdrStyle(hex: 'FF16A34A'));
    _setCell(s, 3, 11 + n, 'Lv Rej', _hdrStyle(hex: 'FFDC2626'));
    _setCell(s, 3, 12 + n, 'Att %', _hdrStyle());
    s.setRowHeight(3, 22);

    // Column widths
    s.setColumnWidth(0, 5.0);
    s.setColumnWidth(1, 9.0);
    s.setColumnWidth(2, 22.0);
    for (int i = 0; i < n; i++) s.setColumnWidth(3 + i, 4.2);
    for (int c = 0; c < 10; c++) s.setColumnWidth(3 + n + c, 9.0);

    // Data rows
    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final row = i + 4;
      final rowBg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';

      _setCell(s, row, 0, i + 1, _cellStyle(center: true, bg: rowBg));
      _setCell(s, row, 1, emp.empId, _cellStyle(center: true, bg: rowBg));
      _setCell(s, row, 2, emp.name, _cellStyle(bg: rowBg));

      for (int j = 0; j < emp.days.length; j++) {
        final status = emp.days[j];
        final c = _statusColors[status] ?? (rowBg, 'FF000000');
        _setCell(
          s,
          row,
          3 + j,
          status,
          _cellStyle(
            center: true,
            bg: c.$1,
            fg: c.$2,
            bold: status == 'P' || status == 'C',
          ),
        );
      }

      final pct = _pctColor(emp.percentage);

      _setCell(
        s,
        row,
        3 + n,
        emp.presentDays,
        _cellStyle(center: true, bg: 'FFECFDF5', fg: 'FF16A34A', bold: true),
      );
      _setCell(
        s,
        row,
        4 + n,
        emp.absentDays,
        _cellStyle(
          center: true,
          bg: emp.absentDays > 0 ? 'FFFEF2F2' : rowBg,
          fg: emp.absentDays > 0 ? 'FFDC2626' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        5 + n,
        emp.leaveDays,
        _cellStyle(
          center: true,
          bg: emp.leaveDays > 0 ? 'FFFFE4E6' : rowBg,
          fg: emp.leaveDays > 0 ? 'FFBE123C' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        6 + n,
        emp.compOffDays,
        _cellStyle(
          center: true,
          bg: emp.compOffDays > 0 ? 'FFFFF7ED' : rowBg,
          fg: emp.compOffDays > 0 ? 'FFD97706' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        7 + n,
        emp.compOffEarned,
        _cellStyle(
          center: true,
          bg: emp.compOffEarned > 0 ? 'FFFFF7ED' : rowBg,
          fg: emp.compOffEarned > 0 ? 'FFD97706' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        8 + n,
        emp.compOffUsed,
        _cellStyle(
          center: true,
          bg: emp.compOffUsed > 0 ? 'FFFEF3C7' : rowBg,
          fg: emp.compOffUsed > 0 ? 'FFB45309' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        9 + n,
        emp.compOffExpired,
        _cellStyle(
          center: true,
          bg: emp.compOffExpired > 0 ? 'FFFEE2E2' : rowBg,
          fg: emp.compOffExpired > 0 ? 'FFDC2626' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        10 + n,
        emp.leaveApproved,
        _cellStyle(
          center: true,
          bg: emp.leaveApproved > 0 ? 'FFECFDF5' : rowBg,
          fg: emp.leaveApproved > 0 ? 'FF16A34A' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        11 + n,
        emp.leaveRejected,
        _cellStyle(
          center: true,
          bg: emp.leaveRejected > 0 ? 'FFFEE2E2' : rowBg,
          fg: emp.leaveRejected > 0 ? 'FFDC2626' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        12 + n,
        '${emp.percentage.toStringAsFixed(1)}%',
        _cellStyle(center: true, bg: pct.$1, fg: pct.$2, bold: true),
      );

      s.setRowHeight(row, 18);
    }

    return excel;
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Daily Excel Builder
// ─────────────────────────────────────────────────────────────────────────────

class DailyExcelBuilder {
  static xl.Excel build(List<EmpDaily> data, DateTime date) {
    final excel = xl.Excel.createExcel();
    const sheet = 'Daily Report';
    excel.rename('Sheet1', sheet);
    final s = excel[sheet];

    // Cols 0-10: SNo EmpID Name In Out Hrs Status Late LateBy CO-Today Holiday
    const lastCol = 10;

    _mergeRow(s, 0, 0, lastCol);
    _setCell(
      s,
      0,
      0,
      'Day-Wise Attendance Report  |  ${fmtDisplay(date)}',
      _titleStyle(),
    );
    s.setRowHeight(0, 30);

    _mergeRow(s, 1, 0, lastCol);
    _setCell(
      s,
      1,
      0,
      'Date: ${fmtDisplay(date)}   (Normal attendance only)',
      _subtitleStyle(),
    );
    s.setRowHeight(1, 18);

    const headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Check In',
      'Check Out',
      'Worked Hrs',
      'Status',
      'Late',
      'Late By',
      'Comp-Off\nEarned Today',
      'Holiday',
    ];
    for (int c = 0; c < headers.length; c++)
      _setCell(s, 2, c, headers[c], _hdrStyle());
    s.setRowHeight(2, 30);

    const widths = [
      6.0,
      9.0,
      24.0,
      13.0, // Check In (wider for HH:MM:SS AM)
      13.0, // Check Out
      13.0, // Worked Hrs (wider for 8h 30m 15s)
      12.0,
      8.0,
      12.0, // Late By
      12.0,
      18.0,
    ];
    for (int c = 0; c < widths.length; c++) s.setColumnWidth(c, widths[c]);

    for (int i = 0; i < data.length; i++) {
      final emp = data[i];
      final row = i + 3;
      final rowBg = i.isEven ? 'FFFFFFFF' : 'FFF8FAFF';
      final sc = _dailyStatusColors[emp.status] ?? (rowBg, 'FF000000');

      _setCell(s, row, 0, i + 1, _cellStyle(center: true, bg: rowBg));
      _setCell(s, row, 1, emp.empId, _cellStyle(center: true, bg: rowBg));
      _setCell(s, row, 2, emp.name, _cellStyle(bg: rowBg));
      _setCell(
        s,
        row,
        3,
        emp.checkIn ?? '-',
        _cellStyle(center: true, bg: rowBg),
      );
      _setCell(
        s,
        row,
        4,
        emp.checkOut ?? '-',
        _cellStyle(center: true, bg: rowBg),
      );
      _setCell(
        s,
        row,
        5,
        emp.workedFormatted,
        _cellStyle(center: true, bg: rowBg),
      );
      _setCell(
        s,
        row,
        6,
        emp.status,
        _cellStyle(center: true, bg: sc.$1, fg: sc.$2, bold: true),
      );
      _setCell(
        s,
        row,
        7,
        emp.isLate ? 'Yes' : 'No',
        _cellStyle(
          center: true,
          bg: emp.isLate ? 'FFFEF3C7' : rowBg,
          fg: emp.isLate ? 'FFB45309' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        8,
        emp.lateFormatted,
        _cellStyle(
          center: true,
          bg: emp.lateMinutes > 0 ? 'FFFEF3C7' : rowBg,
          fg: emp.lateMinutes > 0 ? 'FFB45309' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        9,
        emp.compOffEarned ? 'Yes' : 'No',
        _cellStyle(
          center: true,
          bg: emp.compOffEarned ? 'FFFFFBEB' : rowBg,
          fg: emp.compOffEarned ? 'FF92400E' : 'FF000000',
        ),
      );
      _setCell(
        s,
        row,
        10,
        emp.holidayName ?? '-',
        _cellStyle(bg: rowBg, fg: 'FF0369A1'),
      );

      s.setRowHeight(row, 20);
    }

    // Totals row
    if (data.isNotEmpty) {
      final tr = data.length + 3;
      final present = data.where((e) => e.status == 'Present').length;
      final absent = data.where((e) => e.status == 'Absent').length;
      final onLeave = data.where((e) => e.status == 'Leave').length;
      final compOff = data.where((e) => e.status == 'Comp-Off').length;
      final late = data.where((e) => e.isLate).length;

      _mergeRow(s, tr, 0, 2);
      final ts = xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1D4ED8'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 9,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      );
      _setCell(s, tr, 0, 'TOTALS', ts);
      _setCell(s, tr, 3, '-', ts);
      _setCell(s, tr, 4, '-', ts);
      _setCell(s, tr, 5, '-', ts);
      _setCell(s, tr, 6, 'P:$present  A:$absent  L:$onLeave  C:$compOff', ts);
      _setCell(s, tr, 7, '$late', ts);
      _setCell(s, tr, 8, '-', ts);
      _setCell(s, tr, 9, '-', ts);
      _setCell(s, tr, 10, '${data.length} Emp', ts);
      s.setRowHeight(tr, 22);
    }

    return excel;
  }

  static const Map<String, (String, String)> _dailyStatusColors = {
    'Present': ('FFECFDF5', 'FF16A34A'),
    'Absent': ('FFFEF2F2', 'FFDC2626'),
    'Leave': ('FFFFE4E6', 'FFBE123C'),
    'Holiday': ('FFE0F2FE', 'FF0369A1'),
    'Weekend': ('FFF5F3FF', 'FF7C3AED'),
    'Comp-Off': ('FFFFF7ED', 'FFD97706'),
  };
}
