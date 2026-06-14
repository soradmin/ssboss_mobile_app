import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../auth/repo/auth_api.dart';
import '../../cart/repo/cart_api.dart';
import '../models/order.dart';
import '../order_action_limit_service.dart';

final orderApiProvider = Provider<OrderApi>((ref) {
  return OrderApi(dio);
});

class OrderApi {
  final Dio _apiClient;

  OrderApi(this._apiClient);

  /// Получить детали заказа по ID
  Future<Result<Order>> getOrderDetails(int orderId) async {
    try {
      print('[DEBUG] OrderApi.getOrderDetails: Получаем детали заказа $orderId');
      
      // Сначала пытаемся получить заказ с сервера
      try {
        print('[DEBUG] OrderApi.getOrderDetails: Пытаемся получить заказ с сервера...');
        print('[DEBUG] OrderApi.getOrderDetails: Используем POST /order/by-user с order_id: $orderId');
        
        // Получаем user_token для запроса (если требуется)
        String? userToken;
        try {
          // getUserToken - статический метод, возвращает Result<String>
          final userTokenResult = await AuthApi.getUserToken();
          userTokenResult.when(
            ok: (token) {
              userToken = token;
              print('[DEBUG] OrderApi.getOrderDetails: Получен user_token: ${token.substring(0, 10)}...');
            },
            err: (error) {
              print('[WARNING] OrderApi.getOrderDetails: Не удалось получить user_token: $error');
            },
          );
        } catch (e) {
          print('[WARNING] OrderApi.getOrderDetails: Ошибка при получении user_token: $e');
        }
        
        // Формируем данные для запроса
        final requestData = <String, dynamic>{
          'order_id': orderId,
        };
        if (userToken != null) {
          requestData['user_token'] = userToken;
        }
        // Не добавляем time_zone, так как сервер может не обработать его правильно
        
        print('[DEBUG] OrderApi.getOrderDetails: Отправляем запрос с данными: $requestData');
        
        // Серверный API ожидает POST запрос с order_id в теле запроса
        final response = await _apiClient.post('/order/by-user', data: requestData);
        
        print('[DEBUG] OrderApi.getOrderDetails: Статус ответа: ${response.statusCode}');
        print('[DEBUG] OrderApi.getOrderDetails: Данные ответа: ${response.data}');
        
        // Проверяем статус ответа
        if (response.statusCode != 200) {
          print('[ERROR] OrderApi.getOrderDetails: Неожиданный статус ответа: ${response.statusCode}');
          // Проверяем, есть ли сообщение об ошибке
          if (response.data is Map<String, dynamic>) {
            final errorData = response.data as Map<String, dynamic>;
            final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Заказ не найден';
            print('[ERROR] OrderApi.getOrderDetails: Сообщение об ошибке: $errorMessage');
            throw Exception(errorMessage.toString());
          }
          throw Exception('Ошибка загрузки заказа (статус: ${response.statusCode})');
        }
        
        if (response.data != null) {
          print('[DEBUG] OrderApi.getOrderDetails: Заказ найден на сервере');
          print('[DEBUG] OrderApi.getOrderDetails: Тип ответа: ${response.data.runtimeType}');
          
          // Проверяем, что ответ - это JSON, а не HTML
          if (response.data is String && (response.data as String).trim().startsWith('<!DOCTYPE')) {
            print('[DEBUG] OrderApi.getOrderDetails: Сервер вернул HTML вместо JSON, пропускаем');
            throw Exception('Сервер вернул HTML вместо JSON');
          }
          
          // Обрабатываем вложенную структуру ответа
          Map<String, dynamic> orderData;
          if (response.data is Map<String, dynamic>) {
            final responseMap = response.data as Map<String, dynamic>;
            print('[DEBUG] OrderApi.getOrderDetails: Ключи в ответе: ${responseMap.keys.toList()}');
            
            // Проверяем, есть ли ошибка в ответе (статус 201 или сообщение об ошибке)
            if (responseMap['status'] == 201 || 
                (responseMap.containsKey('message') && responseMap['message'] != null && responseMap['message'] != '')) {
              final errorMessage = responseMap['message']?.toString() ?? 'Заказ не найден';
              print('[ERROR] OrderApi.getOrderDetails: Сервер вернул ошибку: $errorMessage');
              // Продолжаем попытки получить из других источников
              throw Exception(errorMessage);
            }
            
            // Проверяем, есть ли вложенная структура data
            if (responseMap.containsKey('data') && responseMap['data'] is Map) {
              orderData = responseMap['data'] as Map<String, dynamic>;
              print('[DEBUG] OrderApi.getOrderDetails: Используем вложенную структуру data');
            } else {
              orderData = responseMap;
            }
            
            // Проверяем, что в orderData есть ID заказа
            if (!orderData.containsKey('id') || orderData['id'] == null) {
              print('[ERROR] OrderApi.getOrderDetails: В ответе отсутствует ID заказа');
              print('[ERROR] OrderApi.getOrderDetails: Ключи в orderData: ${orderData.keys.toList()}');
              throw Exception('В ответе отсутствует ID заказа');
            }
            
            // Проверяем, что ID в ответе совпадает с запрошенным
            final responseOrderId = orderData['id'];
            int responseOrderIdInt;
            if (responseOrderId is int) {
              responseOrderIdInt = responseOrderId;
            } else if (responseOrderId is String) {
              responseOrderIdInt = int.tryParse(responseOrderId) ?? 0;
            } else {
              responseOrderIdInt = 0;
            }
            
            if (responseOrderIdInt != orderId && responseOrderIdInt != 0) {
              print('[WARNING] OrderApi.getOrderDetails: ID в ответе ($responseOrderIdInt) не совпадает с запрошенным ($orderId)');
            }
            
            print('[DEBUG] OrderApi.getOrderDetails: Статус в ответе: ${orderData['status']} (тип: ${orderData['status']?.runtimeType})');
            print('[DEBUG] OrderApi.getOrderDetails: Номер заказа в ответе: ${orderData['order'] ?? orderData['order_number'] ?? orderData['orderNumber']}');
            print('[DEBUG] OrderApi.getOrderDetails: Сумма в ответе: ${orderData['total_amount'] ?? orderData['totalAmount']}');
            print('[DEBUG] OrderApi.getOrderDetails: Дата в ответе: ${orderData['created_at'] ?? orderData['created'] ?? orderData['order_date'] ?? orderData['orderDate']}');
            
            // Проверяем наличие товаров в ответе сервера
            final orderedProducts = orderData['ordered_products'];
            if (orderedProducts != null && orderedProducts is List) {
              print('[DEBUG] OrderApi.getOrderDetails: Сервер вернул ${orderedProducts.length} товаров в ordered_products');
            } else {
              print('[WARNING] OrderApi.getOrderDetails: Сервер не вернул ordered_products или это не список');
            }
            
            final order = Order.fromJson(orderData);
            print('[DEBUG] OrderApi.getOrderDetails: Заказ распарсен, статус: ${order.status}, displayStatus: ${order.displayStatus}');
            print('[DEBUG] OrderApi.getOrderDetails: Номер заказа: ${order.orderNumber}, Сумма: ${order.totalAmount}, Дата: ${order.orderDate}');
            print('[DEBUG] OrderApi.getOrderDetails: Товаров: ${order.items.length}');
            for (var item in order.items) {
              print('[DEBUG] OrderApi.getOrderDetails: Товар: ${item.name}, ID: ${item.productId}, Изображение: ${item.image}');
            }
            
            // Обновляем локальное хранилище с актуальными данными с сервера
            await _saveOrderToLocalStorage(order);
            
            return Ok(order);
          } else {
            print('[ERROR] OrderApi.getOrderDetails: Неожиданный тип ответа: ${response.data.runtimeType}');
            throw Exception('Неожиданный тип ответа: ${response.data.runtimeType}');
          }
        } else {
          print('[ERROR] OrderApi.getOrderDetails: Ответ сервера пуст');
          throw Exception('Ответ сервера пуст');
        }
      } on DioException catch (e) {
        print('[ERROR] OrderApi.getOrderDetails: DioException при получении с сервера: $e');
        print('[ERROR] OrderApi.getOrderDetails: Тип ошибки: ${e.type}');
        print('[ERROR] OrderApi.getOrderDetails: Статус ответа: ${e.response?.statusCode}');
        print('[ERROR] OrderApi.getOrderDetails: Данные ответа: ${e.response?.data}');
        
        // Если это 404 или 400, значит заказ не найден
        if (e.response?.statusCode == 404 || e.response?.statusCode == 400) {
          final errorData = e.response?.data;
          String errorMessage = 'Заказ не найден';
          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message']?.toString() ?? 
                          errorData['error']?.toString() ?? 
                          'Заказ не найден';
          }
          print('[ERROR] OrderApi.getOrderDetails: Заказ не найден на сервере: $errorMessage');
          // Продолжаем попытки получить из списка заказов или локального хранилища
        } else {
          // Для других ошибок пробуем получить из других источников
          print('[ERROR] OrderApi.getOrderDetails: Ошибка сети или сервера, пробуем другие источники');
        }
      } catch (e) {
        print('[ERROR] OrderApi.getOrderDetails: Общая ошибка получения с сервера: $e');
        print('[ERROR] OrderApi.getOrderDetails: Тип ошибки: ${e.runtimeType}');
      }
      
      // Если не удалось получить с сервера, пытаемся получить актуальный статус из списка заказов
      print('[DEBUG] OrderApi.getOrderDetails: Пытаемся получить актуальный статус из списка заказов...');
      try {
        final userOrdersResult = await getUserOrders();
        final result = userOrdersResult.when(
          ok: (orders) {
            print('[DEBUG] OrderApi.getOrderDetails: Получено заказов из списка: ${orders.length}');
            print('[DEBUG] OrderApi.getOrderDetails: Ищем заказ с ID: $orderId');
            for (var order in orders) {
              print('[DEBUG] OrderApi.getOrderDetails: Проверяем заказ ID: ${order.id} (тип: ${order.id.runtimeType}), номер: ${order.orderNumber}');
            }
            
            // Ищем заказ в списке заказов
            try {
              final foundOrder = orders.firstWhere(
                (order) {
                  final matches = order.id == orderId;
                  print('[DEBUG] OrderApi.getOrderDetails: Сравнение: ${order.id} == $orderId = $matches');
                  return matches;
                },
              );
              
              print('[DEBUG] OrderApi.getOrderDetails: Заказ найден в списке заказов, ID: ${foundOrder.id}, статус: ${foundOrder.status}, номер: ${foundOrder.orderNumber}');
              return foundOrder;
            } catch (e) {
              print('[ERROR] OrderApi.getOrderDetails: Заказ с ID $orderId не найден в списке заказов (всего заказов: ${orders.length})');
              print('[ERROR] OrderApi.getOrderDetails: Ошибка поиска: $e');
              return null;
            }
          },
          err: (error) {
            print('[ERROR] OrderApi.getOrderDetails: Не удалось получить список заказов: $error');
            return null;
          },
        );
        
        if (result != null) {
          // Если нашли заказ в списке, используем его данные
          print('[DEBUG] OrderApi.getOrderDetails: Заказ найден в списке, проверяем локальное хранилище для товаров...');
          final orderData = await _getOrderFromLocalStorage(orderId);
          
          // Если есть товары в локальном хранилище, используем их
          if (orderData != null && orderData['items'] != null && (orderData['items'] as List).isNotEmpty) {
            print('[DEBUG] OrderApi.getOrderDetails: Товары найдены в локальном хранилище, используем их');
            // Используем актуальный статус из списка заказов, но товары из локального хранилища
            final order = Order(
              id: result.id,
              orderNumber: result.orderNumber,
              status: result.status, // Используем актуальный статус из списка заказов
              paymentMethod: result.paymentMethod,
              paymentStatus: result.paymentStatus,
              deliveryStatus: result.status, // Используем актуальный статус для доставки
              totalAmount: result.totalAmount > 0 ? result.totalAmount : (orderData['total_amount'] as num?)?.toDouble() ?? 0.0,
              orderDate: result.orderDate,
              notes: orderData['notes'] as String? ?? '',
              address: null,
              items: (orderData['items'] as List<dynamic>).map((item) {
                final orderItem = OrderItem.fromJson(item);
                return orderItem;
              }).toList(),
            );
            print('[DEBUG] OrderApi.getOrderDetails: Заказ загружен с актуальным статусом и товарами из локального хранилища');
            return Ok(order);
          } else {
            // Если товаров нет в локальном хранилище, используем заказ из списка (с товарами, если они есть)
            print('[DEBUG] OrderApi.getOrderDetails: Товары не найдены в локальном хранилище, используем заказ из списка');
            print('[DEBUG] OrderApi.getOrderDetails: Товаров в заказе из списка: ${result.items.length}');
            
            // Используем заказ из списка напрямую, так как он уже содержит все данные с сервера
            if (result.items.isNotEmpty) {
              print('[DEBUG] OrderApi.getOrderDetails: Заказ из списка содержит товары, используем его');
              // Сохраняем заказ в локальное хранилище для будущего использования
              await _saveOrderToLocalStorage(result);
              return Ok(result);
            } else {
              print('[WARNING] OrderApi.getOrderDetails: Заказ из списка не содержит товаров, но возвращаем его для отображения');
              // Даже без товаров возвращаем заказ, чтобы пользователь мог видеть основную информацию
              return Ok(result);
            }
          }
        }
      } catch (e) {
        print('[DEBUG] OrderApi.getOrderDetails: Ошибка при получении списка заказов: $e');
      }
      
      // Если не удалось получить из списка заказов, пытаемся из локального хранилища
      print('[DEBUG] OrderApi.getOrderDetails: Пытаемся получить заказ из локального хранилища...');
      final orderData = await _getOrderFromLocalStorage(orderId);
      
      if (orderData != null) {
        print('[DEBUG] OrderApi.getOrderDetails: Заказ найден в локальном хранилище');
        print('[DEBUG] OrderApi.getOrderDetails: Данные заказа: $orderData');
        print('[DEBUG] OrderApi.getOrderDetails: Товары в заказе:');
        if (orderData['items'] != null) {
          for (var item in orderData['items']) {
            print('[DEBUG] OrderApi.getOrderDetails: - Товар: ${item['name']}, ID: ${item['product_id']}, Цена: ${item['price']}');
          }
        }
        
        final order = Order.fromJson(orderData);
        print('[DEBUG] OrderApi.getOrderDetails: Заказ загружен из локального хранилища: ${order.orderNumber}, отменен: ${order.isCancelled}, displayStatus: ${order.displayStatus}');
        return Ok(order);
      }
      
      // Если заказ не найден в локальном хранилище, создаем пустой заказ
      print('[DEBUG] OrderApi.getOrderDetails: Заказ не найден в локальном хранилище');
      return Err('Заказ не найден');
    } catch (e) {
      print('[DEBUG] OrderApi.getOrderDetails: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Получить список заказов пользователя
  Future<Result<List<Order>>> getUserOrders() async {
    try {
      print('[DEBUG] OrderApi.getUserOrders: Получаем заказы пользователя');
      
      // Используем POST запрос как в веб-версии
      final response = await _apiClient.post('/order/by-user');
      
      print('[DEBUG] OrderApi.getUserOrders: HTTP статус = ${response.statusCode}');
      print('[DEBUG] OrderApi.getUserOrders: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        print('[DEBUG] OrderApi.getUserOrders: Тип ответа: ${response.data.runtimeType}');
        print('[DEBUG] OrderApi.getUserOrders: Содержимое ответа: ${response.data}');
        
        List<dynamic> data;
        
        // Проверяем тип ответа
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          // Ищем массив заказов в различных возможных ключах
          if (responseMap.containsKey('data') && responseMap['data'] is Map) {
            // Если data это объект с вложенным массивом data
            final innerData = responseMap['data'] as Map<String, dynamic>;
            if (innerData.containsKey('data') && innerData['data'] is List) {
              data = innerData['data'] as List<dynamic>;
            } else {
              data = [];
            }
          } else if (responseMap.containsKey('data') && responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          } else if (responseMap.containsKey('orders') && responseMap['orders'] is List) {
            data = responseMap['orders'] as List<dynamic>;
          } else if (responseMap.containsKey('items') && responseMap['items'] is List) {
            data = responseMap['items'] as List<dynamic>;
          } else {
            // Если это объект с одним заказом, оборачиваем в список
            data = [responseMap];
          }
        } else {
          data = [];
        }
        
        print('[DEBUG] OrderApi.getUserOrders: Найдено заказов: ${data.length}');
        
        if (data.isEmpty) {
          print('[DEBUG] OrderApi.getUserOrders: Список заказов пуст');
          return const Ok([]);
        }
        
        final orders = <Order>[];
        for (var json in data) {
          print('[DEBUG] OrderApi.getUserOrders: Обрабатываем заказ: ${json['order'] ?? json['id']}');
          var order = Order.fromJson(json);
          
          // Если сумма заказа равна 0, попробуем получить из локального хранилища
          if (order.totalAmount == 0.0) {
            print('[DEBUG] OrderApi.getUserOrders: Сумма заказа ${order.id} равна 0, проверяем локальное хранилище');
            final localOrderData = await _getOrderFromLocalStorage(order.id);
            if (localOrderData != null && localOrderData['total_amount'] != null) {
              final localTotal = (localOrderData['total_amount'] as num).toDouble();
              if (localTotal > 0.0) {
                print('[DEBUG] OrderApi.getUserOrders: Найдена сумма в локальном хранилище: $localTotal');
                // Создаем новый объект Order с правильной суммой
                order = Order(
                  id: order.id,
                  orderNumber: order.orderNumber,
                  status: order.status,
                  paymentMethod: order.paymentMethod,
                  paymentStatus: order.paymentStatus,
                  deliveryStatus: order.deliveryStatus,
                  totalAmount: localTotal, // Используем сумму из локального хранилища
                  orderDate: order.orderDate,
                  notes: order.notes,
                  address: order.address,
                  items: order.items,
                );
              }
            }
          }
          
          orders.add(order);
        }
        
        print('[DEBUG] OrderApi.getUserOrders: Успешно создано ${orders.length} заказов');
        return Ok(orders);
      }
      
      return Err('Не удалось получить заказы: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] OrderApi.getUserOrders: DioException: ${e.message}');
      return Err('Ошибка получения заказов: ${e.message}');
    } catch (e) {
      print('[DEBUG] OrderApi.getUserOrders: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Отменить заказ
  Future<Result<void>> cancelOrder(int orderId, {String? reason}) async {
    try {
      print('[DEBUG] OrderApi.cancelOrder: Отменяем заказ $orderId');

      final payload = <String, dynamic>{
        'order_id': orderId,
        'title': 'Отмена заказа',
        'message': reason?.trim().isNotEmpty == true
            ? reason!.trim()
            : 'Заказ отменен пользователем через мобильное приложение',
      };

      // Для гостевых заказов серверу нужен user_token
      try {
        final userTokenResult = await AuthApi.getUserToken();
        userTokenResult.when(
          ok: (token) => payload['user_token'] = token,
          err: (_) {},
        );
      } catch (_) {}

      final response = await _apiClient.post(
        '/cancellation/cancel-order',
        data: payload,
        options: Options(headers: {'language': 'ru'}),
      );

      print('[DEBUG] OrderApi.cancelOrder: HTTP статус = ${response.statusCode}');
      print('[DEBUG] OrderApi.cancelOrder: Ответ сервера = ${response.data}');

      if (response.statusCode == 200) {
        await OrderActionLimitService.recordAction(orderId);
        await _markOrderCancelledLocally(orderId);
        return const Ok(null);
      }

      return Err(_extractApiErrorMessage(response.data) ??
          'Не удалось отменить заказ: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] OrderApi.cancelOrder: DioException: ${e.message}');
      final serverMessage = _extractApiErrorMessage(e.response?.data);
      return Err(serverMessage ?? 'Не удалось отменить заказ. Попробуйте позже.');
    } catch (e) {
      print('[DEBUG] OrderApi.cancelOrder: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Повторить отмененный заказ — добавить товары в корзину
  Future<Result<int>> repeatOrder(Order order) async {
    try {
      if (!order.isCancelled) {
        return const Err('Повторить можно только отмененный заказ');
      }

      if (!await OrderActionLimitService.canPerformAction(order.id)) {
        return const Err(
          'Лимит исчерпан: отменить или повторить этот заказ можно не более 3 раз',
        );
      }

      if (order.items.isEmpty) {
        return const Err('В заказе нет товаров для повторения');
      }

      final cartApi = CartApi();
      var addedCount = 0;
      String? lastError;

      for (final item in order.items) {
        if (item.productId <= 0 || item.quantity <= 0) {
          continue;
        }

        final result = await cartApi.add(
          item.productId,
          item.quantity,
          inventoryId: item.inventoryId,
        );

        result.when(
          ok: (_) => addedCount++,
          err: (error) => lastError = error,
        );
      }

      if (addedCount == 0) {
        return Err(lastError ?? 'Не удалось добавить товары в корзину');
      }

      await OrderActionLimitService.recordAction(order.id);
      return Ok(addedCount);
    } catch (e) {
      return Err('Не удалось повторить заказ: $e');
    }
  }

  String? _extractApiErrorMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    final form = data['form'];
    if (form is Map) {
      for (final value in form.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  /// Оценить товар в заказе
  Future<Result<void>> rateProduct(int orderId, int productId, int rating, String? comment) async {
    try {
      print('[DEBUG] OrderApi.rateProduct: Оцениваем товар $productId в заказе $orderId');
      
      final response = await _apiClient.post('/order/rate', data: {
        'order_id': orderId,
        'product_id': productId,
        'rating': rating,
        'comment': comment,
      });
      
      print('[DEBUG] OrderApi.rateProduct: HTTP статус = ${response.statusCode}');
      print('[DEBUG] OrderApi.rateProduct: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        return const Ok(null);
      }
      
      return Err('Не удалось оценить товар: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] OrderApi.rateProduct: DioException: ${e.message}');
      return Err('Ошибка оценки товара: ${e.message}');
    } catch (e) {
      print('[DEBUG] OrderApi.rateProduct: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Получить заказ из локального хранилища
  Future<Map<String, dynamic>?> _getOrderFromLocalStorage(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = prefs.getString('order_$orderId');
      if (orderJson != null) {
        final orderData = jsonDecode(orderJson) as Map<String, dynamic>;
        final orderNumber = orderData['order_number'];
        print('[DEBUG] OrderApi._getOrderFromLocalStorage: Заказ $orderId загружен из локального хранилища');
        print('[DEBUG] OrderApi._getOrderFromLocalStorage: Номер заказа в данных: $orderNumber');
        return orderData;
      }
      return null;
    } catch (e) {
      print('[DEBUG] OrderApi._getOrderFromLocalStorage: Ошибка загрузки заказа: $e');
      return null;
    }
  }

  Future<void> _markOrderCancelledLocally(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = prefs.getString('order_$orderId');
      if (orderJson == null) return;

      final orderData = jsonDecode(orderJson) as Map<String, dynamic>;
      orderData['cancelled'] = 1;
      orderData['status'] = 'cancelled';
      orderData['delivery_status'] = 'cancelled';
      await prefs.setString('order_$orderId', jsonEncode(orderData));
      print('[DEBUG] OrderApi._markOrderCancelledLocally: Заказ $orderId помечен отмененным');
    } catch (e) {
      print('[DEBUG] OrderApi._markOrderCancelledLocally: Ошибка: $e');
    }
  }

  /// Сохранить заказ в локальное хранилище
  Future<void> _saveOrderToLocalStorage(Order order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderJson = jsonEncode(order.toJson());
      await prefs.setString('order_${order.id}', orderJson);
      print('[DEBUG] OrderApi._saveOrderToLocalStorage: Заказ ${order.id} сохранен в локальное хранилище');
    } catch (e) {
      print('[DEBUG] OrderApi._saveOrderToLocalStorage: Ошибка сохранения заказа: $e');
    }
  }
}
