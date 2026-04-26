import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';

final profileApiProvider = Provider<ProfileApi>((ref) {
  return ProfileApi(dio);
});

class ProfileApi {
  final Dio _apiClient;

  ProfileApi(this._apiClient);

  /// Получить профиль пользователя
  Future<Result<Map<String, dynamic>>> getUserProfile() async {
    try {
      print('[DEBUG] ProfileApi.getUserProfile: Получаем профиль пользователя');
      
      // Создаем Dio клиент с активным токеном
      final activeDio = Dio();
      activeDio.options.baseUrl = _apiClient.options.baseUrl;
      activeDio.options.connectTimeout = _apiClient.options.connectTimeout;
      activeDio.options.receiveTimeout = _apiClient.options.receiveTimeout;
      
      // Добавляем активный токен в заголовки
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isNotEmpty) {
        activeDio.options.headers['Authorization'] = 'Bearer $activeToken';
        print('[DEBUG] ProfileApi.getUserProfile: Используем активный токен: ${activeToken.substring(0, 20)}...');
      } else {
        print('[DEBUG] ProfileApi.getUserProfile: Активный токен не найден, используем гостевой');
      }
      
      final response = await activeDio.get('/user/profile');
      
      print('[DEBUG] ProfileApi.getUserProfile: HTTP статус = ${response.statusCode}');
      print('[DEBUG] ProfileApi.getUserProfile: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        if (responseData.containsKey('data') && responseData['data'] is Map<String, dynamic>) {
          final userData = responseData['data'] as Map<String, dynamic>;
          print('[DEBUG] ProfileApi.getUserProfile: Данные пользователя получены');
          return Ok(userData);
        }
        
        return Err('Не удалось получить данные профиля');
      }
      
      return Err('Ошибка получения профиля: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] ProfileApi.getUserProfile: DioException: ${e.message}');
      return Err('Ошибка получения профиля: ${e.message}');
    } catch (e) {
      print('[DEBUG] ProfileApi.getUserProfile: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Обновить профиль пользователя (только имя)
  Future<Result<bool>> updateProfile({
    required String name,
  }) async {
    try {
      print('[DEBUG] ProfileApi.updateProfile: Обновляем профиль пользователя');
      print('[DEBUG] ProfileApi.updateProfile: Имя: $name');
      
      // API принимает только name, без email
      final response = await _apiClient.post('/user/update-profile', data: {
        'name': name,
      });
      
      print('[DEBUG] ProfileApi.updateProfile: HTTP статус = ${response.statusCode}');
      print('[DEBUG] ProfileApi.updateProfile: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        final success = response.data['success'] ?? 
                       response.data['status'] == 'success' ?? 
                       response.data['message']?.toString().toLowerCase().contains('success') ?? 
                       true;
        print('[DEBUG] ProfileApi.updateProfile: Профиль обновлен: $success');
        return Ok(success);
      }
      
      return Err('Не удалось обновить профиль: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] ProfileApi.updateProfile: DioException: ${e.message}');
      return Err('Ошибка обновления профиля: ${e.message}');
    } catch (e) {
      print('[DEBUG] ProfileApi.updateProfile: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Изменить пароль пользователя
  Future<Result<bool>> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      print('[DEBUG] ProfileApi.updatePassword: Изменяем пароль пользователя');
      
      // Валидация паролей
      if (newPassword != confirmPassword) {
        return Err('Новые пароли не совпадают');
      }
      
      if (newPassword.length < 6) {
        return Err('Новый пароль должен содержать минимум 6 символов');
      }
      
      final response = await _apiClient.post('/user/update-user-password', data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      });
      
      print('[DEBUG] ProfileApi.updatePassword: HTTP статус = ${response.statusCode}');
      print('[DEBUG] ProfileApi.updatePassword: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        final success = response.data['success'] ?? 
                       response.data['status'] == 'success' ?? 
                       response.data['message']?.toString().toLowerCase().contains('success') ?? 
                       true;
        print('[DEBUG] ProfileApi.updatePassword: Пароль изменен: $success');
        return Ok(success);
      }
      
      return Err('Не удалось изменить пароль: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] ProfileApi.updatePassword: DioException: ${e.message}');
      return Err('Ошибка изменения пароля: ${e.message}');
    } catch (e) {
      print('[DEBUG] ProfileApi.updatePassword: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Выйти из системы
  Future<Result<bool>> logout() async {
    try {
      print('[DEBUG] ProfileApi.logout: Выходим из системы');
      
      final response = await _apiClient.get('/user/logout');
      
      print('[DEBUG] ProfileApi.logout: HTTP статус = ${response.statusCode}');
      print('[DEBUG] ProfileApi.logout: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] ProfileApi.logout: Выход выполнен успешно');
        return Ok(true);
      }
      
      return Err('Не удалось выйти из системы: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] ProfileApi.logout: DioException: ${e.message}');
      return Err('Ошибка выхода из системы: ${e.message}');
    } catch (e) {
      print('[DEBUG] ProfileApi.logout: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }

  /// Удалить аккаунт
  Future<Result<bool>> deleteAccount() async {
    try {
      print('[DEBUG] ProfileApi.deleteAccount: Удаляем аккаунт');
      
      final response = await _apiClient.delete('/user/delete');
      
      print('[DEBUG] ProfileApi.deleteAccount: HTTP статус = ${response.statusCode}');
      print('[DEBUG] ProfileApi.deleteAccount: Ответ сервера = ${response.data}');
      
      if (response.statusCode == 200) {
        print('[DEBUG] ProfileApi.deleteAccount: Аккаунт успешно удален');
        return Ok(true);
      }
      
      return Err('Не удалось удалить аккаунт: ${response.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] ProfileApi.deleteAccount: DioException: ${e.message}');
      return Err('Ошибка удаления аккаунта: ${e.message}');
    } catch (e) {
      print('[DEBUG] ProfileApi.deleteAccount: Общая ошибка: $e');
      return Err('Неожиданная ошибка: ${e.toString()}');
    }
  }
}
