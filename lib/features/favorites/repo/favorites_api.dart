import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../catalog/models/product.dart';

final favoritesApiProvider = Provider<FavoritesApi>((ref) {
  return FavoritesApi(dio);
});

class FavoritesApi {
  final Dio _apiClient;

  FavoritesApi(this._apiClient);

  /// Получить список избранных товаров
  Future<Result<List<Product>>> getFavoriteProducts({int page = 1}) async {
    try {
      print('[DEBUG] FavoritesApi.getFavoriteProducts: Получаем список избранных товаров, страница $page');
      
      final response = await _apiClient.get('/user/wishlist/all', queryParameters: {
        'time_zone': 'Asia/Tashkent',
        'order_by': 'created_at',
        'type': 'desc',
        'page': page.toString(),
      });
      
      print('[DEBUG] FavoritesApi.getFavoriteProducts: HTTP статус = ${response.statusCode}');
      print('[DEBUG] FavoritesApi.getFavoriteProducts: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        print('[DEBUG] FavoritesApi.getFavoriteProducts: Тип ответа: ${response.data.runtimeType}');
        
        List<dynamic> data;
        
        // Проверяем тип ответа и извлекаем данные
        if (response.data is List) {
          data = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          print('[DEBUG] FavoritesApi.getFavoriteProducts: Ключи в response.data: ${responseMap.keys.toList()}');
          
          // Ищем массив товаров в различных возможных ключах
          if (responseMap.containsKey('data') && responseMap['data'] is Map) {
            final innerData = responseMap['data'] as Map<String, dynamic>;
            print('[DEBUG] FavoritesApi.getFavoriteProducts: Ключи в data: ${innerData.keys.toList()}');
            
            if (innerData.containsKey('data') && innerData['data'] is List) {
              data = innerData['data'] as List<dynamic>;
              print('[DEBUG] FavoritesApi.getFavoriteProducts: Найдено элементов в data.data: ${data.length}');
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
        
        print('[DEBUG] FavoritesApi.getFavoriteProducts: Найдено товаров: ${data.length}');
        
        if (data.isEmpty) {
          print('[DEBUG] FavoritesApi.getFavoriteProducts: Список избранных товаров пуст');
          return const Ok([]);
        }
        
        final products = data.map((json) {
          // Извлекаем вложенный объект 'product'
          if (json.containsKey('product') && json['product'] is Map<String, dynamic>) {
            final productData = json['product'] as Map<String, dynamic>;
            print('[DEBUG] FavoritesApi.getFavoriteProducts: Обрабатываем товар: ${productData['title'] ?? productData['id']}');
            return Product.fromJson(productData);
          }
          print('[DEBUG] FavoritesApi.getFavoriteProducts: Элемент списка не содержит объекта "product": $json');
          return null;
        }).whereType<Product>().toList(); // Фильтруем null значения
        
        print('[DEBUG] FavoritesApi.getFavoriteProducts: Успешно создано ${products.length} товаров');
        return Ok(products);
      }
      
      return Err('Не удалось получить список избранных товаров: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] FavoritesApi.getFavoriteProducts: DioException: ${e.message}');
      // Проверяем статус код 401 (Unauthorized)
      if (e.response?.statusCode == 401) {
        return Err('UNAUTHORIZED'); // Специальный маркер для неавторизованного пользователя
      }
      return Err('Ошибка получения избранных товаров: ${e.message}');
    } catch (e) {
      print('[DEBUG] FavoritesApi.getFavoriteProducts: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Добавить товар в избранное
  Future<Result<bool>> addToFavorites(int productId) async {
    try {
      print('[DEBUG] FavoritesApi.addToFavorites: Добавляем товар $productId в избранное');
      
      final response = await _apiClient.post('/user/wishlist/action', data: {
        'product_id': productId,
        'action': 'add',
      });
      
      print('[DEBUG] FavoritesApi.addToFavorites: HTTP статус = ${response.statusCode}');
      print('[DEBUG] FavoritesApi.addToFavorites: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] FavoritesApi.addToFavorites: Товар успешно добавлен в избранное');
        return const Ok(true);
      }
      
      return Err('Не удалось добавить товар в избранное: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] FavoritesApi.addToFavorites: DioException: ${e.message}');
      return Err('Ошибка добавления в избранное: ${e.message}');
    } catch (e) {
      print('[DEBUG] FavoritesApi.addToFavorites: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Удалить товар из избранного
  Future<Result<bool>> removeFromFavorites(int productId) async {
    try {
      print('[DEBUG] FavoritesApi.removeFromFavorites: Удаляем товар $productId из избранного');
      
      final response = await _apiClient.post('/user/wishlist/action', data: {
        'product_id': productId,
        'action': 'remove',
      });
      
      print('[DEBUG] FavoritesApi.removeFromFavorites: HTTP статус = ${response.statusCode}');
      print('[DEBUG] FavoritesApi.removeFromFavorites: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] FavoritesApi.removeFromFavorites: Товар успешно удален из избранного');
        return const Ok(true);
      }
      
      return Err('Не удалось удалить товар из избранного: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] FavoritesApi.removeFromFavorites: DioException: ${e.message}');
      return Err('Ошибка удаления из избранного: ${e.message}');
    } catch (e) {
      print('[DEBUG] FavoritesApi.removeFromFavorites: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Переключить статус избранного для товара
  Future<Result<bool>> toggleFavorite(int productId) async {
    try {
      print('[DEBUG] FavoritesApi.toggleFavorite: Переключаем статус избранного для товара $productId');
      
      final response = await _apiClient.post('/user/wishlist/action', data: {
        'product_id': productId,
        'action': 'toggle',
      });
      
      print('[DEBUG] FavoritesApi.toggleFavorite: HTTP статус = ${response.statusCode}');
      print('[DEBUG] FavoritesApi.toggleFavorite: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        // Предполагаем, что сервер возвращает статус избранного
        final isFavorite = response.data['is_favorite'] ?? response.data['favorite'] ?? true;
        print('[DEBUG] FavoritesApi.toggleFavorite: Статус избранного: $isFavorite');
        return Ok(isFavorite);
      }
      
      return Err('Не удалось изменить статус избранного: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] FavoritesApi.toggleFavorite: DioException: ${e.message}');
      return Err('Ошибка изменения статуса избранного: ${e.message}');
    } catch (e) {
      print('[DEBUG] FavoritesApi.toggleFavorite: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }
}
