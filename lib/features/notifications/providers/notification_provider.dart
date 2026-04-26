import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

/// Провайдер для сервиса уведомлений
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Провайдер для проверки инициализации уведомлений
final notificationInitializedProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(notificationServiceProvider);
  await service.initialize();
  return service.isInitialized;
});

