import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../../../app_router.dart';

/// Сервис для работы с push-уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;
  static const String _notificationsKey = 'recent_notifications';
  static const int _maxNotifications = 2; // Сохраняем последние 2 уведомления

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Инициализация Firebase
      await _initializeFirebase();

      // Инициализация локальных уведомлений
      await _initializeLocalNotifications();

      // Настройка обработчиков сообщений
      _setupMessageHandlers();

      // Получение и отправка FCM токена на сервер
      await _getAndSendFcmToken();

      _isInitialized = true;
      print('[NOTIFICATIONS] ✅ Сервис уведомлений инициализирован');
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка инициализации: $e');
    }
  }

  /// Инициализация Firebase Messaging
  Future<void> _initializeFirebase() async {
    // Запрашиваем разрешения
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('[NOTIFICATIONS] Разрешения: ${settings.authorizationStatus}');

    // Настройка для iOS
    if (Platform.isIOS) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Инициализация локальных уведомлений
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Создаем канал для уведомлений (Android)
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'ssboss_notifications', // id
        'SSBOSS Уведомления', // название
        description: 'Уведомления о заказах и акциях',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Настройка обработчиков сообщений
  void _setupMessageHandlers() {
    // Обработка сообщений, когда приложение в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[NOTIFICATIONS] 📨 Сообщение получено в foreground:');
      print('[NOTIFICATIONS]   Заголовок: ${message.notification?.title}');
      print('[NOTIFICATIONS]   Текст: ${message.notification?.body}');
      print('[NOTIFICATIONS]   Данные: ${message.data}');

      _showLocalNotification(message);
    });

    // Обработка сообщений, когда приложение в background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[NOTIFICATIONS] 📬 Сообщение открыто из background:');
      print('[NOTIFICATIONS]   Заголовок: ${message.notification?.title}');
      print('[NOTIFICATIONS]   Текст: ${message.notification?.body}');
      print('[NOTIFICATIONS]   Данные: ${message.data}');
      // Сохраняем уведомление при открытии из background
      _saveNotification(message);
      _handleNotificationTap(message);
    });

    // Обработка сообщений, когда приложение было закрыто и открыто через уведомление
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('[NOTIFICATIONS] 📭 Сообщение открыто из terminated:');
        print('[NOTIFICATIONS]   Заголовок: ${message.notification?.title}');
        print('[NOTIFICATIONS]   Текст: ${message.notification?.body}');
        print('[NOTIFICATIONS]   Данные: ${message.data}');
        // Сохраняем уведомление при открытии из terminated
        _saveNotification(message);
        // Небольшая задержка, чтобы приложение успело инициализироваться
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleNotificationTap(message);
        });
      }
    });
  }

  /// Получение и отправка FCM токена на сервер
  Future<void> _getAndSendFcmToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('[NOTIFICATIONS] 🔑 FCM токен получен: $_fcmToken');

      if (_fcmToken != null) {
        await _sendTokenToServer(_fcmToken!);
      }

      // Слушаем обновления токена
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('[NOTIFICATIONS] 🔄 FCM токен обновлен: $newToken');
        _fcmToken = newToken;
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка получения FCM токена: $e');
    }
  }

  /// Отправка FCM токена на сервер
  Future<void> _sendTokenToServer(String token) async {
    try {
      final activeToken = AppConfig.getActiveBearerToken();
      if (activeToken.isEmpty) {
        print('[NOTIFICATIONS] ⚠️ Пользователь не авторизован, токен не отправлен');
        return;
      }

      final response = await dio.post(
        '/user/fcm-token',
        data: {
          'fcm_token': token,
          'device_type': Platform.isAndroid ? 'android' : 'ios',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $activeToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('[NOTIFICATIONS] ✅ FCM токен успешно отправлен на сервер');
      } else {
        print('[NOTIFICATIONS] ⚠️ Сервер вернул статус: ${response.statusCode}');
      }
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка отправки FCM токена на сервер: $e');
    }
  }

  /// Показать локальное уведомление
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    // Очищаем HTML из body для отображения в уведомлении
    String cleanBody = _cleanHtmlFromText(notification.body ?? '');

    const androidDetails = AndroidNotificationDetails(
      'ssboss_notifications',
      'SSBOSS Уведомления',
      channelDescription: 'Уведомления о заказах и акциях',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''), // Для длинных текстов
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ssboss_notifications',
        'SSBOSS Уведомления',
        channelDescription: 'Уведомления о заказах и акциях',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(cleanBody),
      ),
      iOS: iosDetails,
    );

    // Сохраняем данные в JSON для парсинга при нажатии
    final payload = jsonEncode(message.data);

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      cleanBody,
      details,
      payload: payload,
    );

    // Сохраняем уведомление в историю
    await _saveNotification(message);
  }

  /// Сохраняет уведомление в историю (последние 2)
  Future<void> _saveNotification(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);
      
      List<Map<String, dynamic>> notifications = [];
      if (notificationsJson != null) {
        final decoded = jsonDecode(notificationsJson) as List;
        notifications = decoded.cast<Map<String, dynamic>>();
      }

      // Создаем запись уведомления
      final notificationData = {
        'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Добавляем в начало списка
      notifications.insert(0, notificationData);

      // Оставляем только последние _maxNotifications уведомлений
      if (notifications.length > _maxNotifications) {
        notifications = notifications.take(_maxNotifications).toList();
      }

      // Сохраняем обратно
      await prefs.setString(_notificationsKey, jsonEncode(notifications));
      print('[NOTIFICATIONS] 💾 Уведомление сохранено в историю');
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка сохранения уведомления: $e');
    }
  }

  /// Получает последние уведомления
  Future<List<Map<String, dynamic>>> getRecentNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_notificationsKey);
      
      if (notificationsJson == null) {
        return [];
      }

      final decoded = jsonDecode(notificationsJson) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка получения уведомлений: $e');
      return [];
    }
  }

  /// Очищает HTML теги из текста
  String _cleanHtmlFromText(String text) {
    if (text.isEmpty) return text;
    
    // Удаляем HTML теги
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Декодируем HTML entities
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    
    // Удаляем лишние пробелы
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    print('[NOTIFICATIONS] 👆 Уведомление нажато: ${response.payload}');
    
    // Парсим payload для извлечения данных
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationData(data);
      } catch (e) {
        print('[NOTIFICATIONS] ❌ Ошибка парсинга payload: $e');
      }
    }
  }

  /// Обработка данных уведомления
  void _handleNotificationTap(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    
    // Добавляем title из notification, если его нет в data
    if (message.notification?.title != null && !data.containsKey('title')) {
      data['title'] = message.notification!.title!;
    }
    
    _handleNotificationData(data);
  }

  /// Обработка данных уведомления (общий метод)
  void _handleNotificationData(Map<String, dynamic> data) {
    // Используем GoRouter для навигации
    try {
      // Обработка уведомлений о заказах
      if (data.containsKey('order_id')) {
        final orderId = data['order_id'];
        print('[NOTIFICATIONS] 📦 Открываем заказ: $orderId');
        appRouter.go('/order/$orderId');
        return;
      }

      // Обработка уведомлений об акциях/промо
      if (data.containsKey('type') && data['type'] == 'promotion') {
        // Получаем HTML body из data
        String? htmlBody;
        try {
          if (data.containsKey('html_body') && data['html_body'] != null) {
            htmlBody = utf8.decode(base64Decode(data['html_body']));
          }
        } catch (e) {
          print('[NOTIFICATIONS] ⚠️ Ошибка декодирования HTML body: $e');
        }
        
        final title = data.containsKey('title') && data['title'] != null
            ? data['title'].toString()
            : 'Уведомление';
        
        print('[NOTIFICATIONS] 🎉 Открываем промо-уведомление');
        // Переходим на экран с полным сообщением
        appRouter.go('/notification-details', extra: {
          'title': title,
          'htmlBody': htmlBody,
        });
        return;
      }

      // Обработка уведомлений об акциях (старый формат)
      if (data.containsKey('promotion_id')) {
        final promotionId = data['promotion_id'];
        print('[NOTIFICATIONS] 🎉 Открываем акцию: $promotionId');
        appRouter.go('/');
        return;
      }

      // Обработка уведомлений о товарах
      if (data.containsKey('product_id')) {
        final productId = data['product_id'];
        print('[NOTIFICATIONS] 🛍️ Открываем товар: $productId');
        appRouter.go('/product/$productId');
        return;
      }

      // Если есть HTML body, но нет типа - показываем как промо
      if (data.containsKey('html_body') && data['html_body'] != null) {
        try {
          final htmlBody = utf8.decode(base64Decode(data['html_body']));
          final title = data.containsKey('title') && data['title'] != null
              ? data['title'].toString()
              : 'Уведомление';
          
          print('[NOTIFICATIONS] 📄 Открываем уведомление с HTML');
          appRouter.go('/notification-details', extra: {
            'title': title,
            'htmlBody': htmlBody,
          });
          return;
        } catch (e) {
          print('[NOTIFICATIONS] ⚠️ Ошибка декодирования HTML body: $e');
        }
      }
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка обработки навигации: $e');
    }
  }

  /// Получить текущий FCM токен
  String? get fcmToken => _fcmToken;

  /// Проверить, инициализирован ли сервис
  bool get isInitialized => _isInitialized;

  /// Публичный метод для отправки FCM токена на сервер
  /// Используется после успешной авторизации
  Future<void> sendFcmTokenToServer() async {
    if (_fcmToken != null && _fcmToken!.isNotEmpty) {
      await _sendTokenToServer(_fcmToken!);
    } else {
      // Если токен еще не получен, попробуем получить его
      await _getAndSendFcmToken();
    }
  }
}

/// Обработчик фоновых сообщений (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[NOTIFICATIONS] 🔵 Фоновое сообщение получено: ${message.messageId}');
  print('[NOTIFICATIONS]   Заголовок: ${message.notification?.title}');
  print('[NOTIFICATIONS]   Текст: ${message.notification?.body}');
  print('[NOTIFICATIONS]   Данные: ${message.data}');
}

