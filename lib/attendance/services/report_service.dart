import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_file/open_file.dart';
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

  static Future<void> exportDaily(List<EmpDaily> data, DateTime date) async {
    final excel = DailyExcelBuilder.build(data, date);
    await _saveExcel(excel, 'Attendance_Daily_${fmtFile(date)}');
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
      await OpenFile.open(file.path);
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
      10.0,
      10.0,
      10.0,
      12.0,
      8.0,
      10.0,
      14.0,
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
