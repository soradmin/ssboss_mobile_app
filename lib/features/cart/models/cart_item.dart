import '../../catalog/models/product.dart';

class CartItem {
  final Product product;
  final int qty;
  // Выбранные атрибуты: ключ - id атрибута, значение - id выбранного значения
  final Map<int, int> selectedAttributes;
  CartItem({
    required this.product,
    required this.qty,
    this.selectedAttributes = const {},
  });
  double get subtotal => product.price * qty;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Парсим выбранные атрибуты
    Map<int, int> attributes = {};
    if (json['selectedAttributes'] is Map) {
      final attrMap = json['selectedAttributes'] as Map;
      attributes = attrMap.map((key, value) => 
        MapEntry(int.tryParse(key.toString()) ?? 0, int.tryParse(value.toString()) ?? 0),
      );
    }
    
    return CartItem(
      product: Product.fromJson(json['product']),
      qty: json['qty'] ?? 1,
      selectedAttributes: attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'qty': qty,
      'selectedAttributes': selectedAttributes.map((key, value) => 
        MapEntry(key.toString(), value.toString()),
      ),
    };
  }
}
