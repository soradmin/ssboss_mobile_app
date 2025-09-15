// lib/features/checkout/screens/checkout_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/config.dart';        // AppConfig.apiBaseUrl, ensureGuestToken, guestToken
import '../../../crypto/aes_zero.dart';     // encryptMap(Map<String, dynamic>)

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _placing = false;
  String? _lastMessage;

  Future<void> _placeOrder() async {
    setState(() {
      _placing = true;
      _lastMessage = null;
    });

    try {
      // гарантируем наличие гостевого токена
      await AppConfig.ensureGuestToken();
      final userToken = AppConfig.guestToken;

      // Готовим payload и шифруем как на вебе (AES-CBC + ZeroPadding)
      final payload = <String, dynamic>{
        'user_token': userToken,
        'order_method': 2,            // выберем COD/другой метод позже; пока 2 как в твоих трейсах
        'voucher': '',
        'time_zone': 'Asia/Tashkent',
      };
      final cipherB64 = encryptMap(payload);

      // 1) Создаём заказ: POST /order/action
      final createUrl = Uri.parse('${AppConfig.apiBaseUrl}/order/action');
      final createRes = await http.post(
        createUrl,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'data': cipherB64}),
      );

      final createJson = jsonDecode(createRes.body);

      if (createJson['status'] == 200) {
        final data = createJson['data'] as Map<String, dynamic>;
        final orderId = data['id'];

        // 2) Отправляем письмо (как делает сайт): GET /order/send-order-email/{id}
        final emailUrl = Uri.parse(
          '${AppConfig.apiBaseUrl}/order/send-order-email/$orderId'
          '?id=$orderId&time_zone=Asia%2FTashkent&user_token=$userToken',
        );
        // не обязательно ждать результат; сделаем запрос "в фоне"
        // но чтобы был явный вызов:
        await http.get(
          emailUrl,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json; charset=UTF-8',
          },
        );

        setState(() {
          _lastMessage = 'Заказ оформлен #$orderId';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_lastMessage!)),
          );
        }
      } else if (createJson['status'] == 201) {
        // сервер вернул ошибки формы (как мы видели ранее)
        final data = createJson['data'];
        final form = (data is Map) ? (data['form'] ?? data['product']) : null;
        String msg = 'Ошибка оформления';
        if (form is List) {
          msg = form.join(', ');
        } else if (form is Map) {
          msg = form.values.join(', ');
        }
        setState(() {
          _lastMessage = msg;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } else {
        setState(() {
          _lastMessage = 'Неожиданный ответ сервера: ${createJson['status']}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_lastMessage!)),
          );
        }
      }
    } catch (e) {
      setState(() {
        _lastMessage = 'Сбой сети/парсинга: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lastMessage!)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _placing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление заказа')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Проверьте товары и подтвердите заказ.\n'
              'Метод оплаты пока фиксированный (как на сайте).',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _placing ? null : _placeOrder,
              child: _placing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Оформить сейчас'),
            ),
            if (_lastMessage != null) ...[
              const SizedBox(height: 16),
              Text(_lastMessage!),
            ],
          ],
        ),
      ),
    );
  }
}
