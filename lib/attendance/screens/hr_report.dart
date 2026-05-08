import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

/// MAIN CLASS
class HRReportsScreen extends StatefulWidget {
  const HRReportsScreen({super.key});

  @override
  State<HRReportsScreen> createState() => _HRReportsScreenState();
}

/// SUB CLASS
class _HRReportsScreenState extends State<HRReportsScreen> {
  final ReportService _reportService = ReportService();

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedEmployee;

  final List<String> _employees = [
    'All Employees',
    'John Doe',
    'Jane Smith',
    'Alice Johnson',
  ];

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "--";
    return "${date.day}-${date.month}-${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;
    final horizontalPadding = isDesktop ? size.width * 0.1 : 16.0;
    final spacing = isDesktop ? 20.0 : 12.0;
    final fontSize = isDesktop ? 16.0 : 14.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("HR Reports"),
        backgroundColor: Colors.indigo,
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: spacing,
        ),
        child: Column(
          children: [
            _sectionCard(
              title: "Filters",
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,

                    /// prevents overflow
                    initialValue: _selectedEmployee,
                    items: _employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(fontSize: fontSize),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedEmployee = v),
                    decoration: const InputDecoration(
                      labelText: "Select Employee",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: spacing),

                  /// DATE SELECTION FUNCTION
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            "From: ${_formatDate(_fromDate)}",
                            style: TextStyle(fontSize: fontSize),
                          ),
                          onPressed: () => _pickDate(isFrom: true),
                        ),
                      ),
                      SizedBox(width: spacing),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            "To: ${_formatDate(_toDate)}",
                            style: TextStyle(fontSize: fontSize),
                          ),
                          onPressed: () => _pickDate(isFrom: false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing),
            _reportCard(
              title: "Employee-wise Attendance Report",
              future: _reportService.getEmployeeReport(
                employee: _selectedEmployee,
                fromDate: _fromDate,
                toDate: _toDate,
              ),
            ),
            SizedBox(height: spacing),
            _summaryCard(
              title: "Work Hours Summary",
              future: _reportService.getWorkHoursSummary(
                fromDate: _fromDate,
                toDate: _toDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// HELPERS or FILTER CARD
  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  /// report card
  Widget _reportCard({
    required String title,
    required Future<AttendanceReportModel> future,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<AttendanceReportModel>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData) {
              return const Text("No data available");
            }

            final report = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow("Period", report.period),
                _infoRow("Present Days", report.presentDays.toString()),
                _infoRow("Absent Days", report.absentDays.toString()),
                _infoRow("Total Hours", "${report.totalHours} hrs"),
              ],
            );
          },
        ),
      ),
    );
  }

  /// info card datas
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// summary card at last
Widget _summaryCard({required String title, required Future<double> future}) {
  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<double>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData) {
            return const Text("No data available");
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${snapshot.data} Total Hours Worked",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
