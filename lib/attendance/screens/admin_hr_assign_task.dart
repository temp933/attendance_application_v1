import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  String _taskTitle = "";
  String _description = "";
  String _assignedEmployee = "";
  String _status = "Pending";

  final List<String> _employees = ["Kumar", "Anita", "Rahul", "Sita"];
  final List<String> _statuses = ["Pending", "In Progress"];

  // ✅ Date Controllers
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // ✅ Selected Dates
  DateTime? _startDate;
  DateTime? _endDate;

  final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double spacing = isDesktop ? 20 : 12;
    final double fontSizeLabel = isDesktop ? 16 : 14;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Task"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                [
                      _sectionTitle(
                        "Task Details",
                        fontSize: fontSizeLabel + 2,
                      ),

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

                      DropdownButtonFormField<String>(
                        initialValue: _assignedEmployee.isEmpty
                            ? null
                            : _assignedEmployee,
                        items: _employees
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _assignedEmployee = v!),
                        decoration: const InputDecoration(
                          labelText: "Select Employee",
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? "Select employee" : null,
                      ),

                      // ✅ Start Date
                      _dateField(
                        label: "Start Date",
                        controller: _startDateController,
                        onTap: () => _pickDate(isStart: true),
                      ),

                      // ✅ End Date
                      _dateField(
                        label: "End Date",
                        controller: _endDateController,
                        onTap: () {
                          if (_startDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Select start date first"),
                              ),
                            );
                            return;
                          }
                          _pickDate(isStart: false);
                        },
                      ),

                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        items: _statuses
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
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
                          onPressed: _assignTask,
                          child: const Text("Assign Task"),
                        ),
                      ),
                    ]
                    .map(
                      (e) => Padding(
                        padding: EdgeInsets.only(bottom: spacing),
                        child: e,
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _sectionTitle(String title, {double fontSize = 18}) {
    return Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    );
  }

  Widget _textField(
    String label, {
    int maxLines = 1,
    required Function(String?) onSaved,
    double fontSize = 14,
  }) {
    return TextFormField(
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) => v == null || v.isEmpty ? "Required" : null,
      onSaved: onSaved,
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          validator: (v) => v == null || v.isEmpty ? "Select date" : null,
        ),
      ),
    );
  }

  // ================= DATE PICKER =================
  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate ?? DateTime.now()
          : _endDate ?? _startDate ?? DateTime.now(),
      firstDate: isStart ? DateTime(2020) : _startDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateController.text = _dateFormat.format(picked);

        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _endDateController.clear();
        }
      } else {
        _endDate = picked;
        _endDateController.text = _dateFormat.format(picked);
      }
    });
  }

  void _assignTask() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Task assigned to $_assignedEmployee"),
        backgroundColor: Colors.green,
      ),
    );

    // ✅ Clear form fields
    _formKey.currentState!.reset();

    setState(() {
      _assignedEmployee = "";
      _status = "Pending";

      _startDate = null;
      _endDate = null;

      _startDateController.clear();
      _endDateController.clear();
    });
  }
}
