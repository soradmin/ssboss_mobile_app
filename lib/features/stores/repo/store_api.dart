import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../models/store.dart';

final storeApiProvider = Provider<StoreApi>((ref) {
  return StoreApi(dio);
});

class StoreApi {
  final Dio _apiClient;

  StoreApi(this._apiClient);

  /// Получить информацию о магазине по slug
  Future<Result<Store>> getStoreBySlug(String slug) async {
    try {
      print('[DEBUG] StoreApi.getStoreBySlug: Получаем информацию о магазине $slug');
      
      final response = await _apiClient.get('/store', queryParameters: {
        'slug': slug,
        'required_rating': 'true',
      });
      
      print('[DEBUG] StoreApi.getStoreBySlug: HTTP статус = ${response.statusCode}');
      print('[DEBUG] StoreApi.getStoreBySlug: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        print('[DEBUG] StoreApi.getStoreBySlug: Тип ответа: ${response.data.runtimeType}');
        print('[DEBUG] StoreApi.getStoreBySlug: Ключи ответа: ${response.data is Map ? (response.data as Map).keys.toList() : 'Не Map'}');
        
        // Извлекаем данные из разных возможных структур ответа
        Map<String, dynamic>? storeData;
        if (response.data is Map) {
          final data = response.data as Map;
          
          // Проверяем, есть ли вложенный объект data
          if (data.containsKey('data') && data['data'] is Map) {
            final innerData = data['data'] as Map;
            print('[DEBUG] StoreApi.getStoreBySlug: Ключи в data.data: ${innerData.keys.toList()}');
            
            // Проверяем, есть ли вложенный объект store
            if (innerData.containsKey('store') && innerData['store'] is Map) {
              storeData = Map<String, dynamic>.from(innerData['store'] as Map);
              print('[DEBUG] StoreApi.getStoreBySlug: Найден магазин в data.data.store');
              
              // Добавляем данные из result и review для парсинга
              if (innerData.containsKey('result') && innerData['result'] is Map) {
                final result = innerData['result'] as Map;
                storeData['result'] = result;
                print('[DEBUG] StoreApi.getStoreBySlug: Добавлены данные result');
              }
              if (innerData.containsKey('review')) {
                storeData['review'] = innerData['review'];
                print('[DEBUG] StoreApi.getStoreBySlug: Добавлен review: ${innerData['review']}');
              }
              if (innerData.containsKey('following')) {
                storeData['following'] = innerData['following'];
              }
            } else if (innerData.containsKey('data') && innerData['data'] is Map) {
              // Проверяем, может быть еще один уровень вложенности
              final nestedData = innerData['data'] as Map;
              if (nestedData.containsKey('store') && nestedData['store'] is Map) {
                storeData = nestedData['store'] as Map<String, dynamic>;
                print('[DEBUG] StoreApi.getStoreBySlug: Найден магазин в data.data.data.store');
              } else {
                storeData = nestedData.cast<String, dynamic>();
                print('[DEBUG] StoreApi.getStoreBySlug: Используем data.data.data');
              }
            } else {
              // Если в data.data нет store, используем сам data.data
              storeData = innerData.cast<String, dynamic>();
              print('[DEBUG] StoreApi.getStoreBySlug: Используем data.data напрямую');
            }
          } else if (data.containsKey('store') && data['store'] is Map) {
            storeData = data['store'] as Map<String, dynamic>;
            print('[DEBUG] StoreApi.getStoreBySlug: Найден магазин в data.store');
          } else {
            // Если данные прямо в корне
            storeData = data.cast<String, dynamic>();
            print('[DEBUG] StoreApi.getStoreBySlug: Используем данные из корня ответа');
          }
        }
        
        if (storeData == null || storeData.isEmpty) {
          print('[DEBUG] StoreApi.getStoreBySlug: Не удалось извлечь данные магазина');
          return Err('Данные магазина не найдены в ответе сервера');
        }
        
        print('[DEBUG] StoreApi.getStoreBySlug: Данные магазина: $storeData');
        final store = Store.fromJson(storeData);
        print('[DEBUG] StoreApi.getStoreBySlug: Магазин загружен: ${store.name}');
        
        // Извлекаем товары из ответа, если они есть
        List<dynamic> productsList = [];
        if (response.data is Map) {
          final data = response.data as Map;
          if (data.containsKey('data') && data['data'] is Map) {
            final innerData = data['data'] as Map;
            if (innerData.containsKey('result') && innerData['result'] is Map) {
              final result = innerData['result'] as Map;
              if (result.containsKey('data') && result['data'] is List) {
                productsList = result['data'] as List;
                print('[DEBUG] StoreApi.getStoreBySlug: Найдено товаров: ${productsList.length}');
              }
            }
          }
        }
        
        // Сохраняем товары в объекте Store (через расширение или отдельно)
        // Пока просто логируем, отображение товаров добавим в экране
        
        return Ok(store);
      }
      
      return Err('Не удалось получить информацию о магазине: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] StoreApi.getStoreBySlug: DioException: ${e.message}');
      return Err('Ошибка получения магазина: ${e.message}');
    } catch (e) {
      print('[DEBUG] StoreApi.getStoreBySlug: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Подписаться/отписаться от магазина
  Future<Result<bool>> toggleFollowStore(int storeId) async {
    try {
      print('[DEBUG] StoreApi.toggleFollowStore: Переключаем подписку на магазин $storeId');
      
      final response = await _apiClient.post('/user/store/follow', data: {
        'store_id': storeId,
      });
      
      print('[DEBUG] StoreApi.toggleFollowStore: HTTP статус = ${response.statusCode}');
      print('[DEBUG] StoreApi.toggleFollowStore: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        // Предполагаем, что сервер возвращает статус подписки
        final isFollowing = response.data['is_following'] ?? response.data['following'] ?? true;
        print('[DEBUG] StoreApi.toggleFollowStore: Статус подписки: $isFollowing');
        return Ok(isFollowing);
      }
      
      return Err('Не удалось изменить подписку: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] StoreApi.toggleFollowStore: DioException: ${e.message}');
      return Err('Ошибка изменения подписки: ${e.message}');
    } catch (e) {
      print('[DEBUG] StoreApi.toggleFollowStore: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Получить список любимых магазинов
  Future<Result<List<Store>>> getFavoriteStores({int page = 1}) async {
    try {
      print('[DEBUG] StoreApi.getFavoriteStores: Получаем список любимых магазинов, страница $page');
      
      final response = await _apiClient.get('/user/store/following-list', queryParameters: {
        'time_zone': 'Asia/Tashkent',
        'order_by': 'created_at',
        'type': 'desc',
        'page': page.toString(),
      });
      
      print('[DEBUG] StoreApi.getFavoriteStores: HTTP статус = ${response.statusCode}');
      print('[DEBUG] StoreApi.getFavoriteStores: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        print('[DEBUG] StoreApi.getFavoriteStores: Тип ответа: ${response.data.runtimeType}');
        
        List<dynamic> data;
        
        // Проверяем тип ответа и извлекаем данные
        List<dynamic> rawStoresData = [];
        if (response.data is Map<String, dynamic> && response.data.containsKey('data')) {
          final outerData = response.data['data'] as Map<String, dynamic>;
          if (outerData.containsKey('data') && outerData['data'] is List) {
            rawStoresData = outerData['data'] as List<dynamic>;
          }
        }

        print('[DEBUG] StoreApi.getFavoriteStores: Найдено сырых записей: ${rawStoresData.length}');

        if (rawStoresData.isEmpty) {
          print('[DEBUG] StoreApi.getFavoriteStores: Список любимых магазинов пуст');
          return const Ok([]);
        }

        final stores = rawStoresData.map((itemJson) {
          if (itemJson is Map<String, dynamic> && itemJson.containsKey('store')) {
            // Извлекаем вложенный объект 'store' и создаем копию
            final storeJson = Map<String, dynamic>.from(itemJson['store'] as Map);
            // Поскольку это из списка подписок, мы знаем что пользователь подписан
            storeJson['is_following'] = true;
            return Store.fromJson(storeJson);
          }
          print('[WARNING] StoreApi.getFavoriteStores: Неожиданный формат элемента в списке любимых магазинов: $itemJson');
          return null; // Возвращаем null для некорректных элементов
        }).whereType<Store>().toList(); // Фильтруем null значения

        final enrichedStores = <Store>[];
        for (final store in stores) {
          if (store.slug.isNotEmpty) {
            final details = await getStoreBySlug(store.slug);
            details.when(
              ok: (fullStore) => enrichedStores.add(
                fullStore.copyWith(isFollowing: true),
              ),
              err: (_) => enrichedStores.add(store),
            );
          } else {
            enrichedStores.add(store);
          }
        }
        
        print('[DEBUG] StoreApi.getFavoriteStores: Успешно создано ${enrichedStores.length} магазинов');
        return Ok(enrichedStores);
      }
      
      return Err('Не удалось получить список магазинов: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] StoreApi.getFavoriteStores: DioException: ${e.message}');
      return Err('Ошибка получения магазинов: ${e.message}');
    } catch (e) {
      print('[DEBUG] StoreApi.getFavoriteStores: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Получить детальную информацию о магазине
  Future<Result<Store>> getStoreDetails(int storeId) async {
    try {
      print('[DEBUG] StoreApi.getStoreDetails: Получаем детали магазина $storeId');
      
      final response = await _apiClient.get('/store/$storeId');
      
      print('[DEBUG] StoreApi.getStoreDetails: HTTP статус = ${response.statusCode}');
      print('[DEBUG] StoreApi.getStoreDetails: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        final store = Store.fromJson(response.data);
        print('[DEBUG] StoreApi.getStoreDetails: Детали магазина загружены: ${store.name}');
        return Ok(store);
      }
      
      return Err('Не удалось получить детали магазина: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] StoreApi.getStoreDetails: DioException: ${e.message}');
      return Err('Ошибка получения деталей магазина: ${e.message}');
    } catch (e) {
      print('[DEBUG] StoreApi.getStoreDetails: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Получить товары магазина
  Future<Result<List<dynamic>>> getStoreProducts(String slug, {int page = 1, String sortBy = ''}) async {
    try {
      print('[DEBUG] StoreApi.getStoreProducts: Получаем товары магазина $slug, страница $page');
      
      // Используем тот же endpoint, что и getStoreBySlug, но получаем только товары
      final response = await _apiClient.get('/store', queryParameters: {
        'slug': slug,
        'page': page.toString(),
        'sortby': sortBy,
        'required_rating': 'true',
      });
      
      print('[DEBUG] StoreApi.getStoreProducts: HTTP статус = ${response.statusCode}');
      print('[DEBUG] StoreApi.getStoreProducts: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        List<dynamic> products = [];
        
        if (response.data is Map) {
          final data = response.data as Map;
          // Извлекаем товары из структуры data.data.result.data
          if (data.containsKey('data') && data['data'] is Map) {
            final innerData = data['data'] as Map;
            if (innerData.containsKey('result') && innerData['result'] is Map) {
              final result = innerData['result'] as Map;
              if (result.containsKey('data') && result['data'] is List) {
                products = result['data'] as List<dynamic>;
                print('[DEBUG] StoreApi.getStoreProducts: Найдено товаров в data.data.result.data: ${products.length}');
              }
            }
          }
        } else if (response.data is List) {
          products = response.data as List<dynamic>;
          print('[DEBUG] StoreApi.getStoreProducts: Найдено товаров в корне (List): ${products.length}');
        }
        
        print('[DEBUG] StoreApi.getStoreProducts: Всего найдено товаров: ${products.length}');
        return Ok(products);
      }
      
      return Err('Не удалось получить товары магазина: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] StoreApi.getStoreProducts: DioException: ${e.message}');
      return Err('Ошибка получения товаров: ${e.message}');
    } catch (e) {
      print('[DEBUG] StoreApi.getStoreProducts: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }
}
