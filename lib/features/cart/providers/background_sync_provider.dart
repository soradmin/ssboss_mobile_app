import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../controllers/cart_controller.dart';
import '../../auth/providers/auth_provider.dart';

/// Провайдер для фоновой синхронизации корзины
class BackgroundSyncNotifier extends StateNotifier<bool> {
  final Ref _ref;
  bool _isSyncing = false;

  BackgroundSyncNotifier(this._ref) : super(false);

  /// Запуск фоновой синхронизации
  Future<void> startBackgroundSync() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    state = true;
    
    try {
      print('[DEBUG] BackgroundSync: Запуск фоновой синхронизации корзины');
      
      // Проверяем, что пользователь авторизован
      final user = _ref.read(authProvider);
      if (!user.isAuthenticated) {
        print('[DEBUG] BackgroundSync: Пользователь не авторизован, пропускаем синхронизацию');
        return;
      }
      
      // Синхронизируем корзину
      await _ref.read(cartProvider.notifier).syncWithServer();
      print('[DEBUG] BackgroundSync: Фоновая синхронизация завершена');
      
    } catch (e) {
      print('[DEBUG] BackgroundSync: Ошибка фоновой синхронизации: $e');
    } finally {
      _isSyncing = false;
      state = false;
    }
  }

  /// Синхронизация при возвращении в приложение
  Future<void> syncOnAppResume() async {
    print('[DEBUG] BackgroundSync: Синхронизация при возвращении в приложение');
    await startBackgroundSync();
  }

  /// Периодическая синхронизация (каждые 30 секунд)
  Future<void> startPeriodicSync() async {
    print('[DEBUG] BackgroundSync: Запуск периодической синхронизации');
    
    // Синхронизируем сразу
    await startBackgroundSync();
    
    // Затем каждые 30 секунд
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final user = _ref.read(authProvider);
      if (!user.isAuthenticated) {
        timer.cancel();
        return;
      }
      
      await startBackgroundSync();
    });
  }
}

final backgroundSyncProvider = StateNotifierProvider<BackgroundSyncNotifier, bool>((ref) {
  return BackgroundSyncNotifier(ref);
});

/// Провайдер для автоматической синхронизации при изменении состояния авторизации
final autoSyncProvider = Provider<void>((ref) {
  final user = ref.watch(authProvider);
  final backgroundSync = ref.read(backgroundSyncProvider.notifier);
  
  // Если пользователь авторизован, запускаем синхронизацию
  if (user.isAuthenticated) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backgroundSync.startBackgroundSync();
    });
  }
});
