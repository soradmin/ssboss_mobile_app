import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../services/notification_prefs.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeControllerProvider);
    final asyncPrefs = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
            ),
          ),
        ),
        title: Text(
          context.tr('notifications.settings_title'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: asyncPrefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr('notifications.settings_hint'),
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 16),
            _tile(
              context,
              icon: Icons.shopping_bag_outlined,
              title: context.tr('notifications.pref_orders'),
              subtitle: context.tr('notifications.pref_orders_sub'),
              value: prefs.orders,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .update((p) => p.copyWith(orders: v)),
            ),
            _tile(
              context,
              icon: Icons.local_offer_outlined,
              title: context.tr('notifications.pref_promos'),
              subtitle: context.tr('notifications.pref_promos_sub'),
              value: prefs.promos,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .update((p) => p.copyWith(promos: v)),
            ),
            _tile(
              context,
              icon: Icons.storefront_outlined,
              title: context.tr('notifications.pref_stores'),
              subtitle: context.tr('notifications.pref_stores_sub'),
              value: prefs.stores,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .update((p) => p.copyWith(stores: v)),
            ),
            _tile(
              context,
              icon: Icons.trending_down_rounded,
              title: context.tr('notifications.pref_price'),
              subtitle: context.tr('notifications.pref_price_sub'),
              value: prefs.priceDrops,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .update((p) => p.copyWith(priceDrops: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF9C27B0)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        activeColor: const Color(0xFF9C27B0),
        onChanged: onChanged,
      ),
    );
  }
}
