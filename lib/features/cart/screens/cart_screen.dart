import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../repo/cart_api.dart';
import '../../../core/result.dart';
import '../../checkout/screens/checkout_screen.dart';

enum CartMode { local, server }

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  CartMode _mode = CartMode.local;
  bool _loading = false;
  List<ServerCartLine> _server = const [];

  Future<void> _loadServer() async {
    setState(() => _loading = true);
    final r = await CartApi().getCart();
    if (!mounted) return;
    if (r is Ok<List<ServerCartLine>>) {
      setState(() => _server = r.value);
    } else {
      final msg = (r as Err).message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Серверная корзина: $msg')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localItems = ref.watch(cartProvider);
    final totalLocal = ref.read(cartProvider.notifier).total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<CartMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: CartMode.local, label: Text('Локально')),
                ButtonSegment(value: CartMode.server, label: Text('Сервер')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) async {
                final v = s.first;
                setState(() => _mode = v);
                if (v == CartMode.server) {
                  await _loadServer();
                }
              },
            ),
          ),
        ],
      ),
      body: _mode == CartMode.local
          ? _LocalCartView(items: localItems, total: totalLocal)
          : _ServerCartView(loading: _loading, serverItems: _server),
    );
  }
}

class _LocalCartView extends StatelessWidget {
  final List<CartItem> items;
  final double total;
  const _LocalCartView({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    return items.isEmpty
        ? const Center(child: Text('Ваша корзина пуста'))
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(it.qty.toString())),
                      title: Text(it.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${it.product.price.toStringAsFixed(2)} × ${it.qty}'),
                      trailing: Text('${it.subtotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const CheckoutScreen(), // если конструктор вдруг не const — убери const
    ),
  );
},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Оформить  ·  '),
                      Text('${total.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}

class _ServerCartView extends StatelessWidget {
  final bool loading;
  final List<ServerCartLine> serverItems;
  const _ServerCartView({required this.loading, required this.serverItems});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (serverItems.isEmpty) return const Center(child: Text('На сервере корзина пуста'));

    final total = serverItems.fold<double>(0, (p, e) => p + (e.price * e.quantity));

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: serverItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = serverItems[i];
              return ListTile(
                leading: it.image.isEmpty
                    ? const CircleAvatar(child: Icon(Icons.image_not_supported_outlined))
                    : CircleAvatar(backgroundImage: NetworkImage(it.image)),
                title: Text(it.name.isEmpty ? 'Товар #${it.productId}' : it.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${it.price.toStringAsFixed(2)} × ${it.quantity}'),
                trailing: Text('${(it.price * it.quantity).toStringAsFixed(2)}'),
              );
            },
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checkout: подключим следом')),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Оформить (сервер)  ·  '),
                Text('${total.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
