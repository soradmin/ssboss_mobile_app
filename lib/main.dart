import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/network/network_banner.dart';
import 'core/network/network_status.dart';
import 'app_router.dart';
import 'theme.dart';
import 'features/cart/providers/cart_sync_provider.dart';
import 'features/cart/providers/background_sync_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/app_update/app_update_checker.dart';
import 'core/l10n/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ограничиваем кэш декодированных изображений (особенно важно для iOS).
  PaintingBinding.instance.imageCache.maximumSize = 80;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20; // 48 MB

  // Android 15+: явный edge-to-edge вместо нестабильного режима по умолчанию (Play Console).
  if (!kIsWeb && Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
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

  final container = ProviderContainer();
  await container.read(localeControllerProvider.notifier).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const IShopApp(),
    ),
  );
}

class IShopApp extends ConsumerStatefulWidget {
  const IShopApp({super.key});

  @override
  ConsumerState<IShopApp> createState() => _IShopAppState();
}

class _IShopAppState extends ConsumerState<IShopApp> {
  @override
  void initState() {
    super.initState();
    // Даём Dio interceptor доступ к сетевому состоянию
    WidgetsBinding.instance.addPostFrameCallback((_) {
      networkNotifierRef = ref.read(networkProvider.notifier);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Инициализируем синхронизацию корзины при запуске приложения
    ref.watch(cartSyncProvider);
    
    // Запускаем фоновую синхронизацию
    ref.watch(autoSyncProvider);
    
    // Инициализируем сервис уведомлений
    ref.watch(notificationInitializedProvider);

    // Держим монитор сети активным
    ref.watch(networkProvider);

    // Перестраиваем дерево при смене языка
    final locale = ref.watch(localeControllerProvider);

    // Material/Cupertino не знают локаль `tg` — для системных виджетов
    // (RefreshIndicator, AppBar) используем `ru`, а наши строки идут из JSON.
    final materialLocale =
        locale.code == AppLocale.tg ? const Locale('ru') : Locale(locale.code);
    
    return MaterialApp.router(
      key: ValueKey('locale-${locale.code}'),
      title: 'SSBOSS',
      theme: buildTheme(),
      locale: materialLocale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: (context, child) {
        return NetworkStatusBanner(
          child: AppUpdateChecker(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
