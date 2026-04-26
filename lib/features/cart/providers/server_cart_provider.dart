// lib/features/cart/providers/server_cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repo/cart_api.dart';
import '../models/server_cart_line.dart';
import '../../../core/result.dart';

// Асинхронный провайдер, который загружает корзину с сервера
final serverCartProvider = FutureProvider<List<ServerCartLine>>((ref) async {
  // Создаем экземпляр CartApi и вызываем метод getCart()
  final cartApi = CartApi();
  final result = await cartApi.getCart(); 
  if (result is Ok<List<ServerCartLine>>) {
    return result.value;
  } else {
    // Можно выбросить исключение или вернуть пустой список
    print('Ошибка загрузки серверной корзины: ${(result as Err).message}');
    return []; // или throw Exception('Не удалось загрузить корзину');
  }
});