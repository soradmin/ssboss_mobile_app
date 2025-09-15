import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_item.dart';
import '../models/product.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product p;
  const ProductDetailsScreen({super.key, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: p.image.isEmpty
                  ? const ColoredBox(color: Color(0x11000000), child: Center(child: Icon(Icons.image_not_supported_outlined)))
                  : Image.network(p.image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          Text(p.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).add(CartItem(product: p, qty: 1));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар добавлен в корзину')));
            },
            child: const Text('Добавить в корзину'),
          ),
        ],
      ),
    );
  }
}
