import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/locale_controller.dart';
import 'network_status.dart';

/// Ключ для глобальных SnackBar из Dio / сетевого монитора.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Баннер поверх всего приложения при отсутствии сети / плохом соединении.
class NetworkStatusBanner extends ConsumerWidget {
  final Widget child;

  const NetworkStatusBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkProvider);
    ref.watch(localeControllerProvider);

    ref.listen<NetworkState>(networkProvider, (prev, next) {
      if (prev?.status == next.status) return;

      if (prev?.status == NetworkStatus.offline &&
          next.status == NetworkStatus.online) {
        _showSnack(
          icon: Icons.wifi,
          message: ref.tr('network.restored'),
          color: const Color(0xFF2E7D32),
          seconds: 2,
        );
      }

      if (next.status == NetworkStatus.poor &&
          prev?.status != NetworkStatus.poor) {
        _showSnack(
          icon: Icons.signal_wifi_statusbar_connected_no_internet_4,
          message: ref.tr('network.poor'),
          color: const Color(0xFFE65100),
          seconds: 3,
        );
      }
    });

    final showOfflineBanner = network.isOffline;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: showOfflineBanner
              ? Material(
                  color: const Color(0xFFC62828),
                  elevation: 2,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('network.offline'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(networkProvider.notifier).recheck();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              context.tr('network.refresh'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(child: child),
      ],
    );
  }

  void _showSnack({
    required IconData icon,
    required String message,
    required Color color,
    required int seconds,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: seconds),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
