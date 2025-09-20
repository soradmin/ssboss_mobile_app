// lib/features/auth/repo/auth_api.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- Добавлен импорт
import '../../../core/api_client.dart'; // Наш настроенный Dio
import '../../../core/result.dart'; // <-- Добавлен импорт Result, Ok, Err
import '../../../core/config.dart'; // Для AppConfig.bearer

class AuthApi {
  /// Вход пользователя по email и паролю
  static Future<Result<String>> login(String email, String password) async {
    try {
      // Исправлен вызов dio.post: data передается как именованный параметр
      final res = await dio.post(
        '/user/signin',
        data: { // <-- data как именованный параметр
          'email': email,
          'password': password,
        },
      );

      if (res.statusCode == 200) {
        final data = res.data;
        // Проверяем структуру ответа
        if (data is Map<String, dynamic> && data['token'] is String) {
          final token = data['token'] as String;
          print('[AUTH_API] Login successful, received token: ${token.substring(0, 20)}...');
          return Ok(token); // <-- Ok как конструктор
        } else {
          print('[AUTH_API] Login failed, unexpected response structure: $data');
          return const Err('Не удалось получить токен из ответа'); // <-- Err как конструктор
        }
      } else {
        // Обработка ошибок логина (например, неверный пароль)
        final data = res.data;
        String message = 'Ошибка входа (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> && data['data'] is Map && (data['data'] as Map)['form'] is List) {
           // Иногда ошибки приходят в data.form
           final formErrors = (data['data'] as Map)['form'] as List;
           message = formErrors.join(', ');
        }
        print('[AUTH_API] Login failed: $message');
        return Err(message); // <-- Err как конструктор (без const, если message динамический)
      }
    } on DioException catch (e) {
      print('[AUTH_API] Login DioException: $e');
      String message = 'Ошибка сети';
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> && data['data'] is Map && (data['data'] as Map)['form'] is List) {
           final formErrors = (data['data'] as Map)['form'] as List;
           message = formErrors.join(', ');
        }
        print('[AUTH_API] Login server error response: $data');
      }
      return Err(message); // <-- Err как конструктор
    } catch (e) {
      print('[AUTH_API] Login generic exception: $e');
      return Err('Неизвестная ошибка: $e'); // <-- Err как конструктор
    }
  }

  /// Получение данных профиля текущего пользователя
  /// Требует валидного bearer токена в AppConfig.bearer
  static Future<Result<Map<String, dynamic>>> getProfile() async {
    try {
      // Убедимся, что токен установлен
      if (AppConfig.bearer.isEmpty) {
        return const Err('Пользователь не авторизован'); // <-- Err как конструктор
      }

      final res = await dio.get('/user/profile'); // Путь относительно baseUrl

      if (res.statusCode == 200) {
        final data = res.data;
        // Проверяем структуру ответа
        if (data is Map<String, dynamic> && data['data'] is Map) {
          final userData = data['data'] as Map<String, dynamic>;
          print('[AUTH_API] Profile fetched successfully');
          return Ok(userData); // <-- Ok как конструктор
        } else {
          print('[AUTH_API] Unexpected profile response structure: $data');
          return const Err('Не удалось распарсить данные профиля'); // <-- Err как конструктор
        }
      } else {
        print('[AUTH_API] Failed to fetch profile, status: ${res.statusCode}');
        return const Err('Ошибка загрузки профиля'); // <-- Err как конструктор
      }
    } on DioException catch (e) {
      print('[AUTH_API] Profile DioException: $e');
      if (e.response?.statusCode == 401) {
        // Токен истёк или невалиден
        return const Err('Токен авторизации истёк. Пожалуйста, войдите снова.'); // <-- Err как конструктор
      }
      return Err('Ошибка сети при загрузке профиля: ${e.message}'); // <-- Err как конструктор
    } catch (e) {
      print('[AUTH_API] Profile generic exception: $e');
      return Err('Неизвестная ошибка при загрузке профиля: $e'); // <-- Err как конструктор
    }
  }

  /// Регистрация нового пользователя
  static Future<Result<String>> register({required String name, required String email, required String password}) async {
    try {
      final res = await dio.post(
        '/user/register', // <-- Уточни этот путь!
        data: {
          'name': name,
          'email': email,
          'password': password,
          // Добавь другие поля, если API требует (например, password_confirmation)
        },
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        // Проверяем, возвращает ли API токен сразу после регистрации
        if (data is Map<String, dynamic> && data['token'] is String) {
          final token = data['token'] as String;
          print('[AUTH_API] Registration successful, received token: ${token.substring(0, 20)}...');
          return Ok(token);
        } else {
          // Если токен не возвращается, возможно, нужно залогиниться отдельно
          // или API возвращает сообщение об успехе
          print('[AUTH_API] Registration successful, but no token in response. Data: $data');
          // Попробуем залогиниться
          return await login(email, password);
        }
      } else {
        final data = res.data;
        String message = 'Ошибка регистрации (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> && data['data'] is Map && (data['data'] as Map)['form'] is List) {
          final formErrors = (data['data'] as Map)['form'] as List;
          message = formErrors.join(', ');
        }
        print('[AUTH_API] Registration failed: $message');
        return Err(message);
      }
    } on DioException catch (e) {
      print('[AUTH_API] Registration DioException: $e');
      String message = 'Ошибка сети при регистрации';
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> && data['data'] is Map && (data['data'] as Map)['form'] is List) {
          final formErrors = (data['data'] as Map)['form'] as List;
          message = formErrors.join(', ');
        }
        print('[AUTH_API] Registration server error response: $data');
      }
      return Err(message);
    } catch (e) {
      print('[AUTH_API] Registration generic exception: $e');
      return Err('Неизвестная ошибка при регистрации: $e');
    }
  }


  /// Выход пользователя (очистка токена на клиенте)
  static Future<void> logout() async {
    AppConfig.bearer = ''; // Очищаем токен в памяти
    final sp = await SharedPreferences.getInstance();
    await sp.remove('bearer_token'); // Очищаем токен в хранилище
    print('[AUTH_API] User logged out, token cleared');
  }
}