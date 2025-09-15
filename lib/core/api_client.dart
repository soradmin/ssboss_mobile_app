import 'package:dio/dio.dart';
import 'config.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/json'},
  ),
)..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (AppConfig.bearer.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer ${AppConfig.bearer}';
      }
      return handler.next(options);
    },
  ));
