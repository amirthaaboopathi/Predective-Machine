class ApplianceModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String? brand;
  final String? modelNumber;
  final String? purchaseDate;
  final DateTime addedAt;
  final String? hardwarePort; // e.g. "COM3", "COM4"

  const ApplianceModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.brand,
    this.modelNumber,
    this.purchaseDate,
    required this.addedAt,
    this.hardwarePort,
  });

  bool get isHardwareMonitored => hardwarePort != null && hardwarePort!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'user_id': userId,
      'appliance_name': name,
      'appliance_type': type,
      if (brand != null && brand!.isNotEmpty) 'brand': brand,
      if (modelNumber != null && modelNumber!.isNotEmpty) 'model': modelNumber,
      if (purchaseDate != null && purchaseDate!.isNotEmpty) 'purchase_date': purchaseDate,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  factory ApplianceModel.fromMap(Map<String, dynamic> map, {String? hardwarePort}) {
    return ApplianceModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['appliance_name']?.toString() ?? '',
      type: map['appliance_type']?.toString() ?? 'Other',
      brand: map['brand']?.toString(),
      modelNumber: map['model']?.toString(),
      purchaseDate: map['purchase_date']?.toString(),
      addedAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      hardwarePort: hardwarePort ?? map['hardware_port']?.toString(),
    );
  }

  ApplianceModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? brand,
    String? modelNumber,
    String? purchaseDate,
    DateTime? addedAt,
    String? hardwarePort,
  }) {
    return ApplianceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      modelNumber: modelNumber ?? this.modelNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      addedAt: addedAt ?? this.addedAt,
      hardwarePort: hardwarePort ?? this.hardwarePort,
    );
  }
}
