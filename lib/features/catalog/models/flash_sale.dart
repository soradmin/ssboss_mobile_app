import 'product.dart';

class FlashSale {
  final int id;
  final String title;
  final int status;
  final String startTime;
  final String endTime;
  final List<FlashSaleProduct> products;

  FlashSale({
    required this.id,
    required this.title,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.products,
  });

  factory FlashSale.fromJson(Map<String, dynamic> json) {
    return FlashSale(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => FlashSaleProduct.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FlashSaleProduct {
  final int id;
  final int productId;
  final int flashSaleId;
  final double price;
  final Product productData;

  FlashSaleProduct({
    required this.id,
    required this.productId,
    required this.flashSaleId,
    required this.price,
    required this.productData,
  });

  factory FlashSaleProduct.fromJson(Map<String, dynamic> json) {
    final productDataJson = json['product_data'] as Map<String, dynamic>?;
    
    // Используем цену из flash_sale, если она есть, иначе из product_data
    // Обрабатываем как строку, так и число
    double? flashSalePrice;
    final priceValue = json['price'];
    if (priceValue != null) {
      if (priceValue is num) {
        flashSalePrice = priceValue.toDouble();
      } else if (priceValue is String) {
        flashSalePrice = double.tryParse(priceValue);
      }
    }
    
    Product productData;
    if (productDataJson != null) {
      // Создаем Product из product_data
      final prices = resolveProductPriceFields(productDataJson);

      productData = Product(
        id: (productDataJson['id'] ?? json['product_id'] ?? 0) as int,
        name: (productDataJson['title'] ?? '').toString(),
        image: (productDataJson['image'] ?? '').toString(),
        price: flashSalePrice ?? prices.price,
        oldPrice: prices.oldPrice,
        rating: (productDataJson['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (productDataJson['review_count'] ?? 0) as int,
        badge: productDataJson['badge']?.toString(),
      );
    } else {
      productData = Product(
        id: json['product_id'] as int? ?? 0,
        name: '',
        image: '',
        price: flashSalePrice ?? 0.0,
      );
    }
    
    return FlashSaleProduct(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      flashSaleId: json['flash_sale_id'] as int? ?? 0,
      price: flashSalePrice ?? productData.price,
      productData: productData,
    );
  }
}

