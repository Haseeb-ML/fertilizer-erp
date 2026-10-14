class LedgerEntry {
  final int? id;
  final int partyId; // customer_id or supplier_id
  final String transactionDate;
  final String
  transactionType; // OPENING_BALANCE, SALE, CREDIT_SALE, CASH_SALE, PARTIAL_SALE, PURCHASE, PAYMENT_RECEIVED, PAYMENT_PAID, SALE_RETURN, RETURN, ADJUSTMENT
  final int? referenceId;
  final String? referenceNumber;
  final String description;
  final double debit;
  final double credit;
  final double runningBalance;
  final String createdAt;
  final List<String> itemsDetails;
  final double totalBags;
  final double? invoicePaidAmount;
  final double? invoiceBalanceDue;
  final String? invoicePaymentStatus;
  final String? invoiceNotes;
  final String? customerName;

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
    this.itemsDetails = const [],
    this.totalBags = 0.0,
    this.invoicePaidAmount,
    this.invoiceBalanceDue,
    this.invoicePaymentStatus,
    this.invoiceNotes,
    this.customerName,
  });

  double get previousBalance => runningBalance - debit + credit;

  bool get isSale =>
      (transactionType == 'SALE' ||
          transactionType == 'CREDIT_SALE' ||
          transactionType == 'CASH_SALE' ||
          transactionType == 'PARTIAL_SALE') &&
      transactionType != 'SALE_RETURN' &&
      transactionType != 'SALE_REVERSAL' &&
      transactionType != 'SALE_REVERSAL_REFUND';

  bool get isPayment =>
      transactionType == 'PAYMENT_RECEIVED' ||
      transactionType == 'PAYMENT_PAID';

  bool get isReturn =>
      transactionType == 'SALE_RETURN' ||
      transactionType == 'PURCHASE_RETURN' ||
      transactionType == 'RETURN';

  bool get isOpeningBalance => transactionType == 'OPENING_BALANCE';

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
    List<String> itemsDetails = const [],
    double totalBags = 0.0,
    double? invoicePaidAmount,
    double? invoiceBalanceDue,
    String? invoicePaymentStatus,
    String? invoiceNotes,
    String? customerName,
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
      itemsDetails: itemsDetails,
      totalBags: totalBags,
      invoicePaidAmount: invoicePaidAmount,
      invoiceBalanceDue: invoiceBalanceDue,
      invoicePaymentStatus: invoicePaymentStatus,
      invoiceNotes: invoiceNotes,
      customerName: customerName,
    );
  }

  LedgerEntry copyWith({
    int? id,
    int? partyId,
    String? transactionDate,
    String? transactionType,
    int? referenceId,
    String? referenceNumber,
    String? description,
    double? debit,
    double? credit,
    double? runningBalance,
    String? createdAt,
    List<String>? itemsDetails,
    double? totalBags,
    double? invoicePaidAmount,
    double? invoiceBalanceDue,
    String? invoicePaymentStatus,
    String? invoiceNotes,
    String? customerName,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      referenceId: referenceId ?? this.referenceId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      runningBalance: runningBalance ?? this.runningBalance,
      createdAt: createdAt ?? this.createdAt,
      itemsDetails: itemsDetails ?? this.itemsDetails,
      totalBags: totalBags ?? this.totalBags,
      invoicePaidAmount: invoicePaidAmount ?? this.invoicePaidAmount,
      invoiceBalanceDue: invoiceBalanceDue ?? this.invoiceBalanceDue,
      invoicePaymentStatus: invoicePaymentStatus ?? this.invoicePaymentStatus,
      invoiceNotes: invoiceNotes ?? this.invoiceNotes,
      customerName: customerName ?? this.customerName,
    );
  }
}
