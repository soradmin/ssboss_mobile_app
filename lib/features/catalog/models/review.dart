class Review {
  final int id;
  final int productId;
  final String? userName;
  final double rating;
  final String? comment;
  final String? createdAt;
  final String? updatedAt;

  const Review({
    required this.id,
    required this.productId,
    this.userName,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    try {
      print('[DEBUG] Review.fromJson: Парсим отзыв, ключи: ${json.keys.toList()}');
      print('[DEBUG] Review.fromJson: Сырые данные: $json');
      
      // Пробуем разные варианты ключей для имени пользователя
      String? userName;
      if (json['user_name'] != null) {
        userName = json['user_name'].toString();
        print('[DEBUG] Review.fromJson: Найдено user_name: $userName');
      } else if (json['userName'] != null) {
        userName = json['userName'].toString();
        print('[DEBUG] Review.fromJson: Найдено userName: $userName');
      } else if (json['name'] != null) {
        userName = json['name'].toString();
        print('[DEBUG] Review.fromJson: Найдено name: $userName');
      } else if (json['user'] != null) {
        if (json['user'] is Map) {
          try {
            // Безопасное преобразование Map
            Map<String, dynamic> userMap;
            try {
              userMap = (json['user'] as Map).cast<String, dynamic>();
            } catch (e) {
              userMap = Map<String, dynamic>.from(json['user'] as Map);
            }
            userName = userMap['name']?.toString() ?? userMap['user_name']?.toString();
            print('[DEBUG] Review.fromJson: Найдено user (Map): $userName');
            print('[DEBUG] Review.fromJson: Ключи в user: ${userMap.keys.toList()}');
          } catch (e) {
            print('[ERROR] Review.fromJson: Ошибка при обработке user: $e');
            userName = null;
          }
        } else {
          userName = json['user'].toString();
          print('[DEBUG] Review.fromJson: Найдено user (String): $userName');
        }
      } else {
        print('[DEBUG] Review.fromJson: Имя пользователя не найдено');
      }
      
      // Пробуем разные варианты ключей для комментария
      String? comment;
      if (json['comment'] != null) {
        comment = json['comment'].toString();
        print('[DEBUG] Review.fromJson: Найдено comment: ${comment.length > 50 ? comment.substring(0, 50) + "..." : comment}');
      } else if (json['review'] != null) {
        comment = json['review'].toString();
        print('[DEBUG] Review.fromJson: Найдено review: ${comment.length > 50 ? comment.substring(0, 50) + "..." : comment}');
      } else if (json['text'] != null) {
        comment = json['text'].toString();
        print('[DEBUG] Review.fromJson: Найдено text: ${comment.length > 50 ? comment.substring(0, 50) + "..." : comment}');
      } else if (json['content'] != null) {
        comment = json['content'].toString();
        print('[DEBUG] Review.fromJson: Найдено content: ${comment.length > 50 ? comment.substring(0, 50) + "..." : comment}');
      } else if (json['message'] != null) {
        comment = json['message'].toString();
        print('[DEBUG] Review.fromJson: Найдено message: ${comment.length > 50 ? comment.substring(0, 50) + "..." : comment}');
      } else {
        print('[DEBUG] Review.fromJson: Комментарий не найден');
      }
      
      // Пробуем разные варианты ключей для рейтинга
      double rating = _toDouble(json['rating'] ?? json['rate'] ?? json['stars'] ?? 0);
      print('[DEBUG] Review.fromJson: Найден рейтинг: $rating (из ключей: rating=${json['rating']}, rate=${json['rate']}, stars=${json['stars']})');
      
      // Пробуем разные варианты ключей для даты создания
      String? createdAt;
      if (json['created'] != null) {
        // Отформатированная дата (например: "04:53 pm, 07 Nov, 25")
        createdAt = json['created'].toString();
        print('[DEBUG] Review.fromJson: Найдено created: $createdAt');
      } else if (json['created_at'] != null) {
        // ISO дата (например: "2025-11-07T11:53:35.000000Z")
        createdAt = json['created_at'].toString();
        print('[DEBUG] Review.fromJson: Найдено created_at: $createdAt');
      } else if (json['createdAt'] != null) {
        createdAt = json['createdAt'].toString();
        print('[DEBUG] Review.fromJson: Найдено createdAt: $createdAt');
      } else if (json['date'] != null) {
        createdAt = json['date'].toString();
        print('[DEBUG] Review.fromJson: Найдено date: $createdAt');
      } else {
        print('[DEBUG] Review.fromJson: Дата создания не найдена');
      }
      
      // Пробуем получить ID
      int id = 0;
      if (json['id'] != null) {
        if (json['id'] is int) {
          id = json['id'] as int;
        } else if (json['id'] is String) {
          id = int.tryParse(json['id'] as String) ?? 0;
        } else {
          id = (json['id'] as num?)?.toInt() ?? 0;
        }
        print('[DEBUG] Review.fromJson: Найден id: $id');
      } else {
        print('[DEBUG] Review.fromJson: ID не найден, используем 0');
      }
      
      // Пробуем получить productId
      int productId = 0;
      if (json['product_id'] != null) {
        if (json['product_id'] is int) {
          productId = json['product_id'] as int;
        } else if (json['product_id'] is String) {
          productId = int.tryParse(json['product_id'] as String) ?? 0;
        } else {
          productId = (json['product_id'] as num?)?.toInt() ?? 0;
        }
        print('[DEBUG] Review.fromJson: Найден product_id: $productId');
      } else if (json['productId'] != null) {
        if (json['productId'] is int) {
          productId = json['productId'] as int;
        } else if (json['productId'] is String) {
          productId = int.tryParse(json['productId'] as String) ?? 0;
        } else {
          productId = (json['productId'] as num?)?.toInt() ?? 0;
        }
        print('[DEBUG] Review.fromJson: Найден productId: $productId');
      } else {
        print('[DEBUG] Review.fromJson: productId не найден, используем 0');
      }
      
      final review = Review(
        id: id,
        productId: productId,
        userName: userName,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
        updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString(),
      );
      
      final commentPreview = review.comment != null && review.comment!.isNotEmpty
          ? (review.comment!.length > 50 ? '${review.comment!.substring(0, 50)}...' : review.comment!)
          : 'нет комментария';
      print('[DEBUG] Review.fromJson: Отзыв создан: id=${review.id}, productId=${review.productId}, userName=${review.userName}, rating=${review.rating}, comment=$commentPreview');
      
      return review;
    } catch (e, stackTrace) {
      print('[ERROR] Review.fromJson: Ошибка при парсинге отзыва: $e');
      print('[ERROR] Review.fromJson: Stack trace: $stackTrace');
      print('[ERROR] Review.fromJson: Данные отзыва: $json');
      rethrow;
    }
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_name': userName,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

