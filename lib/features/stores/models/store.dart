class Store {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? logo;
  final String? banner;
  final double rating;
  final int totalProducts;
  final int followersCount;
  final String memberSince;
  final bool isFollowing;
  final String? website;
  final String? email;
  final String? phone;
  final String? address;

  const Store({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.logo,
    this.banner,
    required this.rating,
    required this.totalProducts,
    required this.followersCount,
    required this.memberSince,
    required this.isFollowing,
    this.website,
    this.email,
    this.phone,
    this.address,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    print('[DEBUG] Store.fromJson: Обрабатываем JSON: $json');
    
    // Безопасное извлечение ID
    int storeId;
    if (json['id'] is int) {
      storeId = json['id'] as int;
    } else if (json['id'] is String) {
      storeId = int.tryParse(json['id'] as String) ?? 0;
    } else {
      storeId = 0;
    }
    
    // Безопасное извлечение рейтинга
    double storeRating = 0.0;
    // Пробуем разные поля для рейтинга
    if (json['review'] != null) {
      if (json['review'] is double) {
        storeRating = json['review'] as double;
      } else if (json['review'] is int) {
        storeRating = (json['review'] as int).toDouble();
      } else if (json['review'] is String) {
        storeRating = double.tryParse(json['review'] as String) ?? 0.0;
      }
    }
    if (storeRating == 0.0 && json['rating'] != null) {
      if (json['rating'] is double) {
        storeRating = json['rating'] as double;
      } else if (json['rating'] is int) {
        storeRating = (json['rating'] as int).toDouble();
      } else if (json['rating'] is String) {
        storeRating = double.tryParse(json['rating'] as String) ?? 0.0;
      }
    }
    
    // Безопасное извлечение количества товаров
    int productsCount = 0;
    // Пробуем извлечь из result.total (если данные из getStoreBySlug)
    if (json['result'] is Map && (json['result'] as Map)['total'] != null) {
      final result = json['result'] as Map;
      if (result['total'] is int) {
        productsCount = result['total'] as int;
      } else if (result['total'] is String) {
        productsCount = int.tryParse(result['total'] as String) ?? 0;
      }
    }
    if (productsCount == 0) {
      if (json['total_products'] is int) {
        productsCount = json['total_products'] as int;
      } else if (json['total_products'] is String) {
        productsCount = int.tryParse(json['total_products'] as String) ?? 0;
      } else if (json['products_count'] is int) {
        productsCount = json['products_count'] as int;
      } else if (json['total'] is int) {
        productsCount = json['total'] as int;
      } else if (json['total'] is String) {
        productsCount = int.tryParse(json['total'] as String) ?? 0;
      }
    }
    
    // Безопасное извлечение количества подписчиков
    int followers;
    if (json['followers_count'] is int) {
      followers = json['followers_count'] as int;
    } else if (json['followers_count'] is String) {
      followers = int.tryParse(json['followers_count'] as String) ?? 0;
    } else if (json['followers'] is int) {
      followers = json['followers'] as int;
    } else {
      followers = 0;
    }
    
    print('[DEBUG] Store.fromJson: ID: $storeId, Рейтинг: $storeRating, Товары: $productsCount, Подписчики: $followers');
    print('[DEBUG] Store.fromJson: Ключи JSON: ${json.keys.toList()}');
    print('[DEBUG] Store.fromJson: name=${json['name']}, title=${json['title']}, shop_name=${json['shop_name']}, store_name=${json['store_name']}');
    
    // Ищем название магазина в разных полях
    String? storeName;
    storeName = json['name'] as String?;
    if (storeName == null || storeName.isEmpty) {
      storeName = json['title'] as String?;
    }
    if (storeName == null || storeName.isEmpty) {
      storeName = json['shop_name'] as String?;
    }
    if (storeName == null || storeName.isEmpty) {
      storeName = json['store_name'] as String?;
    }
    if (storeName == null || storeName.isEmpty) {
      storeName = json['seller_name'] as String?;
    }
    
    final finalName = storeName?.trim() ?? 'Неизвестный магазин';
    print('[DEBUG] Store.fromJson: Финальное название магазина: $finalName');
    
    return Store(
      id: storeId,
      name: finalName,
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      logo: json['logo'] as String? ?? json['image'] as String?,
      banner: json['banner'] as String?,
      rating: storeRating,
      totalProducts: productsCount,
      followersCount: followers,
      memberSince: json['member_since'] as String? ?? json['created_at'] as String? ?? '',
      isFollowing: json['is_following'] == true || json['is_following'] == 1,
      website: json['website'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'logo': logo,
      'banner': banner,
      'rating': rating,
      'total_products': totalProducts,
      'followers_count': followersCount,
      'member_since': memberSince,
      'is_following': isFollowing,
      'website': website,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }

  @override
  String toString() {
    return 'Store(id: $id, name: $name, slug: $slug, rating: $rating, isFollowing: $isFollowing)';
  }

  // Получить отформатированный рейтинг
  String get formattedRating {
    return rating.toStringAsFixed(1);
  }

  // Получить отформатированное количество подписчиков
  String get formattedFollowers {
    if (followersCount >= 1000000) {
      return '${(followersCount / 1000000).toStringAsFixed(1)}M';
    } else if (followersCount >= 1000) {
      return '${(followersCount / 1000).toStringAsFixed(1)}K';
    } else {
      return followersCount.toString();
    }
  }

  // Получить отформатированное количество товаров
  String get formattedProducts {
    if (totalProducts >= 1000000) {
      return '${(totalProducts / 1000000).toStringAsFixed(1)}M';
    } else if (totalProducts >= 1000) {
      return '${(totalProducts / 1000).toStringAsFixed(1)}K';
    } else {
      return totalProducts.toString();
    }
  }

  // Получить отформатированную дату регистрации
  String get formattedMemberSince {
    try {
      final date = DateTime.parse(memberSince);
      return '${date.day}.${date.month}.${date.year}';
    } catch (e) {
      return memberSince;
    }
  }

  // Создать копию с обновленным статусом подписки
  Store copyWith({
    bool? isFollowing,
    int? followersCount,
  }) {
    return Store(
      id: id,
      name: name,
      slug: slug,
      description: description,
      logo: logo,
      banner: banner,
      rating: rating,
      totalProducts: totalProducts,
      followersCount: followersCount ?? this.followersCount,
      memberSince: memberSince,
      isFollowing: isFollowing ?? this.isFollowing,
      website: website,
      email: email,
      phone: phone,
      address: address,
    );
  }
}
