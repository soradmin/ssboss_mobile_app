import '../../core/network/api_client.dart';

class CheckoutRepository {
  CheckoutRepository(this._api);
  final ApiClient _api;

  Future<http.Response> placeOrder({
    required String userToken,
    required int orderMethod,          // 1/2/… как у вас
    String voucher = '',
    String timeZone = 'Asia/Tashkent',
  }) {
    return _api.postEncrypted(
      '/api/v1/order/action',          // подтвержденный endpoint
      {
        'user_token': userToken,
        'order_method': orderMethod,
        'voucher': voucher,
        'time_zone': timeZone,
      },
    );
  }

  /// В вебе это “paymentDone” через общий транспорт, но RESTом обычно:
  /// либо /api/v1/order/payment-done, либо ещё раз /order/action c другим набором полей.
  /// Посмотрите в DevTools, какой URL уходит после placeOrder — и подставьте его сюда.
  Future<http.Response> paymentDone({
    required int orderId,
    required int orderMethod,
    required String userToken,
  }) {
    return _api.postEncrypted(
      // если в DevTools увидите иной адрес — замените строку ниже:
      '/api/v1/order/payment-done',
      {
        'id': orderId,
        'payment_token': orderId,      // у них действительно уходит id как token
        'order_method': orderMethod,
        'user_token': userToken,
      },
    );
  }
}
