import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../theme.dart';
import '../models/store.dart';
import '../repo/store_api.dart';

class FavoriteStoresScreen extends ConsumerStatefulWidget {
  const FavoriteStoresScreen({super.key});

  @override
  ConsumerState<FavoriteStoresScreen> createState() =>
      _FavoriteStoresScreenState();
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
        if (!isFollowing) {
          setState(() {
            _stores.removeWhere((s) => s.id == store.id);
          });
        } else {
          setState(() {
            final index = _stores.indexWhere((s) => s.id == store.id);
            if (index != -1) {
              _stores[index] = store.copyWith(isFollowing: true);
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFollowing
                  ? 'Подписались на ${store.name}'
                  : '${store.name} удалён из любимых',
            ),
            backgroundColor: isFollowing ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
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

  String _storeImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return AppConfig.imageUrl(raw);
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
                Color(0xFF9C27B0),
                Color(0xFFE040FB),
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
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('Ошибка загрузки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFavoriteStores,
            child: const Text('Повторить'),
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
          Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
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
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Найти магазины'),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresList() {
    return RefreshIndicator(
      onRefresh: _loadFavoriteStores,
      color: primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _stores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildStoreCard(_stores[index]),
      ),
    );
  }

  Widget _buildStoreCard(Store store) {
    final imageUrl = _storeImageUrl(store.logo);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push('/store/${store.slug}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: const Color(0xFFF1F3F5),
                          child: Icon(
                            Icons.storefront_rounded,
                            color: Colors.grey[400],
                            size: 28,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((store.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        store.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatChip(
                          icon: Icons.star_rounded,
                          label: store.rating > 0
                              ? store.formattedRating
                              : '—',
                          color: Colors.amber[700]!,
                        ),
                        _StatChip(
                          icon: Icons.inventory_2_outlined,
                          label: '${store.formattedProducts} товаров',
                          color: primaryColor,
                        ),
                        if (store.formattedMemberSince.isNotEmpty)
                          _StatChip(
                            icon: Icons.calendar_today_outlined,
                            label: 'с ${store.formattedMemberSince}',
                            color: Colors.grey[700]!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _toggleFollow(store),
                icon: const Icon(Icons.favorite_rounded, color: Colors.red),
                tooltip: 'Убрать из любимых',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
