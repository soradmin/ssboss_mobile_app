// lib/features/profile/repo/auth_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';

class AuthApi {
  /// Регистрация нового пользователя
  static Future<Result<String>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/user/register');
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      });
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      };

      print('[AUTH_API] register: POST $url');
      final res = await http.post(url, headers: headers, body: body);

      print('[AUTH_API] register: Status ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['token'] is String) {
          final token = data['token'] as String;
          print('[AUTH_API] register: Success, token: ${token.substring(0, 20)}...');
          return Ok(token);
        } else {
          print('[AUTH_API] register: Token not found in response: $data');
          return const Err('Не удалось получить токен из ответа');
        }
      } else {
        final data = jsonDecode(res.body);
        String message = 'Ошибка регистрации (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        }
        print('[AUTH_API] register: Failed: $message');
        return Err(message);
      }
    } catch (e) {
      print('[AUTH_API] register: Exception: $e');
      return Err('Ошибка сети: $e');
    }
  }

  /// Вход пользователя
  static Future<Result<String>> login(String email, String password) async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/user/signin');
      final body = jsonEncode({
        'email': email,
        'password': password,
      });
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      };

      print('[AUTH_API] login: POST $url');
      final res = await http.post(url, headers: headers, body: body);

      print('[AUTH_API] login: Status ${res.statusCode}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['token'] is String) {
          final token = data['token'] as String;
          print('[AUTH_API] login: Success, token: ${token.substring(0, 20)}...');
          return Ok(token);
        } else {
          print('[AUTH_API] login: Token not found in response: $data');
          return const Err('Не удалось получить токен из ответа');
        }
      } else {
        final data = jsonDecode(res.body);
        String message = 'Ошибка входа (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        }
        print('[AUTH_API] login: Failed: $message');
        return Err(message);
      }
    } catch (e) {
      print('[AUTH_API] login: Exception: $e');
      return Err('Ошибка сети: $e');
    }
  }

  /// Получение данных профиля
  static Future<Result<Map<String, dynamic>>> getProfile() async {
    try {
      if (AppConfig.bearer.isEmpty) {
        return const Err('Пользователь не авторизован');
      }

      final url = Uri.parse('${AppConfig.apiBaseUrl}/user/profile');
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${AppConfig.bearer}',
      };

      print('[AUTH_API] getProfile: GET $url');
      final res = await http.get(url, headers: headers);

      print('[AUTH_API] getProfile: Status ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['data'] is Map) {
          final userData = data['data'] as Map<String, dynamic>;
          print('[AUTH_API] getProfile: Success');
          return Ok(userData);
        } else {
          print('[AUTH_API] getProfile: Unexpected structure: $data');
          return const Err('Не удалось распарсить данные профиля');
        }
      } else {
        print('[AUTH_API] getProfile: Failed: ${res.statusCode}');
        return Err('Ошибка загрузки профиля: ${res.statusCode}');
      }
    } catch (e) {
      print('[AUTH_API] getProfile: Exception: $e');
      return Err('Ошибка сети: $e');
    }
  }

  /// Выход пользователя
  static Future<void> logout() async {
    AppConfig.bearer = '';
    final sp = await SharedPreferences.getInstance();
    await sp.remove('bearer_token');
    print('[AUTH_API] logout: Token cleared');
  }
}