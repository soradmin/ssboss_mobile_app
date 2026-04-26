class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final bool isAuthenticated;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.isAuthenticated = false,
  });

  factory User.guest() {
    return const User(
      id: 0,
      name: 'Гость',
      email: '',
      isAuthenticated: false,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['username'] ?? 'Пользователь',
      email: json['email'] ?? '',
      phone: json['phone'],
      avatar: json['avatar'],
      isAuthenticated: true,
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    bool? isAuthenticated,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
