class Product {
  final int? id;
  final String name;
  final String sku;
  final String category;
  final String brand;
  final String bagSize;
  final String unit;
  final double purchasePrice;
  final double sellingPrice;
  final double openingStock;
  final double currentStock;
  final double minStockAlert;
  final String notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Product({
    this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.brand,
    this.bagSize = '50 Kg',
    this.unit = 'Bag',
    required this.purchasePrice,
    required this.sellingPrice,
    this.openingStock = 0.0,
    this.currentStock = 0.0,
    this.minStockAlert = 10.0,
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minStockAlert;
  double get inventoryValuation => currentStock * purchasePrice;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'brand': brand,
      'bag_size': bagSize,
      'unit': unit,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'opening_stock': openingStock,
      'current_stock': currentStock,
      'min_stock_alert': minStockAlert,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      category: map['category'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      bagSize: map['bag_size'] as String? ?? '50 Kg',
      unit: map['unit'] as String? ?? 'Bag',
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      openingStock: (map['opening_stock'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      minStockAlert: (map['min_stock_alert'] as num?)?.toDouble() ?? 10.0,
      notes: map['notes'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? category,
    String? brand,
    String? bagSize,
    String? unit,
    double? purchasePrice,
    double? sellingPrice,
    double? openingStock,
    double? currentStock,
    double? minStockAlert,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      bagSize: bagSize ?? this.bagSize,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      openingStock: openingStock ?? this.openingStock,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
