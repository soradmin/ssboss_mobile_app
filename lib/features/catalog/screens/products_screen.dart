import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bottom_navigation_bar.dart';
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

    final Result<List<Product>> result;
    final searchQuery = widget.searchQuery?.trim();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      if (_currentPage == 1) {
        unawaited(UserPreferenceService.instance.recordSearch(searchQuery));
      }
      result = await api.searchProducts(searchQuery, page: _currentPage);
    } else {
      if (_currentPage == 1 && widget.category != null && widget.category!.isNotEmpty) {
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
      );
    }
    
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
          (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty)
              ? 'Поиск'
              : (widget.categoryTitle ?? widget.category ?? 'Товары'),
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
      final screenWidth = MediaQuery.of(context).size.width;
      var crossAxisCount = 2;
      if (screenWidth > 600) {
        crossAxisCount = 3;
      }
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

