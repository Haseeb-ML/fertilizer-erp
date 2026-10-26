class StorageStock {
  final int? id;
  final int storageId;
  final int productId;
  final String productName;
  final String productBrand;
  final String category;
  final String bagSize;
  final String unit;
  final double quantity;
  final double purchasePrice;
  final double sellingPrice;
  final String updatedAt;

  StorageStock({
    this.id,
    required this.storageId,
    required this.productId,
    this.productName = '',
    this.productBrand = '',
    this.category = '',
    this.bagSize = '',
    this.unit = 'Bags',
    required this.quantity,
    this.purchasePrice = 0.0,
    this.sellingPrice = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'storage_id': storageId,
      'product_id': productId,
      'quantity': quantity,
      'updated_at': updatedAt,
    };
  }

  factory StorageStock.fromMap(Map<String, dynamic> map) {
    return StorageStock(
      id: map['id'] as int?,
      storageId: (map['storage_id'] as num).toInt(),
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String? ?? map['name'] as String? ?? '',
      productBrand: map['brand'] as String? ?? '',
      category: map['category'] as String? ?? '',
      bagSize: map['bag_size'] as String? ?? '',
      unit: map['unit'] as String? ?? 'Bags',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  StorageStock copyWith({
    int? id,
    int? storageId,
    int? productId,
    String? productName,
    String? productBrand,
    String? category,
    String? bagSize,
    String? unit,
    double? quantity,
    double? purchasePrice,
    double? sellingPrice,
    String? updatedAt,
  }) {
    return StorageStock(
      id: id ?? this.id,
      storageId: storageId ?? this.storageId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productBrand: productBrand ?? this.productBrand,
      category: category ?? this.category,
      bagSize: bagSize ?? this.bagSize,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
