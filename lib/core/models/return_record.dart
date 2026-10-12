class ReturnRecord {
  final int? id;
  final String returnType; // SALE_RETURN, PURCHASE_RETURN
  final int originalInvoiceId;
  final String originalInvoiceNumber;
  final int partyId;
  final String partyName;
  final String returnDate;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final String refundType; // LEDGER_ADJUST, CASH_REFUND
  final String reason;
  final String createdAt;

  ReturnRecord({
    this.id,
    required this.returnType,
    required this.originalInvoiceId,
    required this.originalInvoiceNumber,
    required this.partyId,
    required this.partyName,
    required this.returnDate,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.refundType,
    this.reason = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'return_type': returnType,
      'original_invoice_id': originalInvoiceId,
      'original_invoice_number': originalInvoiceNumber,
      'party_id': partyId,
      'party_name': partyName,
      'return_date': returnDate,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'refund_type': refundType,
      'reason': reason,
      'created_at': createdAt,
    };
  }

  factory ReturnRecord.fromMap(Map<String, dynamic> map) {
    return ReturnRecord(
      id: map['id'] as int?,
      returnType: map['return_type'] as String? ?? 'SALE_RETURN',
      originalInvoiceId: map['original_invoice_id'] as int? ?? 0,
      originalInvoiceNumber: map['original_invoice_number'] as String? ?? '',
      partyId: map['party_id'] as int? ?? 0,
      partyName: map['party_name'] as String? ?? '',
      returnDate: map['return_date'] as String? ?? '',
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      refundType: map['refund_type'] as String? ?? 'LEDGER_ADJUST',
      reason: map['reason'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
