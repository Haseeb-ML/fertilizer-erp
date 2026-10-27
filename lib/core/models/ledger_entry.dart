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
  final List<LedgerItemDetail> structuredItems;

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
    this.structuredItems = const [],
    this.totalBags = 0.0,
    this.invoicePaidAmount,
    this.invoiceBalanceDue,
    this.invoicePaymentStatus,
    this.invoiceNotes,
    this.customerName,
  });

  List<LedgerItemDetail> get parsedItems {
    if (structuredItems.isNotEmpty) return structuredItems;
    final list = <LedgerItemDetail>[];
    for (final str in itemsDetails) {
      final parsed = LedgerItemDetail.parse(str);
      if (parsed != null) {
        list.add(parsed);
      } else {
        list.add(
          LedgerItemDetail(
            productName: str,
            quantity: 0,
            unitPrice: 0,
            totalPrice: 0,
          ),
        );
      }
    }
    return list;
  }

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
    List<LedgerItemDetail> structuredItems = const [],
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
      structuredItems: structuredItems,
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
    List<LedgerItemDetail>? structuredItems,
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
      structuredItems: structuredItems ?? this.structuredItems,
      totalBags: totalBags ?? this.totalBags,
      invoicePaidAmount: invoicePaidAmount ?? this.invoicePaidAmount,
      invoiceBalanceDue: invoiceBalanceDue ?? this.invoiceBalanceDue,
      invoicePaymentStatus: invoicePaymentStatus ?? this.invoicePaymentStatus,
      invoiceNotes: invoiceNotes ?? this.invoiceNotes,
      customerName: customerName ?? this.customerName,
    );
  }
}

class LedgerItemDetail {
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? reason;

  const LedgerItemDetail({
    required this.productName,
    required this.quantity,
    this.unit = 'Bag',
    required this.unitPrice,
    required this.totalPrice,
    this.reason,
  });

  Map<String, dynamic> toMap() => {
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    if (reason != null) 'reason': reason,
  };

  factory LedgerItemDetail.fromMap(Map<String, dynamic> map) =>
      LedgerItemDetail(
        productName:
            map['productName'] as String? ??
            map['product_name'] as String? ??
            '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: map['unit'] as String? ?? 'Bag',
        unitPrice:
            (map['unitPrice'] as num?)?.toDouble() ??
            (map['unit_price'] as num?)?.toDouble() ??
            0.0,
        totalPrice:
            (map['totalPrice'] as num?)?.toDouble() ??
            (map['total_price'] as num?)?.toDouble() ??
            (map['total_amount'] as num?)?.toDouble() ??
            0.0,
        reason: map['reason'] as String?,
      );

  static LedgerItemDetail? parse(String text) {
    try {
      final isReturn = text.startsWith('Returned:');
      var clean = text;
      String? reason;
      if (isReturn) {
        clean = clean.replaceFirst('Returned:', '').trim();
      }
      if (clean.contains('(') && clean.endsWith(')')) {
        final lastParenOpen = clean.lastIndexOf('(');
        final lastParenClose = clean.lastIndexOf(')');
        if (lastParenClose > lastParenOpen) {
          reason = clean.substring(lastParenOpen + 1, lastParenClose);
          clean = clean.substring(0, lastParenOpen).trim();
        }
      }

      // Expected: "qty unit × name @ ₨rate = ₨total"
      final parts = clean.split('×');
      if (parts.length != 2) return null;
      final left = parts[0].trim();
      final right = parts[1].trim();

      final leftTokens = left.split(' ');
      final qty = double.tryParse(leftTokens[0]) ?? 0.0;
      final unit =
          leftTokens.length > 1 ? leftTokens.sublist(1).join(' ') : 'Bag';

      final atParts = right.split('@');
      if (atParts.length != 2) return null;
      final productName = atParts[0].trim();
      final rateAndTotal = atParts[1].trim();

      final eqParts = rateAndTotal.split('=');
      final rateStr = eqParts[0].replaceAll(RegExp(r'[^0-9.]'), '');
      final totalStr =
          eqParts.length > 1
              ? eqParts[1].replaceAll(RegExp(r'[^0-9.]'), '')
              : '';

      final rate = double.tryParse(rateStr) ?? 0.0;
      final total = double.tryParse(totalStr) ?? (qty * rate);

      return LedgerItemDetail(
        productName: productName,
        quantity: qty,
        unit: unit,
        unitPrice: rate,
        totalPrice: total,
        reason: reason,
      );
    } catch (_) {
      return null;
    }
  }
}
