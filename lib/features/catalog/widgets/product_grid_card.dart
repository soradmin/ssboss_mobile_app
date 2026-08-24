import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/config.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../compare/repo/compare_api.dart';
import '../../favorites/repo/favorites_api.dart';
import '../../personalization/user_preference_service.dart';
import '../models/product.dart';
import 'product_price_row.dart';

typedef ProductAddToCartCallback = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  Product product,
);

/// Карточка товара в сетке — одна и та же на главной, в каталоге,
/// избранном, сравнении, у магазина и в блоках «смотрите также».
class ProductGridCard extends ConsumerWidget {
  /// Вытянутое фото 3:4 на светлой подложке.
  static const double imageAspectRatio = 3 / 4;

  /// `childAspectRatio` для GridView/SliverGrid (2 колонки):
  /// фото 3:4 + название в 2 строки + рейтинг + цена.
  static const double gridChildAspectRatio = 0.52;
  static const double gridMainAxisSpacing = 18;
  static const double gridCrossAxisSpacing = 14;

  static const Color _brandStart = Color(0xFF8813BA);
  static const Color _brandMid = Color(0xFFB02FE0);
  static const Color _brandLight = Color(0xFFE040FB);
  static const Color _ink = Color(0xFF17131B);
  static const Color _muted = Color(0xFF8B8395);
  static const Color _imageBg = Color(0xFFF4F2F6);
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_brandStart, _brandMid, _brandLight],
  );

  final Product product;
  final ProductAddToCartCallback? onAddToCart;
  final bool initiallyFavorite;
  final ValueChanged<bool>? onFavoriteChanged;
  final bool initiallyInCompare;
  final ValueChanged<bool>? onCompareChanged;

  const ProductGridCard({
    super.key,
    required this.product,
    this.onAddToCart,
    this.initiallyFavorite = false,
    this.onFavoriteChanged,
    this.initiallyInCompare = false,
    this.onCompareChanged,
  });

  static String imageUrlFor(Product product) {
    final raw = product.image.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return AppConfig.imageUrl(raw);
  }

  /// Подпись «(N отзывов)» с корректным склонением; реальные значения из API.
  static String reviewsLabel(BuildContext context, int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    final String key;
    if (mod10 == 1 && mod100 != 11) {
      key = 'product.reviews_one';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      key = 'product.reviews_few';
    } else {
      key = 'product.reviews_many';
    }
    return context.tr(key, namedArgs: {'count': count.toString()});
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

    final imageUrl = imageUrlFor(product);
    final hasRating = product.rating > 0;

    return Align(
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/product/${product.id}', extra: product),
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
                    borderRadius: BorderRadius.circular(18),
                    child: ColoredBox(
                      color: _imageBg,
                      child: imageUrl.isEmpty
                          ? const _ProductGridImageShimmer()
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              // Ограничиваем декод в RAM — иначе iOS убивает приложение
                              // при длинном скролле каталога (full-res JPEG × десятки карточек).
                              memCacheWidth: (MediaQuery.devicePixelRatioOf(context) *
                                      (MediaQuery.sizeOf(context).width / 2))
                                  .round()
                                  .clamp(160, 480),
                              memCacheHeight: (MediaQuery.devicePixelRatioOf(context) *
                                      (MediaQuery.sizeOf(context).width / 2) /
                                      ProductGridCard.imageAspectRatio)
                                  .round()
                                  .clamp(200, 640),
                              maxWidthDiskCache: 480,
                              maxHeightDiskCache: 640,
                              placeholder: (context, url) =>
                                  const _ProductGridImageShimmer(),
                              errorWidget: (context, url, error) =>
                                  const _ProductGridImageError(),
                            ),
                    ),
                  ),
                  if (product.badge != null && product.badge!.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: brandGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: initiallyInCompare
                        ? ProductGridCompareButton(
                            product: product,
                            initiallyInCompare: initiallyInCompare,
                            onCompareChanged: onCompareChanged,
                          )
                        : ProductGridFavoriteButton(
                            product: product,
                            initiallyFavorite: initiallyFavorite,
                            onFavoriteChanged: onFavoriteChanged,
                          ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
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
                              SnackBar(
                                content: Text(context.tr('home.added_to_cart')),
                                duration: const Duration(milliseconds: 900),
                              ),
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: brandGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _brandStart.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 19,
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
                                color: const Color(0xFFEF4444),
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
            const SizedBox(height: 10),
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                letterSpacing: -0.2,
                leadingDistribution: TextLeadingDistribution.even,
                color: _ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            hasRating
                ? Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: Color(0xFFFFB300),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      if (product.reviewCount > 0) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            reviewsLabel(context, product.reviewCount),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  )
                : Text(
                    context.tr('product.no_reviews'),
                    style: const TextStyle(fontSize: 12, color: _muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 6),
            ProductPriceRow.fromProduct(
              product,
              priceFontSize: 16.5,
              oldPriceFontSize: 12,
              priceColor: _ink,
            ),
          ],
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
    const bar = Color(0xFFE6E2EA);
    return Align(
      alignment: Alignment.topCenter,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFEDE9F1),
        highlightColor: const Color(0xFFF9F7FB),
        period: const Duration(milliseconds: 1250),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: ProductGridCard.imageAspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9F1),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 11,
              width: 96,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 16,
              width: 72,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductGridCompareButton extends ConsumerStatefulWidget {
  final Product product;
  final bool initiallyInCompare;
  final ValueChanged<bool>? onCompareChanged;

  const ProductGridCompareButton({
    super.key,
    required this.product,
    this.initiallyInCompare = false,
    this.onCompareChanged,
  });

  @override
  ConsumerState<ProductGridCompareButton> createState() =>
      _ProductGridCompareButtonState();
}

class _ProductGridCompareButtonState
    extends ConsumerState<ProductGridCompareButton> {
  late bool _isInCompare;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isInCompare = widget.initiallyInCompare;
  }

  Future<void> _toggleCompare() async {
    if (_isLoading || !_isInCompare) return;

    setState(() => _isLoading = true);

    try {
      final compareApi = ref.read(compareApiProvider);
      final result = await compareApi.removeFromCompare(widget.product.id);
      result.when(
        ok: (_) {
          setState(() {
            _isInCompare = false;
            _isLoading = false;
          });
          widget.onCompareChanged?.call(false);
        },
        err: (_) => setState(() => _isLoading = false),
      );
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleCompare,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A17131B),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.compare_arrows_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

class ProductGridFavoriteButton extends ConsumerStatefulWidget {
  final Product product;
  final bool initiallyFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  const ProductGridFavoriteButton({
    super.key,
    required this.product,
    this.initiallyFavorite = false,
    this.onFavoriteChanged,
  });

  @override
  ConsumerState<ProductGridFavoriteButton> createState() =>
      _ProductGridFavoriteButtonState();
}

class _ProductGridFavoriteButtonState
    extends ConsumerState<ProductGridFavoriteButton> {
  late bool _isFavorite;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initiallyFavorite;
  }

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
            widget.onFavoriteChanged?.call(false);
          },
          err: _onFavoriteErr,
        );
      } else {
        final result = await favoritesApi.addToFavorites(widget.product.id);
        result.when(
          ok: (_) {
            unawaited(UserPreferenceService.instance.recordFavorite(widget.product));
            setState(() {
              _isFavorite = true;
              _isLoading = false;
            });
            widget.onFavoriteChanged?.call(true);
          },
          err: _onFavoriteErr,
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
      _onFavoriteErr(FavoritesApi.needAuth);
    }
  }

  void _onFavoriteErr(String error) {
    setState(() => _isLoading = false);
    if (!mounted) return;
    final needAuth =
        error == FavoritesApi.needAuth || !AppConfig.hasActiveToken();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          needAuth
              ? context.tr('favorites.login_required')
              : context.tr('common.error'),
        ),
        action: needAuth
            ? SnackBarAction(
                label: context.tr('auth.login'),
                onPressed: () => context.push('/login'),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleFavorite,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A17131B),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFavorite
                      ? const Color(0xFFB02FE0)
                      : const Color(0xFF8B8395),
                  size: 19,
                ),
        ),
      ),
    );
  }
}
