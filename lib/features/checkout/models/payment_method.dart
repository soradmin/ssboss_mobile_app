class PaymentMethod {
  final int id;
  final String name;
  final String type;
  final String? description;
  final bool isActive;
  final String? icon;
  final Map<String, dynamic>? config;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.isActive,
    this.icon,
    this.config,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? false,
      icon: json['icon'],
      config: json['config'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'description': description,
      'is_active': isActive,
      'icon': icon,
      'config': config,
    };
  }

  @override
  String toString() {
    return 'PaymentMethod(id: $id, name: $name, type: $type, isActive: $isActive)';
  }
}

// Статичные методы оплаты для демонстрации
class StaticPaymentMethods {
  static List<PaymentMethod> get defaultMethods => [
    const PaymentMethod(
      id: 1,
      name: 'Оплата при доставке',
      type: 'cash_on_delivery',
      description: 'Оплата наличными при получении заказа',
      isActive: true,
      icon: 'cash',
    ),
    const PaymentMethod(
      id: 2,
      name: 'Банковский перевод',
      type: 'bank_transfer',
      description: 'Перевод на банковский счет',
      isActive: true,
      icon: 'bank',
    ),
  ];
}
