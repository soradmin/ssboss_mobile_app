import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(CartItem item) {
    final idx = state.indexWhere((e) => e.product.id == item.product.id);
    if (idx == -1) {
      state = [...state, item];
    } else {
      final ex = state[idx];
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) CartItem(product: ex.product, qty: ex.qty + item.qty) else state[i]
      ];
    }
  }

  void remove(int productId) => state = state.where((e) => e.product.id != productId).toList();
  void clear() => state = [];
  int get count => state.fold(0, (p, e) => p + e.qty);
  double get total => state.fold(0.0, (p, e) => p + e.subtotal);
}

final cartProvider = NotifierProvider<CartController, List<CartItem>>(() => CartController());
