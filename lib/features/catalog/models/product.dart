import 'media.dart'; // Импортируем новые модели

class ProductAttribute {
  final int id;
  final String title;
  final List<ProductAttributeValue> values;
  ProductAttribute({required this.id, required this.title, required this.values});

  factory ProductAttribute.fromJson(Map<String, dynamic> j) => ProductAttribute(
    id: (j['id'] ?? 0) as int,
    title: _attrText(j['title'] ?? j['name'] ?? j['slug']),
    values: (j['values'] as List?)
            ?.map((v) => ProductAttributeValue.fromJson(
                  v is Map<String, dynamic>
                      ? v
                      : Map<String, dynamic>.from(v as Map),
                ))
            .toList() ??
        [],
  );
}

class ProductAttributeValue {
  final int id; // inventory_id (если пришёл из join)
  final int attributeValueId; // attribute_value_id — для выбора в корзине
  final String title;
  /// Цена конкретной позиции склада. `null`/`0` = базовая цена товара.
  final double? price;

  ProductAttributeValue({
    required this.id,
    required this.attributeValueId,
    required this.title,
    this.price,
  });

  factory ProductAttributeValue.fromJson(Map<String, dynamic> j) {
    final rawTitle = _attrText(j['title'] ?? j['name'] ?? j['value'] ?? j['slug']);
    final rawPrice = j['price'];
    double? price;
    if (rawPrice != null) {
      price = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice.toString());
      if (price != null && price <= 0) price = null;
    }
    return ProductAttributeValue(
      id: (j['inventory_id'] ?? j['id'] ?? 0) as int,
      attributeValueId: (j['attribute_value_id'] ?? j['id'] ?? 0) as int,
      title: rawTitle,
      price: price,
    );
  }
}

String _attrText(dynamic raw) {
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty || s == 'null') return '';
  return s;
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
  final String? sellerLogo;
  final String? description; // Описание товара
  final List<String> descriptionImages; // Изображения в описании товара
  final List<ProductImage> images; // Список всех изображений
  final List<ProductVideo> videos; // Список всех видео
  final List<ProductAttribute> attributes;

  /// Товар со скидкой: есть зачёркнутая старая цена (selling) и цена со скидкой (offered).
  bool get hasDiscount {
    if (oldPrice == null) return false;
    return oldPrice! > price && (oldPrice! - price) >= 0.01;
  }

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
    this.sellerLogo,
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
    // API часто отдаёт title=null, а человекочитаемое имя лежит в slug.
    String name = (j['name'] ?? j['title'] ?? '').toString().trim();
    if (name.isEmpty || name == 'null') {
      name = (j['slug'] ?? '').toString().trim();
    }
    final String image = (j['image'] ?? j['thumbnail'] ?? j['thumb'] ?? '').toString();
    final prices = resolveProductPriceFields(j);
    final double price = prices.price;
    final double? oldPrice = prices.oldPrice;
    final double rating = _toDouble(j['rating'] ?? 0);
    final int reviewCount = _toInt(j['review_count'] ?? j['reviews_count'] ?? j['total_reviews'] ?? 0);
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
    String? sellerLogo;
    if (j['store'] is Map) {
      final storeMap = j['store'] as Map;
      sellerLogo = (storeMap['image'] ?? storeMap['logo'] ?? storeMap['thumb'] ?? storeMap['photo'])
          ?.toString();
      if (sellerLogo != null && (sellerLogo.isEmpty || sellerLogo == 'null')) {
        sellerLogo = null;
      }
    }

    // Ищем описание: на бэкенде это description (HTML) и overview.
    String? description;
    for (final key in [
      'description',
      'overview',
      'content',
      'details',
      'product_description',
      'long_description',
      'summary',
      'about',
    ]) {
      final extracted = extractLocalizedText(j[key]);
      if (extracted != null && extracted.isNotEmpty) {
        description = extracted;
        print('[DEBUG] Found description in field "$key"');
        break;
      }
    }
    final descriptionImages = extractHtmlImageUrls(description);

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
      sellerLogo: sellerLogo,
      description: description,
      descriptionImages: descriptionImages,
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
      'sellerLogo': sellerLogo,
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
                          'attribute_value_id': v.attributeValueId,
                          'title': v.title,
                          if (v.price != null) 'price': v.price,
                        })
                    .toList(),
              })
          .toList(),
    };
  }

  /// Цена с учётом выбранных вариантов (inventory.price > 0).
  /// Если у варианта цена 0/null — базовая [price] товара (как на сайте).
  double priceForSelectedAttributes(Map<int, int> selected) {
    double? variantPrice;
    for (final attr in attributes) {
      final valueId = selected[attr.id];
      if (valueId == null || valueId <= 0) continue;
      for (final v in attr.values) {
        if (v.attributeValueId == valueId && v.price != null && v.price! > 0) {
          variantPrice = v.price;
          break;
        }
      }
    }
    return variantPrice ?? price;
  }

  Product copyWith({
    int? id,
    String? name,
    String? image,
    double? price,
    double? oldPrice,
    double? rating,
    int? reviewCount,
    String? badge,
    String? sellerName,
    double? sellerRating,
    String? storeSlug,
    String? sellerLogo,
    String? description,
    List<String>? descriptionImages,
    List<ProductImage>? images,
    List<ProductVideo>? videos,
    List<ProductAttribute>? attributes,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      badge: badge ?? this.badge,
      sellerName: sellerName ?? this.sellerName,
      sellerRating: sellerRating ?? this.sellerRating,
      storeSlug: storeSlug ?? this.storeSlug,
      sellerLogo: sellerLogo ?? this.sellerLogo,
      description: description ?? this.description,
      descriptionImages: descriptionImages ?? this.descriptionImages,
      images: images ?? this.images,
      videos: videos ?? this.videos,
      attributes: attributes ?? this.attributes,
    );
  }
}

/// Текст из HTML / вложенных {ru, tg, en}.
String? extractLocalizedText(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    for (final key in ['ru', 'tg', 'en', 'description', 'text', 'content', 'value']) {
      final inner = extractLocalizedText(raw[key]);
      if (inner != null && inner.isNotEmpty) return inner;
    }
    for (final value in raw.values) {
      final inner = extractLocalizedText(value);
      if (inner != null && inner.isNotEmpty) return inner;
    }
    return null;
  }
  if (raw is List) {
    for (final item in raw) {
      final inner = extractLocalizedText(item);
      if (inner != null && inner.isNotEmpty) return inner;
    }
    return null;
  }
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return s;
}

List<String> extractHtmlImageUrls(String? html) {
  if (html == null || html.isEmpty) return const [];
  final urls = <String>[];
  final imgRegex = RegExp(
    '<img[^>]+src=["\']([^"\']+)["\'][^>]*>',
    caseSensitive: false,
  );
  for (final match in imgRegex.allMatches(html)) {
    final imageUrl = match.group(1);
    if (imageUrl == null || imageUrl.isEmpty) continue;
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : 'https://ssboss.shop${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
    urls.add(fullUrl);
  }
  return urls;
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

/// selling — Продажа(SM), offered — Предложенный(SM) (скидка).
/// offered == 0 означает отсутствие скидки — показываем только selling.
({double price, double? oldPrice}) resolveProductPriceFields(
  Map<String, dynamic> j,
) {
  final selling = _toDoubleOrNull(j['selling']);
  final offered = _toDoubleOrNull(j['offered']);
  final explicit = _toDoubleOrNull(j['price']);

  if (offered != null && offered > 0) {
    return (
      price: offered,
      oldPrice: (selling != null && selling > 0 && selling != offered)
          ? selling
          : null,
    );
  }

  return (
    price: selling ?? explicit ?? 0.0,
    oldPrice: null,
  );
}