import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/config.dart';               // тут берём userToken / lang
import '../../../core/crypto/aes_zero.dart';

class OrderActionResponse {
  final int status;   // 200, 201 и т.п.
  final Map<String, dynamic>? data;
  OrderActionResponse(this.status, this.data);

  factory OrderActionResponse.fromJson(Map<String, dynamic> j) =>
      OrderActionResponse(j['status'] ?? 0, j['data'] as Map<String, dynamic>?);
}

class CheckoutApi {
  final String base = dotenv.get('API_BASE');

  Future<OrderActionResponse> placeOrder({
    required int orderMethod,
    String voucher = '',
    String? timeZone,
  }) async {
    final token = await AppConfig.getUserToken();
    final lang  = dotenv.maybeGet('LANG_CODE') ?? 'en';
    final tz    = timeZone ?? DateTime.now().timeZoneName; // можно подставлять 'Asia/Tashkent'

    final payload = {
      'user_token': token,
      'order_method': orderMethod,
      'voucher': voucher,
      'time_zone': tz,
    };

    final body = jsonEncode({'data': encryptMap(payload)});

    final uri = Uri.parse('$base/order/action');
    final res = await http.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
        'Language': lang,
      },
      body: body,
    );

    final Map<String, dynamic> j = jsonDecode(utf8.decode(res.bodyBytes));
    return OrderActionResponse.fromJson(j);
  }
}
