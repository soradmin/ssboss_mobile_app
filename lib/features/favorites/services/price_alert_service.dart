import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/models/product.dart';
import '../../notifications/services/notification_prefs.dart';
import '../../notifications/services/notification_service.dart';

/// Локальный трекинг цен избранного: при падении цены — локальное уведомление.
class PriceAlertService {
  static const _key = 'wishlist_price_baseline_v1';
  static final PriceAlertService instance = PriceAlertService._();
  PriceAlertService._();

  Future<Map<String, double>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, double> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Сверить текущие цены избранного с сохранёнными и уведомить о снижении.
  Future<List<Product>> checkAndNotify(List<Product> products) async {
    final prefs = await NotificationPrefs.load();
    if (!prefs.priceDrops) {
      await syncBaselines(products);
      return const [];
    }

    final baselines = await _read();
    final drops = <Product>[];
    final next = Map<String, double>.from(baselines);

    for (final p in products) {
      if (p.id <= 0 || p.price <= 0) continue;
      final key = '${p.id}';
      final prev = baselines[key];
      if (prev != null && p.price < prev - 0.009) {
        drops.add(p);
        await NotificationService().showLocalNotification(
          title: '📉 ${p.name}',
          body: 'Цена снизилась: ${prev.toStringAsFixed(0)} → ${p.price.toStringAsFixed(0)} с.',
          payload: jsonEncode({'type': 'product', 'product_id': p.id}),
        );
      }
      next[key] = p.price;
    }

    await _write(next);
    return drops;
  }

  Future<void> syncBaselines(List<Product> products) async {
    final baselines = await _read();
    for (final p in products) {
      if (p.id <= 0 || p.price <= 0) continue;
      baselines['${p.id}'] = p.price;
    }
    await _write(baselines);
  }

  Future<void> removeProduct(int productId) async {
    final baselines = await _read();
    baselines.remove('$productId');
    await _write(baselines);
  }
}
