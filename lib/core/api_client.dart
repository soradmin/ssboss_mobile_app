// lib/core/api_client.dart
import 'package:dio/dio.dart';
import 'config.dart'; // Импортируем AppConfig

/// Единый, предварительно настроенный экземпляр Dio для всего приложения.
final Dio dio = Dio(
  BaseOptions(
    // Базовый URL берется из AppConfig
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Accept': 'application/json',
      // Content-Type будет установлен Dio автоматически для запросов с телом
    },
  ),
)
  // --- Интерцептор для добавления Bearer токена ---
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Если у нас есть Bearer токен (после логина), добавляем его в заголовки
        if (AppConfig.bearer.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${AppConfig.bearer}';
          print('[DIO] Добавлен Bearer токен в заголовок Authorization');
        }
        // print('[DIO] Отправка запроса: ${options.method} ${options.uri}');
        return handler.next(options); // Продолжаем выполнение запроса
      },
    ),
  )
  // --- LogInterceptor для отладки (опционально, но полезно) ---
  // ВАЖНО: Убираем устаревший параметр 'compact'
  ..interceptors.add(
    LogInterceptor(
      request: true,
      requestBody: true, // Показывать тело запроса
      responseBody: true, // Показывать тело ответа
      error: true, // Показывать ошибки
      requestHeader: false, // Уже видны в Dio
      responseHeader: false, // Уже видны в Dio
      // compact: true, // <-- УДАЛЕН, так как больше не поддерживается в новых версиях Dio
    ),
  );