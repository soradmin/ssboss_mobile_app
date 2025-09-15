import '../../catalog/models/product.dart';

class CartItem {
  final Product product;
  final int qty;
  const CartItem({required this.product, required this.qty});
  double get subtotal => product.price * qty;
}
