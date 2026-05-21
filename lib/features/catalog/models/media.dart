class ProductImage {
  final int? id;
  final String image; // Путь к оригинальному изображению
  final String thumb; // Путь к миниатюре
  /// attribute_value_id, привязанные к этому фото (как на вебе).
  final List<int> attributeValueIds;

  ProductImage({
    this.id,
    required this.image,
    required this.thumb,
    this.attributeValueIds = const [],
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    final attributeValueIds = <int>[];
    final attrs = json['attributes'];
    if (attrs is List) {
      for (final item in attrs) {
        if (item is! Map) continue;
        final rawId = item['attribute_value_id'] ??
            (item['attribute_value'] is Map
                ? (item['attribute_value'] as Map)['id']
                : null) ??
            item['id'];
        final parsed = rawId is int ? rawId : int.tryParse('$rawId');
        if (parsed != null && parsed > 0) {
          attributeValueIds.add(parsed);
        }
      }
    }

    return ProductImage(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      image: json['image']?.toString() ?? '',
      thumb: json['thumb']?.toString() ?? '',
      attributeValueIds: attributeValueIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'image': image,
      'thumb': thumb,
      'attributes': attributeValueIds
          .map((valueId) => {'attribute_value_id': valueId})
          .toList(),
    };
  }
}

class ProductVideo {
  final String video; // Путь к видеофайлу
  final String? thumb; // Миниатюра видео (если есть)

  ProductVideo({required this.video, this.thumb});

  factory ProductVideo.fromJson(Map<String, dynamic> json) {
    return ProductVideo(
      video: json['video']?.toString() ?? '',
      thumb: json['thumb']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video': video,
      'thumb': thumb,
    };
  }
}