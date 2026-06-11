import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import '../providers/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME
// ═══════════════════════════════════════════════════════════════════════════════

const Color _primary = Color(0xFF1A56DB);
const Color _accent = Color(0xFF0E9F6E);
const Color _red = Color(0xFFEF4444);
const Color _amber = Color(0xFFF59E0B);
const Color _purple = Color(0xFF7C3AED);
const Color _blue = Color(0xFF0369A1);
const Color _surface = Color(0xFFF0F4FF);
const Color _textDark = Color(0xFF0F172A);
const Color _textMid = Color(0xFF64748B);
const Color _textLight = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);
const Color _hdr1 = Color(0xFF1E3A8A);
const Color _hdr2 = Color(0xFF2563EB);
const Color _divCol = Color(0xFF93C5FD);

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class DayWiseLeave {
  final int leaveId;
  final int empId;
  final String employeeName;
  final String employeeCode;
  final String departmentName;
  final String designationName;
  final int leaveTypeId;
  final String leaveName;
  final String? leaveCode;
  final bool isPaid;
  final String leaveStartDate;
  final String leaveEndDate;
  final bool isHalfDay;
  final String? halfDayPeriod;
  final double numberOfDays;
  final String reason;
  final String finalStatus;
  final String appliedOn;
  final String? approverName;
  final String? remarks;
  final String? cancelReason;

  const DayWiseLeave({
    required this.leaveId,
    required this.empId,
    required this.employeeName,
    required this.employeeCode,
    required this.departmentName,
    required this.designationName,
    required this.leaveTypeId,
    required this.leaveName,
    this.leaveCode,
    required this.isPaid,
    required this.leaveStartDate,
    required this.leaveEndDate,
    required this.isHalfDay,
    this.halfDayPeriod,
    required this.numberOfDays,
    required this.reason,
    required this.finalStatus,
    required this.appliedOn,
    this.approverName,
    this.remarks,
    this.cancelReason,
  });

  factory DayWiseLeave.fromJson(Map<String, dynamic> j) => DayWiseLeave(
    leaveId: j['leave_id'] ?? 0,
    empId: j['emp_id'] ?? 0,
    employeeName: j['employee_name'] ?? '',
    employeeCode: j['employee_code'] ?? '',
    departmentName: j['department_name'] ?? '',
    designationName: j['designation_name'] ?? '',
    leaveTypeId: j['leave_type_id'] ?? 0,
    leaveName: j['leave_name'] ?? '',
    leaveCode: j['leave_code'] as String?,
    isPaid: j['is_paid'] == 1 || j['is_paid'] == true,
    leaveStartDate: j['leave_start_date']?.toString().substring(0, 10) ?? '',
    leaveEndDate: j['leave_end_date']?.toString().substring(0, 10) ?? '',
    isHalfDay: j['is_half_day'] == 1 || j['is_half_day'] == true,
    halfDayPeriod: j['half_day_period'] as String?,
    numberOfDays: double.tryParse(j['number_of_days']?.toString() ?? '0') ?? 0,
    reason: j['reason'] ?? '',
    finalStatus: j['final_status'] ?? '',
    appliedOn: j['applied_on']?.toString().substring(0, 10) ?? '',
    approverName: j['approver_name'] as String?,
    remarks: j['remarks'] as String?,
    cancelReason: j['cancel_reason'] as String?,
  );
}

// ── Matrix models ──────────────────────────────────────────────────────────────

class MatrixDateCol {
  final String date;
  final int day;
  final String dayLabel;
  final bool isWeekend;
  final bool isHoliday;
  final String? holidayName;

  const MatrixDateCol({
    required this.date,
    required this.day,
    required this.dayLabel,
    required this.isWeekend,
    required this.isHoliday,
    this.holidayName,
  });

  factory MatrixDateCol.fromJson(Map<String, dynamic> j) => MatrixDateCol(
    date: j['date'] ?? '',
    day: j['day'] ?? 0,
    dayLabel: j['dayLabel'] ?? '',
    isWeekend: j['isWeekend'] == true,
    isHoliday: j['isHoliday'] == true,
    holidayName: j['holidayName'] as String?,
  );
}

class MatrixDayCell {
  final String date;
  final String? type;
  final String label;

  const MatrixDayCell({required this.date, this.type, required this.label});

  factory MatrixDayCell.fromJson(Map<String, dynamic> j) => MatrixDayCell(
    date: j['date'] ?? '',
    type: j['type'] as String?,
    label: j['label'] ?? '',
  );
}

class MatrixSummary {
  final double paidTaken;
  final double unpaidTaken;
  final double pendingDays;
  final double totalDays;

  const MatrixSummary({
    required this.paidTaken,
    required this.unpaidTaken,
    required this.pendingDays,
    required this.totalDays,
  });

  factory MatrixSummary.fromJson(Map<String, dynamic> j) => MatrixSummary(
    paidTaken: _d(j['paid_taken']),
    unpaidTaken: _d(j['unpaid_taken']),
    pendingDays: _d(j['pending_days']),
    totalDays: _d(j['closing_balance'] ?? j['total_days']),
  );

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
}

class MatrixEmpRow {
  final int empId;
  final String empName;
  final String employeeCode;
  final String departmentName;
  final String designationName;
  final List<MatrixDayCell> days;
  final MatrixSummary summary;

  const MatrixEmpRow({
    required this.empId,
    required this.empName,
    required this.employeeCode,
    required this.departmentName,
    required this.designationName,
    required this.days,
    required this.summary,
  });

  factory MatrixEmpRow.fromJson(Map<String, dynamic> j) => MatrixEmpRow(
    empId: j['emp_id'] ?? 0,
    empName: j['emp_name'] ?? '',
    employeeCode: j['employee_code'] ?? '',
    departmentName: j['department_name'] ?? '',
    designationName: j['designation_name'] ?? '',
    days: (j['days'] as List? ?? [])
        .map((d) => MatrixDayCell.fromJson(d as Map<String, dynamic>))
        .toList(),
    summary: MatrixSummary.fromJson(
      j['summary'] as Map<String, dynamic>? ?? {},
    ),
  );
}

class _DeptModel {
  final int id;
  final String name;
  const _DeptModel(this.id, this.name);
  @override
  bool operator ==(Object o) => o is _DeptModel && o.id == id;
  @override
  int get hashCode => id.hashCode;
}

const _kAllDepts = _DeptModel(-1, 'All Departments');

// ═══════════════════════════════════════════════════════════════════════════════
// DATE HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

String _fmtApi(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtDisplay(DateTime d) {
  const months = [
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
  ];
  return '${d.day} ${months[d.month]} ${d.year}';
}

String _fmtShort(String yyyymmdd) {
  try {
    final p = yyyymmdd.split('-');
    const m = [
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
    ];
    return '${int.parse(p[2])} ${m[int.parse(p[1])]}';
  } catch (_) {
    return yyyymmdd;
  }
}

String _dayName(DateTime d) => const [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
][d.weekday % 7];

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaveReportService {
  // FIX: department.js returns { success: true, data: [...] } not { ok: true }
  // Field is 'id' (aliased in SQL) and 'department_name'
  static Future<List<_DeptModel>> fetchDepartments() async {
    final resp = await ApiClient.get('/departments');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 ||
        (body['ok'] != true && body['success'] != true))
      return [];
    return (body['data'] as List)
        .map(
          (d) => _DeptModel(
            ((d['department_id'] ?? d['id']) as num).toInt(),
            (d['department_name'] ?? d['name'] ?? '') as String,
          ),
        )
        .toList();
  }

  static Future<Map<String, dynamic>> fetchDayWise({
    required DateTime date,
    int? departmentId,
  }) async {
    final params = StringBuffer('?date=${_fmtApi(date)}');
    if (departmentId != null) params.write('&department_id=$departmentId');
    final resp = await ApiClient.get('/leave/report/day-wise$params');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['message'] ?? 'Failed to fetch day-wise report');
    }
    return body;
  }

  static Future<Map<String, dynamic>> fetchMatrix({
    required DateTime from,
    required DateTime to,
    int? departmentId,
  }) async {
    final params = StringBuffer('?from=${_fmtApi(from)}&to=${_fmtApi(to)}');
    if (departmentId != null) params.write('&department_id=$departmentId');
    final resp = await ApiClient.get('/leave/report/matrix$params');
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || body['ok'] != true) {
      throw Exception(body['message'] ?? 'Failed to fetch matrix');
    }
    return body;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXCEL EXPORT HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

String _hex(int r, int g, int b) =>
    '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';

CellStyle _xlsHdr({int r = 30, int g = 86, int b = 219}) {
  return CellStyle(
    backgroundColorHex: ExcelColor.fromHexString(_hex(r, g, b)),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );
}

CellStyle _xlsData({bool bold = false, String? bgHex, String? fgHex}) {
  return CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#${bgHex ?? 'FFFFFF'}'),
    fontColorHex: ExcelColor.fromHexString('#${fgHex ?? '0F172A'}'),
    bold: bold,
    verticalAlign: VerticalAlign.Center,
  );
}

Future<void> _exportDayWiseExcel(
  BuildContext context,
  DateTime date,
  List<DayWiseLeave> data,
) async {
  try {
    final excel = Excel.createExcel();
    final sheetName = 'Day-Wise Leave';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // ── Title row ──
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('L1'));
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'Day-Wise Leave Report — ${_fmtDisplay(date)}',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // ── Header row ──
    final headers = [
      'S.No',
      'Emp ID',
      'Employee Name',
      'Emp Code',
      'Department',
      'Designation',
      'Leave Type',
      'From',
      'To',
      'Days',
      'Type',
      'Status',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = _xlsHdr();
    }

    // ── Data rows ──
    for (var i = 0; i < data.length; i++) {
      final l = data[i];
      final rowIdx = i + 2;

      final bgHex = i.isEven ? 'FFFFFF' : 'F8FAFF';
      final statusBg = switch (l.finalStatus) {
        'Approved' => 'DCFCE7',
        'Pending' => 'FEF3C7',
        'Rejected' => 'FEE2E2',
        _ => bgHex,
      };
      final statusFg = switch (l.finalStatus) {
        'Approved' => '16A34A',
        'Pending' => 'B45309',
        'Rejected' => 'DC2626',
        _ => '0F172A',
      };
      final typeBg = l.isPaid ? 'DCFCE7' : 'FEE2E2';
      final typeFg = l.isPaid ? '16A34A' : 'DC2626';

      final values = [
        '${i + 1}',
        '${l.empId}',
        l.employeeName,
        l.employeeCode,
        l.departmentName,
        l.designationName,
        l.leaveName,
        _fmtShort(l.leaveStartDate),
        _fmtShort(l.leaveEndDate),
        '${l.numberOfDays}',
        l.isPaid ? 'Paid' : 'Unpaid',
        l.finalStatus,
      ];

      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        );
        cell.value = TextCellValue(values[c]);
        if (c == 10) {
          cell.cellStyle = _xlsData(bgHex: typeBg, fgHex: typeFg, bold: true);
        } else if (c == 11) {
          cell.cellStyle = _xlsData(
            bgHex: statusBg,
            fgHex: statusFg,
            bold: true,
          );
        } else {
          cell.cellStyle = _xlsData(bgHex: bgHex, bold: c == 2);
        }
      }
    }

    // ── Column widths ──
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 20);
    sheet.setColumnWidth(5, 20);
    sheet.setColumnWidth(6, 18);
    sheet.setColumnWidth(7, 12);
    sheet.setColumnWidth(8, 12);
    sheet.setColumnWidth(9, 8);
    sheet.setColumnWidth(10, 10);
    sheet.setColumnWidth(11, 12);

    await _saveAndShare(context, excel, 'day_wise_leave_${_fmtApi(date)}.xlsx');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: _red),
      );
    }
  }
}

Future<void> _exportMatrixExcel(
  BuildContext context,
  DateTime from,
  DateTime to,
  List<MatrixDateCol> dates,
  List<MatrixEmpRow> rows,
) async {
  try {
    final excel = Excel.createExcel();
    final sheetName = 'Leave Matrix';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // ── Title ──
    final lastColIdx = 4 + dates.length + 5 - 1;
    final lastColLetter = _colLetter(lastColIdx);
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('${lastColLetter}1'),
    );
    final titleCell = sheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue(
      'Leave Matrix Report — ${_fmtDisplay(from)} to ${_fmtDisplay(to)}',
    );
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // ── Header row ──
    final fixedHeaders = ['S.No', 'Emp ID', 'Employee Name', 'Dept', 'Desig'];
    for (var i = 0; i < fixedHeaders.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(fixedHeaders[i]);
      cell.cellStyle = _xlsHdr();
    }

    for (var i = 0; i < dates.length; i++) {
      final d = dates[i];
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 5 + i, rowIndex: 1),
      );
      cell.value = TextCellValue('${d.dayLabel}\n${d.day}');
      final bg = d.isHoliday
          ? '0369A1'
          : d.isWeekend
          ? '7C3AED'
          : '2563EB';
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#$bg'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );
    }

    final summaryHeaders = ['Paid', 'Unpaid', 'Pending', 'Total'];
    final summaryColors = ['0E9F6E', 'EF4444', 'F59E0B', '7C3AED'];
    for (var i = 0; i < summaryHeaders.length; i++) {
      final colIdx = 5 + dates.length + i;
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 1),
      );
      cell.value = TextCellValue(summaryHeaders[i]);
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#${summaryColors[i]}'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );
    }

    // ── Data rows ──
    for (var i = 0; i < rows.length; i++) {
      final emp = rows[i];
      final rowIdx = i + 2;
      final bgHex = i.isEven ? 'FFFFFF' : 'F8FAFF';

      // Fixed cols
      final fixedVals = [
        '${i + 1}',
        '${emp.empId}',
        emp.empName,
        emp.departmentName,
        emp.designationName,
      ];
      for (var c = 0; c < fixedVals.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx),
        );
        cell.value = TextCellValue(fixedVals[c]);
        cell.cellStyle = _xlsData(bgHex: bgHex, bold: c == 2);
      }

      // Day cells
      for (var j = 0; j < emp.days.length; j++) {
        final d = emp.days[j];
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 5 + j, rowIndex: rowIdx),
        );
        cell.value = TextCellValue(d.label);
        final (bg, fg) = _dayExcelColors(d.type, bgHex);
        cell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#$bg'),
          fontColorHex: ExcelColor.fromHexString('#$fg'),
          bold: d.label.isNotEmpty,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Summary
      final s = emp.summary;
      final sumVals = [
        s.paidTaken > 0 ? s.paidTaken.toStringAsFixed(1) : '',
        s.unpaidTaken > 0 ? s.unpaidTaken.toStringAsFixed(1) : '',
        s.pendingDays > 0 ? s.pendingDays.toStringAsFixed(1) : '',
        s.totalDays > 0 ? s.totalDays.toStringAsFixed(1) : '',
      ];
      final sumBgs = [
        s.paidTaken > 0 ? 'DCFCE7' : bgHex,
        s.unpaidTaken > 0 ? 'FEE2E2' : bgHex,
        s.pendingDays > 0 ? 'FEF3C7' : bgHex,
        s.totalDays > 0 ? 'EDE9FE' : bgHex,
      ];
      final sumFgs = [
        s.paidTaken > 0 ? '16A34A' : '64748B',
        s.unpaidTaken > 0 ? 'DC2626' : '64748B',
        s.pendingDays > 0 ? 'B45309' : '64748B',
        s.totalDays > 0 ? '7C3AED' : '64748B',
      ];

      for (var k = 0; k < sumVals.length; k++) {
        final colIdx = 5 + dates.length + k;
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx),
        );
        cell.value = TextCellValue(sumVals[k]);
        cell.cellStyle = _xlsData(
          bgHex: sumBgs[k],
          fgHex: sumFgs[k],
          bold: true,
        );
      }
    }

    // ── Column widths ──
    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 18);
    sheet.setColumnWidth(4, 18);
    for (var i = 0; i < dates.length; i++) {
      sheet.setColumnWidth(5 + i, 5);
    }
    for (var k = 0; k < 4; k++) {
      sheet.setColumnWidth(5 + dates.length + k, 10);
    }

    await _saveAndShare(
      context,
      excel,
      'leave_matrix_${_fmtApi(from)}_${_fmtApi(to)}.xlsx',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: _red),
      );
    }
  }
}

(String, String) _dayExcelColors(String? type, String fallbackBg) =>
    switch (type) {
      'PL' => ('DCFCE7', '16A34A'),
      'UL' => ('FEE2E2', 'DC2626'),
      'LP' => ('FEF3C7', 'B45309'),
      'H' => ('DBEAFE', '0369A1'),
      'W' => ('EDE9FE', '7C3AED'),
      _ => (fallbackBg, '0F172A'),
    };

String _colLetter(int idx) {
  if (idx < 26) return String.fromCharCode(65 + idx);
  return '${String.fromCharCode(64 + idx ~/ 26)}${String.fromCharCode(65 + idx % 26)}';
}

Future<void> _saveAndShare(
  BuildContext context,
  Excel excel,
  String fileName,
) async {
  final bytes = excel.encode();
  if (bytes == null) throw Exception('Failed to encode Excel file');

  late final Directory dir;
  if (Platform.isAndroid) {
    // Downloads folder — visible in Files app
    dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) dir.createSync(recursive: true);
  } else if (Platform.isIOS) {
    // On iOS, save to Documents folder (accessible via Files app)
    dir = await getApplicationDocumentsDirectory();
  } else {
    dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  }

  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved to ${Platform.isIOS ? 'Documents' : 'Downloads'}: $fileName',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class LeaveReportScreen extends StatefulWidget {
  const LeaveReportScreen({super.key});

  @override
  State<LeaveReportScreen> createState() => _LeaveReportScreenState();
}

class _LeaveReportScreenState extends State<LeaveReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: _DragScroll(),
    child: Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
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
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Admin view  ·  All employees',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
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
            Tab(icon: Icon(Icons.today_rounded, size: 16), text: 'Daily'),
            Tab(icon: Icon(Icons.grid_on_rounded, size: 16), text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_DayWiseTab(), _MatrixTab()],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — DAY-WISE
// ═══════════════════════════════════════════════════════════════════════════════

class _DayWiseTab extends StatefulWidget {
  const _DayWiseTab();

  @override
  State<_DayWiseTab> createState() => _DayWiseTabState();
}

class _DayWiseTabState extends State<_DayWiseTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _date = DateTime.now();

  List<_DeptModel> _departments = [_kAllDepts];
  _DeptModel _selectedDept = _kAllDepts;
  bool _deptLoading = false;

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<DayWiseLeave> _data = [];
  String _search = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    setState(() => _deptLoading = true);
    try {
      final list = await _LeaveReportService.fetchDepartments();
      if (mounted) setState(() => _departments = [_kAllDepts, ...list]);
    } catch (_) {}
    if (mounted) setState(() => _deptLoading = false);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await _LeaveReportService.fetchDayWise(
        date: _date,
        departmentId: _selectedDept.id == -1 ? null : _selectedDept.id,
      );
      final list = (body['data'] as List)
          .map((j) => DayWiseLeave.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted)
        setState(() {
          _data = list;
          _fetched = true;
          _search = '';
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_data.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await _exportDayWiseExcel(context, _date, _filtered);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<DayWiseLeave> get _filtered => _search.isEmpty
      ? _data
      : _data
            .where(
              (e) =>
                  e.employeeName.toLowerCase().contains(
                    _search.toLowerCase(),
                  ) ||
                  e.empId.toString().contains(_search),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: _DragScroll(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Filter card ──
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Select Date'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _DateField('Date', _date, _pickDate)),
                      const SizedBox(width: 10),
                      _NavBtn(
                        Icons.chevron_left_rounded,
                        () => setState(
                          () => _date = _date.subtract(const Duration(days: 1)),
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
                  const SizedBox(height: 10),
                  _DeptDropdown(
                    departments: _departments,
                    selected: _selectedDept,
                    loading: _deptLoading,
                    onChanged: (v) => setState(() => _selectedDept = v),
                  ),
                  const SizedBox(height: 12),
                  _ActionBtn(
                    label: 'View Leaves',
                    icon: Icons.search_rounded,
                    color: _primary,
                    loading: _loading,
                    onTap: _fetch,
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(_error!),
            ],

            if (_loading) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator(color: _primary)),
            ],

            if (_fetched && !_loading) ...[
              const SizedBox(height: 16),

              // Date banner + Export button on same row
              Row(
                children: [
                  Expanded(
                    child: _DateBanner(
                      label: _dayName(_date),
                      value: _fmtDisplay(_date),
                      icon: Icons.event_rounded,
                      color: _primary,
                    ),
                  ),
                  if (_data.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _ExportBtn(loading: _exporting, onTap: _export),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              _DayStatsRow(data: _data),
              const SizedBox(height: 12),

              if (_data.isNotEmpty) ...[
                _SearchBar(onChanged: (v) => setState(() => _search = v)),
                const SizedBox(height: 12),
              ],

              if (_filtered.isEmpty)
                const _EmptyState(message: 'No leaves on this date')
              else
                ...List.generate(
                  _filtered.length,
                  (i) => _DayWiseCard(leave: _filtered[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }

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
}

// ── Day-wise stats row ─────────────────────────────────────────────────────────

class _DayStatsRow extends StatelessWidget {
  final List<DayWiseLeave> data;
  const _DayStatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.length;
    final paid = data.where((e) => e.isPaid).length;
    final unpaid = data.where((e) => !e.isPaid).length;
    final pending = data.where((e) => e.finalStatus == 'Pending').length;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = ((constraints.maxWidth - 12) / 2).clamp(100.0, 300.0);
        Widget chip(String val, String lbl, Color c, IconData icon) => SizedBox(
          width: w,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: c),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      val,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c,
                      ),
                    ),
                    Text(
                      lbl,
                      style: const TextStyle(fontSize: 10, color: _textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            chip(
              '$total',
              'Total On Leave',
              _primary,
              Icons.people_alt_rounded,
            ),
            chip('$paid', 'Paid Leave', _accent, Icons.check_circle_rounded),
            chip('$unpaid', 'Unpaid Leave', _red, Icons.money_off_rounded),
            chip('$pending', 'Pending', _amber, Icons.hourglass_top_rounded),
          ],
        );
      },
    );
  }
}

// ── Day-wise employee card ─────────────────────────────────────────────────────

class _DayWiseCard extends StatefulWidget {
  final DayWiseLeave leave;
  const _DayWiseCard({required this.leave});

  @override
  State<_DayWiseCard> createState() => _DayWiseCardState();
}

class _DayWiseCardState extends State<_DayWiseCard> {
  bool _expanded = false;

  Color get _statusColor => switch (widget.leave.finalStatus) {
    'Approved' => _accent,
    'Pending' => _amber,
    'Rejected' => _red,
    _ => _textMid,
  };

  Color get _paidColor => widget.leave.isPaid ? _accent : _red;
  String get _paidLabel => widget.leave.isPaid ? 'Paid' : 'Unpaid';

  @override
  Widget build(BuildContext context) {
    final l = widget.leave;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? _primary.withOpacity(0.3) : _border,
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_expanded ? 0.07 : 0.03),
              blurRadius: _expanded ? 16 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, widget.leave.isPaid ? _accent : _red],
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          l.employeeName.isNotEmpty
                              ? l.employeeName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
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
                            l.employeeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '#${l.empId}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _textMid,
                                ),
                              ),
                              const Text(
                                '  ·  ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textLight,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  l.departmentName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _textMid,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _Badge(label: _paidLabel, color: _paidColor),
                    const SizedBox(width: 8),
                    _Badge(label: l.finalStatus, color: _statusColor),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _textLight,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 13,
                    color: _textMid,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.leaveName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: _textMid,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.leaveStartDate == l.leaveEndDate
                        ? _fmtShort(l.leaveStartDate)
                        : '${_fmtShort(l.leaveStartDate)} → ${_fmtShort(l.leaveEndDate)}',
                    style: const TextStyle(fontSize: 12, color: _textMid),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${l.numberOfDays == l.numberOfDays.truncateToDouble() ? l.numberOfDays.toInt() : l.numberOfDays} day${l.numberOfDays == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _expandedDetail(l),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedDetail(DayWiseLeave l) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.badge_outlined,
                label: 'Employee Code',
                value: l.employeeCode,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoTile(
                icon: Icons.work_outline,
                label: 'Designation',
                value: l.designationName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.calendar_month_outlined,
                label: 'From',
                value: _fmtShort(l.leaveStartDate),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoTile(
                icon: Icons.calendar_month_rounded,
                label: 'To',
                value: _fmtShort(l.leaveEndDate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InfoTile(
                icon: Icons.today_rounded,
                label: 'Applied On',
                value: _fmtShort(l.appliedOn),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoTile(
                icon: Icons.timelapse_rounded,
                label: 'Half Day',
                value: l.isHalfDay
                    ? (l.halfDayPeriod == 'AM'
                          ? 'Yes – Morning'
                          : 'Yes – Afternoon')
                    : 'No',
                valueColor: l.isHalfDay ? _amber : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _InfoTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Reason',
          value: l.reason.isNotEmpty ? l.reason : '—',
        ),
        if (l.approverName != null && l.approverName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.verified_user_outlined,
            label: l.finalStatus == 'Approved'
                ? 'Approved By'
                : 'Last Action By',
            value: l.approverName!,
            valueColor: l.finalStatus == 'Approved' ? _accent : _amber,
          ),
        ],
        if (l.remarks != null && l.remarks!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.comment_outlined,
            label: 'Remarks',
            value: l.remarks!,
          ),
        ],
        if (l.cancelReason != null && l.cancelReason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InfoTile(
            icon: Icons.cancel_outlined,
            label: 'Cancel Reason',
            value: l.cancelReason!,
            valueColor: _red,
          ),
        ],
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MATRIX
// ═══════════════════════════════════════════════════════════════════════════════

class _MatrixTab extends StatefulWidget {
  const _MatrixTab();

  @override
  State<_MatrixTab> createState() => _MatrixTabState();
}

class _MatrixTabState extends State<_MatrixTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  List<_DeptModel> _departments = [_kAllDepts];
  _DeptModel _selectedDept = _kAllDepts;
  bool _deptLoading = false;

  bool _loading = false;
  bool _fetched = false;
  String? _error;
  List<MatrixDateCol> _dates = [];
  List<MatrixEmpRow> _rows = [];
  String _search = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    setState(() => _deptLoading = true);
    try {
      final list = await _LeaveReportService.fetchDepartments();
      if (mounted) setState(() => _departments = [_kAllDepts, ...list]);
    } catch (_) {}
    if (mounted) setState(() => _deptLoading = false);
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _fetched = false;
    });
    try {
      final body = await _LeaveReportService.fetchMatrix(
        from: _from,
        to: _to,
        departmentId: _selectedDept.id == -1 ? null : _selectedDept.id,
      );
      final dates = (body['dates'] as List)
          .map((d) => MatrixDateCol.fromJson(d as Map<String, dynamic>))
          .toList();
      final rows = (body['data'] as List)
          .map((r) => MatrixEmpRow.fromJson(r as Map<String, dynamic>))
          .toList();
      if (mounted)
        setState(() {
          _dates = dates;
          _rows = rows;
          _fetched = true;
          _search = '';
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    if (_rows.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await _exportMatrixExcel(context, _from, _to, _dates, _filtered);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<MatrixEmpRow> get _filtered => _search.isEmpty
      ? _rows
      : _rows
            .where(
              (r) =>
                  r.empName.toLowerCase().contains(_search.toLowerCase()) ||
                  r.empId.toString().contains(_search),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: _DragScroll(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Date Range'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField('From', _from, () => _pickDate(true)),
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
                        child: _DateField('To', _to, () => _pickDate(false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _QuickChip('This Month', () {
                        final n = DateTime.now();
                        setState(() {
                          _from = DateTime(n.year, n.month, 1);
                          _to = n;
                        });
                      }),
                      _QuickChip('Last Month', () {
                        final n = DateTime.now();
                        setState(() {
                          _from = DateTime(n.year, n.month - 1, 1);
                          _to = DateTime(n.year, n.month, 0);
                        });
                      }),
                      _QuickChip('Last 30 Days', () {
                        final n = DateTime.now();
                        setState(() {
                          _to = n;
                          _from = n.subtract(const Duration(days: 29));
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DeptDropdown(
                    departments: _departments,
                    selected: _selectedDept,
                    loading: _deptLoading,
                    onChanged: (v) => setState(() => _selectedDept = v),
                  ),
                  const SizedBox(height: 12),
                  _ActionBtn(
                    label: 'View Leaves ',
                    icon: Icons.search,
                    color: _primary,
                    loading: _loading,
                    onTap: _fetch,
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(_error!),
            ],

            if (_loading) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator(color: _primary)),
            ],

            if (_fetched && !_loading) ...[
              const SizedBox(height: 16),

              // Banner + Export button
              Row(
                children: [
                  Expanded(
                    child: _DateBanner(
                      label: 'Report Period',
                      value: '${_fmtDisplay(_from)}  →  ${_fmtDisplay(_to)}',
                      icon: Icons.grid_on_rounded,
                      color: _primary,
                    ),
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _ExportBtn(loading: _exporting, onTap: _export),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              _MatrixLegend(),
              const SizedBox(height: 12),

              _MatrixStats(rows: _rows),
              const SizedBox(height: 12),

              if (_rows.isNotEmpty) ...[
                _SearchBar(onChanged: (v) => setState(() => _search = v)),
                const SizedBox(height: 12),
              ],

              if (_filtered.isEmpty)
                const _EmptyState(message: 'No data for selected range')
              else
                _matrixTable(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
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
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  Widget _matrixTable() {
    final rows = _filtered;

    const snoW = 44.0;
    const empIdW = 68.0;
    const nameW = 160.0;
    const deptW = 120.0;
    const dayW = 26.0;
    const sumW = 68.0;
    const hdrH = 40.0;
    const rowH = 28.0;

    Widget div() => Container(width: 1, color: _divCol);
    Widget hdiv(double w) => Container(height: 1, width: w, color: _divCol);

    final totalW =
        snoW +
        empIdW +
        nameW +
        deptW +
        (_dates.length * dayW) +
        (4 * sumW) +
        (_dates.length + 4 + 3);

    Widget fixHdr(String label, double w, {bool center = true}) => Container(
      width: w,
      height: hdrH,
      color: _hdr2,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 2,
      ),
    );

    Widget dayHdr(MatrixDateCol d) {
      final bg = d.isHoliday
          ? _blue
          : d.isWeekend
          ? _purple
          : _hdr2;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dayW,
            height: hdrH / 2,
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
          ),
          Container(height: 1, width: dayW, color: _divCol),
          Container(
            width: dayW,
            height: hdrH / 2,
            color: bg,
            alignment: Alignment.center,
            child: Text(
              '${d.day}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    Widget sumHdr(String label, Color bg) => Container(
      width: sumW,
      height: hdrH,
      color: bg,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
      ),
    );

    (Color, Color) cellColors(String? type) => switch (type) {
      'PL' => (const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'UL' => (const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      'LP' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      'H' => (const Color(0xFFDBEAFE), _blue),
      'W' => (const Color(0xFFEDE9FE), _purple),
      _ => (Colors.transparent, Colors.transparent),
    };

    Widget dataRow(MatrixEmpRow emp, int idx) {
      final rowBg = idx.isEven ? Colors.white : const Color(0xFFF8FAFF);

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
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: fg ?? _textDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );

      Widget dayCell(MatrixDayCell d) {
        final c = cellColors(d.type);
        return Container(
          width: dayW,
          height: rowH,
          color: c.$1 == Colors.transparent ? rowBg : c.$1,
          alignment: Alignment.center,
          child: d.label.isEmpty
              ? null
              : Text(
                  d.label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: c.$2,
                  ),
                ),
        );
      }

      Widget sumCell(String val, Color bg, Color fg) => Container(
        width: sumW,
        height: rowH,
        color: bg,
        alignment: Alignment.center,
        child: Text(
          val,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
        ),
      );

      final s = emp.summary;

      return Row(
        children: [
          cell('${idx + 1}', snoW, fg: _textMid),
          div(),
          cell(emp.empId.toString(), empIdW, fg: _primary, bold: true),
          div(),
          cell(emp.empName, nameW, center: false, bold: true),
          div(),
          cell(emp.departmentName, deptW, center: false, fg: _textMid),
          div(),
          for (int j = 0; j < emp.days.length; j++) ...[
            dayCell(emp.days[j]),
            if (j < emp.days.length - 1) div(),
          ],
          div(),
          sumCell(
            s.paidTaken > 0 ? '${s.paidTaken.toStringAsFixed(1)}d' : '—',
            s.paidTaken > 0 ? const Color(0xFFDCFCE7) : rowBg,
            s.paidTaken > 0 ? const Color(0xFF16A34A) : _textMid,
          ),
          div(),
          sumCell(
            s.unpaidTaken > 0 ? '${s.unpaidTaken.toStringAsFixed(1)}d' : '—',
            s.unpaidTaken > 0 ? const Color(0xFFFEE2E2) : rowBg,
            s.unpaidTaken > 0 ? const Color(0xFFDC2626) : _textMid,
          ),
          div(),
          sumCell(
            s.pendingDays > 0 ? '${s.pendingDays.toStringAsFixed(1)}d' : '—',
            s.pendingDays > 0 ? const Color(0xFFFEF3C7) : rowBg,
            s.pendingDays > 0 ? const Color(0xFFB45309) : _textMid,
          ),
          div(),
          sumCell(
            s.totalDays > 0 ? '${s.totalDays.toStringAsFixed(1)}d' : '—',
            s.totalDays > 0 ? const Color(0xFFEDE9FE) : rowBg,
            s.totalDays > 0 ? _purple : _textMid,
          ),
        ],
      );
    }

    return Center(
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'Leave Matrix',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                behavior: _DragScroll(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            fixHdr('S.No', snoW),
                            div(),
                            fixHdr('Emp ID', empIdW),
                            div(),
                            fixHdr('Employee Name', nameW, center: false),
                            div(),
                            fixHdr('Department', deptW, center: false),
                            div(),
                            for (int i = 0; i < _dates.length; i++) ...[
                              dayHdr(_dates[i]),
                              if (i < _dates.length - 1) div(),
                            ],
                            div(),
                            sumHdr('Paid\nTaken', _accent),
                            div(),
                            sumHdr('Unpaid\nTaken', _red),
                            div(),
                            sumHdr('Pending', _amber),
                            div(),
                            sumHdr('Total\nDays', _purple),
                          ],
                        ),
                      ),
                      hdiv(totalW),
                      for (int i = 0; i < rows.length; i++) ...[
                        dataRow(rows[i], i),
                        hdiv(totalW),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Matrix legend ──────────────────────────────────────────────────────────────

class _MatrixLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: const [
      _LegendChip('PL', 'Paid Leave', Color(0xFFDCFCE7), Color(0xFF16A34A)),
      _LegendChip('UL', 'Unpaid Leave', Color(0xFFFEE2E2), Color(0xFFDC2626)),
      _LegendChip('LP', 'Pending', Color(0xFFFEF3C7), Color(0xFFB45309)),
      _LegendChip('H', 'Holiday', Color(0xFFDBEAFE), _blue),
      _LegendChip('W', 'Week-off', Color(0xFFEDE9FE), _purple),
    ],
  );
}

// ── Matrix stats ───────────────────────────────────────────────────────────────

class _MatrixStats extends StatelessWidget {
  final List<MatrixEmpRow> rows;
  const _MatrixStats({required this.rows});

  @override
  Widget build(BuildContext context) {
    final totalPaid = rows.fold(0.0, (s, r) => s + r.summary.paidTaken);
    final totalUnpaid = rows.fold(0.0, (s, r) => s + r.summary.unpaidTaken);
    final totalPend = rows.fold(0.0, (s, r) => s + r.summary.pendingDays);
    final onLeave = rows
        .where((r) => r.days.any((d) => d.type == 'PL' || d.type == 'UL'))
        .length;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = ((constraints.maxWidth - 12) / 2).clamp(100.0, 300.0);
        Widget chip(String val, String lbl, Color c, IconData icon) => SizedBox(
          width: w,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: c.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: c),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      val,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c,
                      ),
                    ),
                    Text(
                      lbl,
                      style: const TextStyle(fontSize: 10, color: _textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        final chipW = ((constraints.maxWidth - 24) / 3).clamp(80.0, 300.0);
        return Row();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _textMid,
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField(this.label, this.date, this.onTap);

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
                _fmtDisplay(date),
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
      padding: const EdgeInsets.all(9),
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
        color: _primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primary.withOpacity(0.2)),
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

class _DeptDropdown extends StatelessWidget {
  final List<_DeptModel> departments;
  final _DeptModel selected;
  final bool loading;
  final ValueChanged<_DeptModel> onChanged;

  const _DeptDropdown({
    required this.departments,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        const Icon(Icons.business_rounded, size: 16, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<_DeptModel>(
                    value: selected,
                    isExpanded: true,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _primary,
                      size: 18,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    items: departments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(
                              d.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: d.id == -1 ? _primary : _textDark,
                                fontWeight: d.id == -1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: loading ? color.withOpacity(0.5) : color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: loading
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
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
                  const SizedBox(width: 8),
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

// ── NEW: Export button widget ──────────────────────────────────────────────────

class _ExportBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _ExportBtn({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: loading
            ? const Color(0xFF16A34A).withOpacity(0.5)
            : const Color(0xFF16A34A),
        borderRadius: BorderRadius.circular(10),
        boxShadow: loading
            ? null
            : [
                const BoxShadow(
                  color: Color(0x3016A34A),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'Excel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    ),
  );
}

class _DateBanner extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _DateBanner({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.25)),
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
              value,
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

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) => _Card(
    child: TextField(
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: _textDark),
      decoration: const InputDecoration(
        hintText: 'Search by name or employee ID…',
        hintStyle: TextStyle(color: _textMid, fontSize: 13),
        prefixIcon: Icon(Icons.search_rounded, color: _textMid, size: 18),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: _textMid,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

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
      border: Border.all(color: fg.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code,
          style: TextStyle(
            fontSize: 10,
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

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => _Card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 44,
              color: _textMid.withOpacity(0.3),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: _textMid, fontSize: 13),
            ),
          ],
        ),
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
      color: _red.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _red.withOpacity(0.2)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// SCROLL BEHAVIOUR
// ═══════════════════════════════════════════════════════════════════════════════

class _DragScroll extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
