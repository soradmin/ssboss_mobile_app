class Address {
  /// Локальный ID пункта выдачи в приложении (не из БД, не отправлять на сервер как selected_address).
  static const int localPickupId = 0;

  final int id;
  final String name;
  final String address;
  final String city;
  final String? region;
  final String? postalCode;
  final String? phone;
  final String? country; // Код страны (например, 'TJ' для Tajikistan)
  final int? userAddressId; // Реальный user_address_id из базы данных (может отличаться от id)
  final bool isDefault;
  final String type; // 'pickup' или 'delivery'

  const Address({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    this.region,
    this.postalCode,
    this.phone,
    this.country,
    this.userAddressId,
    this.isDefault = false,
    this.type = 'delivery',
  });

  /// Безопасное приведение id из API (int / double / String).
  static int _parseId(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] Address.fromJson: Парсим JSON: $json');

    final id = _parseId(json['id']);
    final userAddressId = _parseId(
      json['user_address_id'] ?? json['id'],
      fallback: id,
    );

    // Обрабатываем структуру API: address_1 + address_2 = полный адрес
    final address1 = json['address_1'] ?? json['address'] ?? json['street'] ?? '';
    final address2 = json['address_2'] ?? '';
    final fullAddress = address2.isNotEmpty ? '$address1, $address2' : address1;

    final defaultRaw = json['default'] ?? json['is_default'] ?? json['isDefault'];
    final isDefault = defaultRaw == 1 ||
        defaultRaw == true ||
        defaultRaw == '1' ||
        defaultRaw == 'true';

    final address = Address(
      id: id,
      name: (json['name'] ?? json['title'] ?? 'Адрес').toString(),
      address: fullAddress.toString(),
      city: (json['city'] ?? '').toString(),
      region: json['state']?.toString() ?? json['region']?.toString(),
      postalCode: json['zip']?.toString() ??
          json['postal_code']?.toString() ??
          json['postalCode']?.toString(),
      phone: json['phone']?.toString(),
      country: json['country']?.toString(),
      userAddressId: userAddressId > 0 ? userAddressId : (id > 0 ? id : null),
      isDefault: isDefault,
      type: (json['type'] ?? 'delivery').toString(),
    );
    
    print('[DEBUG] Address.fromJson: Создан адрес: ${address.name} (${address.type}) - ${address.fullAddress}');
    return address;
  }

  String get fullAddress {
    final parts = [city, region, address].where((e) => e != null && e.isNotEmpty);
    return parts.join(', ');
  }

  bool get isLocalPickup => type == 'pickup' && id == localPickupId;

  /// ID адреса в user_addresses для API (selected_address / default_address).
  int? get serverAddressId {
    if (isLocalPickup) return null;
    final serverId = userAddressId ?? id;
    return serverId > 0 ? serverId : null;
  }
}
