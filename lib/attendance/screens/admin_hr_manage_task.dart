import 'package:flutter/material.dart';

class ManageTaskScreen extends StatefulWidget {
  final bool isAdmin; // true for HR/Admin, false for Employee
  const ManageTaskScreen({super.key, this.isAdmin = false});

  @override
  State<ManageTaskScreen> createState() => _ManageTaskScreenState();
}

class _ManageTaskScreenState extends State<ManageTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  // Task fields
  String _taskTitle = "";
  String _description = "";
  String _assignedEmployee = "";
  String _status = "Pending";
  String _startDate = "";
  String _endDate = "";

  // Sample employees for dropdown (Admin only)
  final List<String> _employees = ["Kumar", "Anita", "Rahul", "Sita"];

  // Sample statuses
  final List<String> _statuses = ["Pending", "In Progress", "Completed"];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.1 : 16;
    final double spacing = isDesktop ? 20 : 12;
    final double fontSizeLabel = isDesktop ? 16 : 14;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? "Manage Tasks" : "My Tasks"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: spacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isAdmin) _taskForm(spacing, fontSizeLabel),
            SizedBox(height: spacing * 1.5),
            _sectionTitle(
              widget.isAdmin ? "All Tasks" : "Your Tasks",
              fontSize: fontSizeLabel + 2,
            ),
            _taskList(fontSizeLabel, spacing),
          ],
        ),
      ),
    );
  }

  // ================= TASK FORM =================
  Widget _taskForm(double spacing, double fontSizeLabel) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(spacing),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Add / Edit Task", fontSize: fontSizeLabel + 2),
              _textField(
                "Task Title",
                fontSize: fontSizeLabel,
                onSaved: (v) => _taskTitle = v!,
              ),
              _textField(
                "Description",
                fontSize: fontSizeLabel,
                maxLines: 3,
                onSaved: (v) => _description = v!,
              ),
              const SizedBox(height: 12),

              // Assign Employee Dropdown
              DropdownButtonFormField<String>(
                initialValue: _assignedEmployee.isEmpty ? null : _assignedEmployee,
                items: _employees
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(fontSize: fontSizeLabel),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _assignedEmployee = v!),
                decoration: const InputDecoration(
                  labelText: "Assign Employee",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Select employee" : null,
              ),
              SizedBox(height: spacing),

              // Dates
              _dateField(
                "Start Date",
                fontSize: fontSizeLabel,
                onSelected: (v) => _startDate = v,
              ),
              _dateField(
                "End Date",
                fontSize: fontSizeLabel,
                onSelected: (v) => _endDate = v,
              ),
              SizedBox(height: spacing),

              // Status Dropdown
              DropdownButtonFormField<String>(
                initialValue: _status,
                items: _statuses
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(fontSize: fontSizeLabel),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: spacing),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    textStyle: TextStyle(fontSize: fontSizeLabel),
                  ),
                  child: const Text("Save Task"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TASK LIST =================
  Widget _taskList(double fontSize, double spacing) {
    // TODO: Replace with API data
    final tasks = [
      {
        "title": "Prepare report",
        "employee": "Kumar",
        "status": "Pending",
        "duration": "10 Mar - 12 Mar",
      },
      {
        "title": "Client Meeting",
        "employee": "Anita",
        "status": "Completed",
        "duration": "15 Mar",
      },
    ];

    return Column(
      children: tasks.map((task) {
        if (!widget.isAdmin && task["employee"] != "Kumar") {
          return const SizedBox();
        }
        return Card(
          margin: EdgeInsets.only(bottom: spacing),
          child: ListTile(
            title: Text(task["title"]!, style: TextStyle(fontSize: fontSize)),
            subtitle: Text(
              "${task["employee"]} • ${task["duration"]}",
              style: TextStyle(fontSize: fontSize - 2),
            ),
            trailing: Chip(
              label: Text(
                task["status"]!,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: _statusColor(task["status"]!),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ================= WIDGET HELPERS =================
  Widget _sectionTitle(String title, {double fontSize = 18}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _textField(
    String label, {
    int maxLines = 1,
    required Function(String?) onSaved,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        style: TextStyle(fontSize: fontSize),
        validator: (v) => v!.isEmpty ? "Required" : null,
        onSaved: onSaved,
      ),
    );
  }

  Widget _dateField(
    String label, {
    required Function(String) onSelected,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        style: TextStyle(fontSize: fontSize),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2022),
            lastDate: DateTime(2100),
            initialDate: DateTime.now(),
          );
          if (picked != null) {
            onSelected("${picked.day}-${picked.month}-${picked.year}");
          }
        },
        validator: (v) => v!.isEmpty ? "Select date" : null,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "In Progress":
        return Colors.blue;
      case "Completed":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Task saved successfully")));

    // TODO: API integration for save / update
  }
}
