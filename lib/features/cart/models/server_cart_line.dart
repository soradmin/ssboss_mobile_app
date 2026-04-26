// lib/features/cart/models/server_cart_line.dart
class ServerCartLine {
  final int id; // cart_item_id, используется для удаления
  final int productId;
  final int inventoryId;
  final int quantity;

  // Данные для отображения, часто приходят внутри объекта 'product'
  final String name;
  final String image;
  final double price;
  
  // Атрибуты товара: ключ - id атрибута, значение - id значения атрибута
  final Map<int, int> selectedAttributes;

  ServerCartLine({
    required this.id,
    required this.productId,
    required this.inventoryId,
    required this.quantity,
    this.name = '',
    this.image = '',
    this.price = 0.0,
    this.selectedAttributes = const {},
  });

  // Метод для создания копии объекта с возможностью изменения некоторых полей
  ServerCartLine copyWith({
    String? name, 
    String? image, 
    double? price,
    Map<int, int>? selectedAttributes,
  }) {
    return ServerCartLine(
      id: id,
      productId: productId,
      inventoryId: inventoryId,
      quantity: quantity,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      selectedAttributes: selectedAttributes ?? this.selectedAttributes,
    );
  }

  @override
  String toString() {
    return 'ServerCartLine(id: $id, productId: $productId, inventoryId: $inventoryId, quantity: $quantity, name: $name, image: $image, price: $price, attributes: $selectedAttributes)';
  }
}