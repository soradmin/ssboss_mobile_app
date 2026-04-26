class ProductImage {
  final String image; // Путь к оригинальному изображению
  final String thumb; // Путь к миниатюре

  ProductImage({required this.image, required this.thumb});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      image: json['image']?.toString() ?? '',
      thumb: json['thumb']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'thumb': thumb,
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