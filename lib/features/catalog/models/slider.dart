class SliderItem {
  final int id;
  final String title;
  final String image;
  final String? link;
  final int? order;
  final bool isActive;

  const SliderItem({
    required this.id,
    required this.title,
    required this.image,
    this.link,
    this.order,
    this.isActive = true,
  });

  factory SliderItem.fromJson(Map<String, dynamic> json) {
    return SliderItem(
      id: (json['id'] ?? 0) as int,
      title: (json['title'] ?? json['name'] ?? '').toString(),
      image: (json['image'] ?? json['url'] ?? '').toString(),
      link: json['url']?.toString(), // В API поле называется 'url'
      order: json['type'] as int?, // Используем 'type' как порядок
      isActive: (json['status'] ?? 1) == 1, // status: 1 = активный
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image': image,
      'link': link,
      'order': order,
      'is_active': isActive,
    };
  }
}
