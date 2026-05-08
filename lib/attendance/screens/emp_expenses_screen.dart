import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';
import 'package:file_picker/file_picker.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ExpenseService _expenseService;
  late Future<List<ExpenseModel>> _expenseHistoryFuture;

  final TextEditingController _dateController = TextEditingController();

  String _expenseType = 'Travel';
  double _amount = 0;
  String _date = '';
  String _billPath = '';

  final List<String> _expenseTypes = [
    'Travel',
    'Food',
    'Accommodation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _expenseService = ExpenseService();
    _expenseHistoryFuture = _expenseService.getExpenseHistory();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _date = "${picked.day}-${picked.month}-${picked.year}";
        _dateController.text = _date;
      });
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final expense = ExpenseModel(
      expenseType: _expenseType,
      amount: _amount,
      date: _date,
      status: "Pending",
      billUrl: _billPath,
      employeeName: "John Doe",
    );

    await _expenseService.submitExpense(expense);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Expense submitted successfully")),
    );

    setState(() {
      _expenseHistoryFuture = _expenseService.getExpenseHistory();
      _billPath = '';
      _dateController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? size.width * 0.18 : 16,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= ADD EXPENSE =================
            Text(
              "Add Expense",
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _expenseType,
                        items: _expenseTypes
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _expenseType = value!),
                        decoration: const InputDecoration(
                          labelText: "Expense Type",
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Amount"),
                        validator: (value) =>
                            value!.isEmpty ? "Enter amount" : null,
                        onSaved: (value) =>
                            _amount = double.tryParse(value!) ?? 0,
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        readOnly: true,
                        controller: _dateController,
                        decoration: const InputDecoration(
                          labelText: "Date",
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _selectDate,
                        validator: (_) => _date.isEmpty ? "Select date" : null,
                      ),

                      const SizedBox(height: 14),

                      OutlinedButton.icon(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles(
                                type: FileType.custom,
                                allowedExtensions: [
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'pdf',
                                ],
                              );

                          if (result != null &&
                              result.files.single.path != null) {
                            setState(() {
                              _billPath = result.files.single.path!;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No file selected")),
                            );
                          }
                        },
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          _billPath.isEmpty
                              ? "Upload Bill"
                              : "Uploaded: ${_billPath.split('/').last}",
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _submitExpense,
                          child: const Text("Submit"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ================= HISTORY =================
            Text(
              "Expense Status",
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<ExpenseModel>>(
              future: _expenseHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No expenses found");
                }

                return Column(
                  children: snapshot.data!
                      .map((e) => _expenseHistoryCard(e, isDesktop))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= HISTORY CARD =================
  Widget _expenseHistoryCard(ExpenseModel expense, bool isDesktop) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 16,
          vertical: isDesktop ? 12 : 8,
        ),
        leading: const Icon(Icons.receipt_long, color: Colors.indigo),
        title: Text(
          expense.expenseType,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("₹${expense.amount} • ${expense.date}"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor(expense.status).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            expense.status,
            style: TextStyle(
              color: _statusColor(expense.status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ================= STATUS COLOR =================
  static Color _statusColor(String status) {
    switch (status) {
      case "Approved":
        return Colors.green;
      case "Rejected":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
