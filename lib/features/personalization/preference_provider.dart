import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_preference_service.dart';

final userPreferenceServiceProvider = Provider<UserPreferenceService>(
  (_) => UserPreferenceService.instance,
);

final preferenceProfileProvider = FutureProvider<PreferenceProfile>((ref) async {
  final service = ref.watch(userPreferenceServiceProvider);
  return service.loadProfile();
});
