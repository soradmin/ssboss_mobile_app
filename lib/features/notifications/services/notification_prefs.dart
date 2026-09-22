import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальные настройки категорий push (OS permission остаётся отдельно).
class NotificationPrefs {
  static const _ordersKey = 'notif_pref_orders';
  static const _promosKey = 'notif_pref_promos';
  static const _storesKey = 'notif_pref_stores';
  static const _priceKey = 'notif_pref_price';

  bool orders;
  bool promos;
  bool stores;
  bool priceDrops;

  NotificationPrefs({
    this.orders = true,
    this.promos = true,
    this.stores = true,
    this.priceDrops = true,
  });

  static Future<NotificationPrefs> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      orders: prefs.getBool(_ordersKey) ?? true,
      promos: prefs.getBool(_promosKey) ?? true,
      stores: prefs.getBool(_storesKey) ?? true,
      priceDrops: prefs.getBool(_priceKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ordersKey, orders);
    await prefs.setBool(_promosKey, promos);
    await prefs.setBool(_storesKey, stores);
    await prefs.setBool(_priceKey, priceDrops);
  }

  NotificationPrefs copyWith({
    bool? orders,
    bool? promos,
    bool? stores,
    bool? priceDrops,
  }) {
    return NotificationPrefs(
      orders: orders ?? this.orders,
      promos: promos ?? this.promos,
      stores: stores ?? this.stores,
      priceDrops: priceDrops ?? this.priceDrops,
    );
  }
}

class NotificationPrefsNotifier extends StateNotifier<AsyncValue<NotificationPrefs>> {
  NotificationPrefsNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = AsyncValue.data(await NotificationPrefs.load());
  }

  Future<void> update(NotificationPrefs Function(NotificationPrefs) fn) async {
    final current = state.valueOrNull ?? await NotificationPrefs.load();
    final next = fn(current);
    await next.save();
    state = AsyncValue.data(next);
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, AsyncValue<NotificationPrefs>>(
  (ref) => NotificationPrefsNotifier(),
);
