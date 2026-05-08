import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';

class ExpenseApprovalScreen extends StatefulWidget {
  const ExpenseApprovalScreen({super.key});

  @override
  State<ExpenseApprovalScreen> createState() => _ExpenseApprovalScreenState();
}

class _ExpenseApprovalScreenState extends State<ExpenseApprovalScreen> {
  final ExpenseService _expenseService = ExpenseService();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 900;
    final double horizontalPadding = isDesktop ? size.width * 0.1 : 16;
    final double spacing = isDesktop ? 20 : 12;
    final double fontSizeTitle = isDesktop ? 18 : 14;
    final double fontSizeSub = isDesktop ? 16 : 12;
    final double buttonFontSize = isDesktop ? 16 : 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Approval"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<List<ExpenseModel>>(
        future: _expenseService.getExpenseHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: spacing),
                child: Text(
                  "No expenses to approve",
                  style: TextStyle(fontSize: fontSizeSub),
                ),
              ),
            );
          }

          final expenses = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: spacing,
            ),
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin: EdgeInsets.only(bottom: spacing),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 20 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Name
                      Text(
                        expense.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSizeTitle,
                        ),
                      ),
                      SizedBox(height: spacing / 2),
                      Text(
                        "Expense Type: ${expense.expenseType}",
                        style: TextStyle(fontSize: fontSizeSub),
                      ),
                      Text(
                        "Amount: ₹${expense.amount}",
                        style: TextStyle(fontSize: fontSizeSub),
                      ),
                      Text(
                        "Date: ${expense.date}",
                        style: TextStyle(fontSize: fontSizeSub),
                      ),

                      SizedBox(height: spacing / 2),
                      if (expense.billUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Open bill (PDF/Image)
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text("View Bill"),
                        ),

                      SizedBox(height: spacing / 2),
                      // Approve/Reject Buttons
                      Wrap(
                        spacing: spacing,
                        runSpacing: spacing / 2,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 24 : 16,
                                vertical: isDesktop ? 14 : 10,
                              ),
                              textStyle: TextStyle(fontSize: buttonFontSize),
                            ),
                            onPressed: () => _updateStatus(expense, "Approved"),
                            child: const Text("Approve"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 24 : 16,
                                vertical: isDesktop ? 14 : 10,
                              ),
                              textStyle: TextStyle(fontSize: buttonFontSize),
                            ),
                            onPressed: () => _updateStatus(expense, "Rejected"),
                            child: const Text("Reject"),
                          ),
                        ],
                      ),

                      SizedBox(height: spacing / 2),
                      // Status Chip
                      Chip(
                        label: Text(
                          expense.status,
                          style: TextStyle(fontSize: fontSizeSub),
                        ),
                        backgroundColor: _statusColor(expense.status),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _updateStatus(ExpenseModel expense, String status) {
    setState(() {
      expense.status = status; // ensure status is non-final
    });

    // TODO: Call API to update expense status
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Expense ${status.toLowerCase()}")));
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Approved":
        return Colors.green.shade300;
      case "Rejected":
        return Colors.red.shade300;
      default:
        return Colors.orange.shade300;
    }
  }
}
