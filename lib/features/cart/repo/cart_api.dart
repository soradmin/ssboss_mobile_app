import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';
import '../models/server_cart_line.dart';

class CartApi {
  /// Добавление товара в серверную корзину
  /// [inventoryId] - ID инвентаря (комбинации атрибутов). Если не указан, будет найден по атрибутам
  /// [selectedAttributes] - выбранные атрибуты (ключ - id атрибута, значение - id значения атрибута)
  Future<Result<void>> add(int productId, int qty, {int? inventoryId, Map<int, int>? selectedAttributes}) async {
    try {
      print('[DEBUG] CartApi.add: Добавляем товар $productId в количестве $qty');
      print('[DEBUG] CartApi.add: inventoryId: $inventoryId, selectedAttributes: $selectedAttributes');
      
      int? invId = inventoryId;
      
      // Если inventory_id не указан, пытаемся найти его по атрибутам
      if (invId == null && selectedAttributes != null && selectedAttributes.isNotEmpty) {
        print('[DEBUG] CartApi.add: Ищем inventory_id по атрибутам: $selectedAttributes');
        invId = await _findInventoryIdByAttributes(productId, selectedAttributes);
        if (invId == null) {
          print('[DEBUG] CartApi.add: Не найден inventory_id для товара $productId с атрибутами $selectedAttributes');
          return const Err('Не найден inventory_id для выбранных атрибутов. Пожалуйста, выберите все атрибуты товара.');
        }
        print('[DEBUG] CartApi.add: Найден inventory_id по атрибутам: $invId');
      }
      
      // Если inventory_id все еще не найден, пытаемся получить первый доступный
      if (invId == null) {
        print('[DEBUG] CartApi.add: inventory_id не найден, пытаемся получить первый доступный');
        invId = await _getInventoryId(productId);
        if (invId == null) {
          print('[DEBUG] CartApi.add: Не найден inventory_id для товара $productId');
          return const Err('Не найден inventory_id. Пожалуйста, выберите все атрибуты товара.');
        }
        print('[DEBUG] CartApi.add: Найден первый доступный inventory_id: $invId');
      }

      // Для авторизованных пользователей используем Bearer токен в заголовке
      // Для гостей используем user_token
      final activeToken = AppConfig.getActiveBearerToken();
      Map<String, dynamic> queryParams = {};
      
      if (activeToken.isNotEmpty) {
        // Авторизованный пользователь - используем Bearer токен в заголовке
        print('[DEBUG] CartApi.add: Авторизованный пользователь, используем Bearer токен');
        // Токен уже добавлен в заголовки через интерцептор
      } else {
        // Гость - используем user_token
        queryParams['user_token'] = AppConfig.guestToken;
        print('[DEBUG] CartApi.add: Гость, используем user_token: ${AppConfig.guestToken}');
      }
      
      final res = await dio.post(
        '/cart/action',
        queryParameters: queryParams,
        data: {
          'product_id': productId, 
          'inventory_id': invId, 
          'quantity': qty,
        },
      );
      
      print('[DEBUG] CartApi.add: Ответ сервера: ${res.statusCode} - ${res.data}');
      return res.statusCode == 200 ? const Ok(null) : Err('HTTP ${res.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CartApi.add: Ошибка DioException: ${e.response?.data} - ${e.message}');
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] CartApi.add: Общая ошибка: $e');
      return Err(e.toString());
    }
  }

  /// Удаление товара из серверной корзины по ID
  Future<Result<void>> remove(int cartItemId) async {
    try {
      print('[DEBUG] CartApi.remove: Удаляем товар с ID $cartItemId');
      final res = await dio.delete('/cart/delete/$cartItemId');
      print('[DEBUG] CartApi.remove: Ответ сервера: ${res.statusCode} - ${res.data}');
      return res.statusCode == 200 ? const Ok(null) : Err('HTTP ${res.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CartApi.remove: Ошибка DioException: ${e.response?.data} - ${e.message}');
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] CartApi.remove: Общая ошибка: $e');
      return Err(e.toString());
    }
  }

  /// Получение корзины с сервера
  Future<Result<List<ServerCartLine>>> getCart() async {
    try {
      print('[DEBUG] CartApi.getCart: Запрашиваем корзину с сервера');
      
      // Для авторизованных пользователей используем Bearer токен в заголовке
      // Для гостей используем user_token
      final activeToken = AppConfig.getActiveBearerToken();
      Map<String, dynamic> queryParams = {};
      
      if (activeToken.isNotEmpty) {
        // Авторизованный пользователь - используем Bearer токен в заголовке
        print('[DEBUG] CartApi.getCart: Авторизованный пользователь, используем Bearer токен');
        // Токен уже добавлен в заголовки через интерцептор
      } else {
        // Гость - используем user_token
        queryParams['user_token'] = AppConfig.guestToken;
        print('[DEBUG] CartApi.getCart: Гость, используем user_token: ${AppConfig.guestToken}');
      }
      
      final res = await dio.get('/cart/by-user', queryParameters: queryParams);
      final data = res.data;
      print('[DEBUG] CartApi.getCart: Ответ сервера: $data');

      // Ищем массив строк корзины в типичных местах
      List list = const [];
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
        print('[DEBUG] CartApi.getCart: Найден массив в data: ${list.length} элементов');
      } else if (data is Map && data['data'] is Map && (data['data'] as Map)['cart'] is List) {
        list = (data['data'] as Map)['cart'] as List;
        print('[DEBUG] CartApi.getCart: Найден массив в data.cart: ${list.length} элементов');
      } else if (data is List) {
        list = data;
        print('[DEBUG] CartApi.getCart: Данные - это массив: ${list.length} элементов');
      } else if (data is Map && data['cart'] is List) {
        list = data['cart'] as List;
        print('[DEBUG] CartApi.getCart: Найден массив в cart: ${list.length} элементов');
      } else {
        print('[DEBUG] CartApi.getCart: Не удалось найти массив корзины в ответе');
        print('[DEBUG] CartApi.getCart: Структура данных: ${data.runtimeType}');
        if (data is Map) {
          print('[DEBUG] CartApi.getCart: Ключи в данных: ${data.keys.toList()}');
        }
      }

      // Парсим элементы корзины с извлечением атрибутов
      final lines = list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        
        // Извлекаем атрибуты из updated_inventory.inventory_attributes
        Map<int, int> attributes = {};
        if (m['updated_inventory'] is Map) {
          final invMap = (m['updated_inventory'] as Map).cast<String, dynamic>();
          if (invMap['inventory_attributes'] is List) {
            final invAttrs = invMap['inventory_attributes'] as List;
            for (final attr in invAttrs) {
              if (attr is! Map) continue;
              final attrMap = attr.cast<String, dynamic>();
              
              // Получаем attribute_value_id и attribute_id
              final attrValueId = int.tryParse('${attrMap['attribute_value_id'] ?? 0}');
              if (attrValueId == null || attrValueId == 0) continue;
              
              // Получаем attribute_id из вложенного объекта attribute_value.attribute
              int? attrId;
              if (attrMap['attribute_value'] is Map) {
                final attrValueMap = (attrMap['attribute_value'] as Map).cast<String, dynamic>();
                if (attrValueMap['attribute'] is Map) {
                  final attrObj = (attrValueMap['attribute'] as Map).cast<String, dynamic>();
                  attrId = int.tryParse('${attrObj['id'] ?? 0}');
                } else {
                  // Если attribute не вложен, пробуем получить из attribute_value.attribute_id
                  attrId = int.tryParse('${attrValueMap['attribute_id'] ?? 0}');
                }
              }
              
              if (attrId != null && attrId > 0 && attrValueId > 0) {
                attributes[attrId] = attrValueId;
                print('[DEBUG] CartApi.getCart: Найден атрибут: attribute_id=$attrId, attribute_value_id=$attrValueId');
              }
            }
          }
        }
        
        print('[DEBUG] CartApi.getCart: Товар ${m['product_id']}, извлечено атрибутов: ${attributes.length}');
        
        // Получаем название и изображение из flash_product если есть
        String productName = '';
        String productImage = '';
        double productPrice = 0.0;
        
        if (m['flash_product'] is Map) {
          final productMap = (m['flash_product'] as Map).cast<String, dynamic>();
          productName = (productMap['title'] ?? productMap['name'] ?? '').toString();
          final rawImage = (productMap['image'] ?? '').toString();
          productImage = rawImage.isNotEmpty ? AppConfig.imageUrl(rawImage) : '';
          productPrice = _toDouble(productMap['offered'] ?? productMap['selling'] ?? productMap['price'] ?? 0);
        }
        
        // Обрабатываем изображение если оно еще не обработано
        String finalImage = productImage;
        if (finalImage.isEmpty) {
          final rawImage = (m['product']?['image'] ?? m['image'] ?? '').toString();
          finalImage = rawImage.isNotEmpty ? AppConfig.imageUrl(rawImage) : '';
        }
        
        return ServerCartLine(
          id: int.tryParse('${m['id'] ?? 0}') ?? 0,
          productId: int.tryParse('${m['product_id'] ?? m['productId'] ?? 0}') ?? 0,
          inventoryId: int.tryParse('${m['inventory_id'] ?? m['inventoryId'] ?? 0}') ?? 0,
          quantity: int.tryParse('${m['quantity'] ?? m['qty'] ?? 0}') ?? 0,
          name: productName.isNotEmpty ? productName : (m['product']?['name'] ?? m['name'] ?? '').toString(),
          image: finalImage,
          price: productPrice > 0 ? productPrice : _toDouble(m['product']?['price'] ?? m['price'] ?? 0),
          selectedAttributes: attributes,
        );
      }).toList();

      // Обогатим тем, чего не хватает (имя/картинка/цена) — дотянем из Product API
      final enriched = <ServerCartLine>[];
      for (final ln in lines) {
        if (ln.name.isNotEmpty && ln.image.isNotEmpty && ln.price > 0) {
          enriched.add(ln);
          continue;
        }
        final details = await _getProductDetails(ln.productId);
        if (details == null) {
          enriched.add(ln);
        } else {
          enriched.add(ln.copyWith(
            name: details['name'] ?? ln.name,
            image: details['image'] ?? ln.image,
            price: details['price'] ?? ln.price,
          ));
        }
      }

      print('[DEBUG] CartApi.getCart: Всего товаров в корзине: ${enriched.length}');
      for (final item in enriched) {
        print('[DEBUG] CartApi.getCart: Товар ${item.productId}, inventory_id: ${item.inventoryId}, атрибутов: ${item.selectedAttributes.length}');
      }

      return Ok(enriched);
    } on DioException catch (e) {
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }

  // ---- helpers ----

  /// Поиск inventory_id по выбранным атрибутам
  /// [selectedAttributes] - Map где ключ - id атрибута, значение - id значения атрибута
  Future<int?> _findInventoryIdByAttributes(int productId, Map<int, int> selectedAttributes) async {
    try {
      print('[DEBUG] CartApi._findInventoryIdByAttributes: Ищем inventory_id для товара $productId с атрибутами $selectedAttributes');
      
      // Получаем детали товара
      final path = '/product/$productId';
      final r = await dio.get(path, queryParameters: {'id': productId, 'user_id': ''});
      final d = r.data;
      
      Map<String, dynamic>? productData;
      if (d is Map && d['data'] is Map) {
        productData = (d['data'] as Map).cast<String, dynamic>();
      } else if (d is Map) {
        productData = d.cast<String, dynamic>();
      }
      
      if (productData == null) {
        print('[DEBUG] CartApi._findInventoryIdByAttributes: Не удалось получить данные товара');
        return null;
      }
      
      // Получаем список инвентарей
      List? inventories;
      if (productData['inventory'] is List) {
        inventories = productData['inventory'] as List;
      } else if (productData['inventories'] is List) {
        inventories = productData['inventories'] as List;
      }
      
      if (inventories == null || inventories.isEmpty) {
        print('[DEBUG] CartApi._findInventoryIdByAttributes: У товара нет инвентарей');
        return null;
      }
      
      print('[DEBUG] CartApi._findInventoryIdByAttributes: Найдено ${inventories.length} инвентарей');
      
      // Ищем инвентарь, который соответствует всем выбранным атрибутам
      for (final inv in inventories) {
        if (inv is! Map) continue;
        
        final invMap = inv.cast<String, dynamic>();
        final invId = int.tryParse('${invMap['id'] ?? 0}');
        if (invId == null || invId == 0) continue;
        
        // Получаем атрибуты этого инвентаря
        List? invAttributes;
        if (invMap['inventory_attributes'] is List) {
          invAttributes = invMap['inventory_attributes'] as List;
        }
        
        if (invAttributes == null || invAttributes.isEmpty) continue;
        
        // Собираем attribute_value_id из инвентаря
        final invAttributeValueIds = <int>{};
        for (final attr in invAttributes) {
          if (attr is! Map) continue;
          final attrMap = attr.cast<String, dynamic>();
          final attrValueId = int.tryParse('${attrMap['attribute_value_id'] ?? 0}');
          if (attrValueId != null && attrValueId > 0) {
            invAttributeValueIds.add(attrValueId);
          }
        }
        
        print('[DEBUG] CartApi._findInventoryIdByAttributes: Инвентарь $invId имеет attribute_value_ids: $invAttributeValueIds');
        print('[DEBUG] CartApi._findInventoryIdByAttributes: Ищем attribute_value_ids: ${selectedAttributes.values.toSet()}');
        
        // Проверяем, что все выбранные значения атрибутов присутствуют в этом инвентаре
        final selectedValueIds = selectedAttributes.values.toSet();
        if (selectedValueIds.length == invAttributeValueIds.length &&
            selectedValueIds.every((id) => invAttributeValueIds.contains(id))) {
          print('[DEBUG] CartApi._findInventoryIdByAttributes: Найден подходящий inventory_id: $invId');
          return invId;
        }
      }
      
      print('[DEBUG] CartApi._findInventoryIdByAttributes: Не найден подходящий inventory_id');
      return null;
    } catch (e) {
      print('[DEBUG] CartApi._findInventoryIdByAttributes: Ошибка: $e');
      return null;
    }
  }

  Future<int?> _getInventoryId(int productId) async {
    // пробуем два распространённых пути
    final paths = ['/products/$productId', '/product/$productId'];
    for (final p in paths) {
      try {
        final r = await dio.get(p, queryParameters: p.contains('/product/') ? {'id': productId, 'user_id': ''} : null);
        final d = r.data;
        List? invs;
        if (d is Map && d['data'] is Map) {
          final mm = d['data'] as Map;
          invs = (mm['inventories'] as List?) ?? (mm['inventory'] as List?);
        } else if (d is Map && d['inventories'] is List) {
          invs = d['inventories'] as List;
        }
        if (invs != null && invs.isNotEmpty) {
          final first = invs.first;
          if (first is Map && first['id'] != null) {
            return int.tryParse('${first['id']}');
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getProductDetails(int id) async {
    try {
      // Используем только правильный endpoint, который возвращает JSON
      final path = '/product/$id';
      try {
        final r = await dio.get(path);
        final d = r.data;
        Map? m;
        if (d is Map && d['data'] is Map) m = d['data'] as Map;
        else if (d is Map) m = d;
        if (m != null) {
          final name = (m['name'] ?? m['title'] ?? '').toString();
          final image = (m['image'] ?? m['thumbnail'] ?? m['thumb'] ?? '').toString();
          final price = _toDouble(m['price'] ?? m['offered'] ?? m['selling'] ?? 0);
          print('[DEBUG] CartApi._getProductDetails: Товар $id, исходное изображение: "$image"');
          final processedImage = AppConfig.imageUrl(image);
          print('[DEBUG] CartApi._getProductDetails: Обработанное изображение: "$processedImage"');
          return {'name': name, 'image': processedImage, 'price': price};
        }
      } catch (e) {
        print('[DEBUG] CartApi._getProductDetails: Ошибка получения деталей товара $id: $e');
      }
      return null;
    } catch (e) {
      print('[DEBUG] CartApi._getProductDetails: Общая ошибка для товара $id: $e');
      return null;
    }
  }

  String _fullImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final base = AppConfig.cdnBaseUrl.isNotEmpty
        ? AppConfig.cdnBaseUrl
        : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base$path';
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  /// Обновление корзины с выбранным адресом доставки
  /// Это нужно сделать перед созданием заказа, чтобы сервер знал, какой адрес использовать
  /// [deliveryType] - 'pickup' для самовывоза или 'delivery' для доставки на адрес
  Future<Result<void>> updateShippingAddress(int addressId, {String? addressType, String? deliveryType}) async {
    try {
      print('[DEBUG] CartApi.updateShippingAddress: Обновляем корзину с адресом $addressId (тип: ${addressType ?? 'не указан'})');
      
      final activeToken = AppConfig.getActiveBearerToken();
      Map<String, dynamic> queryParams = {};
      
      if (activeToken.isNotEmpty) {
        print('[DEBUG] CartApi.updateShippingAddress: Авторизованный пользователь, используем Bearer токен');
      } else {
        queryParams['user_token'] = AppConfig.guestToken;
        print('[DEBUG] CartApi.updateShippingAddress: Гость, используем user_token: ${AppConfig.guestToken}');
      }
      
      // Получаем корзину с сервера
      final cartResult = await getCart();
      if (cartResult is Err) {
        return Err('Не удалось получить корзину: ${(cartResult as Err).message}');
      }
      
      final cartLines = (cartResult as Ok<List<ServerCartLine>>).value;
      if (cartLines.isEmpty) {
        return const Err('Корзина пуста');
      }
      
      // Формируем payload для обновления корзины с адресом
      // Формат как на сайте: {cart: {cartId: {cart: cartId, shipping_place: {...}, shipping_type: 1/2}}, selected_address: addressId, user_token: ...}
      // ВАЖНО: shipping_place передается как ОБЪЕКТ внутри каждого элемента корзины, а не на верхнем уровне!
      print('[DEBUG] CartApi.updateShippingAddress: addressId = $addressId, addressType = $addressType, deliveryType = $deliveryType');
      
      // Используем deliveryType если передан, иначе определяем по addressType
      final effectiveDeliveryType = deliveryType ?? (addressType == 'pickup' && addressId == 1 ? 'pickup' : 'delivery');
      final shippingType = effectiveDeliveryType == 'pickup' ? 2 : 1; // 2 = pickup, 1 = delivery
      
      // Для статического пункта выдачи (ID 1) создаем объект shipping_place
      // Для обычных адресов также используем статический пункт выдачи (ID 1) как shipping_place
      final shippingPlaceObject = {
        'id': 1, // Всегда используем статический пункт выдачи ID 1
        'country': 'TJ',
        'state': 'DU',
        'price': '20.00',
        'day_needed': 1,
        'pickup_price': '0.00',
        'pickup_point': 1,
        'shipping_rule_id': 1,
        'pickup_phone': '930900412',
        'pickup_address_line_1': 'улица Джаббора Расулова, 6/1',
        'pickup_address_line_2': null,
        'pickup_zip': '734000',
        'pickup_state': 'РРП',
        'pickup_city': 'Душанбе',
        'pickup_country': 'Таджикистан',
      };
      
      print('[DEBUG] CartApi.updateShippingAddress: effectiveDeliveryType = $effectiveDeliveryType, shipping_type = $shippingType');
      
      // Формируем payload для каждого элемента корзины
      final cartPayload = <String, dynamic>{};
      for (final line in cartLines) {
        cartPayload['${line.id}'] = {
          'cart': line.id,
          'shipping_place': shippingPlaceObject, // Объект shipping_place внутри каждого элемента корзины
          'shipping_type': shippingType, // 1 = delivery, 2 = pickup
        };
      }
      
      final payload = {
        'cart': cartPayload,
        'selected_address': addressId,
        if (queryParams.containsKey('user_token')) 'user_token': queryParams['user_token'],
      };
      
      print('[DEBUG] CartApi.updateShippingAddress: Payload = $payload');
      
      final res = await dio.post(
        '/cart/update-shipping',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: payload,
      );
      
      print('[DEBUG] CartApi.updateShippingAddress: Ответ сервера: ${res.statusCode} - ${res.data}');
      
      // Проверяем ответ на наличие ошибок
      if (res.statusCode == 200 && res.data is Map) {
        final responseData = res.data as Map<String, dynamic>;
        if (responseData.containsKey('data') && responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('form') && data['form'] is List) {
            final formErrors = data['form'] as List;
            if (formErrors.isNotEmpty) {
              final errorMessage = formErrors.map((e) => e.toString()).join(', ');
              print('[ERROR] CartApi.updateShippingAddress: Ошибки валидации: $errorMessage');
              return Err('Ошибка обновления корзины: $errorMessage');
            }
          }
        }
        return const Ok(null);
      }
      
      return Err('HTTP ${res.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CartApi.updateShippingAddress: Ошибка DioException: ${e.response?.data} - ${e.message}');
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] CartApi.updateShippingAddress: Общая ошибка: $e');
      return Err(e.toString());
    }
  }
}