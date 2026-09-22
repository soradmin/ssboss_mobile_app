import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/locale_controller.dart';
import '../../../core/result.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../models/product.dart';
import '../repo/catalog_api.dart';
import 'product_details_screen.dart';

/// Загрузка карточки товара по id (deep link / push без `extra`).
class ProductDetailsLoader extends ConsumerStatefulWidget {
  final int productId;
  final Product? initial;

  const ProductDetailsLoader({
    super.key,
    required this.productId,
    this.initial,
  });

  @override
  ConsumerState<ProductDetailsLoader> createState() =>
      _ProductDetailsLoaderState();
}

class _ProductDetailsLoaderState extends ConsumerState<ProductDetailsLoader> {
  Product? _product;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && widget.initial!.id == widget.productId) {
      _product = widget.initial;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.productId <= 0) {
      setState(() {
        _loading = false;
        _error = 'invalid';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await CatalogApi().productById(widget.productId);
    if (!mounted) return;
    if (result is Ok<Product>) {
      setState(() {
        _product = result.value;
        _loading = false;
      });
    } else {
      setState(() {
        _error = (result as Err).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);

    if (_product != null) {
      return ProductDetailsScreen(p: _product!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('catalog.products')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 1),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Color(0xFF9C27B0))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('product.not_found'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_error != null && _error != 'invalid') ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _load,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                      ),
                      child: Text(context.tr('common.retry')),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
