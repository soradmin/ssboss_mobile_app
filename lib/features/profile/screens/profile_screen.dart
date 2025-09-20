// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config.dart';
import '../../../core/result.dart'; // Для работы с Result, Ok, Err
import '../../auth/screens/register_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/repo/auth_api.dart'; // Убедись, что путь правильный

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Проверяем, авторизован ли пользователь
    final bool isLoggedIn = AppConfig.bearer.isNotEmpty;

    if (isLoggedIn) {
      // Если авторизован - показываем данные профиля
      return const _UserProfileView();
    } else {
      // Если не авторизован - показываем форму регистрации
      return const RegisterScreen();
    }
  }
}

/// Виджет для отображения данных профиля авторизованного пользователя
class _UserProfileView extends ConsumerStatefulWidget {
  const _UserProfileView();

  @override
  ConsumerState<_UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends ConsumerState<_UserProfileView> {
  late Future<Result<Map<String, dynamic>>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthApi.getProfile();
  }

  Future<void> _logout() async {
    await AuthApi.logout();
    // После выхода можно, например, перенаправить на главный экран
    // или просто обновить состояние родительского виджета.
    // В данном случае ProfileScreen перестроится и покажет RegisterScreen.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выход выполнен')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: FutureBuilder<Result<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final Result<Map<String, dynamic>> result = snapshot.data!;

            if (result is Ok<Map<String, dynamic>>) {
              final Map<String, dynamic> userData = result.value;
              // Предполагаемая структура ответа: data.user.{name, email, ...}
              // Адаптируй ключи под реальную структуру ответа от /api/v1/user/profile
              final String name = userData['name'] as String? ?? 'Не указано';
              final String email = userData['email'] as String? ?? 'Не указано';
              // Можно добавить другие поля, например, avatar, phone и т.д.

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      // В реальном приложении тут будет NetworkImage с аватаром пользователя
                      child: Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Имя'),
                      subtitle: Text(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    // Добавь другие ListTile для других данных пользователя
                    const Spacer(),
                    FilledButton(
                      onPressed: _logout,
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              );
            } else if (result is Err<Map<String, dynamic>>) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ошибка: ${(result as Err).message}'),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _profileFuture = AuthApi.getProfile();
                        });
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }
          }
          // Этот случай маловероятен, но добавим для полноты
          return const Center(child: Text('Нет данных'));
        },
      ),
    );
  }
}