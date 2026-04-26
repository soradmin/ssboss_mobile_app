import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config.dart';

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryStatus;
  final double totalAmount;
  final String orderDate;
  final String? notes;
  final OrderAddress? address;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryStatus,
    required this.totalAmount,
    required this.orderDate,
    this.notes,
    this.address,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] Order.fromJson: Обрабатываем JSON: $json');
    
    // Безопасное извлечение ID
    int orderId;
    if (json['id'] is int) {
      orderId = json['id'] as int;
    } else if (json['id'] is String) {
      orderId = int.tryParse(json['id'] as String) ?? 0;
    } else {
      orderId = 0;
    }
    
    print('[DEBUG] Order.fromJson: Извлечен ID: $orderId');

    // Безопасное извлечение статуса
    String orderStatus;
    if (json['status'] is String) {
      orderStatus = json['status'] as String;
    } else if (json['status'] is int) {
      // Конвертируем числовой статус в строковый
      final statusNum = json['status'] as int;
      switch (statusNum) {
        case 1:
          orderStatus = 'pending';
          break;
        case 2:
          orderStatus = 'confirmed';
          break;
        case 3:
          orderStatus = 'picked_up';
          break;
        case 4:
          orderStatus = 'on_the_way';
          break;
        case 5:
          orderStatus = 'delivered';
          break;
        default:
          orderStatus = 'pending';
      }
    } else {
      orderStatus = 'pending';
    }

    // Безопасное извлечение суммы
    double total;
    if (json['total_amount'] is double) {
      total = json['total_amount'] as double;
    } else if (json['total_amount'] is int) {
      total = (json['total_amount'] as int).toDouble();
    } else if (json['total_amount'] is String) {
      total = double.tryParse(json['total_amount'] as String) ?? 0.0;
    } else {
      total = 0.0;
    }
    
    print('[DEBUG] Order.fromJson: Сумма из JSON: ${json['total_amount']} -> $total');
    
    // Если сумма равна 0, попробуем вычислить из товаров
    if (total == 0.0 && json['ordered_products'] is List) {
      final products = json['ordered_products'] as List<dynamic>;
      double calculatedTotal = 0.0;
      for (var product in products) {
        if (product is Map<String, dynamic>) {
          // Пытаемся извлечь цену из различных полей
          double productPrice = 0.0;
          if (product['price'] is double) {
            productPrice = product['price'] as double;
          } else if (product['price'] is int) {
            productPrice = (product['price'] as int).toDouble();
          } else if (product['price'] is String) {
            productPrice = double.tryParse(product['price'] as String) ?? 0.0;
          } else if (product['selling'] is double) {
            productPrice = product['selling'] as double;
          } else if (product['selling'] is int) {
            productPrice = (product['selling'] as int).toDouble();
          } else if (product['selling'] is String) {
            productPrice = double.tryParse(product['selling'] as String) ?? 0.0;
          }
          
          // Получаем количество
          int quantity = 1;
          if (product['quantity'] is int) {
            quantity = product['quantity'] as int;
          } else if (product['quantity'] is String) {
            quantity = int.tryParse(product['quantity'] as String) ?? 1;
          }
          
          calculatedTotal += productPrice * quantity;
          print('[DEBUG] Order.fromJson: Товар: ${product['name'] ?? product['title']}, цена: $productPrice, количество: $quantity, сумма: ${productPrice * quantity}');
        }
      }
      
      if (calculatedTotal > 0.0) {
        total = calculatedTotal;
        print('[DEBUG] Order.fromJson: Вычисленная сумма из товаров: $total');
      }
    }
    
    // Если сумма все еще 0, попробуем получить из локального хранилища
    if (total == 0.0) {
      print('[DEBUG] Order.fromJson: Пытаемся получить сумму из локального хранилища для заказа $orderId');
      // Попробуем получить из локального хранилища синхронно
      try {
        // Это будет работать только если SharedPreferences уже инициализирован
        // В противном случае нужно будет изменить архитектуру
        print('[DEBUG] Order.fromJson: Сумма остается 0.0, нужно получить из локального хранилища в API');
      } catch (e) {
        print('[DEBUG] Order.fromJson: Ошибка получения из локального хранилища: $e');
      }
    }

    // Безопасное извлечение номера заказа
    String orderNumber = '';
    if (json['order'] is String) {
      orderNumber = json['order'] as String;
    } else if (json['order_number'] is String) {
      orderNumber = json['order_number'] as String;
    } else if (json['orderNumber'] is String) {
      orderNumber = json['orderNumber'] as String;
    }
    
    // Безопасное извлечение метода оплаты
    String paymentMethod = 'cash_on_delivery';
    if (json['order_method'] is int) {
      final methodId = json['order_method'] as int;
      switch (methodId) {
        case 2:
          paymentMethod = 'cash_on_delivery';
          break;
        case 5:
          paymentMethod = 'paypal';
          break;
        case 7:
          paymentMethod = 'bank_transfer';
          break;
        default:
          paymentMethod = 'cash_on_delivery';
      }
    } else if (json['payment_method'] is String) {
      paymentMethod = json['payment_method'] as String;
    }
    
    // Безопасное извлечение даты
    String orderDate = '';
    if (json['created_at'] is String) {
      orderDate = json['created_at'] as String;
    } else if (json['created'] is String) {
      orderDate = json['created'] as String;
    } else if (json['order_date'] is String) {
      orderDate = json['order_date'] as String;
    } else if (json['orderDate'] is String) {
      orderDate = json['orderDate'] as String;
    }
    
    print('[DEBUG] Order.fromJson: Номер заказа: $orderNumber');
    print('[DEBUG] Order.fromJson: Метод оплаты: $paymentMethod');
    print('[DEBUG] Order.fromJson: Дата: $orderDate');
    
    return Order(
      id: orderId,
      orderNumber: orderNumber,
      status: orderStatus,
      paymentMethod: paymentMethod,
      paymentStatus: json['payment_done'] == 1 ? 'paid' : 'unpaid',
      deliveryStatus: orderStatus,
      totalAmount: total,
      orderDate: orderDate,
      notes: json['notes'] as String?,
      address: json['address'] != null ? OrderAddress.fromJson(json['address']) : null,
      items: (json['ordered_products'] as List<dynamic>? ?? json['items'] as List<dynamic>? ?? [])
          .map((item) {
            print('[DEBUG] Order.fromJson: Парсинг товара: $item');
            final orderItem = OrderItem.fromJson(item);
            print('[DEBUG] Order.fromJson: Товар распарсен: ${orderItem.name}, ID: ${orderItem.productId}, Изображение: ${orderItem.image}');
            return orderItem;
          })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': status,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'delivery_status': deliveryStatus,
      'total_amount': totalAmount,
      'order_date': orderDate,
      'notes': notes,
      'address': address?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Получить текущий статус для отображения
  String get displayStatus {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'В ожидании';
      case 'confirmed':
        return 'Подтверждено';
      case 'picked_up':
        return 'В работе';
      case 'on_the_way':
        return 'В пути';
      case 'delivered':
        return 'Доставлено';
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  // Получить статус доставки для отображения
  String get displayDeliveryStatus {
    switch (deliveryStatus.toLowerCase()) {
      case 'pending':
        return 'В ожидании';
      case 'confirmed':
        return 'Подтверждено';
      case 'picked_up':
        return 'В работе';
      case 'on_the_way':
        return 'В пути';
      case 'delivered':
        return 'Доставлено';
      case 'cancelled':
        return 'Отменено';
      default:
        return deliveryStatus;
    }
  }

  // Получить статус оплаты для отображения
  String get displayPaymentStatus {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return 'Оплачено';
      case 'unpaid':
        return 'Не оплачено';
      case 'pending':
        return 'В ожидании';
      default:
        return paymentStatus;
    }
  }

  // Получить метод оплаты для отображения
  String get displayPaymentMethod {
    switch (paymentMethod.toLowerCase()) {
      case 'cash_on_delivery':
        return 'Оплата при доставке';
      case 'bank_transfer':
        return 'Банковский перевод';
      case 'paypal':
        return 'PayPal';
      default:
        return paymentMethod;
    }
  }

  // Проверить, можно ли отменить заказ
  bool get canCancel {
    return status.toLowerCase() == 'pending' || status.toLowerCase() == 'confirmed';
  }
}

class OrderAddress {
  final int id;
  final String name;
  final String address;
  final String city;
  final String country;
  final String phone;
  final String email;

  OrderAddress({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.country,
    required this.phone,
    required this.email,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'country': country,
      'phone': phone,
      'email': email,
    };
  }

  String get fullAddress {
    return '$address, $city, $country';
  }
}

class OrderItem {
  final int id;
  final int productId;
  final String name;
  final String? image;
  final int quantity;
  final double price;
  final double total;
  final String? size;
  final String? color;

  OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    this.image,
    required this.quantity,
    required this.price,
    required this.total,
    this.size,
    this.color,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Безопасное извлечение ID
    int itemId;
    if (json['id'] is int) {
      itemId = json['id'] as int;
    } else if (json['id'] is String) {
      itemId = int.tryParse(json['id'] as String) ?? 0;
    } else {
      itemId = 0;
    }

    // Безопасное извлечение product_id
    int prodId;
    if (json['product_id'] is int) {
      prodId = json['product_id'] as int;
    } else if (json['product_id'] is String) {
      prodId = int.tryParse(json['product_id'] as String) ?? 0;
    } else {
      prodId = 0;
    }

    // Безопасное извлечение количества
    int qty;
    if (json['quantity'] is int) {
      qty = json['quantity'] as int;
    } else if (json['quantity'] is String) {
      qty = int.tryParse(json['quantity'] as String) ?? 0;
    } else {
      qty = 0;
    }

    // Безопасное извлечение цены - проверяем flash_product.selling в первую очередь
    double itemPrice;
    if (json['flash_product']?['selling'] is double) {
      itemPrice = json['flash_product']['selling'] as double;
    } else if (json['flash_product']?['selling'] is int) {
      itemPrice = (json['flash_product']['selling'] as int).toDouble();
    } else if (json['flash_product']?['selling'] is String) {
      itemPrice = double.tryParse(json['flash_product']['selling'] as String) ?? 0.0;
    } else if (json['selling'] is double) {
      itemPrice = json['selling'] as double;
    } else if (json['selling'] is int) {
      itemPrice = (json['selling'] as int).toDouble();
    } else if (json['selling'] is String) {
      itemPrice = double.tryParse(json['selling'] as String) ?? 0.0;
    } else if (json['price'] is double) {
      itemPrice = json['price'] as double;
    } else if (json['price'] is int) {
      itemPrice = (json['price'] as int).toDouble();
    } else if (json['price'] is String) {
      itemPrice = double.tryParse(json['price'] as String) ?? 0.0;
    } else {
      itemPrice = 0.0;
    }

    // Обработка изображения - проверяем разные возможные пути
    String? imageUrl;
    final rawImage = json['flash_product']?['image'] as String? 
        ?? json['product']?['image'] as String? 
        ?? json['image'] as String?;
    if (rawImage != null && rawImage.isNotEmpty) {
      imageUrl = AppConfig.imageUrl(rawImage);
      print('[DEBUG] OrderItem.fromJson: Обработано изображение: $rawImage -> $imageUrl');
    } else {
      print('[DEBUG] OrderItem.fromJson: Изображение не найдено. Доступные ключи: ${json.keys.toList()}');
      if (json['flash_product'] != null) {
        print('[DEBUG] OrderItem.fromJson: flash_product keys: ${(json['flash_product'] as Map).keys.toList()}');
      }
      if (json['product'] != null) {
        print('[DEBUG] OrderItem.fromJson: product keys: ${(json['product'] as Map).keys.toList()}');
      }
    }

    return OrderItem(
      id: itemId,
      productId: prodId,
      name: json['flash_product']?['title'] as String? 
          ?? json['product']?['title'] as String? 
          ?? json['name'] as String? 
          ?? json['title'] as String? 
          ?? '',
      image: imageUrl,
      quantity: qty,
      price: itemPrice,
      total: itemPrice * qty,
      size: json['size'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'image': image,
      'quantity': quantity,
      'price': price,
      'total': total,
      'size': size,
      'color': color,
    };
  }
}
