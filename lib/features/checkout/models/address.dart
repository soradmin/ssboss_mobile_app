class Address {
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

  factory Address.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] Address.fromJson: Парсим JSON: $json');
    
    // Обрабатываем структуру API: address_1 + address_2 = полный адрес
    final address1 = json['address_1'] ?? json['address'] ?? json['street'] ?? '';
    final address2 = json['address_2'] ?? '';
    final fullAddress = address2.isNotEmpty ? '$address1, $address2' : address1;
    
    final address = Address(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['title'] ?? 'Адрес',
      address: fullAddress,
      city: json['city'] ?? '',
      region: json['state'] ?? json['region'], // API использует 'state' вместо 'region'
      postalCode: json['zip'] ?? json['postal_code'] ?? json['postalCode'], // API использует 'zip'
      phone: json['phone'],
      country: json['country'] as String?, // Код страны из 2 символов
      userAddressId: json['user_address_id'] as int? ?? json['id'] as int?, // Реальный user_address_id из базы данных
      isDefault: json['default'] == 1 || json['is_default'] == true || json['isDefault'] == true, // API использует числовое значение
      type: json['type'] ?? 'delivery', // По умолчанию delivery для адресов с сайта
    );
    
    print('[DEBUG] Address.fromJson: Создан адрес: ${address.name} (${address.type}) - ${address.fullAddress}');
    return address;
  }

  String get fullAddress {
    final parts = [city, region, address].where((e) => e != null && e.isNotEmpty);
    return parts.join(', ');
  }
}
