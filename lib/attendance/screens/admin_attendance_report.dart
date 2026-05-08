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

const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _purple = Color(0xFF7C3AED);
const Color _surface = Color(0xFFF0F4FF);
const Color _card = Colors.white;
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _border = Color(0xFFE2E8F0);

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class _Visit {
  final String locationName;
  final DateTime? inTime;
  final DateTime? outTime;
  final int workedMinutes;

  _Visit({
    required this.locationName,
    required this.inTime,
    required this.outTime,
    required this.workedMinutes,
  });

  String get workedFormatted {
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get inFmt => inTime == null ? '--:--' : _fmtTime(inTime!);
  String get outFmt => outTime == null ? '--:--' : _fmtTime(outTime!);
  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _EmpDay {
  final int empId;
  final String empName;
  final DateTime date;
  final List<_Visit> visits;
  final bool isLate;
  final int lateMinutes;
  final String? lateText;

  _EmpDay({
    required this.empId,
    required this.empName,
    required this.date,
    required this.visits,
    this.isLate = false,
    this.lateMinutes = 0,
    this.lateText,
  });

  int get totalMinutes => visits.fold(0, (s, v) => s + v.workedMinutes);

  String get totalFormatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class _Holiday {
  final DateTime date;
  final String name;
  final String type;
  _Holiday({required this.date, required this.name, required this.type});
}

class _ApprovedLeave {
  final int empId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  _ApprovedLeave({
    required this.empId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
  });

  bool coversDate(DateTime d) => !d.isBefore(startDate) && !d.isAfter(endDate);

  String get shortLabel {
    switch (leaveType.toLowerCase()) {
      case 'sick':
        return 'SL';
      case 'casual':
        return 'CL';
      case 'paid':
        return 'PL';
      case 'maternity':
        return 'ML';
      case 'paternity':
        return 'PTL';
      default:
        return 'LOP';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _ReportService {
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<List<_Holiday>> fetchHolidays(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final res = await ApiClient.get(
        '/holidays/range?from=${_fmt(from)}&to=${_fmt(to)}',
      );
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final List rows = body['data'] ?? [];
      return rows
          .map(
            (r) => _Holiday(
              date: DateTime.parse(
                (r['holiday_date'] as String).substring(0, 10),
              ),
              name: r['holiday_name']?.toString() ?? '',
              type: r['holiday_type']?.toString() ?? '',
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('fetchHolidays error: $e');
      return [];
    }
  }

  static Future<List<_ApprovedLeave>> fetchApprovedLeaves(
    DateTime from,
    DateTime to,
  ) async {
    try {
      final res = await ApiClient.get(
        '/leaves/approved-range?from=${_fmt(from)}&to=${_fmt(to)}',
      );
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final List rows = body['data'] ?? [];
      return rows
          .map(
            (r) => _ApprovedLeave(
              empId: int.parse(r['emp_id'].toString()),
              leaveType: r['leave_type']?.toString() ?? 'LOP',
              startDate: DateTime.parse(
                (r['leave_start_date'] as String).substring(0, 10),
              ),
              endDate: DateTime.parse(
                (r['leave_end_date'] as String).substring(0, 10),
              ),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('fetchApprovedLeaves error: $e');
      return [];
    }
  }

  static Future<List<_EmpDay>> fetchRange(DateTime from, DateTime to) async {
    final List<_EmpDay> result = [];
    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      try {
        final res = await ApiClient.get(
          '/attendance/by-date-detail?date=${_fmt(d)}',
        );
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final List rows = (body is Map ? body['data'] : null) ?? [];
        for (final row in rows) {
          if (row is! Map) continue;
          final rawId = row['emp_id'];
          final empId = rawId == null
              ? 0
              : rawId is num
              ? rawId.toInt()
              : int.tryParse(rawId.toString()) ?? 0;
          final empName = row['name']?.toString().trim() ?? '';
          List<_Visit> flatVisits = [];
          bool isLate = false;
          int lateMinutes = 0;
          String? lateText;
          final rawSessions = row['sessions'];
          if (rawSessions is List && rawSessions.isNotEmpty) {
            for (int si = 0; si < rawSessions.length; si++) {
              final sess = rawSessions[si];
              if (sess is! Map) continue;
              if (si == 0) {
                isLate = sess['is_late'] == true || sess['is_late'] == 1;
                lateMinutes = (sess['late_minutes'] as num?)?.toInt() ?? 0;
                lateText = sess['late_text']?.toString();
              }
              final sessionVisits = sess['visits'];
              if (sessionVisits is! List) continue;
              for (final v in sessionVisits) {
                final visit = _parseVisit(v, d);
                if (visit != null) flatVisits.add(visit);
              }
            }
          } else {
            final rawVisits = row['visits'];
            if (rawVisits is List) {
              for (final v in rawVisits) {
                final visit = _parseVisit(v, d);
                if (visit != null) flatVisits.add(visit);
              }
            }
          }

          // ── GUARD: skip employees with no data at all ──────────────
          if (empId == 0 && empName.isEmpty) continue;

          result.add(
            _EmpDay(
              empId: empId,
              empName: empName,
              date: d, // always use the loop date, never trust API date
              visits: flatVisits,
              isLate: isLate,
              lateMinutes: lateMinutes,
              lateText: lateText,
            ),
          );
        }
      } catch (e) {
        debugPrint('fetchRange error for $d: $e');
        continue;
      }
    }
    return result;
  }

  static _Visit? _parseVisit(dynamic v, DateTime date) {
    if (v is! Map) return null;
    final locationName =
        (v['site_name'] ?? v['location_name'])?.toString() ?? 'Unknown';
    final inRaw = v['in_time'];
    final outRaw = v['out_time'];
    final rawMins = v['worked_minutes'];
    int mins = 0;
    if (rawMins is num) {
      mins = rawMins.toInt();
    } else if (rawMins is String) {
      mins = int.tryParse(rawMins) ?? 0;
    }
    if (mins < 0) mins = 0;
    return _Visit(
      locationName: locationName,
      inTime: inRaw != null ? _parseTime(inRaw.toString(), date) : null,
      outTime: outRaw != null ? _parseTime(outRaw.toString(), date) : null,
      workedMinutes: mins,
    );
  }

  static DateTime? _parseTime(String t, DateTime date) {
    try {
      if (t.contains('T') || t.contains('-')) return DateTime.parse(t);
      final parts = t.split(':');
      if (parts.length < 2) return null;
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
        parts.length > 2 ? int.parse(parts[2]) : 0,
      );
    } catch (_) {
      return null; // show --:-- instead of 00:00
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXCEL BUILDER
// ─────────────────────────────────────────────────────────────────────────────
class _ExcelBuilder {
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

  static xl.CellStyle _subHdrStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFD1E9FF'),
    bold: true,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    fontSize: 9,
    fontFamily: 'Arial',
  );

  static xl.CellStyle _cellStyle({bool bold = false, bool center = false}) =>
      xl.CellStyle(
        fontSize: 9,
        fontFamily: 'Arial',
        bold: bold,
        horizontalAlign: center
            ? xl.HorizontalAlign.Center
            : xl.HorizontalAlign.Left,
        verticalAlign: xl.VerticalAlign.Center,
      );

  static xl.CellStyle _totalStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFECFDF5'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static xl.CellStyle _lateStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFFEF3C7'),
    fontColorHex: xl.ExcelColor.fromHexString('FFB45309'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static xl.CellStyle _holidayStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFEDE9FE'),
    fontColorHex: xl.ExcelColor.fromHexString('FF6D28D9'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
  );

  static xl.CellStyle _compOffStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFFFF3CD'),
    fontColorHex: xl.ExcelColor.fromHexString('FF92400E'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
  );

  static xl.CellStyle _leaveStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFFFE4E6'),
    fontColorHex: xl.ExcelColor.fromHexString('FFBe123C'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static xl.CellStyle _sundayStyle() => xl.CellStyle(
    backgroundColorHex: xl.ExcelColor.fromHexString('FFE5E7EB'),
    fontColorHex: xl.ExcelColor.fromHexString('FF6B7280'),
    bold: true,
    fontSize: 9,
    fontFamily: 'Arial',
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
  );

  static void _setCell(
    xl.Sheet sheet,
    int row,
    int col,
    dynamic value, [
    xl.CellStyle? style,
  ]) {
    final cell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value is int
        ? xl.IntCellValue(value)
        : value is double
        ? xl.DoubleCellValue(value)
        : xl.TextCellValue(value?.toString() ?? '');
    if (style != null) cell.cellStyle = style;
  }

  // ── DAY-WISE ──────────────────────────────────────────────────────────────
  static xl.Excel buildDayWise(
    List<_EmpDay> data,
    DateTime from,
    DateTime to,
    List<_Holiday> holidays,
    List<_ApprovedLeave> leaves,
  ) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Day-Wise Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final Set<String> holidayDates = holidays
        .map((h) => _fmtDate(h.date))
        .toSet();

    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0),
    );
    _setCell(
      sheet,
      0,
      0,
      'Attendance Day-Wise Report  |  ${_fmtDate(from)} to ${_fmtDate(to)}',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 12,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );
    sheet.setRowHeight(0, 28);

    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Date',
      'Site Name',
      'Check In',
      'Check Out',
      'Total Hrs',
      'Remarks',
    ];
    for (int c = 0; c < headers.length; c++) {
      _setCell(sheet, 1, c, headers[c], _hdrStyle());
    }
    sheet.setRowHeight(1, 22);

    final widths = [6.0, 9.0, 22.0, 13.0, 22.0, 12.0, 12.0, 12.0, 22.0];
    for (int c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c]);
    }

    int sno = 1, row = 2;
    data.sort((a, b) {
      final dc = a.date.compareTo(b.date);
      return dc != 0 ? dc : a.empId.compareTo(b.empId);
    });

    for (final day in data) {
      final dk = _fmtDate(day.date);
      final isHoliday = holidayDates.contains(dk);
      final isSunday = day.date.weekday == DateTime.sunday;
      final workedOnHoliday = isHoliday && day.visits.isNotEmpty;
      final workedOnSunday = isSunday && day.visits.isNotEmpty && !isHoliday;

      final leaveOnDay = leaves
          .where((l) => l.empId == day.empId && l.coversDate(day.date))
          .firstOrNull;

      if (day.visits.isEmpty) {
        if (isSunday && !isHoliday) {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
            xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row),
          );
          _setCell(sheet, row, 0, 'Sunday  (${day.empName})', _sundayStyle());
        } else if (isHoliday) {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
            xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row),
          );
          _setCell(sheet, row, 0, 'Holiday  (${day.empName})', _holidayStyle());
        } else {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
            xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
          );
          final label = leaveOnDay != null ? leaveOnDay.shortLabel : 'A';
          final remarkText = leaveOnDay != null
              ? '${leaveOnDay.leaveType} Leave'
              : 'Absent';
          _setCell(
            sheet,
            row,
            0,
            '${day.empName} (ID: ${day.empId})  —  $dk',
            leaveOnDay != null ? _leaveStyle() : _cellStyle(),
          );
          _setCell(
            sheet,
            row,
            7,
            label,
            leaveOnDay != null ? _leaveStyle() : _cellStyle(center: true),
          );
          _setCell(
            sheet,
            row,
            8,
            remarkText,
            leaveOnDay != null ? _leaveStyle() : _cellStyle(),
          );
        }
        sheet.setRowHeight(row, 18);
        row++;
        continue;
      }

      final headerBg = (workedOnHoliday || workedOnSunday)
          ? 'FFFFF3CD'
          : day.isLate
          ? 'FFFFF3CD'
          : 'FFE8F0FE';
      final sundayNote = workedOnSunday ? '  — Comp-Off Earned' : '';
      final holidayNote = workedOnHoliday ? '  — Comp-Off Earned' : '';
      final lateNote = day.isLate ? '  Late: ${day.lateText}' : '';
      final headerLabel =
          '${_fmtDateLong(day.date)}  —  ${day.empName}  (ID: ${day.empId})'
          '${workedOnHoliday ? holidayNote : ''}'
          '${workedOnSunday ? sundayNote : ''}'
          '$lateNote';

      sheet.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row),
      );
      _setCell(
        sheet,
        row,
        0,
        headerLabel,
        xl.CellStyle(
          backgroundColorHex: xl.ExcelColor.fromHexString(headerBg),
          bold: true,
          fontSize: 9,
          fontFamily: 'Arial',
        ),
      );
      sheet.setRowHeight(row, 18);
      row++;

      for (int vi = 0; vi < day.visits.length; vi++) {
        final v = day.visits[vi];
        String remarks = '';
        xl.CellStyle cellStyle;

        if ((workedOnHoliday || workedOnSunday) && vi == 0) {
          remarks = workedOnHoliday
              ? 'Worked on Holiday — CO Earned'
              : 'Worked on Sunday — CO Earned';
          cellStyle = _compOffStyle();
        } else if (day.isLate && vi == 0) {
          remarks = 'Late by ${day.lateText}';
          cellStyle = _lateStyle();
        } else {
          cellStyle = _cellStyle(center: true);
        }

        _setCell(sheet, row, 0, sno, _cellStyle(center: true));
        _setCell(sheet, row, 1, day.empId, _cellStyle(center: true));
        _setCell(sheet, row, 2, day.empName, _cellStyle());
        _setCell(sheet, row, 3, dk, _cellStyle(center: true));
        _setCell(sheet, row, 4, v.locationName, _cellStyle());
        _setCell(sheet, row, 5, v.inFmt, _cellStyle(center: true));
        _setCell(sheet, row, 6, v.outFmt, _cellStyle(center: true));
        _setCell(sheet, row, 7, v.workedFormatted, cellStyle);
        _setCell(
          sheet,
          row,
          8,
          remarks,
          remarks.isNotEmpty
              ? ((workedOnHoliday || workedOnSunday) && vi == 0
                    ? _compOffStyle()
                    : _lateStyle())
              : _cellStyle(),
        );

        if (vi == day.visits.length - 1 && day.visits.length > 1) {
          sheet.merge(
            xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row + 1),
            xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row + 1),
          );
          _setCell(
            sheet,
            row + 1,
            0,
            'Total for ${day.empName} on $dk',
            _totalStyle(),
          );
          _setCell(sheet, row + 1, 8, day.totalFormatted, _totalStyle());
          row++;
        }
        row++;
        sno++;
      }
    }
    return excel;
  }

  static int _hrsToMins(String time) {
    if (time.isEmpty) return 0;
    // Handle "1hr 6min" / "30min" / "2hr" format (lateText format)
    final hrMatch = RegExp(r'(\d+)\s*hr').firstMatch(time);
    final minMatch = RegExp(r'(\d+)\s*min').firstMatch(time);
    if (hrMatch != null || minMatch != null) {
      final h = hrMatch != null ? int.parse(hrMatch.group(1)!) : 0;
      final m = minMatch != null ? int.parse(minMatch.group(1)!) : 0;
      return h * 60 + m;
    }
    // Fallback: handle "H:M" format
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  // ── MONTHLY ───────────────────────────────────────────────────────────────
  static xl.Excel buildMonthly(
    List<_EmpDay> data,
    DateTime from,
    DateTime to,
    List<_Holiday> holidays,
    List<_ApprovedLeave> leaves,
  ) {
    final excel = xl.Excel.createExcel();
    const sheetName = 'Monthly Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final List<DateTime> dates = [];
    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      dates.add(d);
    }

    final Set<String> holidayDates = holidays
        .map((h) => _fmtDate(h.date))
        .toSet();

    final Map<int, String> empNames = {};
    final Map<int, Map<String, int>> empDateMins = {};

    for (final day in data) {
      empNames[day.empId] = day.empName;
      if (day.visits.isNotEmpty) {
        empDateMins.putIfAbsent(day.empId, () => {});
        final dk = _fmtDate(day.date);
        final total = day.visits.fold(0, (s, v) => s + v.workedMinutes);
        empDateMins[day.empId]![dk] =
            (empDateMins[day.empId]![dk] ?? 0) + total;
      }
    }

    final Map<int, Map<String, String?>> lateLookup = {};
    for (final day in data) {
      if (day.isLate) {
        lateLookup.putIfAbsent(day.empId, () => {});
        lateLookup[day.empId]![_fmtDate(day.date)] = day.lateText;
      }
    }

    final totalCols = 4 + dates.length + 9;

    sheet.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 0),
    );

    _setCell(
      sheet,
      0,
      0,
      'Attendance Monthly Report  |  ${_fmtDate(from)} to ${_fmtDate(to)}',
      xl.CellStyle(
        backgroundColorHex: xl.ExcelColor.fromHexString('FF1E3A8A'),
        fontColorHex: xl.ExcelColor.fromHexString('FFFFFFFF'),
        bold: true,
        fontSize: 12,
        fontFamily: 'Arial',
        horizontalAlign: xl.HorizontalAlign.Center,
      ),
    );

    // Fixed headers
    final fixedHeaders = ['S.No', 'Emp ID', 'Employee Name', 'Sites'];
    for (int c = 0; c < fixedHeaders.length; c++) {
      _setCell(sheet, 1, c, fixedHeaders[c], _hdrStyle());
    }

    // ── DATE COLUMN HEADERS — only date number; H for holiday, Sun for Sunday ──
    for (int di = 0; di < dates.length; di++) {
      final dk = _fmtDate(dates[di]);
      final isHoliday = holidayDates.contains(dk);
      final isSunday = dates[di].weekday == DateTime.sunday;

      final label = isHoliday
          ? '${dates[di].day}\nH'
          : isSunday
          ? '${dates[di].day}\nSun'
          : '${dates[di].day}';

      _setCell(sheet, 1, 4 + di, label, _subHdrStyle());
    }

    // Summary headers
    _setCell(sheet, 1, 4 + dates.length, 'Total\nWork Hrs', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 1, 'Avg\nWork Hrs', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 2, 'Total\nDays', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 3, 'Present', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 4, 'Absent', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 5, 'Late\nDays', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 6, 'Late\nHrs', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 7, 'CO', _hdrStyle());
    _setCell(sheet, 1, 4 + dates.length + 8, 'Leave', _hdrStyle());

    int row = 2;
    int sno = 1;

    final sortedEmpIds = empNames.keys.toList()..sort();

    for (final empId in sortedEmpIds) {
      final name = empNames[empId] ?? '';
      final dateMap = empDateMins[empId] ?? {};

      int totalDays = 0;
      int presentDays = 0;
      int absentDays = 0;
      int lateDays = 0;
      int lateMins = 0;
      int compOffDays = 0;
      int leaveDays = 0;
      int totalMins = 0;

      _setCell(sheet, row, 0, sno, _cellStyle(center: true));
      _setCell(sheet, row, 1, empId, _cellStyle(center: true));
      _setCell(sheet, row, 2, name, _cellStyle());

      for (int di = 0; di < dates.length; di++) {
        final dk = _fmtDate(dates[di]);
        final isHoliday = holidayDates.contains(dk);
        final isSunday = dates[di].weekday == DateTime.sunday;
        final mins = dateMap[dk] ?? 0;

        final leaveOnDay = leaves
            .where((l) => l.empId == empId && l.coversDate(dates[di]))
            .firstOrNull;

        totalMins += mins;

        if (!isSunday && !isHoliday) totalDays++;

        if (mins > 0) {
          if (!isSunday && !isHoliday) presentDays++;

          final isLate = lateLookup[empId]?.containsKey(dk) ?? false;
          if (isLate) {
            lateDays++;
            final lt = lateLookup[empId]?[dk];
            if (lt != null) lateMins += _hrsToMins(lt);
          }

          if (isSunday || isHoliday) compOffDays++;
        }

        if (mins == 0 && !isSunday && !isHoliday) {
          if (leaveOnDay != null) {
            leaveDays++;
          } else {
            absentDays++;
          }
        }

        // Cell render
        if (mins > 0) {
          _setCell(
            sheet,
            row,
            4 + di,
            _minsToHrs(mins),
            _cellStyle(center: true),
          );
        } else if (isHoliday) {
          _setCell(sheet, row, 4 + di, 'H', _holidayStyle());
        } else if (isSunday) {
          _setCell(sheet, row, 4 + di, 'SUN', _sundayStyle());
        } else if (leaveOnDay != null) {
          _setCell(sheet, row, 4 + di, leaveOnDay.shortLabel, _leaveStyle());
        } else {
          _setCell(sheet, row, 4 + di, 'A', _cellStyle(center: true));
        }
      }

      final avgMins = presentDays > 0 ? (totalMins / presentDays).round() : 0;

      _setCell(sheet, row, 4 + dates.length, _minsToHrs(totalMins));
      _setCell(
        sheet,
        row,
        4 + dates.length + 1,
        avgMins > 0 ? _minsToHrs(avgMins) : '-',
      );
      _setCell(sheet, row, 4 + dates.length + 2, totalDays);
      _setCell(sheet, row, 4 + dates.length + 3, presentDays);
      _setCell(sheet, row, 4 + dates.length + 4, absentDays);
      _setCell(sheet, row, 4 + dates.length + 5, lateDays);
      _setCell(sheet, row, 4 + dates.length + 6, _minsToHrs(lateMins));
      _setCell(sheet, row, 4 + dates.length + 7, compOffDays);
      _setCell(sheet, row, 4 + dates.length + 8, leaveDays);

      row++;
      sno++;
    }

    return excel;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _fmtDateLong(DateTime d) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  static String _minsToHrs(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
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
  late TabController _tabController;

  DateTime _dayDate = DateTime.now();
  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<_EmpDay> _data = [];
  List<_Holiday> _holidays = [];
  List<_ApprovedLeave> _leaves = [];
  String _searchQuery = '';
  String _filterSite = 'All';

  DateTime _mFromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _mToDate = DateTime.now();
  bool _mLoading = false;
  bool _mFetched = false;
  String? _mError;
  List<_EmpDay> _mData = [];
  List<_Holiday> _mHolidays = [];
  List<_ApprovedLeave> _mLeaves = [];

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
  String _fmtKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDayDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dayDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dayDate = picked);
  }

  Future<void> _pickMonthlyDate(bool isFrom) async {
    final current = isFrom ? _mFromDate : _mToDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
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
        _mFromDate = picked;
        if (_mToDate.isBefore(_mFromDate)) _mToDate = _mFromDate;
      } else {
        _mToDate = picked;
        if (_mFromDate.isAfter(_mToDate)) _mFromDate = _mToDate;
      }
    });
  }

  Future<void> _fetchDayData() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final results = await Future.wait([
        _ReportService.fetchRange(_dayDate, _dayDate),
        _ReportService.fetchHolidays(_dayDate, _dayDate),
        _ReportService.fetchApprovedLeaves(_dayDate, _dayDate),
      ]);
      _data = (results[0] as List<_EmpDay>)
        ..sort((a, b) => a.empName.compareTo(b.empName));
      _holidays = results[1] as List<_Holiday>;
      _leaves = results[2] as List<_ApprovedLeave>;
      setState(() {
        _fetched = true;
        _searchQuery = '';
        _filterSite = 'All';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMonthlyData() async {
    setState(() {
      _mLoading = true;
      _mError = null;
      _mFetched = false;
    });
    try {
      final results = await Future.wait([
        _ReportService.fetchRange(_mFromDate, _mToDate),
        _ReportService.fetchHolidays(_mFromDate, _mToDate),
        _ReportService.fetchApprovedLeaves(_mFromDate, _mToDate),
      ]);
      _mData = results[0] as List<_EmpDay>;
      _mHolidays = results[1] as List<_Holiday>;
      _mLeaves = results[2] as List<_ApprovedLeave>;
      setState(() => _mFetched = true);
    } catch (e) {
      setState(() => _mError = e.toString());
    } finally {
      setState(() => _mLoading = false);
    }
  }

  Future<void> _downloadDayWise() async {
    if (_data.isEmpty) {
      _showSnack('No data to export', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final excel = _ExcelBuilder.buildDayWise(
        _data,
        _dayDate,
        _dayDate,
        _holidays,
        _leaves,
      );
      await _saveAndOpen(excel, 'Attendance_DayWise_${_fmtKey(_dayDate)}.xlsx');
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadMonthly() async {
    if (_mData.isEmpty) {
      _showSnack('No data to export', isError: true);
      return;
    }
    setState(() => _mLoading = true);
    try {
      final excel = _ExcelBuilder.buildMonthly(
        _mData,
        _mFromDate,
        _mToDate,
        _mHolidays,
        _mLeaves,
      );
      await _saveAndOpen(
        excel,
        'Attendance_Monthly_${_fmtKey(_mFromDate)}_to_${_fmtKey(_mToDate)}.xlsx',
      );
    } catch (e) {
      _showSnack('Export failed: $e', isError: true);
    } finally {
      setState(() => _mLoading = false);
    }
  }

  Future<void> _saveAndOpen(xl.Excel excel, String fileName) async {
    final bytes = excel.save();
    if (bytes == null) throw Exception('Failed to generate Excel');
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

  List<String> get _allSites {
    final sites = <String>{};
    for (final d in _data) {
      for (final v in d.visits) {
        sites.add(v.locationName);
      }
    }
    return ['All', ...sites.toList()..sort()];
  }

  List<_EmpDay> get _filteredData => _data.where((d) {
    final matchName =
        _searchQuery.isEmpty ||
        d.empName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        d.empId.toString().contains(_searchQuery);
    final matchSite =
        _filterSite == 'All' ||
        d.visits.any((v) => v.locationName == _filterSite);
    return matchName && matchSite;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _DayWiseTab(
              selectedDate: _dayDate,
              loading: _loading,
              fetched: _fetched,
              error: _error,
              data: _filteredData,
              holidays: _holidays,
              leaves: _leaves,
              searchQuery: _searchQuery,
              filterSite: _filterSite,
              allSites: _allSites,
              fmt: _fmt,
              onPickDate: _pickDayDate,
              onFetch: _fetchDayData,
              onDownload: _downloadDayWise,
              onSearchChange: (v) => setState(() => _searchQuery = v),
              onSiteChange: (v) => setState(() => _filterSite = v ?? 'All'),
              onQuickDate: (d) => setState(() => _dayDate = d),
            ),
            _MonthlyTab(
              fromDate: _mFromDate,
              toDate: _mToDate,
              loading: _mLoading,
              fetched: _mFetched,
              error: _mError,
              data: _mData,
              holidays: _mHolidays,
              leaves: _mLeaves,
              fmt: _fmt,
              onPickFrom: () => _pickMonthlyDate(true),
              onPickTo: () => _pickMonthlyDate(false),
              onFetch: _fetchMonthlyData,
              onDownload: _downloadMonthly,
              onQuickRange: (from, to) => setState(() {
                _mFromDate = from;
                _mToDate = to;
              }),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() => PreferredSize(
    preferredSize: const Size.fromHeight(150),
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
                  const SizedBox(width: 10),
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
                        'Export to Excel',
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
                  icon: Icon(Icons.calendar_today_rounded, size: 16),
                  text: 'Day Wise',
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_rounded, size: 16),
                  text: 'Monthly',
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
// TAB 1 — DAY WISE
// ─────────────────────────────────────────────────────────────────────────────
class _DayWiseTab extends StatelessWidget {
  final DateTime selectedDate;
  final bool loading, fetched;
  final String? error;
  final List<_EmpDay> data;
  final List<_Holiday> holidays;
  final List<_ApprovedLeave> leaves;
  final String searchQuery, filterSite;
  final List<String> allSites;
  final String Function(DateTime) fmt;
  final VoidCallback onPickDate, onFetch, onDownload;
  final ValueChanged<String> onSearchChange;
  final ValueChanged<String?> onSiteChange;
  final ValueChanged<DateTime> onQuickDate;

  const _DayWiseTab({
    required this.selectedDate,
    required this.loading,
    required this.fetched,
    required this.error,
    required this.data,
    required this.holidays,
    required this.leaves,
    required this.searchQuery,
    required this.filterSite,
    required this.allSites,
    required this.fmt,
    required this.onPickDate,
    required this.onFetch,
    required this.onDownload,
    required this.onSearchChange,
    required this.onSiteChange,
    required this.onQuickDate,
  });

  int get _totalEmployees => data.length;
  int get _totalVisits => data.fold(0, (s, e) => s + e.visits.length);
  String get _totalWorked {
    final mins = data.fold<int>(0, (s, e) => s + e.totalMinutes);
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final pad = isWide ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
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
                    const _SectionTitle('Select Date'),
                    const SizedBox(height: 12),
                    isWide
                        ? Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: _DatePickerField(
                                  'Date',
                                  selectedDate,
                                  fmt,
                                  onPickDate,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _QuickChip(
                                'Today',
                                () => onQuickDate(DateTime.now()),
                              ),
                              const SizedBox(width: 8),
                              _QuickChip(
                                'Yesterday',
                                () => onQuickDate(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DatePickerField(
                                'Date',
                                selectedDate,
                                fmt,
                                onPickDate,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _QuickChip(
                                    'Today',
                                    () => onQuickDate(DateTime.now()),
                                  ),
                                  _QuickChip(
                                    'Yesterday',
                                    () => onQuickDate(
                                      DateTime.now().subtract(
                                        const Duration(days: 1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                      loading: loading,
                      onTap: onFetch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: fetched && !loading,
                      onTap: onDownload,
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(error!),
              ],
              if (fetched && !loading) ...[
                const SizedBox(height: 14),
                const _LegendRow(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.people_alt_rounded,
                      label: 'Employees',
                      value: _totalEmployees.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.location_on_rounded,
                      label: 'Total Visits',
                      value: _totalVisits.toString(),
                      color: _purple,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'Total Hrs',
                      value: _totalWorked,
                      color: _accent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Card(
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _SearchField(
                                query: searchQuery,
                                onChanged: onSearchChange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: _DropdownField(
                                label: 'All Sites',
                                value: filterSite,
                                items: allSites,
                                onChanged: onSiteChange,
                                icon: Icons.location_on_rounded,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SearchField(
                              query: searchQuery,
                              onChanged: onSearchChange,
                            ),
                            const SizedBox(height: 10),
                            _DropdownField(
                              label: 'All Sites',
                              value: filterSite,
                              items: allSites,
                              onChanged: onSiteChange,
                              icon: Icons.location_on_rounded,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _DayWiseList(
                  data: data,
                  isWide: isWide,
                  holidays: holidays,
                  leaves: leaves,
                  date: selectedDate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND
// ─────────────────────────────────────────────────────────────────────────────
class _LegendRow extends StatelessWidget {
  const _LegendRow();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      _legendChip('Present', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
      _legendChip('Absent', const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      _legendChip('Late', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      _legendChip(
        'Holiday (H)',
        const Color(0xFF6D28D9),
        const Color(0xFFEDE9FE),
      ),
      _legendChip(
        'CO – Worked on Holiday/Sunday',
        const Color(0xFF92400E),
        const Color(0xFFFFFBEB),
      ),
      _legendChip(
        'Leave (SL/CL/PL…)',
        const Color(0xFFBE123C),
        const Color(0xFFFFE4E6),
      ),
      _legendChip(
        'Sunday (SUN)',
        const Color(0xFF6B7280),
        const Color(0xFFE5E7EB),
      ),
    ],
  );

  Widget _legendChip(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: text.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
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
        hintText: 'Search by name or Emp ID…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _DayWiseList extends StatelessWidget {
  final List<_EmpDay> data;
  final bool isWide;
  final List<_Holiday> holidays;
  final List<_ApprovedLeave> leaves;
  final DateTime date;
  const _DayWiseList({
    required this.data,
    required this.isWide,
    required this.holidays,
    required this.leaves,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dk =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final holiday = holidays.where((h) => _fmtDate(h.date) == dk).firstOrNull;
    final isSunday = date.weekday == DateTime.sunday;

    if (data.isEmpty && holiday == null && !isSunday) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: _textMid.withValues(alpha: 0.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No attendance data found.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final anyoneWorked = data.any((e) => e.visits.isNotEmpty);

    return Column(
      children: [
        if (isSunday && holiday == null)
          _dayBanner(
            Icons.nightlight_round,
            'Sunday – Weekly Off',
            'Employees who worked will earn Comp-Off',
            anyoneWorked,
            const Color(0xFF6B7280),
            const Color(0xFFE5E7EB),
            const Color(0xFF9CA3AF),
          ),
        if (holiday != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: anyoneWorked
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    (anyoneWorked
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF6D28D9))
                        .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  anyoneWorked
                      ? Icons.work_outline_rounded
                      : Icons.celebration_rounded,
                  color: anyoneWorked
                      ? const Color(0xFF92400E)
                      : const Color(0xFF6D28D9),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Show holiday name only in the UI, not in the Excel
                        holiday.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: anyoneWorked
                              ? const Color(0xFF92400E)
                              : const Color(0xFF6D28D9),
                        ),
                      ),
                      Text(
                        anyoneWorked
                            ? '${holiday.type} Holiday — Some employees worked (CO earned)'
                            : '${holiday.type} Holiday',
                        style: TextStyle(
                          fontSize: 11,
                          color: anyoneWorked
                              ? const Color(0xFFB45309)
                              : const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final emp in data) ...[
          _EmpExpandCard(
            emp: emp,
            isWide: isWide,
            leaves: leaves,
            date: date,
            holidays: holidays,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _dayBanner(
    IconData icon,
    String title,
    String subtitle,
    bool anyoneWorked,
    Color textColor,
    Color bgColor,
    Color borderColor,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: anyoneWorked ? const Color(0xFFFFFBEB) : bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (anyoneWorked ? const Color(0xFFF59E0B) : borderColor)
            .withValues(alpha: 0.4),
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: anyoneWorked ? const Color(0xFF92400E) : textColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: anyoneWorked ? const Color(0xFF92400E) : textColor,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: anyoneWorked
                    ? const Color(0xFFB45309)
                    : textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _EmpExpandCard extends StatefulWidget {
  final _EmpDay emp;
  final bool isWide;
  final List<_ApprovedLeave> leaves;
  final List<_Holiday> holidays;
  final DateTime date;
  const _EmpExpandCard({
    required this.emp,
    required this.isWide,
    required this.leaves,
    required this.holidays,
    required this.date,
  });
  @override
  State<_EmpExpandCard> createState() => _EmpExpandCardState();
}

class _EmpExpandCardState extends State<_EmpExpandCard>
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

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final emp = widget.emp;
    final dk = _fmtDate(widget.date);
    final holidayOnDay = widget.holidays
        .where((h) => _fmtDate(h.date) == dk)
        .firstOrNull;
    final isSunday = widget.date.weekday == DateTime.sunday;
    final workedOnHoliday = holidayOnDay != null && emp.visits.isNotEmpty;
    final workedOnSunday =
        isSunday && emp.visits.isNotEmpty && !workedOnHoliday;
    final leaveOnDay = widget.leaves
        .where((l) => l.empId == emp.empId && l.coversDate(widget.date))
        .firstOrNull;
    final hasVisits = emp.visits.isNotEmpty;
    final isAbsent = !hasVisits;

    Color cardBorderColor = _border;
    Color? cardBg;

    if (workedOnHoliday || workedOnSunday) {
      cardBorderColor = const Color(0xFFF59E0B).withValues(alpha: 0.5);
      cardBg = const Color(0xFFFFFBEB);
    } else if (isSunday && isAbsent) {
      cardBorderColor = const Color(0xFF9CA3AF).withValues(alpha: 0.4);
      cardBg = const Color(0xFFE5E7EB);
    } else if (emp.isLate) {
      cardBorderColor = const Color(0xFFF59E0B).withValues(alpha: 0.5);
    } else if (isAbsent && leaveOnDay != null) {
      cardBorderColor = const Color(0xFFBE123C).withValues(alpha: 0.3);
      cardBg = const Color(0xFFFFF1F2);
    } else if (isAbsent) {
      cardBorderColor = _red.withValues(alpha: 0.3);
      cardBg = const Color(0xFFFFF9F9);
    }

    final pillColor = (workedOnHoliday || workedOnSunday)
        ? const Color(0xFF92400E)
        : emp.isLate
        ? const Color(0xFFB45309)
        : _accent;
    final pillBg = (workedOnHoliday || workedOnSunday)
        ? const Color(0xFFFEF3C7)
        : emp.isLate
        ? const Color(0xFFFEF3C7)
        : _accent.withValues(alpha: 0.1);
    final pillBorder = (workedOnHoliday || workedOnSunday || emp.isLate)
        ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
        : _accent.withValues(alpha: 0.25);

    Widget statusBadge;
    if (workedOnHoliday) {
      statusBadge = _statusBadge(
        'CO — Worked on Holiday',
        const Color(0xFF92400E),
        const Color(0xFFFEF3C7),
      );
    } else if (workedOnSunday) {
      statusBadge = _statusBadge(
        'CO — Worked on Sunday',
        const Color(0xFF92400E),
        const Color(0xFFFEF3C7),
      );
    } else if (isSunday && isAbsent) {
      statusBadge = _statusBadge(
        'SUN',
        const Color(0xFF6B7280),
        const Color(0xFFE5E7EB),
      );
    } else if (isAbsent && leaveOnDay != null) {
      statusBadge = _statusBadge(
        leaveOnDay.shortLabel,
        const Color(0xFFBE123C),
        const Color(0xFFFFE4E6),
      );
    } else if (isAbsent) {
      statusBadge = _statusBadge('Absent', _red, const Color(0xFFFEE2E2));
    } else if (emp.isLate) {
      statusBadge = _statusBadge(
        emp.lateText != null ? 'Late ${emp.lateText}' : 'Late',
        const Color(0xFFB45309),
        const Color(0xFFFEF3C7),
      );
    } else {
      statusBadge = _statusBadge('Present', _accent, const Color(0xFFDCFCE7));
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasVisits ? _toggle : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (workedOnHoliday || workedOnSunday)
                          ? const Color(0xFFFEF3C7)
                          : isSunday && isAbsent
                          ? const Color(0xFFE5E7EB)
                          : isAbsent
                          ? (leaveOnDay != null
                                ? const Color(0xFFFFE4E6)
                                : const Color(0xFFFEE2E2))
                          : emp.isLate
                          ? const Color(0xFFFEF3C7)
                          : _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        emp.empName.isNotEmpty
                            ? emp.empName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: (workedOnHoliday || workedOnSunday)
                              ? const Color(0xFF92400E)
                              : isSunday && isAbsent
                              ? const Color(0xFF6B7280)
                              : isAbsent
                              ? (leaveOnDay != null
                                    ? const Color(0xFFBE123C)
                                    : _red)
                              : emp.isLate
                              ? const Color(0xFFB45309)
                              : _primary,
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
                          emp.empName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              'ID: ${emp.empId}  ·  ',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textMid,
                              ),
                            ),
                            statusBadge,
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasVisits) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: pillBorder),
                      ),
                      child: Text(
                        emp.totalFormatted,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pillColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _rotate,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textMid,
                        size: 20,
                      ),
                    ),
                  ],
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
                      if (workedOnHoliday || workedOnSunday)
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFFFFBEB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Color(0xFF92400E),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                workedOnHoliday
                                    ? 'Worked on holiday (${holidayOnDay?.name}) — Comp-Off earned'
                                    : 'Worked on Sunday — Comp-Off earned',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        color: const Color(0xFFF1F5FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: widget.isWide
                            ? const _VisitTableHeaderWide()
                            : const _VisitTableHeaderNarrow(),
                      ),
                      for (int i = 0; i < emp.visits.length; i++)
                        _VisitRowWidget(
                          visit: emp.visits[i],
                          isEven: i.isEven,
                          isWide: widget.isWide,
                          isFirstAndLate:
                              i == 0 &&
                              emp.isLate &&
                              !workedOnHoliday &&
                              !workedOnSunday,
                          isFirstAndHoliday:
                              i == 0 && (workedOnHoliday || workedOnSunday),
                          lateText: emp.lateText,
                        ),
                      if (emp.visits.length > 1)
                        Container(
                          color: const Color(0xFFECFDF5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.summarize_rounded,
                                size: 13,
                                color: _accent,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                emp.totalFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _accent,
                                ),
                              ),
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

  Widget _statusBadge(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: text.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text),
    ),
  );
}

class _VisitTableHeaderWide extends StatelessWidget {
  const _VisitTableHeaderWide();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 3,
        child: Row(children: [const SizedBox(width: 18), _hdr('Site Name')]),
      ),
      Expanded(flex: 2, child: _hdr('In Time', center: true)),
      Expanded(flex: 2, child: _hdr('Out Time', center: true)),
      Expanded(flex: 2, child: _hdr('Work Time', center: true)),
    ],
  );
  Widget _hdr(String t, {bool center = false}) => Text(
    t,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _textMid,
    ),
    textAlign: center ? TextAlign.center : TextAlign.left,
  );
}

class _VisitTableHeaderNarrow extends StatelessWidget {
  const _VisitTableHeaderNarrow();
  @override
  Widget build(BuildContext context) => const Text(
    'Visit Details',
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: _textMid,
    ),
  );
}

class _VisitRowWidget extends StatelessWidget {
  final _Visit visit;
  final bool isEven, isWide, isFirstAndLate, isFirstAndHoliday;
  final String? lateText;
  const _VisitRowWidget({
    required this.visit,
    required this.isEven,
    required this.isWide,
    this.isFirstAndLate = false,
    this.isFirstAndHoliday = false,
    this.lateText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isEven ? Colors.white : const Color(0xFFF8FAFF);
    final holidayBg = const Color(0xFFFFFBEB);
    final lateBg = const Color(0xFFFEF3C7);
    final rowBg = isFirstAndHoliday
        ? holidayBg
        : isFirstAndLate
        ? lateBg
        : bg;
    final timeColor = isFirstAndHoliday
        ? const Color(0xFF92400E)
        : isFirstAndLate
        ? const Color(0xFFB45309)
        : _primary;

    if (isWide) {
      return Container(
        color: rowBg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: _textMid,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      visit.locationName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textDark,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.login_rounded,
                    size: 12,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    visit.inFmt,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    size: 12,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    visit.outFmt,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isFirstAndHoliday || isFirstAndLate)
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : _primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visit.workedFormatted,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: timeColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isFirstAndHoliday || isFirstAndLate)
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: _textMid),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  visit.locationName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isFirstAndHoliday || isFirstAndLate)
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : _primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  visit.workedFormatted,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: timeColor,
                  ),
                ),
              ),
            ],
          ),
          if (isFirstAndHoliday)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '★ Worked on holiday / Sunday — Comp-Off earned',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (isFirstAndLate && lateText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⏰ Late by $lateText',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        size: 12,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        visit.inFmt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: _border,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 12,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          visit.outFmt,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — MONTHLY
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyTab extends StatelessWidget {
  final DateTime fromDate, toDate;
  final bool loading, fetched;
  final String? error;
  final List<_EmpDay> data;
  final List<_Holiday> holidays;
  final List<_ApprovedLeave> leaves;
  final String Function(DateTime) fmt;
  final VoidCallback onPickFrom, onPickTo, onFetch, onDownload;
  final void Function(DateTime from, DateTime to) onQuickRange;

  const _MonthlyTab({
    required this.fromDate,
    required this.toDate,
    required this.loading,
    required this.fetched,
    required this.error,
    required this.data,
    required this.holidays,
    required this.leaves,
    required this.fmt,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onFetch,
    required this.onDownload,
    required this.onQuickRange,
  });

  String get _totalWorked {
    final mins = data.fold<int>(0, (s, e) => s + e.totalMinutes);
    return '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final pad = isWide ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
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
                            fromDate,
                            fmt,
                            onPickFrom,
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
                          child: _DatePickerField('To', toDate, fmt, onPickTo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _QuickChip('This Month', () {
                          final now = DateTime.now();
                          onQuickRange(DateTime(now.year, now.month, 1), now);
                        }),
                        _QuickChip('Last Month', () {
                          final now = DateTime.now();
                          onQuickRange(
                            DateTime(now.year, now.month - 1, 1),
                            DateTime(now.year, now.month, 0),
                          );
                        }),
                        _QuickChip(
                          'Last 30 Days',
                          () => onQuickRange(
                            DateTime.now().subtract(const Duration(days: 29)),
                            DateTime.now(),
                          ),
                        ),
                        _QuickChip('Last 3 Months', () {
                          final now = DateTime.now();
                          onQuickRange(
                            DateTime(now.year, now.month - 2, 1),
                            now,
                          );
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
                      loading: loading,
                      onTap: onFetch,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Button(
                      label: 'Download Excel',
                      icon: Icons.download_rounded,
                      color: _accent,
                      loading: false,
                      enabled: fetched && !loading,
                      onTap: onDownload,
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(error!),
              ],
              if (fetched && !loading) ...[
                const SizedBox(height: 14),
                const _LegendRow(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.people_alt_rounded,
                      label: 'Employees',
                      value: data.map((e) => e.empId).toSet().length.toString(),
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.location_on_rounded,
                      label: 'Total Visits',
                      value: data
                          .fold(0, (s, e) => s + e.visits.length)
                          .toString(),
                      color: _purple,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.timer_outlined,
                      label: 'Total Hrs',
                      value: _totalWorked,
                      color: _accent,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MonthlyPreview(
                  data: data,
                  from: fromDate,
                  to: toDate,
                  holidays: holidays,
                  leaves: leaves,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTHLY PREVIEW
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

class _MonthlyPreview extends StatefulWidget {
  final List<_EmpDay> data;
  final DateTime from, to;
  final List<_Holiday> holidays;
  final List<_ApprovedLeave> leaves;
  const _MonthlyPreview({
    required this.data,
    required this.from,
    required this.to,
    required this.holidays,
    required this.leaves,
  });
  @override
  State<_MonthlyPreview> createState() => _MonthlyPreviewState();
}

class _MonthlyPreviewState extends State<_MonthlyPreview> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _dk(DateTime d) => _fmtDate(d);

  static const double _rowH = 38.0;
  static const double _hdrH1 = 38.0;
  static const double _hdrH2 = 32.0;
  static const double wSno = 44.0;
  static const double wId = 72.0;
  static const double wName = 150.0;
  static const double wDay = 42.0;
  static const double wSummary = 76.0;

  static const Color _hdr1 = Color(0xFF1E3A8A);
  static const Color _hdr2 = Color(0xFF2563EB);
  static const Color _hdr3 = Color(0xFF1D4ED8);
  static const Color _divCol = Color(0xFF93C5FD);
  static const Color _presentBg = Color(0xFFDCFCE7);
  static const Color _absentBg = Color(0xFFFEE2E2);
  static const Color _lateBg = Color(0xFFFEF3C7);
  static const Color _holidayBg = Color(0xFFEDE9FE);
  static const Color _compOffBg = Color(0xFFFFFBEB);
  static const Color _leaveBg = Color(0xFFFFE4E6);
  static const Color _sundayBg = Color(0xFFE5E7EB);

  Widget _vDiv() => Container(width: 1, color: _divCol);
  Widget _hDiv(double w) => Container(height: 1, width: w, color: _divCol);

  Widget _fixCell(
    String t,
    double w,
    double h, {
    Color bg = Colors.white,
    TextStyle? style,
    bool center = true,
    bool isHeader = false,
  }) => Container(
    width: w,
    height: h,
    color: bg,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text(
      t,
      style:
          style ??
          (isHeader
              ? const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                )
              : const TextStyle(fontSize: 10, color: _textDark)),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _scrollCell(
    String t,
    double w,
    double h, {
    Color? bg,
    TextStyle? style,
    bool center = true,
  }) => Container(
    width: w,
    height: h,
    color: bg ?? Colors.transparent,
    alignment: center ? Alignment.center : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Text(
      t,
      style: style ?? const TextStyle(fontSize: 10, color: _textDark),
      textAlign: center ? TextAlign.center : TextAlign.left,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final from = widget.from;
    final to = widget.to;
    final holidays = widget.holidays;
    final leaves = widget.leaves;

    if (data.isEmpty) {
      return _Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 40,
                  color: _textMid.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No data for the selected period.',
                  style: TextStyle(color: _textMid, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final List<DateTime> dates = [];
    for (
      DateTime d = from;
      !d.isAfter(to);
      d = d.add(const Duration(days: 1))
    ) {
      dates.add(d);
    }

    final Set<String> holidayDates = holidays
        .map((h) => _fmtDate(h.date))
        .toSet();

    final Map<int, String> empNames = {};
    final Map<int, Map<String, List<_Visit>>> empDateV = {};
    for (final day in data) {
      empNames[day.empId] = day.empName;
      empDateV.putIfAbsent(day.empId, () => {});
      empDateV[day.empId]![_dk(day.date)] = day.visits;
    }

    final Map<int, Map<String, String?>> lateLookup = {};
    for (final day in data) {
      if (day.isLate) {
        lateLookup.putIfAbsent(day.empId, () => {});
        lateLookup[day.empId]![_dk(day.date)] = day.lateText;
      }
    }

    final sortedEmpIds = empNames.keys.toList()..sort();

    final empStats = <int, _EmpStat>{};
    for (final empId in sortedEmpIds) {
      final dateMap = empDateV[empId] ?? {};
      final statuses = <String>[];
      int present = 0,
          absent = 0,
          holiday = 0,
          lateDays = 0,
          lateMins = 0,
          leaveDays = 0,
          compOffDays = 0;

      for (final d in dates) {
        final dk = _dk(d);
        final isHoliday = holidayDates.contains(dk);
        final isSunday = d.weekday == DateTime.sunday;
        final visits = dateMap[dk];
        final hasVisits = visits != null && visits.isNotEmpty;
        final leaveOnDay = leaves
            .where((l) => l.empId == empId && l.coversDate(d))
            .firstOrNull;
        final isLateOnDay = lateLookup[empId]?.containsKey(dk) ?? false;

        if (isSunday) {
          if (hasVisits) {
            compOffDays++;
            present++;
            statuses.add('CO');
          } else {
            statuses.add('SUN');
          }
        } else if (hasVisits) {
          present++;
          if (isHoliday) {
            compOffDays++;
            statuses.add('CO');
          } else if (isLateOnDay) {
            lateDays++;
            lateMins += lateLookup[empId]![dk] != null
                ? _parseLateMinutes(lateLookup[empId]![dk]!)
                : 0;
            statuses.add('L');
          } else {
            statuses.add('P');
          }
        } else if (isHoliday) {
          holiday++;
          statuses.add('H');
        } else if (leaveOnDay != null) {
          leaveDays++;
          statuses.add(leaveOnDay.shortLabel);
        } else {
          absent++;
          statuses.add('A');
        }
      }

      empStats[empId] = _EmpStat(
        statuses: statuses,
        present: present,
        absent: absent,
        holidays: holiday,
        lateDays: lateDays,
        lateMins: lateMins,
        leaveDays: leaveDays,
        compOffDays: compOffDays,
        totalWorkedMins: (empDateV[empId] ?? {}).values.fold(
          0,
          (s, visits) => s + visits.fold(0, (s2, v) => s2 + v.workedMinutes),
        ),
      );
    }

    final double scrollW = dates.length * wDay + 1 + 8 * wSummary + 7;

    Widget leftPanel() => Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _divCol, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fixCell('S.No', wSno, _hdrH1, bg: _hdr1, isHeader: true),
              _vDiv(),
              _fixCell('Emp ID', wId, _hdrH1, bg: _hdr1, isHeader: true),
              _vDiv(),
              _fixCell('Name', wName, _hdrH1, bg: _hdr1, isHeader: true),
            ],
          ),
          _hDiv(wSno + 1 + wId + 1 + wName),
          Row(
            children: [
              _fixCell('', wSno, _hdrH2, bg: _hdr2),
              _vDiv(),
              _fixCell('', wId, _hdrH2, bg: _hdr2),
              _vDiv(),
              _fixCell('', wName, _hdrH2, bg: _hdr2),
            ],
          ),
          _hDiv(wSno + 1 + wId + 1 + wName),
          for (int idx = 0; idx < sortedEmpIds.length; idx++) ...[
            Builder(
              builder: (_) {
                final empId = sortedEmpIds[idx];
                final name = empNames[empId] ?? '';
                final rowBg = idx.isEven
                    ? Colors.white
                    : const Color(0xFFF8FAFF);
                return Row(
                  children: [
                    _fixCell(
                      '${idx + 1}',
                      wSno,
                      _rowH,
                      bg: rowBg,
                      style: const TextStyle(fontSize: 10, color: _textMid),
                    ),
                    _vDiv(),
                    _fixCell(
                      empId.toString(),
                      wId,
                      _rowH,
                      bg: rowBg,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                    _vDiv(),
                    _fixCell(
                      name,
                      wName,
                      _rowH,
                      bg: rowBg,
                      center: false,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                  ],
                );
              },
            ),
            _hDiv(wSno + 1 + wId + 1 + wName),
          ],
        ],
      ),
    );

    Widget rightPanel() => ScrollConfiguration(
      behavior: _DragScrollBehavior(),
      child: Scrollbar(
        controller: _hScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: dates.length * wDay,
                    height: _hdrH1,
                    color: _hdr1,
                    alignment: Alignment.center,
                    child: Text(
                      '${_fmtDate(from)}  –  ${_fmtDate(to)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _vDiv(),
                  Container(
                    width: 8 * wSummary + 7,
                    height: _hdrH1,
                    color: _hdr3,
                    alignment: Alignment.center,
                    child: const Text(
                      'Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              _hDiv(scrollW),
              Row(
                children: [
                  for (int i = 0; i < dates.length; i++)
                    Builder(
                      builder: (_) {
                        final dk = _dk(dates[i]);
                        final isHoliday = holidayDates.contains(dk);
                        final isSunday = dates[i].weekday == DateTime.sunday;
                        final Color bg;
                        final TextStyle style;
                        final String label;

                        if (isSunday) {
                          bg = const Color(0xFF9CA3AF);
                          style = const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          );
                          label = '${dates[i].day}\nSun';
                        } else if (isHoliday) {
                          // No holiday name — just "H" marker
                          bg = const Color(0xFF5B21B6);
                          style = const TextStyle(
                            color: Color(0xFFE9D5FF),
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                          );
                          label = '${dates[i].day}\nH';
                        } else {
                          bg = _hdr2;
                          style = const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          );
                          label = '${dates[i].day}';
                        }
                        return _scrollCell(
                          label,
                          wDay,
                          _hdrH2,
                          bg: bg,
                          style: style,
                        );
                      },
                    ),
                  _vDiv(),
                  for (final (label, bg) in [
                    ('Total\nDays', _hdr3),
                    ('Present\nDays', _hdr3),
                    ('Absent\nDays', _hdr3),
                    ('Leave\nDays', _hdr3),
                    ('CO\nDays', _hdr3),
                    ('Late\nDays', _hdr3),
                    ('Total\nWork\nHrs', const Color(0xFF065F46)),
                    ('Avg\nWork\nHrs', const Color(0xFF0369A1)),
                  ]) ...[
                    _scrollCell(
                      label,
                      wSummary,
                      _hdrH2,
                      bg: bg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (label != 'Avg\nWork\nHrs') _vDiv(),
                  ],
                ],
              ),
              _hDiv(scrollW),
              for (int idx = 0; idx < sortedEmpIds.length; idx++) ...[
                Builder(
                  builder: (_) {
                    final empId = sortedEmpIds[idx];
                    final stat = empStats[empId]!;
                    final rowBg = idx.isEven
                        ? Colors.white
                        : const Color(0xFFF8FAFF);

                    return Row(
                      children: [
                        for (int di = 0; di < dates.length; di++)
                          Builder(
                            builder: (_) {
                              final s = stat.statuses[di];
                              Color bg;
                              TextStyle style;
                              if (s == 'SUN') {
                                bg = _sundayBg;
                                style = const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                );
                              } else if (s == 'CO') {
                                bg = _compOffBg;
                                style = const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E),
                                );
                              } else if (s == 'P') {
                                bg = _presentBg;
                                style = const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                );
                              } else if (s == 'L') {
                                bg = _lateBg;
                                style = const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                );
                              } else if (s == 'A') {
                                bg = _absentBg;
                                style = const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                );
                              } else if (s == 'H') {
                                bg = _holidayBg;
                                style = const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6D28D9),
                                );
                              } else {
                                bg = _leaveBg;
                                style = const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFBE123C),
                                );
                              }
                              return _scrollCell(
                                s,
                                wDay,
                                _rowH,
                                bg: bg,
                                style: style,
                              );
                            },
                          ),
                        _vDiv(),
                        _scrollCell(
                          dates.length.toString(),
                          wSummary,
                          _rowH,
                          bg: rowBg,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.present.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.present > 0
                              ? const Color(0xFFECFDF5)
                              : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.present > 0
                                ? const Color(0xFF16A34A)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.absent.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.absent > 0 ? const Color(0xFFFEF2F2) : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.absent > 0
                                ? const Color(0xFFDC2626)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.leaveDays.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.leaveDays > 0 ? _leaveBg : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.leaveDays > 0
                                ? const Color(0xFFBE123C)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.compOffDays.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.compOffDays > 0 ? _compOffBg : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.compOffDays > 0
                                ? const Color(0xFF92400E)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.lateDays.toString(),
                          wSummary,
                          _rowH,
                          bg: stat.lateDays > 0 ? _lateBg : rowBg,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stat.lateDays > 0
                                ? const Color(0xFFD97706)
                                : _textMid,
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          _minsToWorkedStr(stat.totalWorkedMins),
                          wSummary,
                          _rowH,
                          bg: const Color(0xFFECFDF5),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        _vDiv(),
                        _scrollCell(
                          stat.avgWorkedMins > 0
                              ? _minsToWorkedStr(stat.avgWorkedMins)
                              : '—',
                          wSummary,
                          _rowH,
                          bg: const Color(0xFFE0F2FE),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _hDiv(scrollW),
              ],
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: _hdr1,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Text(
                'Monthly Attendance Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Badge(
                '${sortedEmpIds.length} employee${sortedEmpIds.length == 1 ? '' : 's'}',
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leftPanel(),
              Expanded(child: rightPanel()),
            ],
          ),
        ),
      ],
    );
  }
}

int _parseLateMinutes(String text) {
  int total = 0;
  final hrMatch = RegExp(r'(\d+)\s*hr').firstMatch(text);
  final minMatch = RegExp(r'(\d+)\s*min').firstMatch(text);
  if (hrMatch != null) total += int.parse(hrMatch.group(1)!) * 60;
  if (minMatch != null) total += int.parse(minMatch.group(1)!);
  return total;
}

class _EmpStat {
  final List<String> statuses;
  final int present,
      absent,
      holidays,
      lateDays,
      lateMins,
      leaveDays,
      compOffDays,
      totalWorkedMins;
  const _EmpStat({
    required this.statuses,
    required this.present,
    required this.absent,
    required this.holidays,
    required this.lateDays,
    required this.lateMins,
    required this.leaveDays,
    required this.compOffDays,
    required this.totalWorkedMins,
  });

  int get avgWorkedMins =>
      present > 0 ? (totalWorkedMins / present).round() : 0;
}

String _minsToWorkedStr(int mins) {
  final h = mins ~/ 60;
  final m = mins % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
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

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: _primary,
      ),
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
