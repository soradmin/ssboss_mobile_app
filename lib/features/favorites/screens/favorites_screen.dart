import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme.dart';
import '../../../core/config.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../catalog/models/product.dart';
import '../../catalog/screens/product_details_screen.dart';
import '../../cart/controllers/cart_controller.dart';
import '../repo/favorites_api.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  bool _isUnauthorized = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteProducts();
  }

  Future<void> _loadFavoriteProducts() async {
    // Проверяем авторизацию перед загрузкой
    final user = ref.read(authProvider);
    if (!user.isAuthenticated) {
      setState(() {
        _isUnauthorized = true;
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _isUnauthorized = false;
    });

    final favoritesApi = ref.read(favoritesApiProvider);
    final result = await favoritesApi.getFavoriteProducts();

    result.when(
      ok: (products) {
        setState(() {
          _products = products;
          _isLoading = false;
          _isUnauthorized = false;
        });
      },
      err: (error) {
        // Проверяем, является ли ошибка ошибкой авторизации
        if (error == 'UNAUTHORIZED' || error.contains('401')) {
          setState(() {
            _isUnauthorized = true;
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _error = error;
            _isLoading = false;
            _isUnauthorized = false;
          });
        }
      },
    );
  }

  Future<void> _removeFromFavorites(Product product) async {
    final favoritesApi = ref.read(favoritesApiProvider);
    final result = await favoritesApi.removeFromFavorites(product.id);

    result.when(
      ok: (success) {
        if (success) {
          // Плавная анимация удаления
          setState(() {
            _products.removeWhere((p) => p.id == product.id);
          });
          
          // Показать уведомление с анимацией
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${product.name} удален из избранного',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      err: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ошибка: $error',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authProvider);
    
    // Автоматически обновляем список, если пользователь авторизовался
    ref.listen(authProvider, (previous, next) {
      if (previous != null && !previous.isAuthenticated && next.isAuthenticated) {
        // Пользователь только что авторизовался
        _loadFavoriteProducts();
      }
    });
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF9C27B0), // Основной фиолетовый
                Color(0xFFE040FB), // Светло-фиолетовый
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        title: const Text(
          'Избранные',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: _loadFavoriteProducts,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _isUnauthorized
                ? _buildUnauthorizedState()
                : _error != null
                    ? _buildErrorState()
                    : _products.isEmpty
                        ? _buildEmptyState()
                        : _buildProductsGrid(),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 3),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Загружаем избранные товары...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.red[900]?.withOpacity(0.3) : Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: isDark ? Colors.red[300] : Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ошибка загрузки',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Container(
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _loadFavoriteProducts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.purple[900]?.withOpacity(0.3) : Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: isDark ? Colors.purple[300] : Colors.purple[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Требуется авторизация',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Войдите в аккаунт, чтобы увидеть добавленные товары в избранное',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/login'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Войти'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.pink[900]?.withOpacity(0.3) : Colors.pink[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 48,
                color: isDark ? Colors.pink[300] : Colors.pink[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'У вас пока нет избранных товаров',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте товары в избранное, чтобы они появились здесь!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Найти товары'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return RefreshIndicator(
      onRefresh: _loadFavoriteProducts,
      color: primaryColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58, // Как на главном экране
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildProductCard(product),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    // Количество этого товара в локальной корзине (для бейджа)
    final items = ref.read(cartProvider);
    int qtyInCart = 0;
    for (final it in items) {
      if (it.product.id == product.id) {
        qtyInCart = it.qty;
        break;
      }
    }

    const purple = Color(0xFF7B3FE4);
    final cardHeight = MediaQuery.of(context).size.width / 2 * 1.72; // Аспект 0.58

    return RepaintBoundary(
      child: InkWell(
        onTap: () => context.push('/product/${product.id}', extra: product),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: cardHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Изображение товара с плавающей кнопкой корзины
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: product.image.isEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF6A1B9A).withOpacity(0.1),
                                      const Color(0xFF9C27B0).withOpacity(0.1),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: purple.withOpacity(0.5),
                                    size: 48,
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: AppConfig.imageUrl(product.image),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                memCacheHeight: 220,
                                memCacheWidth: 220,
                                maxHeightDiskCache: 220,
                                maxWidthDiskCache: 220,
                                placeholder: (context, url) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF6A1B9A).withOpacity(0.1),
                                        const Color(0xFF9C27B0).withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: purple.withOpacity(0.5),
                                      size: 48,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF6A1B9A).withOpacity(0.1),
                                        const Color(0xFF9C27B0).withOpacity(0.1),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: purple.withOpacity(0.5),
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      // Бейдж товара
                      if (product.badge != null && product.badge!.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: purple,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Кнопка избранного (красная, заполненная)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _removeFromFavorites(product),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Плавающая круглая кнопка корзины
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                ref.read(cartProvider.notifier).addToCartWithSync(product, 1);
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Товар добавлен в корзину'),
                                    duration: Duration(milliseconds: 900),
                                  ),
                                );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: purple,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                              ),
                            ),
                            if (qtyInCart > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Text(
                                    qtyInCart > 9 ? '9+' : '$qtyInCart',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Цена (сразу после изображения)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} с.',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      if (product.oldPrice != null &&
                          product.oldPrice! > product.price) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${product.oldPrice!.toStringAsFixed(0)} с.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Информация о товаре
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.rating > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 11,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  product.rating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 9),
                                ),
                                if (product.reviewCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${product.reviewCount})',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}