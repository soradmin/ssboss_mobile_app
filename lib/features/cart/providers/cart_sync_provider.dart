// lib/features/cart/providers/cart_sync_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/cart_controller.dart';

// Провайдер для автоматической синхронизации корзины при запуске
final cartSyncProvider = FutureProvider<void>((ref) async {
  final cartController = ref.read(cartProvider.notifier);
  
  // Синхронизируем корзину с сервером при запуске приложения
  await cartController.syncWithServer();
  
  print('[DEBUG] Автоматическая синхронизация корзины завершена');
});
