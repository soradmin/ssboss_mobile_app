import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';
import '../../../crypto/aes_zero.dart';
import '../models/payment_method.dart';
import '../models/address.dart';
import '../repo/address_api.dart';
import '../../auth/repo/auth_api.dart';
import '../utils/order_validator.dart';
import '../../cart/models/cart_item.dart';
import '../../catalog/models/product.dart';
import '../../cart/repo/cart_api.dart';

class PaymentApi {
  static final Dio _dio = dio;
  
  // Создаем отдельный Dio instance для создания заказов БЕЗ /api/v1/ префикса
  static final Dio _orderDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl.replaceFirst('/api/v1', ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  /// Получить доступные методы оплаты
  static Future<Result<List<PaymentMethod>>> getPaymentMethods() async {
    try {
      print('[DEBUG] PaymentApi.getPaymentMethods: Получаем методы оплаты...');
      
      final response = await _dio.get('/payment-methods');
      
      print('[DEBUG] PaymentApi.getPaymentMethods: HTTP статус = ${response.statusCode}');
      print('[DEBUG] PaymentApi.getPaymentMethods: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        List<PaymentMethod> methods = [];
        
        if (response.data is List) {
          methods = (response.data as List)
              .map((json) => PaymentMethod.fromJson(json))
              .toList();
          print('[DEBUG] PaymentApi.getPaymentMethods: Найдено ${methods.length} методов оплаты');
        } else if (response.data is Map && response.data['data'] is List) {
          methods = (response.data['data'] as List)
              .map((json) => PaymentMethod.fromJson(json))
              .toList();
        } else {
          print('[DEBUG] PaymentApi.getPaymentMethods: Данные не являются списком, используем статичные методы');
        }
        
        if (methods.isNotEmpty) {
          return Ok(methods);
        }
      } else {
        print('[DEBUG] PaymentApi.getPaymentMethods: Ошибка HTTP ${response.statusCode}, используем статичные методы');
      }
      
      // Fallback: используем статичные методы оплаты
      return Ok(StaticPaymentMethods.defaultMethods);
    } catch (e) {
      print('[DEBUG] PaymentApi.getPaymentMethods: Ошибка: $e, используем статичные методы');
      return Ok(StaticPaymentMethods.defaultMethods);
    }
  }

  /// Создать заказ с выбранным методом оплаты
  static Future<Result<Map<String, dynamic>>> createOrder({
    required int paymentMethodId,
    required int addressId,
    required List<Map<String, dynamic>> cartItems,
    required double totalAmount,
    required int totalQuantity,
    String? notes,
    String? deliveryType, // 'pickup' или 'delivery'
  }) async {
    try {
    print('[DEBUG] PaymentApi.createOrder: Создаем заказ...');
    print('[DEBUG] PaymentApi.createOrder: paymentMethodId = $paymentMethodId');
    print('[DEBUG] PaymentApi.createOrder: addressId = $addressId');
    print('[DEBUG] PaymentApi.createOrder: cartItems = $cartItems');
    print('[DEBUG] PaymentApi.createOrder: totalAmount = $totalAmount');
    print('[DEBUG] PaymentApi.createOrder: totalQuantity = $totalQuantity');
      
      // Получаем user_token и данные пользователя из профиля
      print('[DEBUG] PaymentApi.createOrder: Получаем данные пользователя...');
      final userTokenResult = await AuthApi.getUserToken();
      final userProfileResult = await AuthApi.getProfile();
      
      // Получаем информацию об адресе
      print('[DEBUG] PaymentApi.createOrder: Получаем информацию об адресе $addressId...');
      final addressApi = AddressApi();
      final addressResult = await addressApi.getAddresses();
      Address? selectedAddress;
      
      if (addressResult is Ok<List<Address>>) {
        try {
          selectedAddress = addressResult.value.firstWhere((addr) => addr.id == addressId);
          print('[DEBUG] PaymentApi.createOrder: Найден адрес: ${selectedAddress.name} (${selectedAddress.fullAddress})');
          print('[DEBUG] PaymentApi.createOrder: Тип адреса: ${selectedAddress.type}');
          print('[DEBUG] PaymentApi.createOrder: Город: ${selectedAddress.city}');
          print('[DEBUG] PaymentApi.createOrder: Телефон: ${selectedAddress.phone}');
        } catch (e) {
          print('[DEBUG] PaymentApi.createOrder: Адрес $addressId не найден: $e');
          print('[DEBUG] PaymentApi.createOrder: Доступные адреса:');
          for (final addr in addressResult.value) {
            print('[DEBUG] PaymentApi.createOrder: - ID: ${addr.id}, Название: ${addr.name}, Тип: ${addr.type}');
          }
        }
      } else {
        print('[DEBUG] PaymentApi.createOrder: Ошибка загрузки адресов: ${(addressResult as Err).message}');
      }

      // Пункт выдачи (id=0) может отсутствовать в списке после сбоя API — восстанавливаем локально.
      if (selectedAddress == null && addressId == Address.localPickupId) {
        selectedAddress = const Address(
          id: Address.localPickupId,
          name: 'Пункт выдачи SSBOSS',
          address: 'улица Джаббора Расулова, 6/1',
          city: 'Душанбе',
          region: 'РРП',
          postalCode: '734000',
          phone: '930900412',
          country: 'TJ',
          type: 'pickup',
          isDefault: true,
        );
        print('[DEBUG] PaymentApi.createOrder: Используем встроенный пункт выдачи (id=0)');
      }
      
      String? userToken;
      Map<String, dynamic>? userData;
      
      final tokenResult = userTokenResult.when(
        ok: (token) {
          userToken = token;
          return null;
        },
        err: (error) {
          print('[DEBUG] PaymentApi.createOrder: Ошибка получения user_token: $error');
          return error;
        },
      );
      
      final profileResult = userProfileResult.when(
        ok: (profile) {
          userData = profile;
          return null;
        },
        err: (error) {
          print('[DEBUG] PaymentApi.createOrder: Ошибка получения профиля: $error');
          return error;
        },
      );
      
      if (tokenResult != null || userToken == null) {
        return Err('Не удалось получить токен пользователя: ${tokenResult ?? 'токен не получен'}');
      }
      
      if (profileResult != null || userData == null) {
        return Err('Не удалось получить данные пользователя: ${profileResult ?? 'профиль не получен'}');
      }
      
      print('[DEBUG] PaymentApi.createOrder: Получен user_token: ${userToken!.substring(0, 10)}...');
      print('[DEBUG] PaymentApi.createOrder: Данные пользователя: ${userData!['name']} (${userData!['email']})');
      
      // ВАЖНО: Перед созданием заказа нужно обновить корзину с выбранным адресом
      // Сервер использует адрес из корзины при создании заказа
      // Обновляем корзину для всех адресов, включая статический
      if (selectedAddress != null) {
        print('[DEBUG] PaymentApi.createOrder: Обновляем корзину с выбранным адресом ${selectedAddress.id} (тип: ${selectedAddress.type})...');
        final cartApi = CartApi();
        final effectiveDeliveryType = deliveryType ??
            (selectedAddress.isLocalPickup || selectedAddress.type == 'pickup'
                ? 'pickup'
                : 'delivery');

        final allAddresses =
            addressResult is Ok<List<Address>> ? addressResult.value : <Address>[];
        final profileDefaultId = _parseProfileDefaultAddressId(userData);
        final serverAddressId = _resolveSelectedAddressForServer(
          selectedAddress,
          allAddresses,
          profileDefaultAddress: profileDefaultId,
        );
        print(
          '[DEBUG] PaymentApi.createOrder: serverAddressId для заказа = $serverAddressId (profile default=$profileDefaultId)',
        );

        if (serverAddressId == null || serverAddressId <= 0) {
          return const Err(
            'Для оформления заказа нужен адрес в профиле. '
            'Добавьте адрес доставки в профиле или выберите сохранённый адрес, затем повторите заказ.',
          );
        }

        final updateResult = await cartApi.updateShippingAddress(
          addressId,
          addressType: selectedAddress.type,
          deliveryType: effectiveDeliveryType,
          selectedAddressForServer: serverAddressId,
        );
        if (updateResult is Err) {
          print('[ERROR] PaymentApi.createOrder: Не удалось обновить корзину с адресом: ${(updateResult as Err).message}');
          // НЕ продолжаем создание заказа, если корзина не обновлена - это критично!
          return Err('Не удалось обновить корзину с адресом: ${(updateResult as Err).message}');
        } else {
          print('[DEBUG] PaymentApi.createOrder: Корзина успешно обновлена с адресом $addressId');
        }
      } else {
        return const Err('Не удалось определить адрес для заказа. Выберите пункт выдачи или адрес доставки.');
      }
      
      // Определяем order_method и название метода оплаты
      int orderMethod;
      String paymentMethodName;
      
      switch (paymentMethodId) {
        case 1: // Оплата при доставке
          orderMethod = 2; // COD
          paymentMethodName = 'cash_on_delivery';
          break;
        case 2: // Банковский перевод
          orderMethod = 7; // Bank transfer
          paymentMethodName = 'bank_transfer';
          break;
        case 3: // PayPal (временно недоступно)
          throw Exception('PayPal временно недоступен');
        default:
          orderMethod = 2; // По умолчанию COD
          paymentMethodName = 'cash_on_delivery';
      }
      
      print('[DEBUG] PaymentApi.createOrder: Выбранный метод оплаты:');
      print('[DEBUG] PaymentApi.createOrder: - ID в приложении: $paymentMethodId');
      print('[DEBUG] PaymentApi.createOrder: - Название для локального хранения: $paymentMethodName');
      print('[DEBUG] PaymentApi.createOrder: - order_method для сервера: $orderMethod');
      
      // Создаем payload в ТОЧНОМ формате, как на сайте
      // На сайте передается только: user_token, order_method, voucher, time_zone
      // Сервер сам берет корзину с сервера и использует выбранный адрес из сессии/корзины
      // Поэтому НЕ передаем: address_id, items, total_amount, user_name и т.д.
      final payload = {
        'user_token': userToken,
        'order_method': orderMethod,
        'voucher': '',
        'time_zone': 'Asia/Tashkent',
      };
      
      print('[DEBUG] PaymentApi.createOrder: ===== ПОЛНЫЙ PAYLOAD ДЛЯ СЕРВЕРА (как на сайте) =====');
      print('[DEBUG] PaymentApi.createOrder: $payload');
      print('[DEBUG] PaymentApi.createOrder: ===== ДЕТАЛИ PAYLOAD =====');
      print('[DEBUG] PaymentApi.createOrder: - user_token: ${payload['user_token']}');
      print('[DEBUG] PaymentApi.createOrder: - order_method: ${payload['order_method']} (тип: ${payload['order_method'].runtimeType})');
      print('[DEBUG] PaymentApi.createOrder: - voucher: ${payload['voucher']}');
      print('[DEBUG] PaymentApi.createOrder: - time_zone: ${payload['time_zone']}');
      print('[DEBUG] PaymentApi.createOrder: ВАЖНО: Сервер сам берет корзину и адрес с сервера!');
      if (selectedAddress != null) {
        print('[DEBUG] PaymentApi.createOrder: - Выбранный адрес: ${selectedAddress.name} (ID: ${selectedAddress.id})');
        print('[DEBUG] PaymentApi.createOrder: - Адрес должен быть выбран в корзине на сервере перед созданием заказа');
      }
      
      // Валидация данных заказа
      final validationResult = OrderValidator.validateOrder(
        cartItems: cartItems.map((item) => CartItem(
          product: Product(
            id: item['product_id'] as int,
            name: item['name'] as String,
            image: item['image'] as String,
            price: item['price'] as double,
            images: [],
            rating: 0.0,
            reviewCount: 0,
          ),
          qty: item['quantity'] as int,
        )).toList(),
        addressId: addressId,
        paymentMethodId: paymentMethodId,
        totalAmount: totalAmount,
        totalQuantity: totalQuantity,
        selectedAddress: selectedAddress,
      );

      if (!validationResult.isValid) {
        print('[ERROR] PaymentApi.createOrder: Валидация не пройдена:');
        for (final error in validationResult.errors) {
          print('[ERROR] PaymentApi.createOrder: - $error');
        }
        return Err('Ошибка валидации: ${validationResult.errors.join(', ')}');
      }

      // Логируем предупреждения
      if (validationResult.warnings.isNotEmpty) {
        print('[WARNING] PaymentApi.createOrder: Предупреждения валидации:');
        for (final warning in validationResult.warnings) {
          print('[WARNING] PaymentApi.createOrder: - $warning');
        }
      }
      
      // Логируем детали товаров из локальной корзины (не из payload, так как на сайте товары не передаются)
      print('[DEBUG] PaymentApi.createOrder: ===== ДЕТАЛИ ТОВАРОВ (из локальной корзины) =====');
      for (int i = 0; i < cartItems.length; i++) {
        final item = cartItems[i];
        print('[DEBUG] PaymentApi.createOrder: Товар ${i + 1}:');
        print('[DEBUG] PaymentApi.createOrder:   - product_id: ${item['product_id']}');
        print('[DEBUG] PaymentApi.createOrder:   - name: ${item['name']}');
        print('[DEBUG] PaymentApi.createOrder:   - image: ${item['image']}');
        print('[DEBUG] PaymentApi.createOrder:   - quantity: ${item['quantity']}');
        print('[DEBUG] PaymentApi.createOrder:   - price: ${item['price']}');
        
        // Безопасное вычисление subtotal с проверкой типов
        final quantity = item['quantity'] is int ? item['quantity'] as int : int.tryParse(item['quantity'].toString()) ?? 0;
        final price = item['price'] is double ? item['price'] as double : double.tryParse(item['price'].toString()) ?? 0.0;
        print('[DEBUG] PaymentApi.createOrder:   - subtotal: ${quantity * price}');
      }
      
      // Отправляем заказ на сервер в зашифрованном формате (как в веб-версии)
      final encrypted = encryptMap(payload);
      final encryptedBody = jsonEncode({'data': encrypted});
      
      print('[DEBUG] PaymentApi.createOrder: Отправляем зашифрованные данные на сервер');
      print('[DEBUG] PaymentApi.createOrder: Размер зашифрованных данных: ${encryptedBody.length} символов');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      final response = await _dio.post('/order/action', 
        data: encryptedBody, // Отправляем зашифрованные данные
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] PaymentApi.createOrder: ===== ОТВЕТ СЕРВЕРА =====');
      print('[DEBUG] PaymentApi.createOrder: Статус: ${response.statusCode}');
      print('[DEBUG] PaymentApi.createOrder: Полный ответ: ${response.data}');
      print('[DEBUG] PaymentApi.createOrder: Тип ответа: ${response.data.runtimeType}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[DEBUG] PaymentApi.createOrder: Заказ успешно создан на сервере!');
        print('[DEBUG] PaymentApi.createOrder: Статус ответа: ${response.statusCode}');
        print('[DEBUG] PaymentApi.createOrder: Заголовки ответа: ${response.headers}');
        
        // Парсим ответ сервера
        final responseData = response.data;
        
        // Проверяем наличие ошибок в ответе (даже при статусе 200/201)
        if (responseData is Map<String, dynamic>) {
          // Проверяем наличие ошибок валидации в data.form
          if (responseData['data'] is Map) {
            final data = responseData['data'] as Map;
            if (data['form'] is List) {
              final formErrors = data['form'] as List;
              if (formErrors.isNotEmpty) {
                final errorMessage = formErrors.map((e) => e.toString()).join(', ');
                print('[ERROR] PaymentApi.createOrder: Ошибки валидации в ответе сервера: $errorMessage');
                return Err(errorMessage);
              }
            }
          }
          
          // Проверяем наличие сообщения об ошибке
          if (responseData['message'] is String && responseData['message'].toString().isNotEmpty) {
            final message = responseData['message'] as String;
            // Если сообщение содержит SQL ошибку или другие ошибки, возвращаем ошибку
            if (message.contains('SQLSTATE') || message.contains('Integrity constraint') || message.contains('cannot be null')) {
              print('[ERROR] PaymentApi.createOrder: Ошибка в сообщении сервера: $message');
              return Err(message);
            }
          }
          
          // Валидация ответа сервера
          final responseValidation = OrderValidator.validateServerResponse(responseData);
          if (!responseValidation.isValid) {
            print('[ERROR] PaymentApi.createOrder: Ошибки в ответе сервера:');
            for (final error in responseValidation.errors) {
              print('[ERROR] PaymentApi.createOrder: - $error');
            }
            // Если есть критические ошибки, возвращаем ошибку
            if (responseValidation.errors.any((e) => e.contains('SQLSTATE') || e.contains('Integrity constraint'))) {
              return Err(responseValidation.errors.join(', '));
            }
          }
          if (responseValidation.warnings.isNotEmpty) {
            print('[WARNING] PaymentApi.createOrder: Предупреждения в ответе сервера:');
            for (final warning in responseValidation.warnings) {
              print('[WARNING] PaymentApi.createOrder: - $warning');
            }
          }
        }
        
        int? orderId;
        String? orderNumber;
        
        if (responseData is Map<String, dynamic>) {
          print('[DEBUG] PaymentApi.createOrder: Структура ответа сервера: ${responseData.keys}');
          
          // Пытаемся извлечь ID заказа из ответа
          if (responseData['data'] is Map<String, dynamic>) {
            final data = responseData['data'] as Map<String, dynamic>;
            print('[DEBUG] PaymentApi.createOrder: Данные в data: ${data.keys}');
            
            // Проверяем, что это не ошибка (если есть form, это ошибка)
            if (data.containsKey('form') && data['form'] is List) {
              final formErrors = data['form'] as List;
              if (formErrors.isNotEmpty) {
                final errorMessage = formErrors.map((e) => e.toString()).join(', ');
                print('[ERROR] PaymentApi.createOrder: Ошибки в data.form: $errorMessage');
                return Err(errorMessage);
              }
            }
            
            orderId = data['id'] as int?;
            orderNumber = data['order_number'] as String? ?? data['order'] as String? ?? data['number'] as String?;
            print('[DEBUG] PaymentApi.createOrder: Из data - ID: $orderId, Номер: $orderNumber');
          } else {
            orderId = responseData['id'] as int?;
            orderNumber = responseData['order_number'] as String? ?? responseData['order'] as String? ?? responseData['number'] as String?;
            print('[DEBUG] PaymentApi.createOrder: Из responseData - ID: $orderId, Номер: $orderNumber');
          }
        }
        
        // Определяем, был ли заказ успешно сохранен на сервере
        bool serverSaved = false;
        
        // Если не удалось получить ID из ответа, генерируем временный
        if (orderId == null) {
          print('[WARNING] PaymentApi.createOrder: Сервер не вернул ID заказа, генерируем локально');
          orderId = DateTime.now().millisecondsSinceEpoch;
          serverSaved = false; // Заказ не был сохранен на сервере
        } else {
          serverSaved = true; // Заказ был сохранен на сервере
        }
        
        // Если не удалось получить номер заказа из ответа, генерируем его
        if (orderNumber == null || orderNumber.isEmpty) {
          print('[WARNING] PaymentApi.createOrder: Сервер не вернул номер заказа, генерируем локально');
          // Генерируем номер заказа в формате как на сайте: ДатаБуквыЦифры
          final now = DateTime.now();
          final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          final randomLetters = _generateRandomString(2).toUpperCase();
          final randomNumbers = (Random().nextInt(999) + 1).toString().padLeft(3, '0');
          orderNumber = '${dateStr}${randomLetters}${randomNumbers}';
          serverSaved = false; // Если нет номера, значит не сохранен на сервере
        } else {
          print('[DEBUG] PaymentApi.createOrder: Используем номер заказа с сервера: $orderNumber');
        }
        
        print('[DEBUG] PaymentApi.createOrder: ID заказа: $orderId');
        print('[DEBUG] PaymentApi.createOrder: Номер заказа: $orderNumber');
        print('[DEBUG] PaymentApi.createOrder: Заказ сохранен на сервере: $serverSaved');
        
        // Создаем данные заказа для локального хранения
        final orderData = {
          'id': orderId,
          'order_number': orderNumber,
          'status': 'pending',
          'payment_method': _getPaymentMethodString(paymentMethodId),
          'payment_status': 'unpaid',
          'delivery_status': 'pending',
          'total_amount': totalAmount,
          'total_quantity': totalQuantity,
          'order_date': DateTime.now().toIso8601String(),
          'notes': notes ?? 'Заказ создан через мобильное приложение',
          'address_id': addressId,
          // Добавляем информацию о пользователе
          'user_name': userData!['name'] ?? 'Пользователь',
          'user_email': userData!['email'] ?? '',
          'user_id': userData!['id'] ?? 0,
          'server_saved': serverSaved,
          'server_response': responseData,
        'items': cartItems.map((item) => {
          'id': item['product_id'],
          'product_id': item['product_id'],
          'name': item['name'] ?? 'Товар',
          'image': item['image'] ?? '',
          'quantity': item['quantity'],
          'price': item['price'],
          'total': _safeCalculateTotal(item['quantity'], item['price']),
          'size': item['size'],
          'color': item['color'],
        }).toList(),
      };
          
          // Сохраняем в локальное хранилище как backup
          await _saveOrderToLocalStorage(orderData);
          
          // Убираем лишний запрос на проверку сохранения - заказ уже создан успешно,
          // подтверждение произойдет через confirmOrder
          print('[DEBUG] PaymentApi.createOrder: Заказ $orderId успешно создан на сервере!');
          
          return Ok({
            'id': orderId,
            'order_id': orderId,
            'order_number': orderNumber,
            'data': orderData
          });
        }
        
        print('[DEBUG] PaymentApi.createOrder: Сервер вернул неожиданный статус: ${response.statusCode}');
        print('[DEBUG] PaymentApi.createOrder: Ответ сервера при ошибке: ${response.data}');
      
      // Если сервер вернул ошибку, возвращаем ошибку
      String errorMessage = 'Ошибка создания заказа (${response.statusCode})';
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['message'] is String) {
          errorMessage = data['message'] as String;
        } else if (data['data'] is Map && (data['data'] as Map)['message'] is String) {
          errorMessage = (data['data'] as Map)['message'] as String;
        }
      }
      
      return Err(errorMessage);
      
      } catch (e) {
      print('[DEBUG] PaymentApi.createOrder: Ошибка создания заказа: $e');
        if (e is DioException) {
          print('[DEBUG] PaymentApi.createOrder: DioException details:');
          print('[DEBUG] PaymentApi.createOrder: - Status Code: ${e.response?.statusCode}');
          print('[DEBUG] PaymentApi.createOrder: - Response Data: ${e.response?.data}');
          print('[DEBUG] PaymentApi.createOrder: - Error Message: ${e.message}');
        
        String errorMessage = 'Ошибка сети при создании заказа';
        if (e.response?.data is Map<String, dynamic>) {
          final data = e.response!.data as Map<String, dynamic>;
          if (data['message'] is String) {
            errorMessage = data['message'] as String;
          }
        }
        return Err(errorMessage);
      }
      return Err('Ошибка создания заказа: $e');
    }
  }

  /// Подтвердить заказ (как в веб-версии после создания заказа)
  static Future<Result<Map<String, dynamic>>> confirmOrder(int orderId) async {
    try {
      print('[DEBUG] PaymentApi.confirmOrder: Подтверждаем заказ $orderId...');
      
      // Получаем user_token из профиля пользователя
      final userTokenResult = await AuthApi.getUserToken();
      
      String? userToken;
      final tokenResult = userTokenResult.when(
        ok: (token) {
          userToken = token;
          return null;
        },
        err: (error) {
          print('[DEBUG] PaymentApi.confirmOrder: Ошибка получения user_token: $error');
          return error;
        },
      );
      
      if (tokenResult != null || userToken == null) {
        return Err('Не удалось получить токен пользователя: ${tokenResult ?? 'токен не получен'}');
      }
      print('[DEBUG] PaymentApi.confirmOrder: Получен user_token: ${userToken!.substring(0, 10)}...');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      // Отправляем запрос на подтверждение заказа (как в веб-версии)
      final response = await _dio.post('/order/by-user',
        data: {
          'user_token': userToken,
          'time_zone': 'Asia/Tashkent',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] PaymentApi.confirmOrder: Сервер ответил со статусом: ${response.statusCode}');
      print('[DEBUG] PaymentApi.confirmOrder: Ответ сервера: ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] PaymentApi.confirmOrder: Заказ успешно подтвержден!');
        return Ok(response.data);
      } else {
        return Err('Ошибка подтверждения заказа: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] PaymentApi.confirmOrder: Ошибка: $e');
      if (e is DioException) {
        print('[DEBUG] PaymentApi.confirmOrder: DioException details:');
        print('[DEBUG] PaymentApi.confirmOrder: - Status Code: ${e.response?.statusCode}');
        print('[DEBUG] PaymentApi.confirmOrder: - Response Data: ${e.response?.data}');
        print('[DEBUG] PaymentApi.confirmOrder: - Error Message: ${e.message}');
      }
      return Err('Ошибка подтверждения заказа: $e');
    }
  }

  /// Отправить email уведомление о заказе (как в веб-версии)
  static Future<Result<Map<String, dynamic>>> sendOrderEmail(int orderId) async {
    try {
      print('[DEBUG] PaymentApi.sendOrderEmail: Отправляем email уведомление для заказа $orderId...');
      
      // Получаем user_token из профиля пользователя
      final userTokenResult = await AuthApi.getUserToken();
      
      String? userToken;
      final tokenResult = userTokenResult.when(
        ok: (token) {
          userToken = token;
          return null;
        },
        err: (error) {
          print('[DEBUG] PaymentApi.sendOrderEmail: Ошибка получения user_token: $error');
          return error;
        },
      );
      
      if (tokenResult != null || userToken == null) {
        return Err('Не удалось получить токен пользователя: ${tokenResult ?? 'токен не получен'}');
      }
      print('[DEBUG] PaymentApi.sendOrderEmail: Получен user_token: ${userToken!.substring(0, 10)}...');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      // Отправляем запрос на отправку email (как в веб-версии)
      final response = await _dio.get('/order/send-order-email/$orderId',
        queryParameters: {
        'id': orderId,
          'time_zone': 'Asia/Tashkent',
          'user_token': userToken,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] PaymentApi.sendOrderEmail: Сервер ответил со статусом: ${response.statusCode}');
      print('[DEBUG] PaymentApi.sendOrderEmail: Ответ сервера: ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] PaymentApi.sendOrderEmail: Email уведомление успешно отправлено!');
        return Ok(response.data);
      } else {
        return Err('Ошибка отправки email уведомления: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] PaymentApi.sendOrderEmail: Ошибка: $e');
      if (e is DioException) {
        print('[DEBUG] PaymentApi.sendOrderEmail: DioException details:');
        print('[DEBUG] PaymentApi.sendOrderEmail: - Status Code: ${e.response?.statusCode}');
        print('[DEBUG] PaymentApi.sendOrderEmail: - Response Data: ${e.response?.data}');
        print('[DEBUG] PaymentApi.sendOrderEmail: - Error Message: ${e.message}');
      }
      return Err('Ошибка отправки email уведомления: $e');
    }
  }

  /// Получить детали заказа
  static Future<Result<Map<String, dynamic>>> getOrderDetails(int orderId) async {
    try {
      print('[DEBUG] PaymentApi.getOrderDetails: Получаем детали заказа $orderId...');
      
      final response = await _dio.get('/orders/$orderId');
      
      print('[DEBUG] PaymentApi.getOrderDetails: HTTP статус = ${response.statusCode}');
      print('[DEBUG] PaymentApi.getOrderDetails: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        return Ok(response.data);
      } else {
        return Err('Ошибка получения заказа: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] PaymentApi.getOrderDetails: Ошибка: $e');
      return Err('Ошибка получения заказа: $e');
    }
  }

  /// Сохранить заказ в локальное хранилище
  static Future<void> _saveOrderToLocalStorage(Map<String, dynamic> orderData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderId = orderData['id'].toString();
      final orderNumber = orderData['order_number'];
      print('[DEBUG] PaymentApi._saveOrderToLocalStorage: Сохраняем заказ $orderId с номером: $orderNumber');
      final orderJson = jsonEncode(orderData);
      await prefs.setString('order_$orderId', orderJson);
      print('[DEBUG] PaymentApi._saveOrderToLocalStorage: Заказ $orderId сохранен в локальное хранилище');
    } catch (e) {
      print('[DEBUG] PaymentApi._saveOrderToLocalStorage: Ошибка сохранения заказа: $e');
    }
  }

  /// Получить заказ из локального хранилища
  static Future<Map<String, dynamic>?> getOrderFromLocalStorage(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = prefs.getString('order_$orderId');
      if (orderJson != null) {
        final orderData = jsonDecode(orderJson) as Map<String, dynamic>;
        print('[DEBUG] PaymentApi.getOrderFromLocalStorage: Заказ $orderId загружен из локального хранилища');
        return orderData;
      }
      return null;
    } catch (e) {
      print('[DEBUG] PaymentApi.getOrderFromLocalStorage: Ошибка загрузки заказа: $e');
      return null;
    }
  }

  // Получение доступных методов оплаты с сервера
  static Future<Result<Map<String, dynamic>>> getServerPaymentMethods() async {
    try {
      print('[DEBUG] PaymentApi.getServerPaymentMethods: Запрашиваем методы оплаты с сервера...');
      
      final response = await _dio.get('/payment-gateway');
      
      print('[DEBUG] PaymentApi.getServerPaymentMethods: Ответ сервера: ${response.data}');
      
      return Ok(response.data);
    } catch (e) {
      print('[DEBUG] PaymentApi.getServerPaymentMethods: Ошибка получения методов оплаты: $e');
      return Err('Ошибка получения методов оплаты: $e');
    }
  }

  /// Преобразовать ID метода оплаты в строку для локального хранения
  static String _getPaymentMethodString(int paymentMethodId) {
    switch (paymentMethodId) {
      case 1: // Оплата при доставке
        return 'cash_on_delivery';
      case 2: // Банковский перевод
        return 'bank_transfer';
      case 3: // PayPal
        return 'paypal';
      default:
        return 'cash_on_delivery';
    }
  }

  /// Генерировать случайную строку для номера заказа
  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  /// Безопасное вычисление общей стоимости товара
  static double _safeCalculateTotal(dynamic quantity, dynamic price) {
    final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
    final prc = price is double ? price : double.tryParse(price.toString()) ?? 0.0;
    return qty * prc;
  }

  /// Сервер пишет orders.user_address_id из users.default_address.
  /// default_address обновляется только через /cart/update-shipping + selected_address.
  static int? _parseProfileDefaultAddressId(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final raw = profile['default_address'] ?? profile['defaultAddress'];
    if (raw is int && raw > 0) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// ID адреса для selected_address на сервере (обновляет users.default_address).
  static int? _resolveSelectedAddressForServer(
    Address selected,
    List<Address> addresses, {
    int? profileDefaultAddress,
  }) {
    if (!selected.isLocalPickup) {
      return selected.serverAddressId;
    }

    // Самовывоз: shipping_type=2, но user_address_id всё равно обязателен в БД.
    // Берём default_address из профиля даже если список адресов не загрузился (часто на iOS).
    if (profileDefaultAddress != null && profileDefaultAddress > 0) {
      return profileDefaultAddress;
    }

    final deliveryAddresses = addresses
        .where((a) => a.type == 'delivery' && a.serverAddressId != null)
        .toList();
    if (deliveryAddresses.isNotEmpty) {
      Address? preferred;
      for (final a in deliveryAddresses) {
        if (a.isDefault) {
          preferred = a;
          break;
        }
      }
      preferred ??= deliveryAddresses.first;
      return preferred.serverAddressId;
    }

    // Пункт выдачи с сервера (id > 0), не встроенная карточка id=0.
    if (selected.serverAddressId != null && selected.serverAddressId! > 0) {
      return selected.serverAddressId;
    }

    final anyServerId = addresses
        .map((a) => a.serverAddressId)
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
    if (anyServerId.isNotEmpty) {
      return anyServerId.first;
    }

    return null;
  }
}