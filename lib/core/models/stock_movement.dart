class StockMovement {
  final int? id;
  final int productId;
  final String productName;
  final String
  movementType; // PURCHASE, SALE, SALE_RETURN, PURCHASE_RETURN, ADJUSTMENT_IN, ADJUSTMENT_OUT
  final double quantity; // positive or negative
  final double balanceAfter;
  final int? referenceId;
  final String? referenceType; // SALE, PURCHASE, ADJUSTMENT, RETURN
  final String notes;
  final String movementDate;
  final String createdAt;

  StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.balanceAfter,
    this.referenceId,
    this.referenceType,
    this.notes = '',
    required this.movementDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'product_name': productName,
      'movement_type': movementType,
      'quantity': quantity,
      'balance_after': balanceAfter,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'movement_date': movementDate,
      'created_at': createdAt,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      movementType: map['movement_type'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (map['balance_after'] as num?)?.toDouble() ?? 0.0,
      referenceId: map['reference_id'] as int?,
      referenceType: map['reference_type'] as String?,
      notes: map['notes'] as String? ?? '',
      movementDate: map['movement_date'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
