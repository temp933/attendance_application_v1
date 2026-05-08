import 'package:flutter/material.dart';

class TravelAssignmentScreen extends StatefulWidget {
  const TravelAssignmentScreen({super.key});

  @override
  State<TravelAssignmentScreen> createState() => _TravelAssignmentScreenState();
}

class _TravelAssignmentScreenState extends State<TravelAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedEmployee;
  String _travelType = "Official";
  String _location = "";
  String _fromDate = "";
  String _toDate = "";
  String _purpose = "";

  final List<String> _employees = ["Kumar", "Priya", "Rohit", "Anita"];
  final List<String> _travelTypes = [
    "Official",
    "Client Visit",
    "Training",
    "Other",
  ];

  void _assignTravel() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Travel/Onsite assigned successfully")),
    );

    // TODO: Send data to API
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.1 : 16;
    final double spacing = isDesktop ? 20 : 12;
    final double fontSize = isDesktop ? 16 : 14;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel / Onsite Assignment"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: spacing,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Select Employee", fontSize),
              DropdownButtonFormField<String>(
                initialValue: _selectedEmployee,
                items: _employees
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: TextStyle(fontSize: fontSize)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedEmployee = v),
                validator: (v) => v == null ? "Select an employee" : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              SizedBox(height: spacing),

              _sectionTitle("Travel Type", fontSize),
              DropdownButtonFormField<String>(
                initialValue: _travelType,
                items: _travelTypes
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: TextStyle(fontSize: fontSize)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _travelType = v!),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              SizedBox(height: spacing),

              _sectionTitle("Location", fontSize),
              TextFormField(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                style: TextStyle(fontSize: fontSize),
                validator: (v) => v!.isEmpty ? "Enter location" : null,
                onSaved: (v) => _location = v!,
              ),
              SizedBox(height: spacing),

              _datePickerField(
                "From Date",
                _fromDate,
                (val) => _fromDate = val,
                fontSize,
              ),
              SizedBox(height: spacing),
              _datePickerField(
                "To Date",
                _toDate,
                (val) => _toDate = val,
                fontSize,
              ),
              SizedBox(height: spacing),

              _sectionTitle("Purpose", fontSize),
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                style: TextStyle(fontSize: fontSize),
                validator: (v) => v!.isEmpty ? "Enter purpose" : null,
                onSaved: (v) => _purpose = v!,
              ),
              SizedBox(height: spacing * 2),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _assignTravel,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text("Assign", style: TextStyle(fontSize: fontSize)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datePickerField(
    String label,
    String value,
    Function(String) onSelected,
    double fontSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label, fontSize),
        TextFormField(
          readOnly: true,
          controller: TextEditingController(text: value),
          style: TextStyle(fontSize: fontSize),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2022),
              lastDate: DateTime(2100),
              initialDate: DateTime.now(),
            );
            if (picked != null) {
              setState(
                () =>
                    onSelected("${picked.day}-${picked.month}-${picked.year}"),
              );
            }
          },
          validator: (v) => value.isEmpty ? "Select $label" : null,
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, double fontSize) {
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
}
