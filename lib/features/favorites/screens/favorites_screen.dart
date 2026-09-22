import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../catalog/models/product.dart';
import '../../catalog/widgets/product_grid_card.dart';
import '../repo/favorites_api.dart';
import '../services/price_alert_service.dart';
import '../../auth/providers/auth_provider.dart';

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
    final user = ref.read(authProvider);
    if (!user.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isUnauthorized = true;
        _isLoading = false;
        _error = null;
        _products = [];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _isUnauthorized = false;
      });
    }

    final favoritesApi = ref.read(favoritesApiProvider);
    final result = await favoritesApi.getFavoriteProducts();
    if (!mounted) return;

    result.when(
      ok: (products) {
        setState(() {
          _products = products;
          _isLoading = false;
          _isUnauthorized = false;
          _error = null;
        });
        Future(() async {
          final drops =
              await PriceAlertService.instance.checkAndNotify(products);
          if (drops.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.tr(
                    'favorites.price_drop',
                    namedArgs: {'count': '${drops.length}'},
                  ),
                ),
                backgroundColor: const Color(0xFF9C27B0),
              ),
            );
          }
        });
      },
      err: (error) {
        if (error == 'UNAUTHORIZED' || error.contains('401')) {
          setState(() {
            _isUnauthorized = true;
            _isLoading = false;
            _error = null;
            _products = [];
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

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    
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
                Color(0xFF9C27B0),
                Color(0xFFE040FB),
              ],
            ),
          ),
        ),
        title: Text(
          context.tr('favorites.title'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadFavoriteProducts,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: context.tr('common.update'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final bottomPad = BottomNavigationBarWidget.occupiedHeight(context);

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF9C27B0)),
              const SizedBox(height: 16),
              Text(
                context.tr('favorites.loading'),
                style: const TextStyle(fontSize: 16, color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_isUnauthorized) {
      return _buildUnauthorizedState(bottomPad);
    }

    if (_error != null) {
      return _buildErrorState(bottomPad);
    }

    if (_products.isEmpty) {
      return _buildEmptyState(bottomPad);
    }

    return _buildProductsGrid(bottomPad);
  }

  Widget _buildErrorState(double bottomPad) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              context.tr('catalog.load_error'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadFavoriteProducts,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('common.retry')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedState(double bottomPad) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad + 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('favorites.need_auth'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('favorites.need_auth_hint'),
              style: const TextStyle(fontSize: 15, color: textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push('/login'),
              icon: const Icon(Icons.login_rounded),
              label: Text(context.tr('auth.sign_in')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(double bottomPad) {
    final title = context.tr('favorites.empty');
    final hint = context.tr('favorites.empty_hint');
    final cta = context.tr('favorites.find_products');
    final home = context.tr('favorites.browse_home');

    return RefreshIndicator(
      onRefresh: _loadFavoriteProducts,
      color: primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(24, 48, 24, bottomPad + 24),
        children: [
          const SizedBox(height: 48),
          Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 52,
                color: Color(0xFF9C27B0),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title == 'favorites.empty'
                ? 'Пока нет товаров в избранном'
                : title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            hint == 'favorites.empty_hint'
                ? 'Сохраняйте понравившиеся товары, нажимая ♥ на карточке — они появятся здесь'
                : hint,
            style: const TextStyle(
              fontSize: 15,
              color: textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/catalog'),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
            label: Text(
              cta == 'favorites.find_products' ? 'Перейти в каталог' : cta,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(
              home == 'favorites.browse_home' ? 'На главную' : home,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(double bottomPad) {
    return RefreshIndicator(
      onRefresh: _loadFavoriteProducts,
      color: primaryColor,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad + 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: ProductGridCard.gridChildAspectRatio,
          crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
          mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return ProductGridCard(
            key: ValueKey(product.id),
            product: product,
            initiallyFavorite: true,
            onFavoriteChanged: (isFavorite) {
              if (!isFavorite) {
                setState(() {
                  _products.removeWhere((p) => p.id == product.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        'favorites.removed',
                        namedArgs: {'name': product.name},
                      ),
                    ),
                    backgroundColor: Colors.orange[600],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
