import 'purchase_item.dart';

class Purchase {
  final int? id;
  final String invoiceNumber;
  final int supplierId;
  final String supplierName;
  final String purchaseDate;
  final double subtotal;
  final double discount;
  final double freightCharges;
  final double grandTotal;
  final double paidAmount;
  final double balanceDue;
  final String paymentStatus; // PAID, PARTIAL, UNPAID
  final String? paymentMethod;
  final String notes;
  final bool isReversed;
  final String createdAt;
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.purchaseDate,
    required this.subtotal,
    this.discount = 0.0,
    this.freightCharges = 0.0,
    required this.grandTotal,
    this.paidAmount = 0.0,
    required this.balanceDue,
    required this.paymentStatus,
    this.paymentMethod,
    this.notes = '',
    this.isReversed = false,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'purchase_date': purchaseDate,
      'subtotal': subtotal,
      'discount': discount,
      'freight_charges': freightCharges,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'notes': notes,
      'is_reversed': isReversed ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Purchase.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseItem> items = const [],
  }) {
    return Purchase(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      supplierId: map['supplier_id'] as int? ?? 0,
      supplierName: map['supplier_name'] as String? ?? '',
      purchaseDate: map['purchase_date'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      freightCharges: (map['freight_charges'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status'] as String? ?? 'UNPAID',
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String? ?? '',
      isReversed: (map['is_reversed'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String? ?? '',
      items: items,
    );
  }

  Purchase copyWith({
    int? id,
    String? invoiceNumber,
    int? supplierId,
    String? supplierName,
    String? purchaseDate,
    double? subtotal,
    double? discount,
    double? freightCharges,
    double? grandTotal,
    double? paidAmount,
    double? balanceDue,
    String? paymentStatus,
    String? paymentMethod,
    String? notes,
    bool? isReversed,
    String? createdAt,
    List<PurchaseItem>? items,
  }) {
    return Purchase(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      freightCharges: freightCharges ?? this.freightCharges,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isReversed: isReversed ?? this.isReversed,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
