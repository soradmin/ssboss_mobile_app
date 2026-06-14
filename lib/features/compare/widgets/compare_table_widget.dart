import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../theme.dart';
import '../../catalog/models/product.dart';
import '../../catalog/widgets/product_grid_card.dart';
import '../../catalog/widgets/product_price_row.dart';

class CompareTableWidget extends StatelessWidget {
  final List<Product> products;
  final void Function(Product product) onRemove;

  const CompareTableWidget({
    super.key,
    required this.products,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final winnerId = _resolveOverallWinner(products);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (winnerId != null) _BestChoiceBanner(products: products, winnerId: winnerId),
        const SizedBox(height: 12),
        _ProductHeadersRow(
          products: products,
          onRemove: onRemove,
          winnerId: winnerId,
        ),
        const SizedBox(height: 12),
        _CompareSectionTitle('Основные параметры'),
        _CompareRow(
          label: 'Цена',
          products: products,
          bestProductIds: _bestByPrice(products),
          builder: (p) => ProductPriceRow.fromProduct(
            p,
            priceFontSize: 15,
            oldPriceFontSize: 11,
            alignment: MainAxisAlignment.center,
          ),
        ),
        _CompareRow(
          label: 'Скидка',
          products: products,
          bestProductIds: _bestByDiscount(products),
          builder: (p) => Text(
            p.hasDiscount ? '-${_discountPercent(p)}%' : '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.hasDiscount ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ),
        _CompareRow(
          label: 'Рейтинг',
          products: products,
          bestProductIds: _bestByRating(products),
          builder: (p) => _RatingCell(product: p),
        ),
        _CompareRow(
          label: 'Отзывы',
          products: products,
          bestProductIds: _bestByReviews(products),
          builder: (p) => Text(
            p.reviewCount > 0 ? '${p.reviewCount}' : '—',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (products.any((p) => (p.sellerName ?? '').isNotEmpty)) ...[
          _CompareRow(
            label: 'Продавец',
            products: products,
            builder: (p) => Text(
              (p.sellerName ?? '').isNotEmpty ? p.sellerName! : '—',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        ..._buildAttributeRows(products, isDark),
      ],
    );
  }

  List<Widget> _buildAttributeRows(List<Product> products, bool isDark) {
    final titles = <String>{};
    for (final product in products) {
      for (final attr in product.attributes) {
        final title = attr.title.trim();
        if (title.isNotEmpty) titles.add(title);
      }
    }
    if (titles.isEmpty) return [];

    final sortedTitles = titles.toList()..sort();
    return [
      const SizedBox(height: 8),
      _CompareSectionTitle('Характеристики'),
      ...sortedTitles.map(
        (title) => _CompareRow(
          label: title,
          products: products,
          builder: (p) => Text(
            _attributeValue(p, title),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    ];
  }
}

class _BestChoiceBanner extends StatelessWidget {
  final List<Product> products;
  final int winnerId;

  const _BestChoiceBanner({
    required this.products,
    required this.winnerId,
  });

  @override
  Widget build(BuildContext context) {
    final winner = products.firstWhere((p) => p.id == winnerId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.12),
            const Color(0xFFE040FB).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: primaryColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Лучший выбор',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  winner.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductHeadersRow extends StatelessWidget {
  final List<Product> products;
  final void Function(Product product) onRemove;
  final int? winnerId;

  const _ProductHeadersRow({
    required this.products,
    required this.onRemove,
    this.winnerId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ProductHeaderCard(
              product: products[i],
              isWinner: winnerId == products[i].id,
              onRemove: () => onRemove(products[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductHeaderCard extends StatelessWidget {
  final Product product;
  final bool isWinner;
  final VoidCallback onRemove;

  const _ProductHeaderCard({
    required this.product,
    required this.isWinner,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = ProductGridCard.imageUrlFor(product);

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}', extra: product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: ProductGridCard.imageAspectRatio,
                      child: imageUrl.isEmpty
                          ? ColoredBox(
                              color: Colors.grey[200]!,
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.grey[400],
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  if (isWinner)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Лучший',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareSectionTitle extends StatelessWidget {
  final String title;

  const _CompareSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final List<Product> products;
  final Set<int>? bestProductIds;
  final Widget Function(Product product) builder;

  const _CompareRow({
    required this.label,
    required this.products,
    required this.builder,
    this.bestProductIds,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : const Color(0xFFE9ECEF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : const Color(0xFF6C757D),
              ),
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < products.length; i++) ...[
                  if (i > 0)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark ? Colors.grey[700] : const Color(0xFFE9ECEF),
                    ),
                  Expanded(
                    child: _CompareCell(
                      isBest: bestProductIds?.contains(products[i].id) ?? false,
                      child: builder(products[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareCell extends StatelessWidget {
  final Widget child;
  final bool isBest;

  const _CompareCell({
    required this.child,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isBest ? Colors.green.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Center(child: child),
          if (isBest)
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }
}

class _RatingCell extends StatelessWidget {
  final Product product;

  const _RatingCell({required this.product});

  @override
  Widget build(BuildContext context) {
    if (product.rating <= 0) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          product.rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

int _discountPercent(Product product) {
  if (!product.hasDiscount || product.oldPrice == null || product.oldPrice! <= 0) {
    return 0;
  }
  return (((product.oldPrice! - product.price) / product.oldPrice!) * 100).round();
}

String _attributeValue(Product product, String title) {
  for (final attr in product.attributes) {
    if (attr.title.trim() == title && attr.values.isNotEmpty) {
      return attr.values.map((v) => v.title).where((t) => t.isNotEmpty).join(', ');
    }
  }
  return '—';
}

Set<int> _bestByPrice(List<Product> products) {
  final valid = products.where((p) => p.price > 0).toList();
  if (valid.length < 2) return {};
  final minPrice = valid.map((p) => p.price).reduce((a, b) => a < b ? a : b);
  return valid.where((p) => p.price == minPrice).map((p) => p.id).toSet();
}

Set<int> _bestByDiscount(List<Product> products) {
  final withDiscount = products.where((p) => p.hasDiscount).toList();
  if (withDiscount.length < 2) return {};
  final maxDiscount = withDiscount
      .map(_discountPercent)
      .reduce((a, b) => a > b ? a : b);
  if (maxDiscount <= 0) return {};
  return withDiscount
      .where((p) => _discountPercent(p) == maxDiscount)
      .map((p) => p.id)
      .toSet();
}

Set<int> _bestByRating(List<Product> products) {
  final rated = products.where((p) => p.rating > 0).toList();
  if (rated.length < 2) return {};
  final maxRating = rated.map((p) => p.rating).reduce((a, b) => a > b ? a : b);
  return rated.where((p) => p.rating == maxRating).map((p) => p.id).toSet();
}

Set<int> _bestByReviews(List<Product> products) {
  final reviewed = products.where((p) => p.reviewCount > 0).toList();
  if (reviewed.length < 2) return {};
  final maxReviews =
      reviewed.map((p) => p.reviewCount).reduce((a, b) => a > b ? a : b);
  return reviewed
      .where((p) => p.reviewCount == maxReviews)
      .map((p) => p.id)
      .toSet();
}

int? _resolveOverallWinner(List<Product> products) {
  if (products.length < 2) return null;

  final scores = <int, int>{for (final p in products) p.id: 0};

  void addPoints(Set<int> winners) {
    for (final id in winners) {
      scores[id] = (scores[id] ?? 0) + 1;
    }
  }

  addPoints(_bestByPrice(products));
  addPoints(_bestByDiscount(products));
  addPoints(_bestByRating(products));
  addPoints(_bestByReviews(products));

  final maxScore = scores.values.reduce((a, b) => a > b ? a : b);
  if (maxScore <= 0) return null;

  final leaders = scores.entries.where((e) => e.value == maxScore).toList();
  if (leaders.length != 1) return null;
  return leaders.first.key;
}
