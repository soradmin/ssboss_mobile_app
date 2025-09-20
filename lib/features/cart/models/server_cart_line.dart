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

  ServerCartLine({
    required this.id,
    required this.productId,
    required this.inventoryId,
    required this.quantity,
    this.name = '',
    this.image = '',
    this.price = 0.0,
  });

  // Метод для создания копии объекта с возможностью изменения некоторых полей
  ServerCartLine copyWith({String? name, String? image, double? price}) {
    return ServerCartLine(
      id: id,
      productId: productId,
      inventoryId: inventoryId,
      quantity: quantity,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
    );
  }

  @override
  String toString() {
    return 'ServerCartLine(id: $id, productId: $productId, inventoryId: $inventoryId, quantity: $quantity, name: $name, image: $image, price: $price)';
  }
}