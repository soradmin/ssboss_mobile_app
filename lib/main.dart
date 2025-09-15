import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'app_router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем конфиг (.env внутри) и гостевой токен
  await AppConfig.ensureLoaded();
  await AppConfig.ensureGuestToken();

  runApp(const ProviderScope(child: IShopApp()));
}

class IShopApp extends StatelessWidget {
  const IShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SSBOSS',
      theme: buildTheme(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
