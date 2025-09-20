// lib/features/cart/providers/server_cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repo/cart_api.dart';
import '../../../core/result.dart'; // <-- Импортируем Result, Ok, Err

// Асинхронный провайдер, который загружает корзину с сервера
final serverCartProvider = FutureProvider<List<ServerCartLine>>((ref) async {
  // Используем СТАТИЧЕСКИЙ метод CartApi.getCart()
  final result = await CartApi.getCart(); 
  if (result is Ok<List<ServerCartLine>>) {
    return result.value;
  } else {
    // Можно выбросить исключение или вернуть пустой список
    print('Ошибка загрузки серверной корзины: ${(result as Err).message}'); // <-- Теперь Ok и Err найдены
    return []; // или throw Exception('Не удалось загрузить корзину');
  }
});