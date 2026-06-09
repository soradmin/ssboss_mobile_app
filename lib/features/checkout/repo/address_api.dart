import 'dart:convert';

import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';
import '../models/address.dart';
import '../../auth/repo/auth_api.dart';

class AddressApi {
  // Используем глобальную переменную dio из api_client.dart

  /// Создание нового адреса
  Future<Result<Address>> createAddress({
    required String name,
    required String address,
    required String city,
    String? region,
    String? postalCode,
    String? phone,
    String country = 'TJ', // Код страны по умолчанию (TJ = Tajikistan)
    String type = 'delivery',
  }) async {
    try {
      print('[DEBUG] AddressApi.createAddress: Создаем новый адрес...');
      
      // Получаем email пользователя из профиля
      String? userEmail;
      try {
        final profileResult = await AuthApi.getProfile();
        if (profileResult is Ok<Map<String, dynamic>>) {
          userEmail = profileResult.value['email'] as String?;
          print('[DEBUG] AddressApi.createAddress: Получен email из профиля: $userEmail');
        }
      } catch (e) {
        print('[DEBUG] AddressApi.createAddress: Не удалось получить email из профиля: $e');
      }
      
      // Формируем payload в формате, который ожидает сервер
      final payload = {
        'action': 'create',
        'name': name,
        'address_1': address, // Сервер ожидает address_1, а не address
        'city': city,
        'state': region, // Сервер может ожидать state вместо region
        'region': region,
        'zip': postalCode, // Сервер ожидает zip, а не postal_code
        'postal_code': postalCode, // Оставляем для совместимости
        'phone': phone,
        'type': type,
        'is_default': false,
        'country': country, // Код страны из 2 символов (например, 'TJ' для Tajikistan)
        if (userEmail != null) 'email': userEmail, // Добавляем email (обязательное поле)
      };
      
      print('[DEBUG] AddressApi.createAddress: Payload = $payload');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      final res = await dio.post(
        '/user/address/action',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] AddressApi.createAddress: HTTP статус = ${res.statusCode}');
      print('[DEBUG] AddressApi.createAddress: Ответ сервера = ${res.data}');
      
      final data = res.data;
      
      // Проверяем наличие ошибок валидации в ответе
      if (data is Map) {
        if (data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          // Проверяем наличие ошибок валидации
          if (dataMap['form'] is List) {
            final formErrors = dataMap['form'] as List;
            if (formErrors.isNotEmpty) {
              final errorMessage = formErrors.map((e) => e.toString()).join(', ');
              print('[ERROR] AddressApi.createAddress: Ошибки валидации: $errorMessage');
              return Err(errorMessage);
            }
          }
          
          // Если ошибок нет, пытаемся распарсить адрес
          if (dataMap.containsKey('id') || dataMap.containsKey('name')) {
            final address = Address.fromJson(dataMap);
            return Ok(address);
          }
        }
      }
      
      return const Err('Неверный формат ответа сервера');
    } on DioException catch (e) {
      print('[DEBUG] AddressApi.createAddress: DioException: ${e.message}');
      if (e.response?.data is Map) {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['data'] is Map) {
          final dataMap = errorData['data'] as Map<String, dynamic>;
          if (dataMap['form'] is List) {
            final formErrors = dataMap['form'] as List;
            final errorMessage = formErrors.map((e) => e.toString()).join(', ');
            return Err(errorMessage);
          }
        }
        if (errorData['message'] is String) {
          return Err(errorData['message'] as String);
        }
      }
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] AddressApi.createAddress: Общая ошибка: $e');
      return Err(e.toString());
    }
  }

  /// Обновление существующего адреса
  Future<Result<Address>> updateAddress({
    required int id,
    required String name,
    required String address,
    required String city,
    String? region,
    String? postalCode,
    String? phone,
    String country = 'TJ', // Код страны по умолчанию (TJ = Tajikistan)
    String type = 'delivery',
  }) async {
    try {
      print('[DEBUG] AddressApi.updateAddress: Обновляем адрес ID=$id...');
      
      // Получаем email пользователя из профиля
      String? userEmail;
      try {
        final profileResult = await AuthApi.getProfile();
        if (profileResult is Ok<Map<String, dynamic>>) {
          userEmail = profileResult.value['email'] as String?;
          print('[DEBUG] AddressApi.updateAddress: Получен email из профиля: $userEmail');
        }
      } catch (e) {
        print('[DEBUG] AddressApi.updateAddress: Не удалось получить email из профиля: $e');
      }
      
      // Формируем payload в формате, который ожидает сервер
      final payload = {
        'action': 'update',
        'id': id,
        'name': name,
        'address_1': address, // Сервер ожидает address_1, а не address
        'city': city,
        'state': region, // Сервер может ожидать state вместо region
        'region': region,
        'zip': postalCode, // Сервер ожидает zip, а не postal_code
        'postal_code': postalCode, // Оставляем для совместимости
        'phone': phone,
        'type': type,
        'country': country, // Код страны из 2 символов (например, 'TJ' для Tajikistan)
        if (userEmail != null) 'email': userEmail, // Добавляем email
      };
      
      print('[DEBUG] AddressApi.updateAddress: Payload = $payload');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      final res = await dio.post(
        '/user/address/action',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] AddressApi.updateAddress: HTTP статус = ${res.statusCode}');
      print('[DEBUG] AddressApi.updateAddress: Ответ сервера = ${res.data}');
      
      final data = res.data;
      
      // Проверяем наличие ошибок валидации в ответе
      if (data is Map) {
        if (data['data'] is Map) {
          final dataMap = data['data'] as Map<String, dynamic>;
          // Проверяем наличие ошибок валидации
          if (dataMap['form'] is List) {
            final formErrors = dataMap['form'] as List;
            if (formErrors.isNotEmpty) {
              final errorMessage = formErrors.map((e) => e.toString()).join(', ');
              print('[ERROR] AddressApi.updateAddress: Ошибки валидации: $errorMessage');
              return Err(errorMessage);
            }
          }
          
          // Если ошибок нет, пытаемся распарсить адрес
          if (dataMap.containsKey('id') || dataMap.containsKey('name')) {
            final address = Address.fromJson(dataMap);
            return Ok(address);
          }
        }
      }
      
      return const Err('Неверный формат ответа сервера');
    } on DioException catch (e) {
      print('[DEBUG] AddressApi.updateAddress: DioException: ${e.message}');
      if (e.response?.data is Map) {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['data'] is Map) {
          final dataMap = errorData['data'] as Map<String, dynamic>;
          if (dataMap['form'] is List) {
            final formErrors = dataMap['form'] as List;
            final errorMessage = formErrors.map((e) => e.toString()).join(', ');
            return Err(errorMessage);
          }
        }
        if (errorData['message'] is String) {
          return Err(errorData['message'] as String);
        }
      }
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] AddressApi.updateAddress: Общая ошибка: $e');
      return Err(e.toString());
    }
  }

  /// Удаление адреса
  Future<Result<void>> deleteAddress(int id) async {
    try {
      print('[DEBUG] AddressApi.deleteAddress: Удаляем адрес ID=$id...');
      
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        return const Err('Пользователь не авторизован');
      }
      
      // Используем DELETE запрос на endpoint /user/address/delete/{id}
      final res = await dio.delete(
        '/user/address/delete/$id',
        options: Options(
          headers: {
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );
      
      print('[DEBUG] AddressApi.deleteAddress: HTTP статус = ${res.statusCode}');
      print('[DEBUG] AddressApi.deleteAddress: Ответ сервера = ${res.data}');
      
      // Проверяем ответ сервера
      if (res.statusCode == 200) {
        final data = res.data;
        
        if (data is Map) {
          // Проверяем статус ответа
          final status = data['status'];
          final message = data['message']?.toString() ?? '';
          
          if (status == 200 || message.toLowerCase().contains('success')) {
            print('[DEBUG] AddressApi.deleteAddress: Адрес успешно удален');
            return const Ok(null);
          }
          
          // Проверяем наличие ошибок валидации
          if (data['data'] is Map) {
            final dataMap = data['data'] as Map<String, dynamic>;
            if (dataMap['form'] is List) {
              final formErrors = dataMap['form'] as List;
              if (formErrors.isNotEmpty) {
                final errorMessage = formErrors.map((e) => e.toString()).join(', ');
                print('[ERROR] AddressApi.deleteAddress: Ошибки валидации: $errorMessage');
                return Err(errorMessage);
              }
            }
          }
          
          // Если есть сообщение об ошибке
          if (message.isNotEmpty && !message.toLowerCase().contains('success')) {
            print('[ERROR] AddressApi.deleteAddress: Ошибка: $message');
            return Err(message);
          }
        }
        
        // Если дошли сюда и статус 200, считаем успешным
        print('[DEBUG] AddressApi.deleteAddress: Адрес успешно удален (статус 200)');
        return const Ok(null);
      }
      
      // Если статус не 200, возвращаем ошибку
      return Err('Ошибка удаления адреса: ${res.statusCode}');
    } on DioException catch (e) {
      print('[DEBUG] AddressApi.deleteAddress: DioException: ${e.message}');
      print('[DEBUG] AddressApi.deleteAddress: Response data: ${e.response?.data}');
      
      if (e.response?.data is Map) {
        final errorData = e.response!.data as Map<String, dynamic>;
        if (errorData['data'] is Map) {
          final dataMap = errorData['data'] as Map<String, dynamic>;
          if (dataMap['form'] is List) {
            final formErrors = dataMap['form'] as List;
            if (formErrors.isNotEmpty) {
              final errorMessage = formErrors.map((e) => e.toString()).join(', ');
              return Err(errorMessage);
            }
          }
        }
        if (errorData['message'] is String) {
          return Err(errorData['message'] as String);
        }
      }
      
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] AddressApi.deleteAddress: Общая ошибка: $e');
      return Err(e.toString());
    }
  }

  static const Address _localPickup = Address(
    id: Address.localPickupId,
    name: 'Пункт выдачи SSBOSS',
    address: 'улица Джаббора Расулова, 6/1',
    city: 'Душанбе',
    region: 'РРП',
    postalCode: '734000',
    phone: '930900412',
    country: 'TJ',
    type: 'pickup',
    isDefault: true,
  );

  static List<Address> _withLocalPickup(List<Address> serverAddresses) {
    return [_localPickup, ...serverAddresses];
  }

  static dynamic _normalizeResponseBody(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return jsonDecode(trimmed);
      }
    }
    return raw;
  }

  static List<Map<String, dynamic>> _extractAddressMaps(dynamic body) {
    final normalized = _normalizeResponseBody(body);
    if (normalized is List) {
      return normalized
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (normalized is! Map) return [];

    final map = Map<String, dynamic>.from(normalized);
    final status = map['status'];
    if (status != null && status != 200 && status != '200') {
      final message = map['message']?.toString() ?? 'Ошибка API адресов ($status)';
      print('[DEBUG] AddressApi: API status=$status message=$message');
      return [];
    }

    final dataField = map['data'];
    if (dataField is List) {
      return dataField
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (dataField is Map) {
      final nested = Map<String, dynamic>.from(dataField);
      final list = nested['data'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final addresses = nested['addresses'];
      if (addresses is List) {
        return addresses
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  static List<Address> _parseServerAddresses(List<Map<String, dynamic>> maps) {
    final result = <Address>[];
    for (final json in maps) {
      try {
        result.add(Address.fromJson(json));
      } catch (e) {
        print('[DEBUG] AddressApi: пропуск адреса $json — $e');
      }
    }
    return result;
  }

  /// Получение всех адресов пользователя
  Future<Result<List<Address>>> getAddresses() async {
    try {
      print('[DEBUG] AddressApi.getAddresses: Получаем адреса пользователя...');

      await AppConfig.ensureAuthTokensLoaded();
      final activeToken = AppConfig.getActiveBearerToken();

      if (activeToken.isEmpty) {
        print('[DEBUG] AddressApi.getAddresses: нет токена — только пункт выдачи');
        return const Ok([_localPickup]);
      }

      print(
        '[DEBUG] AddressApi.getAddresses: токен len=${activeToken.length}, '
        'mobile=${AppConfig.mobileBearer.isNotEmpty}, bearer=${AppConfig.bearer.isNotEmpty}',
      );

      try {
        final res = await dio.get(
          '/user/address/all',
          queryParameters: {
            'time_zone': 'Asia/Tashkent',
            'order_by': 'created_at',
            'type': 'desc',
            'page': 1,
          },
          options: Options(
            responseType: ResponseType.json,
            headers: {'Authorization': 'Bearer $activeToken'},
          ),
        );

        print(
          '[DEBUG] AddressApi.getAddresses: HTTP ${res.statusCode}, '
          'тип=${res.data.runtimeType}',
        );

        final rawMaps = _extractAddressMaps(res.data);
        final serverAddresses = _parseServerAddresses(rawMaps);
        final all = _withLocalPickup(serverAddresses);

        print(
          '[DEBUG] AddressApi.getAddresses: с сервера ${serverAddresses.length}, '
          'всего ${all.length}',
        );

        if (serverAddresses.isEmpty) {
          print(
            '[WARN] AddressApi.getAddresses: пустой список доставки при активном токене. '
            'body=${res.data}',
          );
        }

        return Ok(all);
      } on DioException catch (e) {
        print('[DEBUG] AddressApi.getAddresses: DioException ${e.message}');
        if (e.response?.statusCode == 401) {
          return const Err(
            'Сессия истекла. Выйдите и войдите снова, затем откройте адреса.',
          );
        }
        return Err(
          e.response?.data?.toString() ?? e.message ?? 'Ошибка загрузки адресов',
        );
      }
    } catch (e) {
      print('[DEBUG] AddressApi.getAddresses: общая ошибка: $e');
      return const Ok([_localPickup]);
    }
  }
}
