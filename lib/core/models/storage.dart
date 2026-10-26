class Storage {
  final int? id;
  final String name;
  final String code;
  final String location;
  final String inchargeName;
  final String contactNumber;
  final int capacityBags;
  final bool isDefault;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Storage({
    this.id,
    required this.name,
    this.code = '',
    this.location = '',
    this.inchargeName = '',
    this.contactNumber = '',
    this.capacityBags = 0,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'code': code,
      'location': location,
      'incharge_name': inchargeName,
      'contact_number': contactNumber,
      'capacity_bags': capacityBags,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Storage.fromMap(Map<String, dynamic> map) {
    return Storage(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      location: map['location'] as String? ?? '',
      inchargeName: map['incharge_name'] as String? ?? '',
      contactNumber: map['contact_number'] as String? ?? '',
      capacityBags: (map['capacity_bags'] as num?)?.toInt() ?? 0,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Storage copyWith({
    int? id,
    String? name,
    String? code,
    String? location,
    String? inchargeName,
    String? contactNumber,
    int? capacityBags,
    bool? isDefault,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Storage(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      location: location ?? this.location,
      inchargeName: inchargeName ?? this.inchargeName,
      contactNumber: contactNumber ?? this.contactNumber,
      capacityBags: capacityBags ?? this.capacityBags,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
