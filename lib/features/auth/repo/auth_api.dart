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

      print('[AUTH_API] login: Status ${res.statusCode}');
      print('[AUTH_API] login: Response: ${res.data}');
      
      if (res.statusCode == 200) {
        final data = res.data;
        print('[AUTH_API] login: Parsed data: $data');
        
        // Проверяем, есть ли ошибки в ответе (статус 200, но с ошибкой)
        if (data is Map<String, dynamic>) {
          // Проверяем наличие ошибок в структуре ответа
          if (data['status'] == 201 || data['status'] == 400 || data['status'] == 401) {
            String errorMessage = _extractErrorMessage(data, email: email);
            print('[AUTH_API] login: Error in response: $errorMessage');
            return Err(errorMessage);
          }
          
          // Проверяем наличие ошибок в data.form
          if (data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap['form'] is List) {
              final formErrors = dataMap['form'] as List;
              if (formErrors.isNotEmpty) {
                String errorMessage = _extractFormErrorMessage(formErrors, email: email, responseData: data);
                print('[AUTH_API] login: Form errors: $errorMessage');
                return Err(errorMessage);
              }
            }
          }
        }
        
        // Проверяем разные возможные места для токена
        String? token;
        if (data is Map<String, dynamic>) {
          // Пробуем разные поля для токена
          token = data['token'] as String?;
          if (token == null) {
            token = data['access_token'] as String?;
          }
          if (token == null) {
            token = data['auth_token'] as String?;
          }
          if (token == null && data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            token = dataMap['token'] as String?;
          }
        }
        
        if (token != null && token.isNotEmpty) {
          print('[AUTH_API] login: Success, token: ${token.substring(0, 20)}...');
          return Ok(token);
        } else {
          print('[AUTH_API] login: Token not found in response: $data');
          return const Err('Не удалось получить токен из ответа');
        }
      } else {
        final data = res.data;
        String message = _extractErrorMessage(data, email: email);
        if (message.isEmpty) {
          message = 'Ошибка входа (${res.statusCode})';
        }
        print('[AUTH_API] login: Failed: $message');
        return Err(message);
      }
    } on DioException catch (e) {
      print('[AUTH_API] Login DioException: $e');
      String message = 'Ошибка сети';
      if (e.response != null) {
        final data = e.response?.data;
        message = _extractErrorMessage(data, email: email);
        if (message.isEmpty) {
          message = 'Ошибка сети при входе';
        }
        print('[AUTH_API] Login server error response: $data');
      } else if (e.type == DioExceptionType.connectionTimeout || 
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        message = 'Превышено время ожидания. Проверьте подключение к интернету';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'Ошибка подключения. Проверьте подключение к интернету';
      }
      return Err(message);
    } catch (e) {
      print('[AUTH_API] Login generic exception: $e');
      return Err('Неизвестная ошибка: $e'); // <-- Err как конструктор
    }
  }

  /// Получение данных профиля текущего пользователя
  /// Использует активный токен (мобильный или общий)
  static Future<Result<Map<String, dynamic>>> getProfile() async {
    try {
      // Проверяем наличие активного токена
      if (!AppConfig.hasActiveToken()) {
        return const Err('Пользователь не авторизован');
      }

      // Создаем Dio клиент с активным токеном
      final activeDio = Dio();
      activeDio.options.baseUrl = dio.options.baseUrl;
      activeDio.options.connectTimeout = dio.options.connectTimeout;
      activeDio.options.receiveTimeout = dio.options.receiveTimeout;
      
      // Добавляем активный токен в заголовки
      final activeToken = AppConfig.getActiveBearerToken();
      activeDio.options.headers['Authorization'] = 'Bearer $activeToken';
      
      print('[AUTH_API] getProfile: Используем активный токен: ${activeToken.substring(0, 20)}...');
      
      final res = await activeDio.get('/user/profile');

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
      // Используем правильный endpoint с POST запросом
      final res = await dio.post(
        '/user/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      print('[AUTH_API] register: Status ${res.statusCode}');
      print('[AUTH_API] register: Response: ${res.data}');
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        print('[AUTH_API] register: Parsed data: $data');
        
        // Проверяем, что именно вернул сервер
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String?;
          if (message != null && message.contains('already verified')) {
            print('[AUTH_API] register: User already exists and verified');
            return Ok('LOGIN_REQUIRED'); // Пользователь уже существует, нужно войти
          }
        }
        
        // При успешной регистрации всегда требуется верификация
        print('[AUTH_API] register: Registration successful, verification required');
        return Ok('VERIFICATION_REQUIRED'); // Специальный код для верификации
      } else {
        final data = res.data;
        String message = 'Ошибка регистрации (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        } else if (data is Map<String, dynamic> && data['data'] is Map && (data['data'] as Map)['form'] is List) {
          final formErrors = (data['data'] as Map)['form'] as List;
          message = formErrors.map((e) => e.toString()).join(', ');
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
          message = formErrors.map((e) => e.toString()).join(', ');
        }
        print('[AUTH_API] Registration server error response: $data');
      }
      return Err(message);
    } catch (e) {
      print('[AUTH_API] Registration generic exception: $e');
      return Err('Неизвестная ошибка при регистрации: $e');
    }
  }


  /// Верификация кода подтверждения email
  static Future<Result<String>> verifyEmail({required String email, required String code}) async {
    try {
      final res = await dio.post(
        '/user/verify',
        data: {
          'email': email,
          'code': code,
        },
      );

      print('[AUTH_API] verifyEmail: Status ${res.statusCode}');
      print('[AUTH_API] verifyEmail: Response: ${res.data}');
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        print('[AUTH_API] verifyEmail: Verification successful, trying to login...');
        
        // После успешной верификации автоматически входим в систему
        // Извлекаем email из ответа или используем переданный
        String loginEmail = email;
        if (data is Map<String, dynamic> && data['data'] is Map) {
          final userData = data['data'] as Map<String, dynamic>;
          loginEmail = userData['email'] as String? ?? email;
        }
        
        // После успешной верификации возвращаем специальный код
        // Пользователь должен будет войти в систему с паролем
        print('[AUTH_API] verifyEmail: Verification successful, user needs to login');
        return Ok('LOGIN_REQUIRED'); // Специальный код для входа
      } else {
        final data = res.data;
        String message = 'Ошибка верификации (${res.statusCode})';
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        }
        print('[AUTH_API] Email verification failed: $message');
        return Err(message);
      }
    } on DioException catch (e) {
      print('[AUTH_API] Email verification DioException: $e');
      String message = 'Ошибка сети при верификации';
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        }
        print('[AUTH_API] Email verification server error response: $data');
      }
      return Err(message);
    } catch (e) {
      print('[AUTH_API] Email verification generic exception: $e');
      return Err('Неизвестная ошибка при верификации: $e');
    }
  }

  /// Повторная отправка кода подтверждения
  static Future<Result<String>> resendVerificationCode({required String email}) async {
    try {
      // Пробуем разные возможные endpoints для повторной отправки
      final endpoints = ['/user/resend-verification', '/user/resend', '/user/signup'];
      
      for (final endpoint in endpoints) {
        try {
          final res = await dio.post(
            endpoint,
            data: {
              'email': email,
            },
          );

          print('[AUTH_API] resendVerificationCode: Status ${res.statusCode}');
          print('[AUTH_API] resendVerificationCode: Response: ${res.data}');
          
          if (res.statusCode == 200 || res.statusCode == 201) {
            final data = res.data;
            String message = 'Код подтверждения отправлен повторно';
            
            if (data is Map<String, dynamic> && data['message'] is String) {
              message = data['message'] as String;
            }
            
            print('[AUTH_API] resendVerificationCode: Success');
            return Ok(message);
          }
        } catch (e) {
          print('[AUTH_API] Endpoint $endpoint failed: $e');
          continue;
        }
      }
      
      return Err('Не удалось отправить код повторно');
    } on DioException catch (e) {
      print('[AUTH_API] Resend verification DioException: $e');
      String message = 'Ошибка сети при повторной отправке';
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['message'] is String) {
          message = data['message'] as String;
        }
        print('[AUTH_API] Resend verification server error response: $data');
      }
      return Err(message);
    } catch (e) {
      print('[AUTH_API] Resend verification generic exception: $e');
      return Err('Неизвестная ошибка при повторной отправке: $e');
    }
  }

  /// Получение user_token из профиля пользователя
  /// Этот токен нужен для создания заказов
  static Future<Result<String>> getUserToken() async {
    try {
      // Проверяем наличие активного токена
      if (!AppConfig.hasActiveToken()) {
        return const Err('Пользователь не авторизован');
      }

      // Получаем профиль пользователя для извлечения user_token
      final profileResult = await getProfile();
      
      if (profileResult is Ok<Map<String, dynamic>>) {
        final userData = profileResult.value;
        final userId = userData['id'] as int?;
        
        if (userId != null) {
          // Генерируем user_token на основе ID пользователя и текущего времени
          // Это обеспечит уникальность токена для каждого пользователя
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final userToken = 'u${userId}_${timestamp}';
          
          print('[AUTH_API] getUserToken: Generated user_token for user $userId: ${userToken.substring(0, 10)}...');
          return Ok(userToken);
        } else {
          print('[AUTH_API] getUserToken: User ID not found in profile data');
          return const Err('Не удалось получить ID пользователя из профиля');
        }
      } else {
        print('[AUTH_API] getUserToken: Failed to get profile: ${profileResult.toString()}');
        return Err('Не удалось получить профиль пользователя');
      }
    } catch (e) {
      print('[AUTH_API] getUserToken generic exception: $e');
      return Err('Неизвестная ошибка при получении user_token: $e');
    }
  }

  /// Проверка валидности токена
  static Future<Result<bool>> validateToken() async {
    try {
      if (AppConfig.bearer.isEmpty) {
        print('[AUTH_API] validateToken: No bearer token');
        return const Ok(false);
      }

      final res = await dio.get('/user/profile');

      print('[AUTH_API] validateToken: HTTP status: ${res.statusCode}');
      print('[AUTH_API] validateToken: Response: ${res.data}');

      if (res.statusCode == 200) {
        // Проверяем содержимое ответа
        final data = res.data;
        if (data is Map<String, dynamic>) {
          // Проверяем на ошибки в содержимом
          if (data['status'] == 201 || 
              (data['message'] != null && data['message'].toString().contains("couldn't found")) ||
              (data['data'] is Map && (data['data'] as Map)['form'] is List)) {
            print('[AUTH_API] validateToken: Token invalid - server returned error in content');
            return const Ok(false);
          }
          
          // Проверяем, что есть валидные данные пользователя
          if (data['data'] is Map) {
            final userData = data['data'] as Map<String, dynamic>;
            if (userData.containsKey('id') && userData['id'] != null) {
              print('[AUTH_API] validateToken: Token is valid - user data found');
              return const Ok(true);
            }
          }
        }
        
        print('[AUTH_API] validateToken: Token invalid - no valid user data');
        return const Ok(false);
      } else {
        print('[AUTH_API] validateToken: Token is invalid, status: ${res.statusCode}');
        return const Ok(false);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        print('[AUTH_API] validateToken: Token expired (401)');
        return const Ok(false);
      }
      print('[AUTH_API] validateToken: Network error: ${e.message}');
      return const Ok(false);
    } catch (e) {
      print('[AUTH_API] validateToken: Generic error: $e');
      return const Ok(false);
    }
  }

  /// Проверка валидности мобильного токена (независимого от сайта)
  static Future<Result<bool>> validateMobileToken() async {
    try {
      if (AppConfig.mobileBearer.isEmpty) {
        print('[AUTH_API] validateMobileToken: No mobile bearer token');
        return const Ok(false);
      }

      // Создаем отдельный Dio клиент с мобильным токеном
      final mobileDio = Dio();
      mobileDio.options.baseUrl = dio.options.baseUrl;
      mobileDio.options.connectTimeout = dio.options.connectTimeout;
      mobileDio.options.receiveTimeout = dio.options.receiveTimeout;
      
      // Добавляем мобильный токен в заголовки
      mobileDio.options.headers['Authorization'] = 'Bearer ${AppConfig.mobileBearer}';
      
      final res = await mobileDio.get('/user/profile');

      print('[AUTH_API] validateMobileToken: HTTP status: ${res.statusCode}');
      print('[AUTH_API] validateMobileToken: Response: ${res.data}');

      if (res.statusCode == 200) {
        // Проверяем содержимое ответа
        final data = res.data;
        if (data is Map<String, dynamic>) {
          // Проверяем на ошибки в содержимом
          if (data['status'] == 201 || 
              (data['message'] != null && data['message'].toString().contains("couldn't found")) ||
              (data['data'] is Map && (data['data'] as Map)['form'] is List)) {
            print('[AUTH_API] validateMobileToken: Mobile token invalid - server returned error in content');
            return const Ok(false);
          }
          
          // Проверяем, что есть валидные данные пользователя
          if (data['data'] is Map) {
            final userData = data['data'] as Map<String, dynamic>;
            if (userData.containsKey('id') && userData['id'] != null) {
              print('[AUTH_API] validateMobileToken: Mobile token is valid - user data found');
              return const Ok(true);
            }
          }
        }
        
        print('[AUTH_API] validateMobileToken: Mobile token invalid - no valid user data');
        return const Ok(false);
      } else {
        print('[AUTH_API] validateMobileToken: Mobile token is invalid, status: ${res.statusCode}');
        return const Ok(false);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        print('[AUTH_API] validateMobileToken: Mobile token expired (401)');
        return const Ok(false);
      }
      print('[AUTH_API] validateMobileToken: Network error: ${e.message}');
      return const Ok(false);
    } catch (e) {
      print('[AUTH_API] validateMobileToken: Generic error: $e');
      return const Ok(false);
    }
  }

  /// Выход пользователя (очистка токена на клиенте)
  static Future<void> logout() async {
    AppConfig.bearer = ''; // Очищаем токен в памяти
    final sp = await SharedPreferences.getInstance();
    await sp.remove('bearer_token'); // Очищаем токен в хранилище
    print('[AUTH_API] User logged out, token cleared');
  }

  /// Извлечение сообщения об ошибке из ответа сервера
  static String _extractErrorMessage(dynamic data, {String? email}) {
    if (data == null) return '';
    
    if (data is Map<String, dynamic>) {
      // Пробуем получить сообщение напрямую
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        String message = data['message'] as String;
        // Переводим английские сообщения на русский
        message = _translateErrorMessage(message, email: email, responseData: data);
        return message;
      }
      
      // Пробуем получить сообщение из data.message
      if (data['data'] is Map) {
        final dataMap = data['data'] as Map<String, dynamic>;
        if (dataMap['message'] is String && (dataMap['message'] as String).isNotEmpty) {
          String message = dataMap['message'] as String;
          message = _translateErrorMessage(message, email: email, responseData: data);
          return message;
        }
        
        // Пробуем получить ошибки из data.form
        if (dataMap['form'] is List) {
          final formErrors = dataMap['form'] as List;
          if (formErrors.isNotEmpty) {
            return _extractFormErrorMessage(formErrors, email: email, responseData: data);
          }
        }
      }
    }
    
    return '';
  }

  /// Извлечение сообщений об ошибках из массива form
  static String _extractFormErrorMessage(List formErrors, {String? email, dynamic responseData}) {
    if (formErrors.isEmpty) return '';
    
    // Берем первую ошибку
    final firstError = formErrors.first;
    
    if (firstError is Map) {
      // Если ошибка в формате объекта, ищем поле с сообщением
      // Формат Laravel Validation: {"email": ["The email field is required."]}
      if (firstError.containsKey('email')) {
        final emailError = firstError['email'];
        if (emailError is List && emailError.isNotEmpty) {
          return _translateErrorMessage(emailError.first.toString(), email: email, responseData: responseData);
        } else if (emailError is String) {
          return _translateErrorMessage(emailError, email: email, responseData: responseData);
        }
        return 'Неправильный email или пароль';
      }
      
      if (firstError.containsKey('password')) {
        final passwordError = firstError['password'];
        if (passwordError is List && passwordError.isNotEmpty) {
          return _translateErrorMessage(passwordError.first.toString(), email: email, responseData: responseData);
        } else if (passwordError is String) {
          return _translateErrorMessage(passwordError, email: email, responseData: responseData);
        }
        return 'Неправильный пароль';
      }
      
      // Пробуем найти любое сообщение об ошибке
      for (var entry in firstError.entries) {
        final key = entry.key.toString().toLowerCase();
        final value = entry.value;
        
        // Проверяем, является ли ключ полем email или password
        if (key.contains('email')) {
          if (value is List && value.isNotEmpty) {
            return _translateErrorMessage(value.first.toString(), email: email, responseData: responseData);
          } else if (value is String) {
            return _translateErrorMessage(value, email: email, responseData: responseData);
          }
        } else if (key.contains('password')) {
          if (value is List && value.isNotEmpty) {
            return _translateErrorMessage(value.first.toString(), email: email, responseData: responseData);
          } else if (value is String) {
            return _translateErrorMessage(value, email: email, responseData: responseData);
          }
        }
        
        // Если значение - строка, используем её
        if (value is String && value.isNotEmpty) {
          return _translateErrorMessage(value, email: email, responseData: responseData);
        }
        // Если значение - массив, берем первый элемент
        if (value is List && value.isNotEmpty) {
          return _translateErrorMessage(value.first.toString(), email: email, responseData: responseData);
        }
      }
    } else if (firstError is String) {
      return _translateErrorMessage(firstError, email: email, responseData: responseData);
    }
    
    // Если сообщение содержит "Wrong email/password", показываем общее сообщение
    // Сервер не различает ошибки email и пароля
    return 'Неправильный email или пароль';
  }

  /// Перевод английских сообщений об ошибках на русский
  static String _translateErrorMessage(String message, {String? email, dynamic responseData}) {
    final lowerMessage = message.toLowerCase();
    
    // Ошибки связанные с email
    if (lowerMessage.contains('wrong email') || 
        lowerMessage.contains('email not found') ||
        lowerMessage.contains('user not found') ||
        lowerMessage.contains('couldn\'t found')) {
      return 'Email или пароль введены неверно';
    }
    
    // Ошибки связанные с паролем
    if (lowerMessage.contains('wrong password') ||
        lowerMessage.contains('password incorrect') ||
        lowerMessage.contains('invalid password') ||
        lowerMessage.contains('password does not match')) {
      return 'Неправильный пароль';
    }
    
    // Ошибки связанные с верификацией
    if (lowerMessage.contains('not verified') ||
        lowerMessage.contains('email not verified') ||
        lowerMessage.contains('user is not verified')) {
      return 'Email не подтвержден. Пожалуйста, подтвердите email перед входом';
    }
    
    // Ошибки валидации
    if (lowerMessage.contains('validation') || lowerMessage.contains('invalid')) {
      if (lowerMessage.contains('email')) {
        return 'Некорректный формат email';
      }
      if (lowerMessage.contains('password')) {
        return 'Некорректный формат пароля';
      }
    }
    
    // Общие ошибки авторизации
    if (lowerMessage.contains('wrong email/password') ||
        lowerMessage.contains('unauthorized') || 
        lowerMessage.contains('authentication failed')) {
      // Сервер не различает ошибки email и пароля, показываем общее сообщение
      return 'Неправильный email или пароль';
    }
    
    // Возвращаем оригинальное сообщение, если не нашли перевод
    return message;
  }

  /// Определение типа ошибки (email или пароль) на основе контекста
  /// Поскольку сервер возвращает одинаковое сообщение для обоих случаев,
  /// мы показываем общее сообщение для безопасности
  static String _determineErrorType(String defaultMessage, {String? email, dynamic responseData}) {
    // Сервер не различает ошибки email и пароля, поэтому показываем общее сообщение
    // Это безопаснее, чем пытаться угадать тип ошибки
    return 'Неправильный email или пароль';
  }
}