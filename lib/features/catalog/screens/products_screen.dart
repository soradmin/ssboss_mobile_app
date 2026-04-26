import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/widgets/bottom_navigation_bar.dart';
import '../repo/catalog_api.dart';
import '../models/product.dart';
import '../../../core/result.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/repo/cart_api.dart';
import '../../cart/widgets/cart_badge.dart';
import '../../favorites/repo/favorites_api.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? searchQuery;
  final String? categoryTitle;
  final int? categoryId;

  const ProductsScreen({
    super.key,
    this.category,
    this.searchQuery,
    this.categoryTitle,
    this.categoryId,
  });

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _products.clear();
        _hasMore = true;
        _loading = true;
        _error = null;
      });
    } else if (_loadingMore) {
      return;
    } else {
      setState(() => _loadingMore = true);
    }

    final api = CatalogApi();
    print('[DEBUG] ProductsScreen._loadProducts: Загружаем товары для category="${widget.category}", categoryId="${widget.categoryId}", search="${widget.searchQuery}"');
    final result = await api.products(
      page: _currentPage,
      category: widget.category,
      search: widget.searchQuery,
      categoryId: widget.categoryId,
    );
    
    if (result is Ok<List<Product>>) {
      final newProducts = result.value;
      setState(() {
        if (refresh) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }
        _currentPage++;
        _hasMore = newProducts.length >= 20; // Предполагаем, что если меньше 20, то это последняя страница
        _loading = false;
        _loadingMore = false;
      });
    } else {
      setState(() {
        _error = (result as Err).message;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: Text(
          widget.categoryTitle ?? widget.category ?? 'Товары',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadProducts(refresh: true),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Ошибка загрузки товаров', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
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
              child: ElevatedButton(
                onPressed: () => _loadProducts(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Товары не найдены'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProducts(refresh: true),
      child: CustomScrollView(
        slivers: [
            SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: _products.length + (_loadingMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= _products.length) {
                  return const _LoadingCard();
                }
                return _ProductCard(product: _products[index]);
              },
            ),
          ),
          if (_hasMore && !_loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _loadProducts(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Загрузить еще'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Количество этого товара в локальной корзине (для бейджа)
    final items = ref.watch(cartProvider);
    int qtyInCart = 0;
    for (final it in items) {
      if (it.product.id == product.id) {
        qtyInCart = it.qty;
        break;
      }
    }

    const purple = Color(0xFF7B3FE4);

    return InkWell(
      onTap: () => context.push('/product/${product.id}', extra: product),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                            imageUrl: product.image,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
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

                  // Кнопка избранного в правом верхнем углу
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _FavoriteButton(product: product),
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
                            await ref.read(cartProvider.notifier).addToCartWithSync(product, 1);
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
    );
  }

  // Метод для правильного склонения слова "оценка"
  String _getReviewCountText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'оценка';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'оценки';
    } else {
      return 'оценок';
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ColoredBox(color: Colors.white),
              ),
              SizedBox(height: 8),
              ColoredBox(color: Colors.white, child: SizedBox(height: 20, width: double.infinity)),
              SizedBox(height: 4),
              ColoredBox(color: Colors.white, child: SizedBox(height: 16, width: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// Виджет кнопки избранного
class _FavoriteButton extends ConsumerStatefulWidget {
  final Product product;
  
  const _FavoriteButton({required this.product});
  
  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _isFavorite = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Можно загрузить начальное состояние избранного при необходимости
    // Для простоты используем локальное состояние
  }
  
  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final favoritesApi = ref.read(favoritesApiProvider);
      
      // Переключаем статус избранного
      if (_isFavorite) {
        final result = await favoritesApi.removeFromFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = false;
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.product.name} удален из избранного'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      } else {
        final result = await favoritesApi.addToFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = true;
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.product.name} добавлен в избранное'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleFavorite,
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
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.black87,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
