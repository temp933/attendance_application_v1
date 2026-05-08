import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/asign_location.dart';
import '../services/asign_location_services.dart';
import '../providers/api_client.dart';

class AdminAssignLocation extends StatefulWidget {
  final String role;

  const AdminAssignLocation({super.key, required this.role});

  @override
  State<AdminAssignLocation> createState() => _AdminAssignLocationState();
}

class _AdminAssignLocationState extends State<AdminAssignLocation>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AssignLocationModel> allEmployees = [];
  Set<int> selectedEmpIds = {};
  bool isLoading = true;

  // ── Helpers ────────────────────────────────────────────────────────────────

  String formatDate(DateTime? d) {
    if (d == null) return "-";
    return DateFormat('yyyy-MM-dd').format(d);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Working":
        return Colors.green;
      case "Future":
        return Colors.orange;
      case "Extended":
        return Colors.blue;
      case "Relieved":
        return Colors.purple;
      case "Completed":
        return Colors.red;
      case "Not Completed":
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  // ── Filtered lists ─────────────────────────────────────────────────────────

  /// Tab 1: Active (working / future / not-completed) + Extended + Relieved until end date
  List<AssignLocationModel> get workingNowAndFuture {
    return allEmployees.where((e) {
      // Backend already computes work_status correctly — trust it
      return e.displayStatus == "Working" ||
          e.displayStatus == "Future" ||
          e.displayStatus == "Not Completed" ||
          e.displayStatus == "Extended" ||
          e.displayStatus == "Relieved";
    }).toList();
  }

  /// Tab 2: All employees for checkbox + assign
  List<AssignLocationModel> get allForAssignment => allEmployees;

  // ── Data fetching ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Clear selection when switching tabs
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => selectedEmpIds.clear());
      }
    });
    fetchEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchEmployees() async {
    try {
      final data = await AssignLocationService.getCurrentWorkingEmployees();
      if (!mounted) return;
      setState(() {
        allEmployees = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
    }
  }

  // ── Status update ──────────────────────────────────────────────────────────

  Future<void> updateWorkStatus(
    AssignLocationModel e,
    String status, {
    String? reason,
    DateTime? endDate,
  }) async {
    try {
      await AssignLocationService.updateWorkStatus(
        empId: e.empId,
        status: status,
        updatedBy: widget.role,
        reason: reason,
        endDate: endDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(endDate),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status updated to $status")));
      fetchEmployees();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $err")));
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void openRelievedDialog(AssignLocationModel e) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Relieved"),
            content: TextField(
              controller: reasonCtrl,
              onChanged: (_) => setDialogState(() {}),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Reason (Required)",
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: reasonCtrl.text.trim().isNotEmpty
                    ? () {
                        updateWorkStatus(
                          e,
                          "Relieved",
                          reason: reasonCtrl.text.trim(),
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text("Submit"),
              ),
            ],
          );
        },
      ),
    );
  }

  void openExtendedDialog(AssignLocationModel e) {
    final reasonCtrl = TextEditingController();
    DateTime? newEndDate;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool canSubmit =
              reasonCtrl.text.trim().isNotEmpty && newEndDate != null;

          return AlertDialog(
            title: const Text("Extended"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        initialDate: e.endDate ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => newEndDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "New End Date (Required)",
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        newEndDate == null
                            ? "Select new end date"
                            : DateFormat('yyyy-MM-dd').format(newEndDate!),
                        style: TextStyle(
                          color: newEndDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    onChanged: (_) => setDialogState(() {}),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Extend Reason (Required)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () {
                        updateWorkStatus(
                          e,
                          "Extended",
                          reason: reasonCtrl.text.trim(),
                          endDate: newEndDate,
                        );
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text("Submit"),
              ),
            ],
          );
        },
      ),
    );
  }

  void openAssignDialog() {
    String? selectedLocation;
    int? selectedLocationId;
    final aboutCtrl = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    List<Map<String, dynamic>> locations = [];
    bool isLoadingLocations = true;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch locations once
            if (isLoadingLocations && locations.isEmpty) {
              Future.microtask(() async {
                try {
                  final response = await ApiClient.get('/locations');
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body) as List<dynamic>;
                    setDialogState(() {
                      locations = data
                          .map(
                            (loc) => {
                              'id': loc['location_id'] as int,
                              'name': loc['location_nick_name'] as String,
                            },
                          )
                          .toList();
                      isLoadingLocations = false;
                    });
                  } else {
                    setDialogState(() => isLoadingLocations = false);
                  }
                } catch (_) {
                  setDialogState(() => isLoadingLocations = false);
                }
              });
            }

            final bool isFormFilled =
                selectedLocationId != null &&
                aboutCtrl.text.trim().isNotEmpty &&
                startDate != null &&
                endDate != null;

            return AlertDialog(
              title: const Text("Assign Location"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Location dropdown
                    isLoadingLocations
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<int>(
                            initialValue: selectedLocationId,
                            onChanged: (val) {
                              setDialogState(() {
                                selectedLocationId = val;
                                selectedLocation =
                                    locations.firstWhere(
                                          (l) => l['id'] == val,
                                        )['name']
                                        as String;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: "Location",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            items: locations
                                .map(
                                  (loc) => DropdownMenuItem<int>(
                                    value: loc['id'] as int,
                                    child: Text(loc['name'] as String),
                                  ),
                                )
                                .toList(),
                          ),
                    const SizedBox(height: 12),

                    // Start date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => startDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Start Date",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          startDate == null
                              ? "Select start date"
                              : DateFormat('yyyy-MM-dd').format(startDate!),
                          style: TextStyle(
                            color: startDate == null
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // End date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: startDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "End Date",
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          endDate == null
                              ? "Select end date"
                              : DateFormat('yyyy-MM-dd').format(endDate!),
                          style: TextStyle(
                            color: endDate == null ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // About work
                    TextField(
                      controller: aboutCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "About Work",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isFormFilled
                      ? () async {
                          // Validate end >= start
                          if (endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "End date cannot be before start date",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            await AssignLocationService.assignLocation(
                              empIds: selectedEmpIds.toList(),
                              locationId: selectedLocationId!,
                              aboutWork: aboutCtrl.text.trim(),
                              startDate: DateFormat(
                                'yyyy-MM-dd',
                              ).format(startDate!),
                              endDate: DateFormat(
                                'yyyy-MM-dd',
                              ).format(endDate!),
                              assignBy: widget.role,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Successfully assigned ${selectedEmpIds.length} employee(s)!",
                                ),
                              ),
                            );
                            Navigator.pop(context);
                            setState(() => selectedEmpIds.clear());
                            fetchEmployees();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                        }
                      : null,
                  child: const Text("Assign"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Action menu ────────────────────────────────────────────────────────────

  Widget buildMenu(AssignLocationModel e) {
    // Only show relevant actions based on current status
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == "Completed") {
          updateWorkStatus(e, "Completed");
        } else if (value == "Relieved") {
          openRelievedDialog(e);
        } else if (value == "Extended") {
          openExtendedDialog(e);
        }
      },
      itemBuilder: (context) {
        return [
          if (e.displayStatus != "Completed" && e.displayStatus != "Relieved")
            const PopupMenuItem(
              value: "Completed",
              child: Text("Mark Completed"),
            ),
          if (e.displayStatus != "Completed" && e.displayStatus != "Relieved")
            const PopupMenuItem(value: "Relieved", child: Text("Relieved")),
          if (e.displayStatus != "Completed" && e.displayStatus != "Relieved")
            const PopupMenuItem(value: "Extended", child: Text("Extended")),
        ];
      },
    );
  }

  // ── List builder ───────────────────────────────────────────────────────────

  Widget buildList(
    List<AssignLocationModel> list, {
    required bool showCheckbox,
  }) {
    if (list.isEmpty) {
      return const Center(child: Text("No records found"));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 700;

        if (isDesktop) {
          return _buildDesktopList(list, showCheckbox: showCheckbox);
        } else {
          return _buildMobileList(list, showCheckbox: showCheckbox);
        }
      },
    );
  }

  // ── Desktop list ───────────────────────────────────────────────────────────

  Widget _buildDesktopList(
    List<AssignLocationModel> list, {
    required bool showCheckbox,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final e = list[index];
        final statusColor = getStatusColor(e.displayStatus);
        final hasReason = e.extendReason != null && e.extendReason!.isNotEmpty;

        final rowWidgets = _buildDesktopRow(e, statusColor, showCheckbox);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: (!showCheckbox && hasReason)
              ? ExpansionTile(
                  title: Row(children: rowWidgets),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [_buildReasonTile(e)],
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: rowWidgets),
                ),
        );
      },
    );
  }

  List<Widget> _buildDesktopRow(
    AssignLocationModel e,
    Color statusColor,
    bool showCheckbox,
  ) {
    return [
      if (showCheckbox)
        Checkbox(
          value: selectedEmpIds.contains(e.empId),
          onChanged: (val) => setState(() {
            if (val == true) {
              selectedEmpIds.add(e.empId);
            } else {
              selectedEmpIds.remove(e.empId);
            }
          }),
        ),
      Expanded(
        child: Text(
          e.empId.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      Expanded(child: Text(e.empName)),
      Expanded(child: Text(e.locationName ?? "-")),
      Expanded(child: Text(formatDate(e.startDate))),
      Expanded(child: Text(formatDate(e.endDate))),
      Expanded(
        child: Text(
          e.displayStatus,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
        ),
      ),
      if (!showCheckbox) buildMenu(e),
    ];
  }

  // ── Mobile list (horizontal scroll) ───────────────────────────────────────

  static const List<String> _mobileHeaders = [
    "ID",
    "Name",
    "Location",
    "Start",
    "End",
    "Status",
  ];
  static const List<double> _colWidths = [55, 140, 110, 105, 105, 115];

  // Shared horizontal ScrollController so header + rows scroll together
  final ScrollController _mobileScrollCtrl = ScrollController();

  Widget _buildMobileList(
    List<AssignLocationModel> list, {
    required bool showCheckbox,
  }) {
    const double checkW = 50.0;
    const double menuW = 60.0;

    double totalWidth = _colWidths.fold(0, (a, b) => a + b);
    if (showCheckbox) totalWidth += checkW;
    if (!showCheckbox) totalWidth += menuW;

    return Column(
      children: [
        // ── Sticky header ──────────────────────────────────────────────────
        SingleChildScrollView(
          controller: _mobileScrollCtrl,
          scrollDirection: Axis.horizontal,
          child: Container(
            width: totalWidth,
            color: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
            child: Row(
              children: [
                if (showCheckbox)
                  SizedBox(
                    width: checkW,
                    child: const Icon(Icons.check_box_outline_blank, size: 20),
                  ),
                ..._mobileHeaders.asMap().entries.map(
                  (entry) => SizedBox(
                    width: _colWidths[entry.key],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!showCheckbox) SizedBox(width: menuW),
              ],
            ),
          ),
        ),

        // ── Scrollable rows ────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final e = list[index];
              final statusColor = getStatusColor(e.displayStatus);
              final hasReason =
                  e.extendReason != null && e.extendReason!.isNotEmpty;

              Widget rowContent = SingleChildScrollView(
                // Sync horizontal scroll with header
                controller: _mobileScrollCtrl,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Row(
                    children: [
                      if (showCheckbox)
                        SizedBox(
                          width: checkW,
                          child: Checkbox(
                            value: selectedEmpIds.contains(e.empId),
                            onChanged: (val) => setState(() {
                              if (val == true) {
                                selectedEmpIds.add(e.empId);
                              } else {
                                selectedEmpIds.remove(e.empId);
                              }
                            }),
                          ),
                        ),
                      _mobileCell(
                        e.empId.toString(),
                        0,
                        fontWeight: FontWeight.bold,
                      ),
                      _mobileCell(e.empName, 1),
                      _mobileCell(e.locationName ?? "-", 2),
                      _mobileCell(formatDate(e.startDate), 3),
                      _mobileCell(formatDate(e.endDate), 4),
                      _mobileCell(e.displayStatus, 5, color: statusColor),
                      if (!showCheckbox)
                        SizedBox(width: menuW, child: buildMenu(e)),
                    ],
                  ),
                ),
              );

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                  color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                ),
                child: (!showCheckbox && hasReason)
                    ? ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.all(12),
                        title: rowContent,
                        children: [_buildReasonTile(e)],
                      )
                    : rowContent,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mobileCell(
    String text,
    int colIndex, {
    Color? color,
    FontWeight? fontWeight,
  }) {
    return SizedBox(
      width: _colWidths[colIndex],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: fontWeight,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildReasonTile(AssignLocationModel e) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blue[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.isRelieved
                ? "Relieved Reason: ${e.extendReason}"
                : "Extend Reason: ${e.extendReason}",
            style: TextStyle(
              color: e.isRelieved ? Colors.purple : Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (e.doneBy != null) ...[
            const SizedBox(height: 4),
            Text(
              "Done By: ${e.doneBy}",
              style: const TextStyle(
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Employee Work Assignment"),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Working / Future"),
            Tab(text: "All Employees"),
          ],
        ),
        actions: [
          if (selectedEmpIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.assignment),
              tooltip: "Assign Location",
              onPressed: openAssignDialog,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                buildList(workingNowAndFuture, showCheckbox: false),
                buildList(allForAssignment, showCheckbox: true),
              ],
            ),
    );
  }
}
