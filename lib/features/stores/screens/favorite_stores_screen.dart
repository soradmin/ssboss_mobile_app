import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../theme.dart';
import '../models/store.dart';
import '../repo/store_api.dart';

class FavoriteStoresScreen extends ConsumerStatefulWidget {
  const FavoriteStoresScreen({super.key});

  @override
  ConsumerState<FavoriteStoresScreen> createState() => _FavoriteStoresScreenState();
}

class _FavoriteStoresScreenState extends ConsumerState<FavoriteStoresScreen> {
  List<Store> _stores = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStores();
  }

  Future<void> _loadFavoriteStores() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final storeApi = ref.read(storeApiProvider);
    final result = await storeApi.getFavoriteStores();

    result.when(
      ok: (stores) {
        setState(() {
          _stores = stores;
          _isLoading = false;
        });
      },
      err: (error) {
        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _toggleFollow(Store store) async {
    final storeApi = ref.read(storeApiProvider);
    final result = await storeApi.toggleFollowStore(store.id);

    result.when(
      ok: (isFollowing) {
        setState(() {
          final index = _stores.indexWhere((s) => s.id == store.id);
          if (index != -1) {
            _stores[index] = store.copyWith(isFollowing: isFollowing);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFollowing ? 'Подписались на ${store.name}' : 'Отписались от ${store.name}'),
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
          'Любимые магазины',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _stores.isEmpty
                  ? _buildEmptyState()
                  : _buildStoresList(),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
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
              onPressed: _loadFavoriteStores,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'У вас пока нет любимых магазинов',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Подпишитесь на интересные магазины!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
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
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Найти магазины'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresList() {
    return RefreshIndicator(
      onRefresh: _loadFavoriteStores,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stores.length,
        itemBuilder: (context, index) {
          final store = _stores[index];
          return _buildStoreCard(store);
        },
      ),
    );
  }

  Widget _buildStoreCard(Store store) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/store/${store.slug}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Логотип магазина
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: store.logo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              store.logo!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.store, color: Colors.grey[400]);
                              },
                            ),
                          )
                        : Icon(Icons.store, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 12),
                  // Информация о магазине
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (store.description != null) ...[
                          Text(
                            store.description!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              store.formattedRating,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.shopping_bag, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${store.formattedProducts} товаров',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${store.formattedFollowers} подписчиков',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.calendar_today, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'С ${store.formattedMemberSince}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Кнопка подписки
                  IconButton(
                    onPressed: () => _toggleFollow(store),
                    icon: Icon(
                      store.isFollowing ? Icons.favorite : Icons.favorite_border,
                      color: store.isFollowing ? Colors.red : Colors.grey,
                    ),
                    tooltip: store.isFollowing ? 'Отписаться' : 'Подписаться',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
