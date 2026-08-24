import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../theme.dart';
import '../../../core/config.dart';
import '../models/store.dart';
import '../repo/store_api.dart';
import '../../catalog/models/product.dart';
import '../../catalog/widgets/product_grid_card.dart';

class StoreDetailsScreen extends ConsumerStatefulWidget {
  final String storeSlug;

  const StoreDetailsScreen({
    super.key,
    required this.storeSlug,
  });

  @override
  ConsumerState<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends ConsumerState<StoreDetailsScreen> {
  Store? _store;
  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  bool _productsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStoreDetails();
  }

  Future<void> _loadStoreDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final storeApi = ref.read(storeApiProvider);
    final result = await storeApi.getStoreBySlug(widget.storeSlug);

    result.when(
      ok: (store) {
        setState(() {
          _store = store;
          _isLoading = false;
        });
        // Загружаем товары магазина
        _loadStoreProducts();
      },
      err: (error) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _loadStoreProducts() async {
    setState(() {
      _productsLoading = true;
    });

    final storeApi = ref.read(storeApiProvider);
    final result = await storeApi.getStoreProducts(widget.storeSlug);

    result.when(
      ok: (productsData) {
        // Парсим товары напрямую из ответа API
        final products = productsData
            .where((p) => p is Map<String, dynamic>)
            .map((p) {
              try {
                return Product.fromJson(p as Map<String, dynamic>);
              } catch (e) {
                print('[ERROR] Ошибка парсинга товара: $e');
                return null;
              }
            })
            .whereType<Product>()
            .toList();
        
        setState(() {
          _products = products;
          _productsLoading = false;
        });
      },
      err: (error) {
        print('[ERROR] Ошибка загрузки товаров магазина: $error');
        setState(() {
          _productsLoading = false;
        });
      },
    );
  }

  Future<void> _toggleFollow() async {
    if (_store == null) return;

    final storeApi = ref.read(storeApiProvider);
    final result = await storeApi.toggleFollowStore(_store!.id);

    result.when(
      ok: (isFollowing) {
        setState(() {
          _store = _store!.copyWith(isFollowing: isFollowing);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFollowing ? context.tr('stores.followed', namedArgs: {'name': _store!.name}) : context.tr('stores.unfollowed', namedArgs: {'name': _store!.name})),
            backgroundColor: isFollowing ? Colors.green : Colors.orange,
          ),
        );
      },
      err: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('common.error')}: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
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
        title: Text(
          context.tr('stores.store'),
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
            onPressed: _loadStoreDetails,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _store == null
                  ? Center(child: Text(context.tr('stores.not_found')))
                  : _buildStoreDetails(),
      extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 1),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('catalog.load_error'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
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
              onPressed: _loadStoreDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.tr('common.retry')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDetails() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Баннер магазина
          if (_store!.banner != null)
            Container(
              height: 200,
              width: double.infinity,
              child: Image.network(
                _store!.banner!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(Icons.store, size: 64, color: Colors.grey[400]),
                  );
                },
              ),
            ),
          
          // Основная информация
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Логотип и название
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _store!.resolvedLogoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _store!.resolvedLogoUrl,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF8813BA),
                                size: 36,
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFF8813BA),
                              size: 36,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _store!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '${_store!.formattedRating} рейтинг',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Кнопка подписки
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _store!.isFollowing
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFC94F4F), // Темно-красный
                                Color(0xFFE85A5A), // Светло-красный
                              ],
                              stops: [0.0, 1.0],
                            )
                          : const LinearGradient(
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
                      onPressed: _toggleFollow,
                      icon: Icon(
                        _store!.isFollowing ? Icons.favorite : Icons.favorite_border,
                        color: Colors.white,
                      ),
                      label: Text(
                        _store!.isFollowing ? context.tr('stores.unfollow') : context.tr('stores.follow'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Статистика
                _buildStatsCard(),
                
                const SizedBox(height: 16),
                
                // Описание
                if (_store!.description != null) ...[
                  _buildInfoCard(
                    context.tr('stores.about'),
                    _store!.description!,
                    Icons.info_outline,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Контактная информация
                if (_store!.email != null || _store!.phone != null || _store!.website != null)
                  _buildContactCard(),
                
                const SizedBox(height: 24),
                
                // Товары магазина
                _buildStoreProducts(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr('stores.products')} (${_store!.totalProducts})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_productsLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: ProductGridCard.gridChildAspectRatio,
              crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
              mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const ProductGridCardSkeleton(),
          )
        else if (_products.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.tr('stores.no_products'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: ProductGridCard.gridChildAspectRatio,
              crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
              mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return ProductGridCard(product: _products[index]);
            },
          ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('stores.stats'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.shopping_bag_outlined,
                    label: context.tr('catalog.products'),
                    value: _store!.formattedProducts,
                    color: Colors.blue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.people_outline,
                    label: context.tr('stores.subscribers'),
                    value: _store!.formattedFollowers,
                    color: Colors.green,
                  ),
                ),
                Container(
                  width: 1,
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.calendar_today_outlined,
                    label: context.tr('stores.on_platform'),
                    value: _store!.formattedMemberSince,
                    color: Colors.orange,
                    valueFontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    double valueFontSize = 18,
  }) {
    return SizedBox(
      height: 84,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_mail, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  context.tr('stores.contacts'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_store!.email != null)
              _buildContactItem(Icons.email, 'Email', _store!.email!),
            if (_store!.phone != null)
              _buildContactItem(Icons.phone, context.tr('stores.phone'), _store!.phone!),
            if (_store!.website != null)
              _buildContactItem(Icons.language, context.tr('stores.website'), _store!.website!),
            if (_store!.address != null)
              _buildContactItem(Icons.location_on, context.tr('stores.address'), _store!.address!),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
