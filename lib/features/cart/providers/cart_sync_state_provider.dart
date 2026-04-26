// lib/features/cart/providers/cart_sync_state_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Состояние синхронизации корзины
enum CartSyncState {
  idle,      // Не синхронизируется
  syncing,    // Синхронизируется
  success,    // Успешно синхронизировано
  error,      // Ошибка синхронизации
}

// Провайдер для отслеживания состояния синхронизации
final cartSyncStateProvider = StateProvider<CartSyncState>((ref) => CartSyncState.idle);

// Провайдер для последнего сообщения об ошибке синхронизации
final cartSyncErrorProvider = StateProvider<String?>((ref) => null);
