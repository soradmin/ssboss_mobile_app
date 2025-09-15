class Product {
  final int id;
  final String name;
  final String image;
  final double price;
  final double? oldPrice;
  final double rating;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.oldPrice,
    this.rating = 0,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: (j['id'] ?? 0) as int,
        name: (j['name'] ?? j['title'] ?? '').toString(),
        image: (j['image'] ?? j['thumbnail'] ?? j['thumb'] ?? '').toString(),
        price: _toDouble(j['price'] ?? j['offered'] ?? j['selling'] ?? 0),
        oldPrice: j['selling'] != null ? _toDouble(j['selling']) : null,
        rating: _toDouble(j['rating'] ?? 0),
      );
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
