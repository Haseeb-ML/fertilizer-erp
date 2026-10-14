class Customer {
  final int? id;
  final String name;
  final String phone;
  final String villageOrAddress;
  final double openingBalance;
  final double currentBalance;
  final double creditLimit;
  final String notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.villageOrAddress = '',
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
    this.creditLimit = 0.0,
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'village_or_address': villageOrAddress,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'credit_limit': creditLimit,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      villageOrAddress: map['village_or_address'] as String? ?? '',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? villageOrAddress,
    double? openingBalance,
    double? currentBalance,
    double? creditLimit,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      villageOrAddress: villageOrAddress ?? this.villageOrAddress,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
