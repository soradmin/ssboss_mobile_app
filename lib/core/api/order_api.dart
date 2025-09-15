import 'dart:convert';
import 'package:http/http.dart' as http;
import '../crypto/aes_zero.dart';

class OrderApi {
  static const _base = 'https://ssboss.shop/api/v1';

  static Future<http.Response> placeOrder({
    required String userToken,
    required int orderMethod,          // число, как в веб-пэйлоаде (у тебя мы видели 2)
    String voucher = '',
    String timeZone = 'Asia/Tashkent',
  }) {
    final payload = {
      'user_token': userToken,
      'order_method': orderMethod,
      'voucher': voucher,
      'time_zone': timeZone,
    };

    final encrypted = encryptMap(payload);
    final body = jsonEncode({'data': encrypted});

    return http.post(
      Uri.parse('$_base/order/action'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: body,
    );
  }
}
