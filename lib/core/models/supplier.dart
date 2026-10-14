class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String companyOrAddress;
  final double openingBalance;
  final double currentBalance;
  final String notes;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Supplier({
    this.id,
    required this.name,
    this.phone = '',
    this.companyOrAddress = '',
    this.openingBalance = 0.0,
    this.currentBalance = 0.0,
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
      'company_or_address': companyOrAddress,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      companyOrAddress: map['company_or_address'] as String? ?? '',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? companyOrAddress,
    double? openingBalance,
    double? currentBalance,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      companyOrAddress: companyOrAddress ?? this.companyOrAddress,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
