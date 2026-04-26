import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../catalog/models/product.dart';

final compareApiProvider = Provider<CompareApi>((ref) {
  return CompareApi(dio);
});

class CompareApi {
  final Dio _apiClient;

  CompareApi(this._apiClient);

  /// Получить список товаров для сравнения
  Future<Result<List<Product>>> getCompareProducts({int page = 1}) async {
    try {
      print('[DEBUG] CompareApi.getCompareProducts: Получаем список товаров для сравнения, страница $page');
      
      final response = await _apiClient.get('/user/compare-list/all', queryParameters: {
        'time_zone': 'Asia/Tashkent',
        'order_by': 'created_at',
        'type': 'desc',
        'page': page.toString(),
      });
      
      print('[DEBUG] CompareApi.getCompareProducts: HTTP статус = ${response.statusCode}');
      print('[DEBUG] CompareApi.getCompareProducts: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        print('[DEBUG] CompareApi.getCompareProducts: Тип ответа: ${response.data.runtimeType}');
        
        List<dynamic> data;
        
        // Проверяем тип ответа и извлекаем данные
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          print('[DEBUG] CompareApi.getCompareProducts: Ключи в response.data: ${responseMap.keys.toList()}');
          
          // Ищем массив товаров в различных возможных ключах
          if (responseMap.containsKey('data') && responseMap['data'] is Map) {
            final innerData = responseMap['data'] as Map<String, dynamic>;
            print('[DEBUG] CompareApi.getCompareProducts: Ключи в data: ${innerData.keys.toList()}');
            
            if (innerData.containsKey('data') && innerData['data'] is List) {
              data = innerData['data'] as List<dynamic>;
              print('[DEBUG] CompareApi.getCompareProducts: Найдено элементов в data.data: ${data.length}');
            } else {
              data = [];
            }
          } else if (responseMap.containsKey('data') && responseMap['data'] is List) {
            data = responseMap['data'] as List<dynamic>;
          } else if (responseMap.containsKey('products') && responseMap['products'] is List) {
            data = responseMap['products'] as List<dynamic>;
          } else if (responseMap.containsKey('items') && responseMap['items'] is List) {
            data = responseMap['items'] as List<dynamic>;
          } else {
            data = [];
          }
        } else {
          data = [];
        }
        
        print('[DEBUG] CompareApi.getCompareProducts: Найдено товаров: ${data.length}');
        
        if (data.isEmpty) {
          print('[DEBUG] CompareApi.getCompareProducts: Список товаров для сравнения пуст');
          return const Ok([]);
        }
        
        final products = data.map((json) {
          // Извлекаем вложенный объект 'product'
          if (json.containsKey('product') && json['product'] is Map<String, dynamic>) {
            final productData = json['product'] as Map<String, dynamic>;
            print('[DEBUG] CompareApi.getCompareProducts: Обрабатываем товар: ${productData['title'] ?? productData['id']}');
            return Product.fromJson(productData);
          }
          print('[DEBUG] CompareApi.getCompareProducts: Элемент списка не содержит объекта "product": $json');
          return null;
        }).whereType<Product>().toList(); // Фильтруем null значения
        
        print('[DEBUG] CompareApi.getCompareProducts: Успешно создано ${products.length} товаров');
        return Ok(products);
      }
      
      return Err('Не удалось получить список товаров для сравнения: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CompareApi.getCompareProducts: DioException: ${e.message}');
      return Err('Ошибка получения товаров для сравнения: ${e.message}');
    } catch (e) {
      print('[DEBUG] CompareApi.getCompareProducts: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Добавить товар в сравнение
  Future<Result<bool>> addToCompare(int productId) async {
    try {
      print('[DEBUG] CompareApi.addToCompare: Добавляем товар $productId в сравнение');
      
      final response = await _apiClient.post('/user/compare-list/action', data: {
        'product_id': productId,
        'action': 'add',
      });
      
      print('[DEBUG] CompareApi.addToCompare: HTTP статус = ${response.statusCode}');
      print('[DEBUG] CompareApi.addToCompare: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        final success = response.data['success'] ?? response.data['status'] == 'success' ?? true;
        print('[DEBUG] CompareApi.addToCompare: Товар добавлен в сравнение: $success');
        return Ok(success);
      }
      
      return Err('Не удалось добавить товар в сравнение: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CompareApi.addToCompare: DioException: ${e.message}');
      return Err('Ошибка добавления товара в сравнение: ${e.message}');
    } catch (e) {
      print('[DEBUG] CompareApi.addToCompare: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Удалить товар из сравнения
  Future<Result<bool>> removeFromCompare(int productId) async {
    try {
      print('[DEBUG] CompareApi.removeFromCompare: Удаляем товар $productId из сравнения');
      
      final response = await _apiClient.post('/user/compare-list/action', data: {
        'product_id': productId,
        'action': 'remove',
      });
      
      print('[DEBUG] CompareApi.removeFromCompare: HTTP статус = ${response.statusCode}');
      print('[DEBUG] CompareApi.removeFromCompare: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        final success = response.data['success'] ?? response.data['status'] == 'success' ?? true;
        print('[DEBUG] CompareApi.removeFromCompare: Товар удален из сравнения: $success');
        return Ok(success);
      }
      
      return Err('Не удалось удалить товар из сравнения: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CompareApi.removeFromCompare: DioException: ${e.message}');
      return Err('Ошибка удаления товара из сравнения: ${e.message}');
    } catch (e) {
      print('[DEBUG] CompareApi.removeFromCompare: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Переключить статус сравнения для товара
  Future<Result<bool>> toggleCompare(int productId) async {
    try {
      print('[DEBUG] CompareApi.toggleCompare: Переключаем статус сравнения для товара $productId');
      
      final response = await _apiClient.post('/user/compare-list/action', data: {
        'product_id': productId,
        'action': 'toggle',
      });
      
      print('[DEBUG] CompareApi.toggleCompare: HTTP статус = ${response.statusCode}');
      print('[DEBUG] CompareApi.toggleCompare: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        // Предполагаем, что сервер возвращает статус сравнения
        final isCompared = response.data['is_compared'] ?? response.data['compared'] ?? true;
        print('[DEBUG] CompareApi.toggleCompare: Статус сравнения: $isCompared');
        return Ok(isCompared);
      }
      
      return Err('Не удалось изменить статус сравнения: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] CompareApi.toggleCompare: DioException: ${e.message}');
      return Err('Ошибка изменения статуса сравнения: ${e.message}');
    } catch (e) {
      print('[DEBUG] CompareApi.toggleCompare: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }
}
