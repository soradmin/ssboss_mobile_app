import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../theme.dart';
import '../../../core/config.dart';
import '../models/store.dart';
import '../repo/store_api.dart';
import '../../catalog/models/product.dart';

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
            content: Text(isFollowing ? 'Подписались на ${_store!.name}' : 'Отписались от ${_store!.name}'),
            backgroundColor: isFollowing ? Colors.green : Colors.orange,
          ),
        );
      },
      err: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Магазин',
          style: TextStyle(
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
                  ? const Center(child: Text('Магазин не найден'))
                  : _buildStoreDetails(),
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
            'Ошибка загрузки',
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
              child: const Text('Повторить'),
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
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _store!.logo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _store!.logo!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.store, color: Colors.grey[400]);
                                },
                              ),
                            )
                          : Icon(Icons.store, color: Colors.grey[400]),
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
                        _store!.isFollowing ? 'Отписаться' : 'Подписаться',
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
                    'О магазине',
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
          'Товары магазина (${_store!.totalProducts})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_productsLoading)
          const Center(child: CircularProgressIndicator())
        else if (_products.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Товары не найдены',
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
              childAspectRatio: 0.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return _buildProductCard(product);
            },
          ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        context.push('/product/${product.id}');
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение товара
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: AppConfig.imageUrl(product.image),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  if (product.badge != null && product.badge!.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.badge!,
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
                  if (product.oldPrice != null && product.oldPrice! > product.price) ...[
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
                            const Icon(Icons.star, size: 11, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 9),
                            ),
                            if (product.reviewCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${product.reviewCount})',
                                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
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

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Статистика',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    Icons.shopping_bag,
                    'Товары',
                    _store!.formattedProducts,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.people,
                    'Подписчики',
                    _store!.formattedFollowers,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    Icons.calendar_today,
                    'С',
                    _store!.formattedMemberSince,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
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
                  'Контактная информация',
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
              _buildContactItem(Icons.phone, 'Телефон', _store!.phone!),
            if (_store!.website != null)
              _buildContactItem(Icons.language, 'Сайт', _store!.website!),
            if (_store!.address != null)
              _buildContactItem(Icons.location_on, 'Адрес', _store!.address!),
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
