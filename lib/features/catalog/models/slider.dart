class SliderItem {
  final int id;
  final String title;
  final String image;
  final String? link;
  final int? order;
  final int? sourceType;
  final bool isActive;

  const SliderItem({
    required this.id,
    required this.title,
    required this.image,
    this.link,
    this.order,
    this.sourceType,
    this.isActive = true,
  });

  factory SliderItem.fromJson(Map<String, dynamic> json) {
    return SliderItem(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? json['url'] ?? '').toString(),
      link: (json['url'] ?? json['link'] ?? json['slug'])?.toString(),
      order: json['type'] as int?,
      sourceType: json['source_type'] as int?,
      isActive: (json['status'] ?? 1) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'link': link,
      'order': order,
      'source_type': sourceType,
      'is_active': isActive,
    };
  }
}
