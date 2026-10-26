class StockTransfer {
  final int? id;
  final String transferNumber;
  final int fromStorageId;
  final String fromStorageName;
  final int toStorageId;
  final String toStorageName;
  final int productId;
  final String productName;
  final double quantity;
  final String transferDate;
  final String vehicleNumber;
  final String driverName;
  final String notes;
  final String createdAt;

  StockTransfer({
    this.id,
    required this.transferNumber,
    required this.fromStorageId,
    this.fromStorageName = '',
    required this.toStorageId,
    this.toStorageName = '',
    required this.productId,
    this.productName = '',
    required this.quantity,
    required this.transferDate,
    this.vehicleNumber = '',
    this.driverName = '',
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transfer_number': transferNumber,
      'from_storage_id': fromStorageId,
      'to_storage_id': toStorageId,
      'product_id': productId,
      'quantity': quantity,
      'transfer_date': transferDate,
      'vehicle_number': vehicleNumber,
      'driver_name': driverName,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory StockTransfer.fromMap(Map<String, dynamic> map) {
    return StockTransfer(
      id: map['id'] as int?,
      transferNumber: map['transfer_number'] as String? ?? '',
      fromStorageId: (map['from_storage_id'] as num).toInt(),
      fromStorageName: map['from_storage_name'] as String? ?? '',
      toStorageId: (map['to_storage_id'] as num).toInt(),
      toStorageName: map['to_storage_name'] as String? ?? '',
      productId: (map['product_id'] as num).toInt(),
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      transferDate: map['transfer_date'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      driverName: map['driver_name'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  StockTransfer copyWith({
    int? id,
    String? transferNumber,
    int? fromStorageId,
    String? fromStorageName,
    int? toStorageId,
    String? toStorageName,
    int? productId,
    String? productName,
    double? quantity,
    String? transferDate,
    String? vehicleNumber,
    String? driverName,
    String? notes,
    String? createdAt,
  }) {
    return StockTransfer(
      id: id ?? this.id,
      transferNumber: transferNumber ?? this.transferNumber,
      fromStorageId: fromStorageId ?? this.fromStorageId,
      fromStorageName: fromStorageName ?? this.fromStorageName,
      toStorageId: toStorageId ?? this.toStorageId,
      toStorageName: toStorageName ?? this.toStorageName,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      transferDate: transferDate ?? this.transferDate,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverName: driverName ?? this.driverName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
