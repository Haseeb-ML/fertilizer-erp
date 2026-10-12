class BusinessSettings {
  final int id;
  final String businessName;
  final String ownerName;
  final String phone;
  final String address;
  final String city;
  final String ntnStrn;
  final String invoicePrefix;
  final String purchasePrefix;
  final String currencySymbol;
  final String pinCode;
  final bool isPinEnabled;
  final double initialCashBalance;
  final String updatedAt;

  BusinessSettings({
    this.id = 1,
    required this.businessName,
    this.ownerName = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.ntnStrn = '',
    this.invoicePrefix = 'INV-',
    this.purchasePrefix = 'PUR-',
    this.currencySymbol = '₨',
    this.pinCode = '',
    this.isPinEnabled = false,
    this.initialCashBalance = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'owner_name': ownerName,
      'phone': phone,
      'address': address,
      'city': city,
      'ntn_strn': ntnStrn,
      'invoice_prefix': invoicePrefix,
      'purchase_prefix': purchasePrefix,
      'currency_symbol': currencySymbol,
      'pin_code': pinCode,
      'is_pin_enabled': isPinEnabled ? 1 : 0,
      'initial_cash_balance': initialCashBalance,
      'updated_at': updatedAt,
    };
  }

  factory BusinessSettings.fromMap(Map<String, dynamic> map) {
    return BusinessSettings(
      id: map['id'] as int? ?? 1,
      businessName: map['business_name'] as String? ?? 'Fertilizer Agency',
      ownerName: map['owner_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      ntnStrn: map['ntn_strn'] as String? ?? '',
      invoicePrefix: map['invoice_prefix'] as String? ?? 'INV-',
      purchasePrefix: map['purchase_prefix'] as String? ?? 'PUR-',
      currencySymbol: map['currency_symbol'] as String? ?? '₨',
      pinCode: map['pin_code'] as String? ?? '',
      isPinEnabled: (map['is_pin_enabled'] as int? ?? 0) == 1,
      initialCashBalance:
          (map['initial_cash_balance'] as num?)?.toDouble() ?? 0.0,
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  BusinessSettings copyWith({
    int? id,
    String? businessName,
    String? ownerName,
    String? phone,
    String? address,
    String? city,
    String? ntnStrn,
    String? invoicePrefix,
    String? purchasePrefix,
    String? currencySymbol,
    String? pinCode,
    bool? isPinEnabled,
    double? initialCashBalance,
    String? updatedAt,
  }) {
    return BusinessSettings(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      ntnStrn: ntnStrn ?? this.ntnStrn,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      purchasePrefix: purchasePrefix ?? this.purchasePrefix,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      pinCode: pinCode ?? this.pinCode,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      initialCashBalance: initialCashBalance ?? this.initialCashBalance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
