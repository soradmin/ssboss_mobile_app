import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/config.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../favorites/repo/favorites_api.dart';
import '../models/product.dart';
import 'product_price_row.dart';

typedef ProductAddToCartCallback = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  Product product,
);

/// Карточка товара в сетке — та же, что в экране каталога (`products_screen`).
class ProductGridCard extends ConsumerWidget {
  /// Фото 3:4 (как Wildberries) — удобно для вертикальных инфографик на карточке.
  static const double imageAspectRatio = 3 / 4;

  /// `childAspectRatio` для GridView/SliverGrid с этой карточкой (2 колонки).
  static const double gridChildAspectRatio = 0.58;

  final Product product;
  final ProductAddToCartCallback? onAddToCart;

  const ProductGridCard({
    super.key,
    required this.product,
    this.onAddToCart,
  });

  static String imageUrlFor(Product product) {
    final raw = product.image.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return AppConfig.imageUrl(raw);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    var qtyInCart = 0;
    for (final it in items) {
      if (it.product.id == product.id) {
        qtyInCart = it.qty;
        break;
      }
    }

    const purple = Color(0xFF7B3FE4);
    final imageUrl = imageUrlFor(product);

    return Align(
      alignment: Alignment.topCenter,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}', extra: product),
        borderRadius: BorderRadius.circular(12),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: imageAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: imageUrl.isEmpty
                        ? const _ProductGridImageShimmer()
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) =>
                                const _ProductGridImageShimmer(),
                            errorWidget: (context, url, error) =>
                                const _ProductGridImageError(),
                          ),
                  ),
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
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ProductGridFavoriteButton(product: product),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (onAddToCart != null) {
                              await onAddToCart!(context, ref, product);
                              return;
                            }
                            await ref
                                .read(cartProvider.notifier)
                                .addToCartWithSync(product, 1);
                            if (!context.mounted) return;
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
                            decoration: const BoxDecoration(
                              color: purple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: ProductPriceRow.fromProduct(product),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
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
          ],
        ),
      ),
      ),
    );
  }
}

/// Shimmer в области фото карточки (пока грузится сеть).
class _ProductGridImageShimmer extends StatelessWidget {
  const _ProductGridImageShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      period: const Duration(milliseconds: 1250),
      child: const ColoredBox(color: Color(0xFFE6E6E6)),
    );
  }
}

class _ProductGridImageError extends StatelessWidget {
  const _ProductGridImageError();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF0F0F0),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

/// Скелетон карточки в сетке (главная, каталог, магазин).
class ProductGridCardSkeleton extends StatelessWidget {
  const ProductGridCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const bar = Color(0xFFCBCBCB);
    return Align(
      alignment: Alignment.topCenter,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFE6E6E6),
          highlightColor: const Color(0xFFF8F8F8),
          period: const Duration(milliseconds: 1250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: ProductGridCard.imageAspectRatio,
                child: ColoredBox(
                  color: const Color(0xFFE6E6E6),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: bar,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB8B8B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Container(
                  height: 16,
                  width: 64,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 110,
                      decoration: BoxDecoration(
                        color: bar,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductGridFavoriteButton extends ConsumerStatefulWidget {
  final Product product;

  const ProductGridFavoriteButton({super.key, required this.product});

  @override
  ConsumerState<ProductGridFavoriteButton> createState() =>
      _ProductGridFavoriteButtonState();
}

class _ProductGridFavoriteButtonState
    extends ConsumerState<ProductGridFavoriteButton> {
  bool _isFavorite = false;
  bool _isLoading = false;

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final favoritesApi = ref.read(favoritesApiProvider);

      if (_isFavorite) {
        final result = await favoritesApi.removeFromFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = false;
              _isLoading = false;
            });
          },
          err: (_) => setState(() => _isLoading = false),
        );
      } else {
        final result = await favoritesApi.addToFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = true;
              _isLoading = false;
            });
          },
          err: (_) => setState(() => _isLoading = false),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
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
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
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
