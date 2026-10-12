import 'sale_item.dart';

class Sale {
  final int? id;
  final String invoiceNumber;
  final int? customerId; // Null for walk-in cash customer
  final String customerName;
  final String saleDate;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final double paidAmount;
  final double balanceDue;
  final double totalCost; // Cost of goods sold (COGS)
  final double grossProfit; // grandTotal - totalCost
  final String paymentStatus; // PAID, PARTIAL, UNPAID
  final String paymentMethod; // Cash, Credit, Bank Transfer, etc.
  final String notes;
  final bool isReversed;
  final String createdAt;
  final List<SaleItem> items;

  Sale({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.customerName,
    required this.saleDate,
    required this.subtotal,
    this.discount = 0.0,
    required this.grandTotal,
    this.paidAmount = 0.0,
    required this.balanceDue,
    this.totalCost = 0.0,
    this.grossProfit = 0.0,
    required this.paymentStatus,
    required this.paymentMethod,
    this.notes = '',
    this.isReversed = false,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'sale_date': saleDate,
      'subtotal': subtotal,
      'discount': discount,
      'grand_total': grandTotal,
      'paid_amount': paidAmount,
      'balance_due': balanceDue,
      'total_cost': totalCost,
      'gross_profit': grossProfit,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'notes': notes,
      'is_reversed': isReversed ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory Sale.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem> items = const [],
  }) {
    return Sale(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String? ?? 'Walk-in Customer',
      saleDate: map['sale_date'] as String? ?? '',
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balanceDue: (map['balance_due'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
      grossProfit: (map['gross_profit'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status'] as String? ?? 'PAID',
      paymentMethod: map['payment_method'] as String? ?? 'Cash',
      notes: map['notes'] as String? ?? '',
      isReversed: (map['is_reversed'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String? ?? '',
      items: items,
    );
  }

  Sale copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    String? customerName,
    String? saleDate,
    double? subtotal,
    double? discount,
    double? grandTotal,
    double? paidAmount,
    double? balanceDue,
    double? totalCost,
    double? grossProfit,
    String? paymentStatus,
    String? paymentMethod,
    String? notes,
    bool? isReversed,
    String? createdAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      saleDate: saleDate ?? this.saleDate,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceDue: balanceDue ?? this.balanceDue,
      totalCost: totalCost ?? this.totalCost,
      grossProfit: grossProfit ?? this.grossProfit,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      isReversed: isReversed ?? this.isReversed,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
