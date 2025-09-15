import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')), // <-- const только у Text
      body: const Center(child: Text('Тут будут заказы пользователя')),
    );
  }
}
