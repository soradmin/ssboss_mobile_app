import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../theme.dart';
import '../../catalog/models/product.dart';
import '../../catalog/repo/catalog_api.dart';
import '../../catalog/widgets/product_grid_card.dart';
import '../repo/compare_api.dart';
import '../widgets/compare_table_widget.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  List<Product> _products = [];
  List<Product> _detailedProducts = [];
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompareProducts();
  }

  Future<void> _loadCompareProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _detailedProducts = [];
    });

    final compareApi = ref.read(compareApiProvider);
    final result = await compareApi.getCompareProducts();

    result.when(
      ok: (products) async {
        setState(() {
          _products = products;
          _isLoading = false;
        });
        if (products.length >= 2) {
          await _loadDetailedProducts(products);
        }
      },
      err: (error) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadDetailedProducts(List<Product> products) async {
    setState(() => _isLoadingDetails = true);

    final catalogApi = CatalogApi();
    final detailed = <Product>[];

    for (final product in products) {
      final result = await catalogApi.productById(product.id);
      result.when(
        ok: (fullProduct) => detailed.add(fullProduct),
        err: (_) => detailed.add(product),
      );
    }

    if (!mounted) return;
    setState(() {
      _detailedProducts = detailed;
      _isLoadingDetails = false;
    });
  }

  List<Product> get _productsForComparison =>
      _detailedProducts.isNotEmpty ? _detailedProducts : _products;

  Future<void> _removeFromCompare(Product product) async {
    final compareApi = ref.read(compareApiProvider);
    final result = await compareApi.removeFromCompare(product.id);

    result.when(
      ok: (success) {
        if (!success) return;

        setState(() {
          _products.removeWhere((p) => p.id == product.id);
          _detailedProducts.removeWhere((p) => p.id == product.id);
        });

        if (_products.length >= 2 && _detailedProducts.length < _products.length) {
          _loadDetailedProducts(_products);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.compare_arrows_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${product.name} удален из сравнений',
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
      },
      err: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $error'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : backgroundColor,
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
              stops: [0.0, 1.0],
            ),
          ),
        ),
        title: const Text(
          'Сравнения',
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
            onPressed: _loadCompareProducts,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _products.isEmpty
                    ? _buildEmptyState()
                    : _buildContent(),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 1),
    );
  }

  Widget _buildContent() {
    if (_products.length == 1) {
      return _buildSingleProductView();
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadCompareProducts,
          color: primaryColor,
          child: CompareTableWidget(
            products: _productsForComparison,
            onRemove: _removeFromCompare,
          ),
        ),
        if (_isLoadingDetails)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildSingleProductView() {
    final product = _products.first;

    return RefreshIndicator(
      onRefresh: _loadCompareProducts,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Добавьте ещё один товар, чтобы сравнить цену, рейтинг и характеристики',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ProductGridCard(
            key: ValueKey(product.id),
            product: product,
            initiallyInCompare: true,
            onCompareChanged: (isInCompare) {
              if (!isInCompare) {
                setState(() => _products.clear());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} удален из сравнений'),
                    backgroundColor: Colors.orange[600],
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
          ),
        ],
      ),
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
            'Загружаем товары для сравнения...',
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
                color: isDark ? Colors.red[900]?.withValues(alpha: 0.3) : Colors.red[50],
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
                    Color(0xFF9C27B0),
                    Color(0xFFE040FB),
                  ],
                  stops: [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _loadCompareProducts,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Повторить', style: TextStyle(color: Colors.white)),
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
                color: isDark ? Colors.blue[900]?.withValues(alpha: 0.3) : Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compare_arrows_rounded,
                size: 48,
                color: isDark ? Colors.blue[300] : Colors.blue[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'У вас пока нет товаров для сравнения',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте товары в сравнение, чтобы они появились здесь!',
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
                    Color(0xFF9C27B0),
                    Color(0xFFE040FB),
                  ],
                  stops: [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                label: const Text('Найти товары', style: TextStyle(color: Colors.white)),
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
}
