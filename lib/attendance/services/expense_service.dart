import '../models/expense_model.dart';

class ExpenseService {
  Future<void> submitExpense(ExpenseModel expense) async {
    // TODO: Replace with API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<List<ExpenseModel>> getExpenseHistory() async {
    // TODO: Replace with API call
    await Future.delayed(const Duration(seconds: 1));

    return [
      ExpenseModel(
        expenseType: "Travel",
        amount: 2500,
        date: "05 Mar 2025",
        status: "Approved",
        billUrl: "bill1.jpg",
        employeeName: "Alice Smith",
      ),
      ExpenseModel(
        expenseType: "Travel",
        amount: 1000,
        date: "22-12-2025",
        status: "Pending",
        billUrl: "bill1.jpg",
        employeeName: "Alice Smith", // <-- add this
      ),
    ];
  }
}
