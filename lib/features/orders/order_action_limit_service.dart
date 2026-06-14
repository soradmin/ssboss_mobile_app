import 'package:shared_preferences/shared_preferences.dart';

/// Ограничивает отмену/повтор одного заказа (защита от злоупотреблений).
class OrderActionLimitService {
  static const int maxActionsPerOrder = 3;

  static String _key(int orderId) => 'order_action_count_$orderId';

  static Future<int> getActionCount(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(orderId)) ?? 0;
  }

  static Future<int> getRemainingActions(int orderId) async {
    final used = await getActionCount(orderId);
    final remaining = maxActionsPerOrder - used;
    return remaining < 0 ? 0 : remaining;
  }

  static Future<bool> canPerformAction(int orderId) async {
    return await getActionCount(orderId) < maxActionsPerOrder;
  }

  static Future<void> recordAction(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(orderId)) ?? 0;
    await prefs.setInt(_key(orderId), current + 1);
  }
}
