import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'app_router.dart';
import 'theme.dart';
import 'features/cart/providers/cart_sync_provider.dart';
import 'features/cart/providers/background_sync_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/notifications/providers/notification_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15+: явный edge-to-edge вместо нестабильного режима по умолчанию (Play Console).
  if (!kIsWeb && Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // FCM-проект ssboss-940a1 (не путать с ssbossactual / Realtime Database)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Регистрируем обработчик фоновых сообщений
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Загружаем конфиг (.env внутри) и гостевой токен
  await AppConfig.ensureLoaded();
  await AppConfig.ensureGuestToken();
  
  // Загружаем Bearer токены если они есть (мобильный имеет приоритет)
  await AppConfig.ensureAuthTokensLoaded();

  runApp(const ProviderScope(child: IShopApp()));
}

class IShopApp extends ConsumerWidget {
  const IShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Инициализируем синхронизацию корзины при запуске приложения
    ref.watch(cartSyncProvider);
    
    // Запускаем фоновую синхронизацию
    ref.watch(autoSyncProvider);
    
    // Инициализируем сервис уведомлений
    ref.watch(notificationInitializedProvider);
    
    return MaterialApp.router(
      title: 'SSBOSS',
      theme: buildTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
