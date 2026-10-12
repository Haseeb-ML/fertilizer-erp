class Payment {
  final int? id;
  final String paymentType; // CUSTOMER_IN, SUPPLIER_OUT
  final String partyType; // CUSTOMER, SUPPLIER
  final int partyId;
  final String partyName;
  final int? referenceInvoiceId;
  final String? referenceInvoiceNumber;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String referenceNumber;
  final String notes;
  final String createdAt;

  Payment({
    this.id,
    required this.paymentType,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    this.referenceInvoiceId,
    this.referenceInvoiceNumber,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber = '',
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_type': paymentType,
      'party_type': partyType,
      'party_id': partyId,
      'party_name': partyName,
      'reference_invoice_id': referenceInvoiceId,
      'reference_invoice_number': referenceInvoiceNumber,
      'amount': amount,
      'payment_date': paymentDate,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      paymentType: map['payment_type'] as String? ?? 'CUSTOMER_IN',
      partyType: map['party_type'] as String? ?? 'CUSTOMER',
      partyId: map['party_id'] as int? ?? 0,
      partyName: map['party_name'] as String? ?? '',
      referenceInvoiceId: map['reference_invoice_id'] as int?,
      referenceInvoiceNumber: map['reference_invoice_number'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: map['payment_date'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      referenceNumber: map['reference_number'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
