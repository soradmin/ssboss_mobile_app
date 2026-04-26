// lib/core/config.dart
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // --- Базовые URL ---
  // Дефолтные значения. Могут быть переопределены из .env или assets/app_config.json
  static String apiBaseUrl = 'https://ssboss.shop/api/v1';
  static String cdnBaseUrl = 'https://ssboss.shop';
  static String imagesPath = '/images/products'; // Относительный путь к изображениям товаров

  // --- Токены ---
  static String guestToken = ''; // Гостевой токен для корзины/чекаута без логина
  static String bearer = '';     // Bearer токен для авторизованных пользователей (синхронизируется с сайтом)
  static String mobileBearer = ''; // Независимый Bearer токен только для мобильного приложения

  /// Загружает конфигурацию при запуске приложения.
  /// Приоритет источников: .env (если загружен) > assets/app_config.json > hardcoded defaults
  static Future<void> ensureLoaded() async {
    print('[CONFIG] Начало загрузки конфигурации...');

    // --- 1. Попытка загрузить из .env (если файл существует и dotenv инициализирован) ---
    if (dotenv.isInitialized) {
      print('[CONFIG] .env файл найден и инициализирован.');
      final envApiBase = dotenv.maybeGet('API_BASE_URL') ?? dotenv.maybeGet('API_BASE');
      if (envApiBase != null && envApiBase.isNotEmpty) {
        apiBaseUrl = envApiBase;
        print('[CONFIG] API Base URL из .env: $apiBaseUrl');
      }
      final envCdnBase = dotenv.maybeGet('CDN_BASE_URL') ?? dotenv.maybeGet('CDN_BASE') ?? dotenv.maybeGet('UPLOADS_BASE');
      if (envCdnBase != null && envCdnBase.isNotEmpty) {
        cdnBaseUrl = envCdnBase;
        print('[CONFIG] CDN Base URL из .env: $cdnBaseUrl');
      }
      final envImagesPath = dotenv.maybeGet('IMAGES_PATH');
      if (envImagesPath != null && envImagesPath.isNotEmpty) {
        imagesPath = envImagesPath;
        print('[CONFIG] Images Path из .env: $imagesPath');
      }
    } else {
      print('[CONFIG] .env файл НЕ найден или не инициализирован. Используются дефолты или assets/app_config.json.');
    }
  

    // --- 2. Попытка загрузить из assets/app_config.json ---
    // try {
    //   // Этот блок закомментирован, так как в текущей архитектуре мы полагаемся на .env и дефолты.
    //   // Если потребуется, можно раскомментировать.
    //   // final raw = await rootBundle.loadString('assets/app_config.json');
    //   // final data = jsonDecode(raw) as Map<String, dynamic>;
    //   // apiBaseUrl = data['apiBaseUrl'] ?? data['apiBase'] ?? apiBaseUrl;
    //   // cdnBaseUrl = data['cdnBaseUrl'] ?? data['cdnBase'] ?? data['uploadsBase'] ?? cdnBaseUrl;
    //   // imagesPath = data['imagesPath'] ?? imagesPath;
    // } catch (e) {
    //   print('[CONFIG] Ошибка загрузки assets/app_config.json: $e. Используются текущие значения.');
    // }

    print('[CONFIG] Финальные значения после загрузки:');
    print('[CONFIG]   apiBaseUrl: $apiBaseUrl');
    print('[CONFIG]   cdnBaseUrl: $cdnBaseUrl');
    print('[CONFIG]   imagesPath: $imagesPath');

    // --- 3. Генерация/загрузка guestToken ---
    final sp = await SharedPreferences.getInstance();
    String? token = sp.getString('guest_token');
    if (token == null || token.isEmpty) {
      // Генерируем новый уникальный гостевой токен
      token = 'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await sp.setString('guest_token', token);
      print('[CONFIG] Сгенерирован и сохранен новый guest token: $token');
    } else {
      print('[CONFIG] Загружен существующий guest token: $token');
    }
    guestToken = token;

    print('[CONFIG] Конфигурация загружена.');
  }

  /// Метод-заглушка для совместимости.
  /// Ранее использовался для асинхронной инициализации гостевого токена.
  /// Теперь guestToken инициализируется в ensureLoaded().
  @Deprecated('Используйте AppConfig.ensureLoaded()')
  static Future<void> ensureGuestToken() async {
    // Ничего не делаем, токен уже загружен
    print('[CONFIG] ensureGuestToken (устарел) вызван, но ничего не делает.');
  }

  /// Вспомогательный метод для формирования полного URL к изображению
  static String imageUrl(String rawFilename) {
    // Убираем возможные пробелы и лишние символы
    rawFilename = rawFilename.trim();

    // Если это уже полный URL (начинается с http), возвращаем его как есть
    if (rawFilename.startsWith('http')) {
      return rawFilename;
    }

    // Проверяем, содержит ли путь уже префикс /uploads/
    if (rawFilename.startsWith('/uploads/')) {
      // Если да, то просто добавляем базовый URL
      return '${cdnBaseUrl}$rawFilename';
    }

    // Если нет, то добавляем префикс /uploads/
    final path = rawFilename.startsWith('/') ? rawFilename : '/$rawFilename';
    return '${cdnBaseUrl}/uploads$path';
  }

  static Future<void> saveBearerToken(String token) async {
    bearer = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('bearer_token', token);
    print('[CONFIG] AppConfig.saveBearerToken: Bearer token saved');
  }

  static Future<String?> getBearerToken() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('bearer_token');
    if (token != null && token.isNotEmpty) {
      bearer = token;
    }
    return token;
  }

  static Future<void> clearBearerToken() async {
    bearer = '';
    final sp = await SharedPreferences.getInstance();
    await sp.remove('bearer_token');
    print('[CONFIG] AppConfig.clearBearerToken: Bearer token cleared');
  }

  // --- Методы для мобильного токена (независимого от сайта) ---
  static Future<void> saveMobileBearerToken(String token) async {
    mobileBearer = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('mobile_bearer_token', token);
    print('[CONFIG] AppConfig.saveMobileBearerToken: Mobile Bearer token saved');
  }

  static Future<String?> getMobileBearerToken() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('mobile_bearer_token');
    if (token != null && token.isNotEmpty) {
      mobileBearer = token;
    }
    return token;
  }

  static Future<void> clearMobileBearerToken() async {
    mobileBearer = '';
    final sp = await SharedPreferences.getInstance();
    await sp.remove('mobile_bearer_token');
    print('[CONFIG] AppConfig.clearMobileBearerToken: Mobile Bearer token cleared');
  }

  // --- Методы для работы с активным токеном ---
  static String getActiveBearerToken() {
    // Приоритет: мобильный токен, затем общий токен
    return mobileBearer.isNotEmpty ? mobileBearer : bearer;
  }

  static bool hasActiveToken() {
    return mobileBearer.isNotEmpty || bearer.isNotEmpty;
  }

}