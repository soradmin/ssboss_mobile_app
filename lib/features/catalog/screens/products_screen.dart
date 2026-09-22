import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../core/l10n/locale_controller.dart';
import '../repo/catalog_api.dart';
import '../models/product.dart';
import '../../../core/result.dart';
import '../widgets/product_grid_card.dart';
import '../../personalization/user_preference_service.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? searchQuery;
  final String? categoryTitle;
  final int? categoryId;
  final int? brandId;
  final String? brandTitle;
  final int? bannerId;
  final int? sliderId;

  const ProductsScreen({
    super.key,
    this.category,
    this.searchQuery,
    this.categoryTitle,
    this.categoryId,
    this.brandId,
    this.brandTitle,
    this.bannerId,
    this.sliderId,
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

  String _sortby = '';
  double _minPrice = 0;
  double _maxPrice = 0;
  int _minRating = 0;

  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    var n = 0;
    if (_sortby.isNotEmpty) n++;
    if (_minPrice > 0) n++;
    if (_maxPrice > 0) n++;
    if (_minRating > 0) n++;
    return n;
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
    final searchQuery = widget.searchQuery?.trim();
    final Result<List<Product>> result;

    if (searchQuery != null &&
        searchQuery.isNotEmpty &&
        widget.bannerId == null &&
        widget.sliderId == null &&
        _sortby.isEmpty &&
        _minPrice <= 0 &&
        _maxPrice <= 0 &&
        _minRating <= 0) {
      if (_currentPage == 1) {
        unawaited(UserPreferenceService.instance.recordSearch(searchQuery));
      }
      result = await api.searchProducts(searchQuery, page: _currentPage);
    } else {
      if (_currentPage == 1 &&
          widget.category != null &&
          widget.category!.isNotEmpty) {
        unawaited(
          UserPreferenceService.instance.recordCategoryBrowse(
            categorySlug: widget.category!,
            categoryTitle: widget.categoryTitle,
          ),
        );
      }
      result = await api.products(
        page: _currentPage,
        category: widget.category,
        categoryId: widget.categoryId,
        brandId: widget.brandId,
        search: searchQuery,
        sortby: _sortby,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        rating: _minRating,
        bannerId: widget.bannerId,
        sliderId: widget.sliderId,
      );
    }

    if (!mounted) return;
    if (result is Ok<List<Product>>) {
      final newProducts = result.value;
      setState(() {
        if (refresh || _currentPage == 1) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }
        _currentPage++;
        _hasMore = newProducts.length >= 20;
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

  Future<void> _openFilters() async {
    _minCtrl.text = _minPrice > 0 ? _minPrice.toStringAsFixed(0) : '';
    _maxCtrl.text = _maxPrice > 0 ? _maxPrice.toStringAsFixed(0) : '';
    var draftSort = _sortby;
    var draftRating = _minRating;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Widget sortChip(String label, String value) {
              final selected = draftSort == value;
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setModal(() {
                  draftSort = selected ? '' : value;
                }),
                selectedColor: const Color(0xFFE1BEE7),
                checkmarkColor: const Color(0xFF9C27B0),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('catalog.filters'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('catalog.sort'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        sortChip(context.tr('catalog.sort_new'), ''),
                        sortChip(
                          context.tr('catalog.sort_price_asc'),
                          'price_low_to_high',
                        ),
                        sortChip(
                          context.tr('catalog.sort_price_desc'),
                          'price_high_to_low',
                        ),
                        sortChip(
                          context.tr('catalog.sort_rating'),
                          'avg_customer_review',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('catalog.price_range'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.tr('catalog.price_min'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.tr('catalog.price_max'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('catalog.min_rating'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0, 3, 4, 5].map((r) {
                        final selected = draftRating == r;
                        final label = r == 0
                            ? context.tr('catalog.any')
                            : '$r+ ★';
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) => setModal(() => draftRating = r),
                          selectedColor: const Color(0xFFE1BEE7),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              draftSort = '';
                              draftRating = 0;
                              _minCtrl.clear();
                              _maxCtrl.clear();
                              setModal(() {});
                            },
                            child: Text(context.tr('catalog.reset')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF9C27B0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              _sortby = draftSort;
                              _minRating = draftRating;
                              _minPrice =
                                  double.tryParse(_minCtrl.text.trim()) ?? 0;
                              _maxPrice =
                                  double.tryParse(_maxCtrl.text.trim()) ?? 0;
                              Navigator.pop(ctx, true);
                            },
                            child: Text(context.tr('catalog.apply')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      await _loadProducts(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        title: Text(
          (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty)
              ? context.tr('common.search')
              : (widget.brandTitle ??
                  widget.categoryTitle ??
                  widget.category ??
                  context.tr('catalog.products')),
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
            tooltip: context.tr('catalog.filters'),
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _activeFilterCount > 0,
              label: Text('$_activeFilterCount'),
              child: const Icon(Icons.tune_rounded, color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: () => _loadProducts(refresh: true),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _buildBody(),
      extendBody: true,
    );
  }

  Widget _buildBody() {
    if (_loading && _products.isEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      var crossAxisCount = 2;
      if (screenWidth > 600) crossAxisCount = 3;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: ProductGridCard.gridChildAspectRatio,
            crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
            mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
          ),
          itemCount: crossAxisCount * 4,
          itemBuilder: (context, index) => const ProductGridCardSkeleton(),
        ),
      );
    }

    if (_error != null && _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                context.tr('catalog.load_error'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadProducts(refresh: true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                ),
                child: Text(context.tr('common.retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                context.tr('catalog.empty'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('catalog.empty_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              if (_activeFilterCount > 0)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _sortby = '';
                      _minPrice = 0;
                      _maxPrice = 0;
                      _minRating = 0;
                    });
                    _loadProducts(refresh: true);
                  },
                  child: Text(context.tr('catalog.reset')),
                )
              else
                FilledButton(
                  onPressed: () => context.go('/catalog'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                  ),
                  child: Text(context.tr('catalog.go_categories')),
                ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProducts(refresh: true),
      child: CustomScrollView(
        slivers: [
          if (_activeFilterCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_sortby.isNotEmpty)
                      InputChip(
                        label: Text(_sortLabel()),
                        onDeleted: () {
                          setState(() => _sortby = '');
                          _loadProducts(refresh: true);
                        },
                      ),
                    if (_minPrice > 0 || _maxPrice > 0)
                      InputChip(
                        label: Text(
                          '${_minPrice > 0 ? _minPrice.toStringAsFixed(0) : '0'} – '
                          '${_maxPrice > 0 ? _maxPrice.toStringAsFixed(0) : '∞'} ${context.tr('common.currency')}',
                        ),
                        onDeleted: () {
                          setState(() {
                            _minPrice = 0;
                            _maxPrice = 0;
                          });
                          _loadProducts(refresh: true);
                        },
                      ),
                    if (_minRating > 0)
                      InputChip(
                        label: Text('$_minRating+ ★'),
                        onDeleted: () {
                          setState(() => _minRating = 0);
                          _loadProducts(refresh: true);
                        },
                      ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
                crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
                childAspectRatio: ProductGridCard.gridChildAspectRatio,
              ),
              itemCount: _products.length + (_loadingMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= _products.length) {
                  return const ProductGridCardSkeleton();
                }
                return ProductGridCard(product: _products[index]);
              },
            ),
          ),
          if (_hasMore && !_loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: FilledButton(
                    onPressed: () => _loadProducts(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                    ),
                    child: Text(context.tr('catalog.load_more')),
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }

  String _sortLabel() {
    switch (_sortby) {
      case 'price_low_to_high':
        return context.tr('catalog.sort_price_asc');
      case 'price_high_to_low':
        return context.tr('catalog.sort_price_desc');
      case 'avg_customer_review':
        return context.tr('catalog.sort_rating');
      default:
        return context.tr('catalog.sort_new');
    }
  }
}
