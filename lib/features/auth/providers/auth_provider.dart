import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../../../core/config.dart';
import '../../../core/result.dart';
import '../repo/auth_api.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../notifications/services/notification_service.dart';

class AuthNotifier extends StateNotifier<User> {
  final Ref _ref;
  
  AuthNotifier(this._ref) : super(User.guest()) {
    print('[DEBUG] AuthProvider: Инициализация AuthProvider');
    // Проверяем статус авторизации при инициализации
    _checkAuthStatus();
    // Также загружаем токен асинхронно для более точной проверки
    _checkAuthStatusAsync();
  }

  void _checkAuthStatus() {
    // Если есть мобильный или общий Bearer токен, считаем пользователя авторизованным
    // (пока не завершится асинхронная проверка)
    if (AppConfig.mobileBearer.isNotEmpty || AppConfig.bearer.isNotEmpty) {
      state = const User(
        id: 1,
        name: 'Пользователь',
        email: '',
        isAuthenticated: true,
      );
      print('[DEBUG] AuthProvider: Токен найден, пользователь временно авторизован (ожидается проверка)');
    } else {
      state = User.guest();
      print('[DEBUG] AuthProvider: Токены не найдены, пользователь не авторизован');
    }
  }

  Future<void> _checkAuthStatusAsync() async {
    // Сначала проверяем мобильный токен
    final mobileToken = await AppConfig.getMobileBearerToken();
    print('[DEBUG] AuthProvider: Загружен мобильный токен: ${mobileToken != null ? 'да' : 'нет'}');
    
    if (mobileToken != null && mobileToken.isNotEmpty) {
      print('[DEBUG] AuthProvider: Мобильный токен найден, проверяем валидность...');
      print('[DEBUG] AuthProvider: Мобильный токен длина: ${mobileToken.length}');
      print('[DEBUG] AuthProvider: Мобильный токен начало: ${mobileToken.length > 20 ? mobileToken.substring(0, 20) : mobileToken}...');
      
      // Обновляем AppConfig.mobileBearer для синхронизации
      AppConfig.mobileBearer = mobileToken;
      
      // Проверяем валидность мобильного токена через API
      try {
        final validationResult = await AuthApi.validateMobileToken();
        if (validationResult is Ok<bool> && validationResult.value) {
          // Получаем реальные данные пользователя
          final profileResult = await AuthApi.getProfile();
          if (profileResult is Ok<Map<String, dynamic>>) {
            final userData = profileResult.value;
            state = User(
              id: userData['id'] ?? 1,
              name: userData['name'] ?? 'Пользователь',
              email: userData['email'] ?? '',
              isAuthenticated: true,
            );
            print('[DEBUG] AuthProvider: Пользователь авторизован через мобильный токен: ${userData['name']}');
            _syncCartOnAuth();
            _syncFcmTokenOnAuth();
          } else {
            // Fallback если не удалось получить профиль
            state = const User(
              id: 1,
              name: 'Пользователь',
              email: '',
              isAuthenticated: true,
            );
            print('[DEBUG] AuthProvider: Пользователь авторизован через мобильный токен (fallback)');
            _syncCartOnAuth();
            _syncFcmTokenOnAuth();
          }
        } else {
          print('[DEBUG] AuthProvider: Мобильный токен недействителен');
          AppConfig.mobileBearer = '';
          state = User.guest();
        }
      } catch (e) {
        print('[DEBUG] AuthProvider: Ошибка проверки мобильного токена: $e');
        AppConfig.mobileBearer = '';
        state = User.guest();
      }
    } else {
      // Если мобильного токена нет, проверяем общий токен (для совместимости)
      final token = await AppConfig.getBearerToken();
      print('[DEBUG] AuthProvider: Загружен общий токен: ${token != null ? 'да' : 'нет'}');
      
      if (token != null && token.isNotEmpty) {
        print('[DEBUG] AuthProvider: Общий токен найден, проверяем валидность...');
        AppConfig.bearer = token;
        
        try {
          final validationResult = await AuthApi.validateToken();
          if (validationResult is Ok<bool> && validationResult.value) {
            // Получаем реальные данные пользователя
            final profileResult = await AuthApi.getProfile();
            if (profileResult is Ok<Map<String, dynamic>>) {
              final userData = profileResult.value;
              state = User(
                id: userData['id'] ?? 1,
                name: userData['name'] ?? 'Пользователь',
                email: userData['email'] ?? '',
                isAuthenticated: true,
              );
              print('[DEBUG] AuthProvider: Пользователь авторизован через общий токен: ${userData['name']}');
              _syncCartOnAuth();
              _syncFcmTokenOnAuth();
            } else {
              // Fallback если не удалось получить профиль
              state = const User(
                id: 1,
                name: 'Пользователь',
                email: '',
                isAuthenticated: true,
              );
              print('[DEBUG] AuthProvider: Пользователь авторизован через общий токен (fallback)');
              _syncCartOnAuth();
              _syncFcmTokenOnAuth();
            }
          } else {
            print('[DEBUG] AuthProvider: Общий токен недействителен');
            AppConfig.bearer = '';
            state = User.guest();
          }
        } catch (e) {
          print('[DEBUG] AuthProvider: Ошибка проверки общего токена: $e');
          AppConfig.bearer = '';
          state = User.guest();
        }
      } else {
        print('[DEBUG] AuthProvider: Токены не найдены, пользователь не авторизован');
        AppConfig.bearer = '';
        AppConfig.mobileBearer = '';
        state = User.guest();
      }
    }
  }

  void login(User user) {
    state = user;
  }

  void logout() {
    state = User.guest();
  }

  // Выход только из мобильного приложения (не затрагивает сайт)
  Future<void> mobileLogout() async {
    print('[DEBUG] AuthProvider: Выход только из мобильного приложения');
    await AppConfig.clearMobileBearerToken();
    state = User.guest();
  }

  // Полный выход (затрагивает и сайт)
  Future<void> fullLogout() async {
    print('[DEBUG] AuthProvider: Полный выход из системы');
    await AppConfig.clearBearerToken();
    await AppConfig.clearMobileBearerToken();
    state = User.guest();
  }

  Future<void> refreshAuthStatus() async {
    await _checkAuthStatusAsync();
  }

  /// Автоматическая синхронизация корзины при успешной авторизации
  Future<void> _syncCartOnAuth() async {
    try {
      print('[DEBUG] AuthProvider: Запускаем автоматическую синхронизацию корзины');
      await _ref.read(cartProvider.notifier).syncWithServer();
      print('[DEBUG] AuthProvider: Автоматическая синхронизация корзины завершена');
    } catch (e) {
      print('[DEBUG] AuthProvider: Ошибка автоматической синхронизации корзины: $e');
    }
  }

  /// Регистрация FCM-токена на сервере после входа
  Future<void> _syncFcmTokenOnAuth() async {
    try {
      final notificationService = NotificationService();
      if (notificationService.isInitialized) {
        await notificationService.syncPendingFcmTokenIfNeeded();
      } else {
        await notificationService.initialize();
      }
      print('[DEBUG] AuthProvider: FCM токен синхронизирован с сервером');
    } catch (e) {
      print('[DEBUG] AuthProvider: Ошибка синхронизации FCM токена: $e');
    }
  }

  Future<void> forceLogout() async {
    print('[DEBUG] AuthProvider: Принудительный выход из системы');
    await AppConfig.clearBearerToken(); // Очищаем токен в SharedPreferences
    state = User.guest();
  }

  bool get isAuthenticated => state.isAuthenticated;
}

final authProvider = StateNotifierProvider<AuthNotifier, User>((ref) {
  return AuthNotifier(ref);
});
