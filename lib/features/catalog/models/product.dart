import 'media.dart'; // Импортируем новые модели

class ProductAttribute {
  final int id;
  final String title;
  final List<ProductAttributeValue> values;
  ProductAttribute({required this.id, required this.title, required this.values});
  factory ProductAttribute.fromJson(Map<String, dynamic> j) => ProductAttribute(
    id: (j['id'] ?? 0) as int,
    title: (j['title'] ?? '').toString(),
    values: (j['values'] as List?)?.map((v) => ProductAttributeValue.fromJson(v)).toList() ?? [],
  );
}
class ProductAttributeValue {
  final int id; // inventory_id
  final int attributeValueId; // attribute_value_id - это то, что нужно для выбора атрибутов
  final String title;
  ProductAttributeValue({required this.id, required this.attributeValueId, required this.title});
  factory ProductAttributeValue.fromJson(Map<String, dynamic> j) => ProductAttributeValue(
    id: (j['id'] ?? j['inventory_id'] ?? 0) as int,
    attributeValueId: (j['attribute_value_id'] ?? j['id'] ?? 0) as int, // Используем attribute_value_id если есть, иначе id
    title: j['title']?.toString() ?? '',
  );
}

class Product {
  final int id;
  final String name;
  final String image; // Основное изображение (оставим для совместимости)
  final double price;
  final double? oldPrice;
  final double rating;
  final int reviewCount; // Количество отзывов
  final String? badge; // Бейдж товара (New, Trending, etc.)
  final String? sellerName; // Название продавца/магазина
  final double? sellerRating; // Рейтинг продавца
  final String? storeSlug; // Slug магазина для навигации
  final String? description; // Описание товара
  final List<String> descriptionImages; // Изображения в описании товара
  final List<ProductImage> images; // Список всех изображений
  final List<ProductVideo> videos; // Список всех видео
  final List<ProductAttribute> attributes;

  Product({
    required this.id,
    required this.name,
    required this.image,
    required this.price,
    this.oldPrice,
    this.rating = 0,
    this.reviewCount = 0,
    this.badge,
    this.sellerName,
    this.sellerRating,
    this.storeSlug,
    this.description,
    this.descriptionImages = const [], // По умолчанию пустой список
    this.images = const [], // По умолчанию пустой список
    this.videos = const [], // По умолчанию пустой список
    this.attributes = const [],
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    // Отладочная информация для проверки полей
    print('[DEBUG] Product JSON keys: ${j.keys.toList()}');
    for (final key in j.keys) {
      if (key.toString().toLowerCase().contains('desc') || 
          key.toString().toLowerCase().contains('content') ||
          key.toString().toLowerCase().contains('detail')) {
        print('[DEBUG] Found potential description field "$key": ${j[key]}');
      }
    }
    
    // Старая логика для основных полей
    final int id = (j['id'] ?? 0) as int;
    final String name = (j['name'] ?? j['title'] ?? '').toString();
    final String image = (j['image'] ?? j['thumbnail'] ?? j['thumb'] ?? '').toString();
    final double price = _toDouble(j['price'] ?? j['offered'] ?? j['selling'] ?? 0);
    final double? oldPrice = j['selling'] != null ? _toDouble(j['selling']) : null;
    final double rating = _toDouble(j['rating'] ?? 0);
    final int reviewCount = (j['review_count'] ?? j['reviews_count'] ?? 0) as int;
    final String? badge = j['badge']?.toString();
    // Парсим название продавца/магазина из разных полей
    String? sellerName = j['seller_name'] ?? j['shop_name'] ?? j['seller'] ?? j['shop']?.toString();
    if (sellerName == null || sellerName.isEmpty) {
      if (j['store'] is Map) {
        final storeMap = j['store'] as Map;
        sellerName = storeMap['name']?.toString() ?? storeMap['title']?.toString();
      }
      if ((sellerName == null || sellerName.isEmpty) && j['shop'] is Map) {
        final shopMap = j['shop'] as Map;
        sellerName = shopMap['name']?.toString() ?? shopMap['title']?.toString();
      }
    }
    // Парсим рейтинг продавца
    double? sellerRating = j['seller_rating'] != null ? _toDouble(j['seller_rating']) : null;
    if (sellerRating == null) {
      if (j['store'] is Map) {
        final storeMap = j['store'] as Map;
        if (storeMap['rating'] != null) {
          sellerRating = _toDouble(storeMap['rating']);
        }
      }
    }
    print('[DEBUG PRODUCT] Парсинг продавца: sellerName=$sellerName, sellerRating=$sellerRating');
    // Парсим slug магазина из разных полей
    String? storeSlug = j['store_slug'] ?? j['shop_slug'] ?? j['seller_slug'];
    if (storeSlug == null || storeSlug.isEmpty) {
      if (j['store'] is Map) {
        final storeMap = j['store'] as Map;
        storeSlug = storeMap['slug']?.toString();
      }
      if ((storeSlug == null || storeSlug.isEmpty) && j['shop'] is Map) {
        final shopMap = j['shop'] as Map;
        storeSlug = shopMap['slug']?.toString();
      }
    }
    // Ищем описание в различных возможных полях
    String? description;
    for (final key in ['description', 'content', 'details', 'product_description', 'long_description', 'summary', 'about']) {
      if (j[key] != null && j[key].toString().trim().isNotEmpty) {
        description = j[key].toString().trim();
        print('[DEBUG] Found description in field "$key": $description');
        break;
      }
    }

    // Новая логика для изображений и видео
    List<ProductImage> images = [];
    List<ProductVideo> videos = [];
    List<ProductAttribute> attributes = [];

    // Проверяем, есть ли данные в j['images']
    if (j['images'] is List) {
      images = (j['images'] as List)
          .map((item) => item is Map<String, dynamic> ? ProductImage.fromJson(item) : ProductImage(image: '', thumb: ''))
          .toList();
    }

    // Проверяем, есть ли данные в j['videos']
    if (j['videos'] is List) {
      videos = (j['videos'] as List)
          .map((item) => item is Map<String, dynamic> ? ProductVideo.fromJson(item) : ProductVideo(video: ''))
          .toList();
    }
    // Пробуем разные варианты ключей для атрибутов
    final attrData = j['attribute'] ?? j['attributes'] ?? j['product_attribute'] ?? j['product_attributes'];
    if (attrData is List) {
      final attrList = attrData as List;
      print('[DEBUG] Найдены атрибуты (${attrList.length}): $attrList');
      attributes = attrList
          .map((a) {
            if (a is Map<String, dynamic>) {
              print('[DEBUG] Парсим атрибут: $a');
              print('[DEBUG] Ключи атрибута: ${a.keys.toList()}');
              try {
                final parsed = ProductAttribute.fromJson(a);
                print('[DEBUG] Успешно распарсен атрибут: ${parsed.title}, значений: ${parsed.values.length}');
                return parsed;
              } catch (e) {
                print('[DEBUG] Ошибка парсинга атрибута: $e');
                return null;
              }
            } else {
              print('[DEBUG] Пропускаем невалидный атрибут (не Map): $a');
              return null;
            }
          })
          .where((a) => a != null)
          .cast<ProductAttribute>()
          .toList();
      print('[DEBUG] Успешно распарсено атрибутов: ${attributes.length}');
    } else if (attrData != null) {
      print('[DEBUG] Атрибуты найдены, но не являются списком. Тип: ${attrData.runtimeType}, значение: $attrData');
      // Попробуем преобразовать в список, если это объект
      if (attrData is Map) {
        print('[DEBUG] Пробуем преобразовать Map в список атрибутов');
        final map = attrData as Map<String, dynamic>;
        attributes = map.entries.map((entry) {
          print('[DEBUG] Обрабатываем ключ: ${entry.key}, значение: ${entry.value}');
          // Если значение - список, считаем его значениями атрибута
          if (entry.value is List) {
            final values = (entry.value as List).map((v) {
              if (v is Map) {
                return ProductAttributeValue.fromJson(v as Map<String, dynamic>);
              } else {
                return ProductAttributeValue(id: 0, attributeValueId: 0, title: v.toString());
              }
            }).toList();
            return ProductAttribute(id: 0, title: entry.key, values: values);
          } else {
            return ProductAttribute(
              id: 0,
              title: entry.key,
              values: [ProductAttributeValue(id: 0, attributeValueId: 0, title: entry.value.toString())],
            );
          }
        }).toList();
        print('[DEBUG] Преобразовано атрибутов из Map: ${attributes.length}');
      }
    } else {
      print('[DEBUG] Атрибуты не найдены. Проверены ключи: attribute, attributes, product_attribute, product_attributes');
    }

    return Product(
      id: id,
      name: name,
      image: image,
      price: price,
      oldPrice: oldPrice,
      rating: rating,
      reviewCount: reviewCount,
      badge: badge,
      sellerName: sellerName,
      sellerRating: sellerRating,
      storeSlug: storeSlug,
      description: description,
      descriptionImages: const [], // Будет заполнено позже через API
      images: images,
      videos: videos,
      attributes: attributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'price': price,
      'oldPrice': oldPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'badge': badge,
      'sellerName': sellerName,
      'sellerRating': sellerRating,
      'storeSlug': storeSlug,
      'description': description,
      'descriptionImages': descriptionImages,
      'images': images.map((img) => img.toJson()).toList(),
      'videos': videos.map((vid) => vid.toJson()).toList(),
      'attribute': attributes
          .map((a) => {
                'id': a.id,
                'title': a.title,
                'values': a.values
                    .map((v) => {
                          'id': v.id,
                          'title': v.title,
                        })
                    .toList(),
              })
          .toList(),
    };
  }
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;