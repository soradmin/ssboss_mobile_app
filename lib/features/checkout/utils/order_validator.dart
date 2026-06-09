import '../models/address.dart';
import '../../cart/models/cart_item.dart';

class OrderValidator {
  /// Валидация данных заказа перед отправкой на сервер
  static ValidationResult validateOrder({
    required List<CartItem> cartItems,
    required int addressId,
    required int paymentMethodId,
    required double totalAmount,
    required int totalQuantity,
    Address? selectedAddress,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Проверка корзины
    if (cartItems.isEmpty) {
      errors.add('Корзина пуста');
    }

    // Проверка суммы
    if (totalAmount <= 0) {
      errors.add('Сумма заказа должна быть больше 0');
    }

    // Проверка количества товаров
    if (totalQuantity <= 0) {
      errors.add('Количество товаров должно быть больше 0');
    }

    if (selectedAddress == null) {
      errors.add('Информация об адресе не найдена');
    } else if (!selectedAddress.isLocalPickup &&
        (selectedAddress.serverAddressId == null ||
            selectedAddress.serverAddressId! <= 0)) {
      errors.add('Не выбран адрес доставки');
    } else if (selectedAddress.isLocalPickup) {
      // Самовывоз (id=0): serverAddressId подставляется из профиля в PaymentApi.
    } else {
      // Проверка данных адреса
      if (selectedAddress.name.isEmpty) {
        warnings.add('Название адреса пустое');
      }
      
      if (selectedAddress.fullAddress.isEmpty) {
        warnings.add('Полный адрес пустой');
      }
      
      if (selectedAddress.city.isEmpty) {
        warnings.add('Город не указан');
      }
    }

    // Проверка метода оплаты
    if (paymentMethodId <= 0) {
      errors.add('Не выбран метод оплаты');
    }

    // Проверка товаров
    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];
      
      if (item.product.id <= 0) {
        errors.add('Товар ${i + 1}: неверный ID товара');
      }
      
      if (item.product.name.isEmpty) {
        warnings.add('Товар ${i + 1}: название пустое');
      }
      
      if (item.product.price <= 0) {
        errors.add('Товар ${i + 1}: цена должна быть больше 0');
      }
      
      if (item.qty <= 0) {
        errors.add('Товар ${i + 1}: количество должно быть больше 0');
      }
    }

    // Проверка соответствия суммы
    final calculatedTotal = cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
    if ((calculatedTotal - totalAmount).abs() > 0.01) {
      warnings.add('Сумма в корзине (${calculatedTotal.toStringAsFixed(2)}) не соответствует переданной сумме (${totalAmount.toStringAsFixed(2)})');
    }

    // Проверка соответствия количества
    final calculatedQuantity = cartItems.fold(0, (sum, item) => sum + item.qty);
    if (calculatedQuantity != totalQuantity) {
      warnings.add('Количество товаров в корзине ($calculatedQuantity) не соответствует переданному количеству ($totalQuantity)');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Валидация ответа сервера
  static ValidationResult validateServerResponse(Map<String, dynamic> response) {
    final errors = <String>[];
    final warnings = <String>[];

    // Проверка статуса ответа
    if (!response.containsKey('status') && !response.containsKey('data')) {
      errors.add('Неверный формат ответа сервера');
    }

    // Проверка данных заказа в ответе
    if (response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      
      if (!data.containsKey('id') || data['id'] == null) {
        warnings.add('Сервер не вернул ID заказа');
      }
      
      if (!data.containsKey('order_number') && !data.containsKey('order')) {
        warnings.add('Сервер не вернул номер заказа');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  /// Получить все сообщения (ошибки + предупреждения)
  List<String> get allMessages => [...errors, ...warnings];

  /// Получить сообщение для отображения пользователю
  String get userMessage {
    if (errors.isNotEmpty) {
      return 'Ошибки:\n${errors.join('\n')}';
    } else if (warnings.isNotEmpty) {
      return 'Предупреждения:\n${warnings.join('\n')}';
    } else {
      return 'Все проверки пройдены успешно';
    }
  }
}
