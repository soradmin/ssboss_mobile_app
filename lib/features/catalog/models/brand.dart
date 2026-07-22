class Brand {
  final int id;
  final String name;
  final String logo;
  final String? slug;
  final int status;
  final String? createdAt;
  final String? updatedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.logo,
    this.slug,
    this.status = 1,
    this.createdAt,
    this.updatedAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return Brand(
      id: id,
      name: (json['name'] ?? json['title'] ?? '').toString(),
      logo: (json['logo'] ?? json['image'] ?? '').toString(),
      slug: json['slug']?.toString(),
      status: (json['status'] is int)
          ? json['status'] as int
          : int.tryParse(json['status']?.toString() ?? '') ?? 1,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
      'slug': slug,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isActive => status == 1;
}
