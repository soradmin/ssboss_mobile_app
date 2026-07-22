import 'package:flutter/material.dart';

import 'app_update_service.dart';

/// Запускает проверку обновления один раз после появления UI.
class AppUpdateChecker extends StatefulWidget {
  final Widget child;

  const AppUpdateChecker({super.key, required this.child});

  @override
  State<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends State<AppUpdateChecker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        AppUpdateService.instance.checkAndPrompt(context);
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
