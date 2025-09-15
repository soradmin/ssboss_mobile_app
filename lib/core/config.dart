// lib/core/config.dart
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Базовые URL с дефолтами
  static String apiBaseUrl = 'https://ssboss.shop/api/v1';
  static String cdnBaseUrl = 'https://ssboss.shop';

  // Язык по умолчанию
  static String langCode = 'en';

  // Токены
  static String guestToken = '';
  static String bearer = ''; // <-- ЭТО НУЖНО ДЛЯ api_client, если юзер авторизуется

  /// Подтягиваем значения из .env, если он загружен
  static Future<void> ensureLoaded() async {
    if (dotenv.isInitialized) {
      // у тебя ключ называется API_BASE
      apiBaseUrl = dotenv.maybeGet('API_BASE') ??
          dotenv.maybeGet('API_BASE_URL') ??
          apiBaseUrl;

      cdnBaseUrl = dotenv.maybeGet('CDN_BASE') ??
          dotenv.maybeGet('CDN_BASE_URL') ??
          cdnBaseUrl;

      langCode = dotenv.maybeGet('LANG_CODE') ?? langCode;
    }
  }

  /// Генерируем/читаем гостевой токен (для корзины/чекаута)
  static Future<void> ensureGuestToken() async {
    if (guestToken.isNotEmpty) return;
    final sp = await SharedPreferences.getInstance();
    var token = sp.getString('guest_token');
    token ??=
        'g_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    await sp.setString('guest_token', token);
    guestToken = token;
  }
}
