class ExpenseModel {
  final String expenseType;
  final double amount;
  final String date;
  String status; // mutable for approval
  final String billUrl;
  final String employeeName; // added to show employee in approval list

  ExpenseModel({
    required this.expenseType,
    required this.amount,
    required this.date,
    required this.status,
    required this.billUrl,
    required this.employeeName,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      expenseType: json['expenseType'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: json['date'] ?? '',
      status: json['status'] ?? '',
      billUrl: json['billUrl'] ?? '',
      employeeName: json['employeeName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expenseType': expenseType,
      'amount': amount,
      'date': date,
      'status': status,
      'billUrl': billUrl,
      'employeeName': employeeName,
    };
  }
}
