class LedgerEntry {
  final int? id;
  final int partyId; // customer_id or supplier_id
  final String transactionDate;
  final String
  transactionType; // OPENING_BALANCE, SALE, PURCHASE, PAYMENT_RECEIVED, PAYMENT_PAID, RETURN, ADJUSTMENT
  final int? referenceId;
  final String? referenceNumber;
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;
  final String createdAt;

  LedgerEntry({
    this.id,
    required this.partyId,
    required this.transactionDate,
    required this.transactionType,
    this.referenceId,
    this.referenceNumber,
    required this.description,
    this.debit = 0.0,
    this.credit = 0.0,
    required this.runningBalance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap({required bool isCustomer}) {
    final map = <String, dynamic>{
      if (id != null) 'id': id,
      'transaction_date': transactionDate,
      'transaction_type': transactionType,
      'reference_id': referenceId,
      'reference_number': referenceNumber,
      'description': description,
      'debit': debit,
      'credit': credit,
      'running_balance': runningBalance,
      'created_at': createdAt,
    };
    if (isCustomer) {
      map['customer_id'] = partyId;
    } else {
      map['supplier_id'] = partyId;
    }
    return map;
  }

  factory LedgerEntry.fromMap(
    Map<String, dynamic> map, {
    required bool isCustomer,
  }) {
    return LedgerEntry(
      id: map['id'] as int?,
      partyId:
          (isCustomer ? map['customer_id'] : map['supplier_id']) as int? ?? 0,
      transactionDate: map['transaction_date'] as String? ?? '',
      transactionType: map['transaction_type'] as String? ?? '',
      referenceId: map['reference_id'] as int?,
      referenceNumber: map['reference_number'] as String?,
      description: map['description'] as String? ?? '',
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (map['running_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
