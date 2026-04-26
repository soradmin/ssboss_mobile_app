// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config.dart';
import '../../../core/result.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/repo/auth_api.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/controllers/cart_controller.dart';
import '../repo/profile_api.dart';
import '../../../theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    
    print('[DEBUG] ProfileScreen: Статус авторизации: ${user.isAuthenticated}');
    print('[DEBUG] ProfileScreen: Данные пользователя: id=${user.id}, name=${user.name}, email=${user.email}');
    print('[DEBUG] ProfileScreen: AppConfig.bearer: ${AppConfig.bearer.isNotEmpty ? 'есть' : 'нет'}');
    print('[DEBUG] ProfileScreen: AppConfig.mobileBearer: ${AppConfig.mobileBearer.isNotEmpty ? 'есть' : 'нет'}');
    print('[DEBUG] ProfileScreen: AppConfig.hasActiveToken: ${AppConfig.hasActiveToken()}');
    print('[DEBUG] ProfileScreen: Проверка условий: user.isAuthenticated=${user.isAuthenticated}, AppConfig.hasActiveToken=${AppConfig.hasActiveToken()}');

    // Дополнительная проверка: если пользователь не авторизован ИЛИ нет активного токена
    if (user.isAuthenticated && AppConfig.hasActiveToken()) {
      print('[DEBUG] ProfileScreen: Показываем профиль пользователя');
      return const _UserProfileView();
    } else {
      print('[DEBUG] ProfileScreen: Показываем экран входа (пользователь не авторизован)');
      return const LoginScreen();
    }
  }
}

class _UserProfileView extends ConsumerStatefulWidget {
  const _UserProfileView();

  @override
  ConsumerState<_UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends ConsumerState<_UserProfileView>
    with TickerProviderStateMixin {
  late Future<Result<Map<String, dynamic>>> _profileFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] _UserProfileView: initState вызван');
    
    _profileFuture = _fetchUserProfile();
    
    // Инициализация анимаций
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Result<Map<String, dynamic>>> _fetchUserProfile() async {
    try {
      final profileApi = ref.read(profileApiProvider);
      return await profileApi.getUserProfile();
        } catch (e) {
      return Err('Ошибка загрузки профиля: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] _UserProfileView: build вызван');
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: false,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Современная SliverAppBar с градиентным фоном
          SliverAppBar(
            expandedHeight: 320,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9C27B0), // Основной фиолетовый
                      Color(0xFFE040FB), // Светло-фиолетовый
                      Color(0xFFF8BBD9), // Розово-фиолетовый
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: _buildModernProfileHeader(),
                ),
              ),
            ),
          ),
          
          // Основной контент с белым фоном
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 30,
                  bottom: MediaQuery.of(context).viewPadding.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Edit Profile Button
                    _buildEditProfileButton(),
                    const SizedBox(height: 30),
                    
                    // Profile Sections
                    _buildProfileSections(),
                    const SizedBox(height: 30),
                    
                    // Security Section
                    _buildSecuritySection(),
                    const SizedBox(height: 20),
                    
                    // App Version
                    _buildAppVersion(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
    );
  }

  Widget _buildModernProfileHeader() {
    return FutureBuilder<Result<Map<String, dynamic>>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }
        
        if (snapshot.hasError || snapshot.data is Err) {
          return _buildErrorState();
        }
        
        final result = snapshot.data!;
        if (result is Err) {
          return _buildErrorState();
        }
        
        final profileData = (result as Ok).value;
        return _buildModernProfileContent(profileData);
      },
    );
  }

  Widget _buildModernProfileContent(Map<String, dynamic> profileData) {
    final name = profileData['name']?.toString() ?? 'Пользователь';
    final email = profileData['email']?.toString() ?? '';
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Простой аватар без иконки редактирования
                  Hero(
                    tag: 'user_avatar',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Имя пользователя
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Email
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return const Center(
                        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
                          children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 16),
          Text(
            'Ошибка загрузки профиля',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profileData) {
    final name = profileData['name']?.toString() ?? 'Пользователь';
    final email = profileData['email']?.toString() ?? '';
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Avatar with Hero animation
                Hero(
                  tag: 'user_avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFF8E24AA),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // User name
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Email
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Premium badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Премиум',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditProfileButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9C27B0), // Основной фиолетовый
              Color(0xFFE040FB), // Светло-фиолетовый
            ],
            stops: [0.0, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: FilledButton.icon(
          onPressed: () => context.push('/edit-profile'),
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text(
            'Редактировать профиль',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(
          icon: Icons.shopping_bag_outlined,
          title: 'Мои заказы',
          subtitle: 'История заказов и статусы',
          onTap: () => context.push('/orders'),
        ),
        const SizedBox(height: 12),
        _buildProfileCard(
          icon: Icons.location_on_outlined,
          title: 'Мои адреса',
          subtitle: 'Управление адресами доставки',
          onTap: () => context.push('/addresses'),
        ),
        const SizedBox(height: 12),
        _buildProfileCard(
          icon: Icons.storefront_outlined,
          title: 'Любимые магазины',
          subtitle: 'Подписки на магазины',
          onTap: () => context.push('/favorite-stores'),
        ),
        const SizedBox(height: 12),
        _buildProfileCard(
          icon: Icons.favorite_border,
          title: 'Избранные',
          subtitle: 'Любимые товары',
          onTap: () => context.push('/favorites'),
        ),
        const SizedBox(height: 12),
        _buildProfileCard(
          icon: Icons.balance_outlined,
          title: 'Сравнения',
          subtitle: 'Сравнить товары',
          onTap: () => context.push('/compare'),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E24AA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF8E24AA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Безопасность и аккаунт',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildSecurityCard(
              icon: Icons.logout,
              title: 'Выйти из приложения',
              subtitle: 'Завершить сеанс только в приложении',
              color: Colors.orange,
              onTap: _mobileLogout,
            ),
            const SizedBox(height: 12),
            _buildSecurityCard(
              icon: Icons.logout_outlined,
              title: 'Выйти везде',
              subtitle: 'Завершить сеанс на сайте и в приложении',
              color: Colors.red,
              onTap: _fullLogout,
            ),
            const SizedBox(height: 12),
            _buildSecurityCard(
              icon: Icons.delete_forever,
              title: 'Удалить аккаунт',
              subtitle: 'Безвозвратное удаление',
              color: Colors.red,
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Text(
        'Версия приложения 1.0.0',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  // Выход только из мобильного приложения
  Future<void> _mobileLogout() async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выйти из приложения'),
          content: const Text('Вы уверены, что хотите выйти из приложения? Вы останетесь авторизованными на сайте.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await ref.read(authProvider.notifier).mobileLogout();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы вышли из приложения'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выхода: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Полный выход (затрагивает и сайт)
  Future<void> _fullLogout() async {
    try {
      // Показываем диалог подтверждения
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выйти везде'),
          content: const Text('Вы уверены, что хотите выйти из всех устройств? Это завершит сеанс на сайте и в приложении.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти везде'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final profileApi = ref.read(profileApiProvider);
        await profileApi.logout();
        
        // Очищаем все токены
        await ref.read(authProvider.notifier).fullLogout();
        // Очищаем корзину при выходе
        ref.read(cartProvider.notifier).clearCart();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы вышли из всех устройств'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выхода: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Показываем модальное окно подтверждения
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Индикатор
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Иконка предупреждения
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            
            // Заголовок
            const Text(
              'Удалить аккаунт?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Описание
            Text(
              'Это действие нельзя отменить. Все ваши данные будут удалены навсегда.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            
            // Кнопки
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFC94F4F), // Темно-красный
                          Color(0xFFE85A5A), // Светло-красный
                        ],
                        stops: [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Удалить'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final profileApi = ref.read(profileApiProvider);
      final result = await profileApi.deleteAccount();

      // Закрываем диалог загрузки
      if (mounted) Navigator.of(context).pop();

      if (result is Ok<bool>) {
        // Очищаем все данные пользователя
        await ref.read(authProvider.notifier).refreshAuthStatus();
        // Очищаем корзину при выходе
      ref.read(cartProvider.notifier).clearCart();
        
        if (mounted) {
          // Показываем сообщение об успехе
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Аккаунт успешно удален'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Переходим на главную страницу
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            context.go('/');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления аккаунта: ${(result as Err).message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Закрываем диалог загрузки
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Произошла ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}