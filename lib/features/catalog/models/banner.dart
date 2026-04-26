class Banner {
  final int id;
  final String title;
  final String image;
  final int type;
  final int? sourceType;
  final String? url;
  final String? slug;
  final int status;
  final int closable;
  final String? createdAt;
  final String? updatedAt;

  const Banner({
    required this.id,
    required this.title,
    required this.image,
    required this.type,
    this.sourceType,
    this.url,
    this.slug,
    this.status = 1,
    this.closable = 2,
    this.createdAt,
    this.updatedAt,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      type: (json['type'] ?? 0) as int,
      sourceType: json['source_type'] as int?,
      url: json['url']?.toString(),
      slug: json['slug']?.toString(),
      status: (json['status'] ?? 1) as int,
      closable: (json['closable'] ?? 2) as int,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'type': type,
      'source_type': sourceType,
      'url': url,
      'slug': slug,
      'status': status,
      'closable': closable,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Определение размера баннера по типу
  // На основе данных пользователя:
  // - type 1: может быть главным слайдером или баннером после New Year Sale
  // - type 2-3, 6-7: баннеры после New Year Sale (средние)
  // - type 4: баннер 1600x800
  // - type 5: баннер 2000x300
  // - type 8-9: баннер 2000x250 (внизу)
  BannerSize? get size {
    switch (type) {
      case 4:
        return BannerSize.large1600x800; // 1600x800
      case 5:
        return BannerSize.large2000x300; // 2000x300
      case 8:
      case 9:
        return BannerSize.bottom2000x250; // 2000x250 (внизу)
      case 1:
      case 2:
      case 3:
      case 6:
      case 7:
      default:
        return BannerSize.medium; // Средние баннеры после New Year Sale
    }
  }

  bool get isActive => status == 1;
}

enum BannerSize {
  mainSlider,
  medium,
  large1600x800,
  large2000x300,
  bottom2000x250,
  small400x400, // Исключаем из отображения
}

