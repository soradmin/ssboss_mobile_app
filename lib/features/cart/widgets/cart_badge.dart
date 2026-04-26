import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../../catalog/models/product.dart';
import '../../../theme.dart';

class CartBadge extends ConsumerWidget {
  final Widget child;
  final int? productId; // Если указан, показывает количество конкретного товара
  final bool showTotal; // Если true, показывает общее количество в корзине
  
  const CartBadge({
    super.key,
    required this.child,
    this.productId,
    this.showTotal = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    
    int count = 0;
    
    if (showTotal) {
      // Показываем общее количество товаров в корзине
      count = cartItems.fold(0, (sum, item) => sum + item.qty);
    } else if (productId != null) {
      // Показываем количество конкретного товара
      final cartItem = cartItems.firstWhere(
        (item) => item.product.id == productId,
        orElse: () => CartItem(product: Product(id: 0, name: '', image: '', price: 0, images: [], rating: 0, reviewCount: 0), qty: 0),
      );
      count = cartItem.qty;
    }
    
    if (count == 0) {
      return child;
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1),
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
