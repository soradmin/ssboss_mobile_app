// lib/features/cart/controllers/cart_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_item.dart';
import '../models/server_cart_line.dart';
import '../repo/cart_api.dart';
import '../../catalog/models/product.dart';
import '../../catalog/models/media.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';

// Провайдер для локальной корзины
final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController();
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super([]) {
    _loadCart();
  }

  // Загружаем корзину из SharedPreferences
  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('local_cart');
      if (cartJson != null) {
        final List<dynamic> cartList = json.decode(cartJson);
        final items = cartList.map((json) => CartItem.fromJson(json)).toList();
        state = items;
      }
    } catch (e) {
      print('Ошибка загрузки корзины: $e');
    }
  }

  // Сохраняем корзину в SharedPreferences
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(state.map((item) => item.toJson()).toList());
      await prefs.setString('local_cart', cartJson);
    } catch (e) {
      print('Ошибка сохранения корзины: $e');
    }
  }

  // Добавляем товар в корзину
  void addToCart(Product product, int quantity, {Map<int, int>? selectedAttributes}) {
    // Проверяем, есть ли товар с такими же атрибутами
    final existingIndex = state.indexWhere((item) {
      if (item.product.id != product.id) return false;
      // Сравниваем атрибуты
      final itemAttrs = item.selectedAttributes;
      final newAttrs = selectedAttributes ?? {};
      if (itemAttrs.length != newAttrs.length) return false;
      for (final key in itemAttrs.keys) {
        if (itemAttrs[key] != newAttrs[key]) return false;
      }
      return true;
    });
    
    if (existingIndex != -1) {
      // Товар уже есть с такими же атрибутами, увеличиваем количество
      final updatedItems = List<CartItem>.from(state);
      updatedItems[existingIndex] = CartItem(
        product: product,
        qty: updatedItems[existingIndex].qty + quantity,
        selectedAttributes: updatedItems[existingIndex].selectedAttributes,
      );
      state = updatedItems;
    } else {
      // Новый товар или товар с другими атрибутами
      state = [
        ...state,
        CartItem(
          product: product,
          qty: quantity,
          selectedAttributes: selectedAttributes ?? {},
        ),
      ];
    }
    
    _saveCart();
  }

  // Генерируем уникальный ключ для товара с учетом атрибутов
  String _getItemKey(CartItem item) {
    final attrsStr = item.selectedAttributes.entries
        .map((e) => '${e.key}:${e.value}')
        .toList()
        ..sort();
    return '${item.product.id}_${attrsStr.join('_')}';
  }

  // Удаляем товар из корзины (по уникальному ключу)
  void removeFromCart(int productId, {Map<int, int>? selectedAttributes}) {
    if (selectedAttributes != null) {
      // Удаляем конкретный товар с указанными атрибутами
      state = state.where((item) {
        if (item.product.id != productId) return true;
        // Сравниваем атрибуты
        final itemAttrs = item.selectedAttributes;
        final targetAttrs = selectedAttributes;
        if (itemAttrs.length != targetAttrs.length) return true;
        for (final key in itemAttrs.keys) {
          if (itemAttrs[key] != targetAttrs[key]) return true;
        }
        return false; // Найден товар с такими же атрибутами - удаляем
      }).toList();
    } else {
      // Удаляем все товары с таким productId (для обратной совместимости)
      state = state.where((item) => item.product.id != productId).toList();
    }
    _saveCart();
  }

  // Обновляем количество товара (с учетом атрибутов)
  void updateQuantity(int productId, int newQuantity, {Map<int, int>? selectedAttributes}) {
    if (newQuantity <= 0) {
      removeFromCart(productId, selectedAttributes: selectedAttributes);
      return;
    }
    
    final updatedItems = state.map((item) {
      if (item.product.id == productId) {
        // Если указаны атрибуты, обновляем только товар с такими же атрибутами
        if (selectedAttributes != null) {
          final itemAttrs = item.selectedAttributes;
          final targetAttrs = selectedAttributes;
          if (itemAttrs.length == targetAttrs.length) {
            bool matches = true;
            for (final key in itemAttrs.keys) {
              if (itemAttrs[key] != targetAttrs[key]) {
                matches = false;
                break;
              }
            }
            if (matches) {
              return CartItem(
                product: item.product,
                qty: newQuantity,
                selectedAttributes: item.selectedAttributes,
              );
            }
          }
        } else {
          // Если атрибуты не указаны, обновляем первый найденный (для обратной совместимости)
          return CartItem(
            product: item.product,
            qty: newQuantity,
            selectedAttributes: item.selectedAttributes,
          );
        }
      }
      return item;
    }).toList();
    
    state = updatedItems;
    _saveCart();
  }

  // Очищаем корзину
  void clearCart() {
    state = [];
    _saveCart();
  }

  // Вычисляем общую сумму
  double get total {
    return state.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  // Получаем количество товаров
  int get itemCount {
    return state.fold(0, (sum, item) => sum + item.qty);
  }

  // Синхронизация с серверной корзиной
  Future<void> syncWithServer() async {
    try {
      final cartApi = CartApi();
      final serverResult = await cartApi.getCart();
      
      if (serverResult is Ok<List<ServerCartLine>>) {
        final serverItems = serverResult.value;
        print('[DEBUG] Получено с сервера: ${serverItems.length} товаров');
        
        // Если серверная корзина пуста, очищаем локальную корзину
        if (serverItems.isEmpty) {
          print('[DEBUG] Серверная корзина пуста, очищаем локальную корзину');
          state = [];
          await _saveCart();
          print('[DEBUG] Локальная корзина очищена');
          return;
        }
        
        // Конвертируем серверные элементы в локальные
        final serverCartItems = <CartItem>[];
        for (final serverItem in serverItems) {
          if (serverItem.productId > 0 && serverItem.quantity > 0) {
            print('[DEBUG] syncWithServer: Обрабатываем товар ${serverItem.name}');
            print('[DEBUG] syncWithServer: Исходное изображение с сервера: "${serverItem.image}"');
            print('[DEBUG] syncWithServer: inventory_id: ${serverItem.inventoryId}, атрибутов: ${serverItem.selectedAttributes.length}');
            
            final processedImage = serverItem.image.isNotEmpty ? AppConfig.imageUrl(serverItem.image) : '';
            print('[DEBUG] syncWithServer: Обработанное изображение: "$processedImage"');
            
            // Создаем Product из ServerCartLine
            final product = Product(
              id: serverItem.productId,
              name: serverItem.name.isNotEmpty ? serverItem.name : 'Товар #${serverItem.productId}',
              image: processedImage,
              price: serverItem.price > 0 ? serverItem.price : 0.0,
              images: serverItem.image.isNotEmpty 
                ? [ProductImage(image: processedImage, thumb: processedImage)]
                : [],
              rating: 0.0,
              reviewCount: 0,
            );
            print('[DEBUG] syncWithServer: Создан Product для ${product.name}, image: ${product.image}');
            print('[DEBUG] syncWithServer: Атрибуты товара: ${serverItem.selectedAttributes}');
            
            serverCartItems.add(CartItem(
              product: product,
              qty: serverItem.quantity,
              selectedAttributes: serverItem.selectedAttributes, // Используем атрибуты с сервера
            ));
          }
        }
        
        // Заменяем локальную корзину серверной (сервер - источник истины)
        final localCart = List<CartItem>.from(state);

        print('[DEBUG] Локальная корзина: ${localCart.length} товаров');
        print('[DEBUG] Серверная корзина: ${serverCartItems.length} товаров');

        // Используем только товары с сервера (удаляем товары, которых нет на сервере)
        for (final serverItem in serverCartItems) {
          print('[DEBUG] Добавлен товар с сервера: ${serverItem.product.name} (количество: ${serverItem.qty})');
        }
        
        // Полностью заменяем локальную корзину серверной
        state = serverCartItems;
        await _saveCart();
        print('[DEBUG] Корзина синхронизирована: ${serverCartItems.length} товаров с сервера (локальные товары, удаленные на сервере, были удалены)');
      } else {
        final errorMessage = (serverResult as Err).message;
        print('[DEBUG] Ошибка загрузки серверной корзины: $errorMessage');
      }
    } catch (e) {
      print('[DEBUG] Ошибка синхронизации корзины: $e');
    }
  }

  // Добавление товара с синхронизацией на сервер
  Future<void> addToCartWithSync(Product product, int quantity, {Map<int, int>? selectedAttributes}) async {
    // Сначала добавляем в локальную корзину
    addToCart(product, quantity, selectedAttributes: selectedAttributes);
    print('[DEBUG] Товар добавлен в локальную корзину: ${product.name} (количество: $quantity, атрибуты: $selectedAttributes)');
    
    // Затем синхронизируем с сервером
    try {
      final cartApi = CartApi();
      final result = await cartApi.add(product.id, quantity, selectedAttributes: selectedAttributes);
      
      if (result is Ok) {
        print('[DEBUG] Товар успешно добавлен в серверную корзину: ${product.name}');
      } else {
        print('[DEBUG] Ошибка добавления в серверную корзину: ${(result as Err).message}');
        // Можно показать уведомление пользователю о проблеме с синхронизацией
      }
    } catch (e) {
      print('[DEBUG] Ошибка синхронизации при добавлении товара: $e');
    }
  }

  // Обновление количества с синхронизацией на сервер
  Future<void> updateQuantityWithSync(int productId, int newQuantity, {Map<int, int>? selectedAttributes}) async {
    // Получаем текущее количество товара в локальной корзине (с учетом атрибутов)
    CartItem? currentItem;
    if (selectedAttributes != null) {
      currentItem = state.firstWhere(
        (item) {
          if (item.product.id != productId) return false;
          final itemAttrs = item.selectedAttributes;
          final targetAttrs = selectedAttributes;
          if (itemAttrs.length != targetAttrs.length) return false;
          for (final key in itemAttrs.keys) {
            if (itemAttrs[key] != targetAttrs[key]) return false;
          }
          return true;
        },
        orElse: () => CartItem(
          product: Product(
            id: -1,
            name: '',
            image: '',
            price: 0,
            images: [],
            rating: 0,
            reviewCount: 0,
          ),
          qty: 0,
          selectedAttributes: const {},
        ),
      );
    } else {
      currentItem = state.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => CartItem(
          product: Product(
            id: -1,
            name: '',
            image: '',
            price: 0,
            images: [],
            rating: 0,
            reviewCount: 0,
          ),
          qty: 0,
          selectedAttributes: const {},
        ),
      );
    }
    final currentQuantity = currentItem.product.id != -1 ? currentItem.qty : 0;
    
    // Вычисляем изменение количества
    final quantityChange = newQuantity - currentQuantity;
    
    print('[DEBUG] updateQuantityWithSync: Товар $productId, текущее количество: $currentQuantity, новое: $newQuantity, изменение: $quantityChange');
    
    // Сначала обновляем локально
    updateQuantity(productId, newQuantity, selectedAttributes: selectedAttributes);
    
    // Если новое количество равно 0, удаляем товар полностью
    if (newQuantity == 0) {
      try {
        final cartApi = CartApi();
        
        // Сначала получаем корзину с сервера, чтобы найти ID элемента корзины
        final serverResult = await cartApi.getCart();
        
        if (serverResult is Ok<List<ServerCartLine>>) {
          final serverItems = serverResult.value;
          
          // Ищем товар с нужным productId и атрибутами
          ServerCartLine? serverItem;
          if (selectedAttributes != null && selectedAttributes.isNotEmpty) {
            serverItem = serverItems.firstWhere(
              (item) {
                if (item.productId != productId) return false;
                // Сравниваем атрибуты
                final itemAttrs = item.selectedAttributes;
                final targetAttrs = selectedAttributes;
                if (itemAttrs.length != targetAttrs.length) return false;
                for (final key in itemAttrs.keys) {
                  if (itemAttrs[key] != targetAttrs[key]) return false;
                }
                return true;
              },
              orElse: () => ServerCartLine(id: 0, productId: 0, inventoryId: 0, quantity: 0),
            );
          } else {
            serverItem = serverItems.firstWhere(
              (item) => item.productId == productId,
              orElse: () => ServerCartLine(id: 0, productId: 0, inventoryId: 0, quantity: 0),
            );
          }
          
          if (serverItem.id > 0) {
            // Удаляем товар по ID элемента корзины
            final result = await cartApi.remove(serverItem.id);
            if (result is Ok) {
              print('[DEBUG] Товар удален из серверной корзины по ID: ${serverItem.id}');
            } else {
              print('[DEBUG] Ошибка удаления товара из серверной корзины: ${(result as Err).message}');
            }
          } else {
            print('[DEBUG] Товар не найден в серверной корзине, пропускаем удаление');
          }
        } else {
          print('[DEBUG] Ошибка получения серверной корзины для удаления: ${(serverResult as Err).message}');
        }
      } catch (e) {
        print('[DEBUG] Ошибка синхронизации при удалении товара: $e');
      }
      return;
    }
    
    // Если есть изменение количества, отправляем только изменение на сервер
    if (quantityChange != 0) {
      try {
        final cartApi = CartApi();
        // Используем inventory_id из текущего товара, если он есть
        int? inventoryId;
        if (currentItem.product.id != -1 && selectedAttributes != null) {
          // Пытаемся найти inventory_id по атрибутам
          // Для этого нужно получить детали товара, но это может быть медленно
          // Вместо этого используем синхронизацию через add с правильными атрибутами
        }
        final result = await cartApi.add(
          productId, 
          quantityChange,
          selectedAttributes: selectedAttributes,
        );
        if (result is Ok) {
          print('[DEBUG] Количество товара обновлено на сервере: $productId (изменение: $quantityChange)');
        } else {
          print('[DEBUG] Ошибка обновления количества в серверной корзине: ${(result as Err).message}');
        }
      } catch (e) {
        print('[DEBUG] Ошибка синхронизации при обновлении количества товара: $e');
      }
    }
  }

  // Удаление товара с синхронизацией на сервер
  Future<void> removeFromCartWithSync(int productId, {Map<int, int>? selectedAttributes}) async {
    print('[DEBUG] removeFromCartWithSync: Удаляем товар $productId с атрибутами: $selectedAttributes');
    
    // Сначала удаляем локально
    removeFromCart(productId, selectedAttributes: selectedAttributes);
    
    // Затем пытаемся удалить с сервера
    try {
      final cartApi = CartApi();
      
      // Сначала получаем корзину с сервера, чтобы найти ID элемента корзины
      final serverResult = await cartApi.getCart();
      
      if (serverResult is Ok<List<ServerCartLine>>) {
        final serverItems = serverResult.value;
        
        // Ищем товар с нужным productId и атрибутами
        ServerCartLine? serverItem;
        if (selectedAttributes != null && selectedAttributes.isNotEmpty) {
          serverItem = serverItems.firstWhere(
            (item) {
              if (item.productId != productId) return false;
              // Сравниваем атрибуты
              final itemAttrs = item.selectedAttributes;
              final targetAttrs = selectedAttributes;
              if (itemAttrs.length != targetAttrs.length) return false;
              for (final key in itemAttrs.keys) {
                if (itemAttrs[key] != targetAttrs[key]) return false;
              }
              return true;
            },
            orElse: () => ServerCartLine(id: 0, productId: 0, inventoryId: 0, quantity: 0),
          );
        } else {
          serverItem = serverItems.firstWhere(
            (item) => item.productId == productId,
            orElse: () => ServerCartLine(id: 0, productId: 0, inventoryId: 0, quantity: 0),
          );
        }
        
        if (serverItem.id > 0) {
          // Удаляем товар по ID элемента корзины
          final result = await cartApi.remove(serverItem.id);
          if (result is Ok) {
            print('[DEBUG] Товар удален из серверной корзины по ID: ${serverItem.id}');
          } else {
            print('[DEBUG] Ошибка удаления из серверной корзины: ${(result as Err).message}');
          }
        } else {
          print('[DEBUG] Товар не найден в серверной корзине, пропускаем удаление');
        }
      } else {
        print('[DEBUG] Ошибка получения серверной корзины для удаления: ${(serverResult as Err).message}');
      }
    } catch (e) {
      print('[DEBUG] Ошибка синхронизации при удалении товара: $e');
    }
  }

  // Отправка локальной корзины на сервер
  Future<void> _syncLocalCartToServer() async {
    try {
      final cartApi = CartApi();
      print('[DEBUG] Отправляем ${state.length} товаров на сервер');
      
      for (final item in state) {
        final result = await cartApi.add(item.product.id, item.qty);
        if (result is Ok) {
          print('[DEBUG] Товар отправлен на сервер: ${item.product.name} (количество: ${item.qty})');
        } else {
          print('[DEBUG] Ошибка отправки товара на сервер: ${(result as Err).message}');
        }
      }
      
      print('[DEBUG] Локальная корзина отправлена на сервер');
    } catch (e) {
      print('[DEBUG] Ошибка отправки локальной корзины на сервер: $e');
    }
  }
}