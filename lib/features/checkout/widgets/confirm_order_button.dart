import 'package:flutter/material.dart';
import 'package:ssboss_wb_app/../../...order_api.dart';
import 'package:ssboss_wb_app/../../...config.dart'; // если нужен гость-токен из AppConfig

class ConfirmOrderButton extends StatelessWidget {
  final String userToken;   // передаём guestToken/токен пользователя
  final int orderMethod;    // 1=COD (наложка), 2=BANK, и т.д.
  final String voucher;     // '' если нет
  final String langCode;    // 'en' или 'ru'

  const ConfirmOrderButton({
    super.key,
    required this.userToken,
    required this.orderMethod,
    this.voucher = '',
    this.langCode = 'en',
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: () async {
        // 1) Создаём заказ
        final a = await placeOrder(
          userToken: userToken,
          orderMethod: orderMethod,
          voucher: voucher,
          timeZone: 'Asia/Tashkent',
          lang: langCode,
        );

        if (a.status == 200) {
          final data = (a.body['data'] as Map<String, dynamic>?);
          final orderId = data?['id'];
          if (orderId is int) {
            // 2) Для COD/BANK — сразу подтверждаем оплату
            if (orderMethod == 1 || orderMethod == 2) {
              final b = await paymentDone(
                orderId: orderId,
                orderMethod: orderMethod,
                userToken: userToken,
                lang: langCode,
              );

              if (b.status == 200) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заказ оформлен')),
                  );
                  // TODO: очистить корзину и перейти на экран заказа
                }
              } else {
                final msg = b.body['data']?['form']?.toString() ?? 'Ошибка оплаты';
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            } else {
              // для других способов оплаты — ваш дальнейший флоу (Stripe, PayPal и т.д.)
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ответ без id заказа')),
              );
            }
          }
        } else if (a.status == 201) {
          final msg = a.body['data']?['form']?.toString() ?? 'Ошибка валидации';
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: HTTP ${a.status}')),
            );
          }
        }
      },
      child: const Text('Оформить заказ'),
    );
  }
}
