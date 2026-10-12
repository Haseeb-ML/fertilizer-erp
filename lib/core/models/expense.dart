class Expense {
  final int? id;
  final String category;
  final double amount;
  final String expenseDate;
  final String paymentMethod;
  final String title;
  final String notes;
  final String createdAt;

  Expense({
    this.id,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.paymentMethod = 'Cash',
    required this.title,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'amount': amount,
      'expense_date': expenseDate,
      'payment_method': paymentMethod,
      'title': title,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      category: map['category'] as String? ?? 'Miscellaneous',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      expenseDate: map['expense_date'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      title: map['title'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Expense copyWith({
    int? id,
    String? category,
    double? amount,
    String? expenseDate,
    String? paymentMethod,
    String? title,
    String? notes,
    String? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
