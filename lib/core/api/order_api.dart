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
    String? userName,
    String? userEmail,
    int? userId,
    String? notes,
  }) {
    final payload = {
      'user_token': userToken,
      'order_method': orderMethod,
      'voucher': voucher,
      'time_zone': timeZone,
      // Добавляем информацию о пользователе если передана
      if (userName != null) 'user_name': userName,
      if (userEmail != null) 'user_email': userEmail,
      if (userId != null) 'user_id': userId,
      if (notes != null) 'notes': notes,
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
