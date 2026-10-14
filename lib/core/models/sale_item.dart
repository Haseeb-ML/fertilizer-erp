class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double unitCost; // For FIFO / COGS calculation
  final double totalPrice;

  SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.unitCost = 0.0,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'unit': unit,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit_cost': unitCost,
      'total_price': totalPrice,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      unit: map['unit'] as String? ?? 'Bag',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    String? productName,
    String? unit,
    double? quantity,
    double? unitPrice,
    double? unitCost,
    double? totalPrice,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCost: unitCost ?? this.unitCost,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          productName == other.productName;

  @override
  int get hashCode => Object.hash(id, productId, productName);
}
