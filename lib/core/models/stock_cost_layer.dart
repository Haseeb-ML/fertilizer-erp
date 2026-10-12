class StockCostLayer {
  final int? id;
  final int productId;
  final int? purchaseId;
  final String purchaseDate;
  final double unitCost;
  final double originalQuantity;
  final double remainingQuantity;
  final String createdAt;

  StockCostLayer({
    this.id,
    required this.productId,
    this.purchaseId,
    required this.purchaseDate,
    required this.unitCost,
    required this.originalQuantity,
    required this.remainingQuantity,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'purchase_id': purchaseId,
      'purchase_date': purchaseDate,
      'unit_cost': unitCost,
      'original_quantity': originalQuantity,
      'remaining_quantity': remainingQuantity,
      'created_at': createdAt,
    };
  }

  factory StockCostLayer.fromMap(Map<String, dynamic> map) {
    return StockCostLayer(
      id: map['id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      purchaseId: map['purchase_id'] as int?,
      purchaseDate: map['purchase_date'] as String? ?? '',
      unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0.0,
      originalQuantity: (map['original_quantity'] as num?)?.toDouble() ?? 0.0,
      remainingQuantity: (map['remaining_quantity'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  StockCostLayer copyWith({
    int? id,
    int? productId,
    int? purchaseId,
    String? purchaseDate,
    double? unitCost,
    double? originalQuantity,
    double? remainingQuantity,
    String? createdAt,
  }) {
    return StockCostLayer(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      purchaseId: purchaseId ?? this.purchaseId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      unitCost: unitCost ?? this.unitCost,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
