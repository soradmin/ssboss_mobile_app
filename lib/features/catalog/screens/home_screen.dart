import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_item.dart';
import '../repo/catalog_api.dart';
import '../models/product.dart';
import '../../../core/result.dart';         // Ok/Err
import '../../cart/repo/cart_api.dart';    // серверная корзина

final _api = CatalogApi();

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Product> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _api.products();
    if (res is Ok<List<Product>>) {
      setState(() => _products = res.value);
    } else {
      final msg = (res as Err).message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка каталога: $msg')),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartCount = cart.fold<int>(0, (p, e) => p + e.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSBOSS'),
        actions: [
          Stack(
            children: [
              IconButton(
                onPressed: () => context.go('/cart'),
                icon: const Icon(Icons.shopping_cart_outlined),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/'); break;
            case 1: context.go('/cart'); break;
            case 2: context.go('/orders'); break;
            case 3: context.go('/profile'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Корзина'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Заказы'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Профиль'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroBanner(),
                          const SizedBox(height: 12),
                          Text('Хиты продаж', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, i) => _ProductCard(p: _products[i]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CarouselSlider(
        options: CarouselOptions(height: 160, viewportFraction: 1.0, autoPlay: true),
        items: [1, 2, 3]
            .map((i) => Container(color: Colors.black12, child: Center(child: Text('Баннер $i'))))
            .toList(),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product p;
  const _ProductCard({required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/product/${p.id}', extra: p),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: p.image.isEmpty
                    ? const ColoredBox(
                        color: Color(0x11000000),
                        child: Center(child: Icon(Icons.image_not_supported_outlined)),
                      )
                    : Image.network(
                        p.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0x11000000),
                          child: Center(child: Icon(Icons.broken_image_outlined)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            FilledButton.tonal(
              onPressed: () async {
                // 1) мгновенно — локальная корзина (для бейджа и UI)
                ref.read(cartProvider.notifier).add(CartItem(product: p, qty: 1));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Добавлено: ${p.name}')),
                  );
                }

                // 2) серверная синхронизация (как в карточке товара)
                final r = await CartApi().add(p.id, 1);
                if (r is Err) {
                  final msg = r.message;
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Серверная корзина: $msg')),
                    );
                  }
                }
              },
              child: const Text('В корзину'),
            ),
          ]),
        ),
      ),
    );
  }
}
