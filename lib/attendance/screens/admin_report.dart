import 'package:flutter/material.dart';
import '../models/report.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ================= FILTER STATE =================
  DateTimeRange? dateRange;
  String departmentFilter = 'All';
  String statusFilter = 'All';

  final List<String> departments = ['All', 'IT', 'HR', 'Finance'];
  final List<String> statuses = [
    'All',
    'Present',
    'Absent',
    'Pending',
    'Approved',
    'Completed',
  ];

  // ================= DATA =================
  late List<AttendanceReport> attendance;
  late List<TaskReport> tasks;
  late List<LeaveReport> leaves;
  late List<HolidayReport> holidays;
  late List<EmployeeReport> employees;
  late List<DepartmentReport> departmentsData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadDummyData();
  }

  void _loadDummyData() {
    attendance = [
      AttendanceReport(
        employeeId: 'EMP01',
        employeeName: 'John',
        department: 'IT',
        date: DateTime.now(),
        checkIn: '09:00',
        checkOut: '18:00',
        status: 'Present',
      ),
    ];

    tasks = [
      TaskReport(
        employeeName: 'John',
        department: 'IT',
        taskName: 'Dashboard UI',
        assignedDate: DateTime.now().subtract(const Duration(days: 2)),
        completedDate: null,
        status: 'Pending',
      ),
    ];

    leaves = [
      LeaveReport(
        employeeName: 'Sara',
        department: 'HR',
        leaveType: 'Casual',
        fromDate: DateTime.now(),
        toDate: DateTime.now().add(const Duration(days: 2)),
        approvalStatus: 'Pending',
        reason: 'Family',
      ),
    ];

    holidays = [
      HolidayReport(holidayName: 'Republic Day', date: DateTime(2026, 1, 26)),
    ];

    employees = [
      EmployeeReport(
        employeeId: 'EMP01',
        employeeName: 'John',
        department: 'IT',
        role: 'Developer',
        email: 'john@mail.com',
        phone: '9999999999',
        dateOfJoining: DateTime(2024, 6, 1),
        status: 'Active',
      ),
    ];

    departmentsData = [
      DepartmentReport(
        departmentId: 'D01',
        departmentName: 'IT',
        managerName: 'Robert',
        totalEmployees: 12,
      ),
    ];
  }

  // ================= FILTER LOGIC =================
  bool _matchDepartment(String dept) =>
      departmentFilter == 'All' || dept == departmentFilter;

  bool _matchStatus(String status) =>
      statusFilter == 'All' || status == statusFilter;

  bool _matchDate(DateTime date) {
    if (dateRange == null) return true;
    return date.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
        date.isBefore(dateRange!.end.add(const Duration(days: 1)));
  }

  void _resetFilters() {
    setState(() {
      dateRange = null;
      departmentFilter = 'All';
      statusFilter = 'All';
    });
  }

  // ================= DOWNLOAD STUBS =================
  void _downloadCSV(String type) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$type CSV download (stub)')));
  }

  void _downloadPDF(String type) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$type PDF download (stub)')));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.1 : 12;
    final double spacing = isDesktop ? 20 : 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Tasks'),
            Tab(text: 'Leaves'),
            Tab(text: 'Holidays'),
            Tab(text: 'Employees'),
            Tab(text: 'Departments'),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: spacing,
        ),
        child: Column(
          children: [
            _filterBar(),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _cardList(
                    attendance
                        .where(
                          (a) =>
                              _matchDepartment(a.department) &&
                              _matchStatus(a.status) &&
                              _matchDate(a.date),
                        )
                        .toList(),
                    (a) => [
                      'Employee: ${a.employeeName}',
                      'Dept: ${a.department}',
                      'Date: ${a.date.toString().split(' ')[0]}',
                      'In: ${a.checkIn}',
                      'Out: ${a.checkOut}',
                      'Status: ${a.status}',
                    ],
                    'Attendance',
                  ),
                  _cardList(
                    tasks
                        .where(
                          (t) =>
                              _matchDepartment(t.department) &&
                              _matchStatus(t.status) &&
                              _matchDate(t.assignedDate),
                        )
                        .toList(),
                    (t) => [
                      'Employee: ${t.employeeName}',
                      'Task: ${t.taskName}',
                      'Dept: ${t.department}',
                      'Status: ${t.status}',
                    ],
                    'Tasks',
                  ),
                  _cardList(
                    leaves
                        .where(
                          (l) =>
                              _matchDepartment(l.department) &&
                              _matchStatus(l.approvalStatus) &&
                              _matchDate(l.fromDate),
                        )
                        .toList(),
                    (l) => [
                      'Employee: ${l.employeeName}',
                      'Dept: ${l.department}',
                      'Type: ${l.leaveType}',
                      'Status: ${l.approvalStatus}',
                    ],
                    'Leaves',
                  ),
                  _cardList(
                    holidays.where((h) => _matchDate(h.date)).toList(),
                    (h) => [
                      'Holiday: ${h.holidayName}',
                      'Date: ${h.date.toString().split(' ')[0]}',
                    ],
                    'Holidays',
                  ),
                  _cardList(
                    employees
                        .where(
                          (e) =>
                              _matchDepartment(e.department) &&
                              _matchStatus(e.status),
                        )
                        .toList(),
                    (e) => [
                      'Name: ${e.employeeName}',
                      'Dept: ${e.department}',
                      'Role: ${e.role}',
                      'Status: ${e.status}',
                    ],
                    'Employees',
                  ),
                  _cardList(
                    departmentsData,
                    (d) => [
                      'Dept: ${d.departmentName}',
                      'Manager: ${d.managerName}',
                      'Employees: ${d.totalEmployees}',
                    ],
                    'Departments',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FILTER BAR =================
  Widget _filterBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        DropdownButton<String>(
          value: departmentFilter,
          items: departments
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => departmentFilter = v!),
        ),
        DropdownButton<String>(
          value: statusFilter,
          items: statuses
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => statusFilter = v!),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.date_range),
          label: const Text('Date'),
          onPressed: () async {
            final r = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (r != null) setState(() => dateRange = r);
          },
        ),
        TextButton(onPressed: _resetFilters, child: const Text('Reset')),
      ],
    );
  }

  // ================= CARD LIST GENERIC =================
  Widget _cardList<T>(
    List<T> items,
    List<String> Function(T) mapToStrings,
    String type,
  ) {
    if (items.isEmpty) return Center(child: Text('No $type records'));

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadCSV(type),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _downloadPDF(type),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              final lines = mapToStrings(item);
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map(
                          (line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(line),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
