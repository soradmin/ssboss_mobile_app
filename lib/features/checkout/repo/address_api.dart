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

  /// Получение всех адресов пользователя
  Future<Result<List<Address>>> getAddresses() async {
    try {
      print('[DEBUG] AddressApi.getAddresses: Получаем адреса пользователя...');
      
      // Сначала добавляем статический пункт выдачи
      final List<Address> addresses = [
        const Address(
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
        ),
      ];
      
      // Пытаемся получить адреса с сервера (только для авторизованных пользователей)
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isNotEmpty) {
        try {
          print('[DEBUG] AddressApi.getAddresses: Загружаем адреса для авторизованного пользователя');
          print('[DEBUG] AddressApi.getAddresses: Bearer token длина: ${activeToken.length}');
          print('[DEBUG] AddressApi.getAddresses: Bearer token начало: ${activeToken.length > 20 ? activeToken.substring(0, 20) : activeToken}...');
          print('[DEBUG] AddressApi.getAddresses: Полный Bearer token: $activeToken');
          
          // Пробуем разные возможные endpoints
          final endpoints = [
            '/user/address/all',
            '/user/addresses',
            '/addresses',
            '/user/address',
          ];
          
          Response? res;
          String? workingEndpoint;
          
          for (final endpoint in endpoints) {
            try {
              print('[DEBUG] AddressApi.getAddresses: Пробуем endpoint: $endpoint');
              
              res = await dio.get(
                endpoint,
                queryParameters: {
                  'time_zone': 'Asia/Tashkent',
                  'order_by': 'created_at',
                  'type': 'desc',
                  'page': 1,
                },
                options: Options(
                  headers: {
                    'Authorization': 'Bearer $activeToken',
                  },
                ),
              );
              
              print('[DEBUG] AddressApi.getAddresses: $endpoint - HTTP статус = ${res.statusCode}');
              print('[DEBUG] AddressApi.getAddresses: $endpoint - Тип ответа: ${res.data.runtimeType}');
              
              // Проверяем, что получили JSON, а не HTML
              if (res.data is Map || res.data is List) {
                print('[DEBUG] AddressApi.getAddresses: Найден рабочий endpoint: $endpoint');
                workingEndpoint = endpoint;
                break;
              } else {
                print('[DEBUG] AddressApi.getAddresses: $endpoint вернул HTML, пробуем следующий...');
              }
            } catch (e) {
              print('[DEBUG] AddressApi.getAddresses: $endpoint - ошибка: $e');
              continue;
            }
          }
          
          if (res == null || workingEndpoint == null) {
            print('[DEBUG] AddressApi.getAddresses: Ни один endpoint не вернул JSON');
            throw Exception('Не найден рабочий API endpoint для адресов');
          }
        
        print('[DEBUG] AddressApi.getAddresses: HTTP статус = ${res.statusCode}');
        print('[DEBUG] AddressApi.getAddresses: Тип ответа: ${res.data.runtimeType}');
        print('[DEBUG] AddressApi.getAddresses: Ответ сервера = ${res.data}');
        
        final data = res.data;
        
                // Проверяем различные возможные структуры ответа
                if (data is Map) {
                  print('[DEBUG] AddressApi.getAddresses: Ответ - Map, ключи: ${data.keys.toList()}');
                  
                  // Проверяем наличие data
                  if (data.containsKey('data')) {
                    final dataField = data['data'];
                    print('[DEBUG] AddressApi.getAddresses: Поле data найдено, тип: ${dataField.runtimeType}');
                    print('[DEBUG] AddressApi.getAddresses: Содержимое data: $dataField');
                    
                    if (dataField is List) {
                      print('[DEBUG] AddressApi.getAddresses: data - это List с ${dataField.length} элементами');
                      try {
                        final serverAddresses = dataField
                            .map((json) {
                              print('[DEBUG] AddressApi.getAddresses: Парсим адрес: $json');
                              return Address.fromJson(json as Map<String, dynamic>);
                            })
                            .toList();
                        addresses.addAll(serverAddresses);
                        print('[DEBUG] AddressApi.getAddresses: Успешно добавлено ${serverAddresses.length} адресов с сервера');
                      } catch (e) {
                        print('[DEBUG] AddressApi.getAddresses: Ошибка парсинга адресов: $e');
                      }
                    } else if (dataField is Map) {
                      print('[DEBUG] AddressApi.getAddresses: data - это Map: $dataField');
                      
                      // Проверяем структуру пагинации: data.data (список адресов)
                      if (dataField.containsKey('data') && dataField['data'] is List) {
                        final addressesList = dataField['data'] as List;
                        print('[DEBUG] AddressApi.getAddresses: Найден список адресов в data.data с ${addressesList.length} элементами');
                        try {
                          final serverAddresses = addressesList
                              .map((json) {
                                print('[DEBUG] AddressApi.getAddresses: Парсим адрес: $json');
                                return Address.fromJson(json as Map<String, dynamic>);
                              })
                              .toList();
                          addresses.addAll(serverAddresses);
                          print('[DEBUG] AddressApi.getAddresses: Успешно добавлено ${serverAddresses.length} адресов из data.data');
                        } catch (e) {
                          print('[DEBUG] AddressApi.getAddresses: Ошибка парсинга адресов из data.data: $e');
                        }
                      }
                      // Возможно, адреса находятся в другом поле
                      else if (dataField.containsKey('addresses')) {
                        final addressesField = dataField['addresses'];
                        print('[DEBUG] AddressApi.getAddresses: Найдено поле addresses: $addressesField');
                        if (addressesField is List) {
                          try {
                            final serverAddresses = addressesField
                                .map((json) => Address.fromJson(json as Map<String, dynamic>))
                                .toList();
                            addresses.addAll(serverAddresses);
                            print('[DEBUG] AddressApi.getAddresses: Успешно добавлено ${serverAddresses.length} адресов из поля addresses');
                          } catch (e) {
                            print('[DEBUG] AddressApi.getAddresses: Ошибка парсинга адресов из поля addresses: $e');
                          }
                        }
                      }
                    }
                  }
                } else if (data is List) {
          print('[DEBUG] AddressApi.getAddresses: Ответ - прямой List с ${data.length} элементами');
          try {
            final serverAddresses = data
                .map((json) {
                  print('[DEBUG] AddressApi.getAddresses: Парсим адрес: $json');
                  return Address.fromJson(json as Map<String, dynamic>);
                })
                .toList();
            addresses.addAll(serverAddresses);
            print('[DEBUG] AddressApi.getAddresses: Успешно добавлено ${serverAddresses.length} адресов с сервера');
          } catch (e) {
            print('[DEBUG] AddressApi.getAddresses: Ошибка парсинга адресов: $e');
          }
        } else {
          print('[DEBUG] AddressApi.getAddresses: Неожиданный тип ответа: ${data.runtimeType}');
        }
        } catch (e) {
          print('[DEBUG] AddressApi.getAddresses: Ошибка загрузки с сервера: $e');
          // Продолжаем со статическим адресом
        }
      } else {
        print('[DEBUG] AddressApi.getAddresses: Пользователь не авторизован, показываем только пункт выдачи');
      }
      
      print('[DEBUG] AddressApi.getAddresses: Всего адресов: ${addresses.length}');
      return Ok(addresses);
      
    } catch (e) {
      print('[DEBUG] AddressApi.getAddresses: Общая ошибка: $e');
      // В случае ошибки возвращаем хотя бы статический пункт выдачи
      return const Ok([
        Address(
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
        ),
      ]);
    }
  }
}
