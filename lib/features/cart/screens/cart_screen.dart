import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/network/network_status.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../../catalog/models/product.dart';
import '../../../theme.dart';
import '../../../core/config.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeControllerProvider);
    final localItems = ref.watch(cartProvider);
    final totalLocal = ref.read(cartProvider.notifier).total;

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
          context.tr('cart.title'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              // Показываем индикатор загрузки
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(context.tr('cart.syncing')),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: primaryColor,
                  ),
                );
              }
              
              // Выполняем синхронизацию
              await ref.read(cartProvider.notifier).syncWithServer();
              
              if (context.mounted) {
                // Показываем результат
                final currentItems = ref.read(cartProvider);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr(
                      'cart.synced',
                      namedArgs: {'count': '${currentItems.length}'},
                    )),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: context.tr('cart.sync'),
          ),
        ],
      ),
      body: _LocalCartView(items: localItems, total: totalLocal),
      extendBody: true,
    );
  }
}

class _LocalCartView extends ConsumerWidget {
  final List<CartItem> items;
  final double total;
  const _LocalCartView({required this.items, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeControllerProvider);
    final currency = context.tr('common.currency');
    return items.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('cart.empty'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('cart.empty_hint'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go('/catalog'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                    ),
                    child: Text(context.tr('cart.go_catalog')),
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final net = ref.watch(networkProvider);
                  if (!net.hasIssue || items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    width: double.infinity,
                    color: const Color(0xFFFFF3E0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(context.tr('cart.offline_banner'))),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              context.push('/product/${it.product.id}', extra: it.product);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 36, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: AppConfig.imageUrl(it.product.image),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image, color: Colors.grey),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          it.product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: textPrimary,
                                          ),
                                        ),
                                        if (it.selectedAttributes.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: _buildAttributeChips(it),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '${it.product.price.toStringAsFixed(0)} $currency × ${it.qty}',
                                          style: const TextStyle(
                                            color: textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              onPressed: () async {
                                                await ref.read(cartProvider.notifier).updateQuantityWithSync(
                                                  it.product.id,
                                                  it.qty - 1,
                                                  selectedAttributes: it.selectedAttributes,
                                                );
                                              },
                                              icon: const Icon(Icons.remove, color: primaryColor),
                                            ),
                                            Text(
                                              it.qty.toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity: VisualDensity.compact,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 36,
                                                minHeight: 36,
                                              ),
                                              onPressed: () async {
                                                await ref.read(cartProvider.notifier).updateQuantityWithSync(
                                                  it.product.id,
                                                  it.qty + 1,
                                                  selectedAttributes: it.selectedAttributes,
                                                );
                                              },
                                              icon: const Icon(Icons.add, color: primaryColor),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Кнопка удаления в правом верхнем углу (незаметная, как на скриншоте)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                // Показываем подтверждение удаления
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(context.tr('cart.remove_title')),
                                    content: Text(context.tr(
                                      'cart.remove_confirm',
                                      namedArgs: {'name': it.product.name},
                                    )),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text(context.tr('common.cancel')),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: Text(context.tr('common.delete')),
                                      ),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true && context.mounted) {
                                  // Удаляем товар с синхронизацией (с учетом атрибутов)
                                  await ref.read(cartProvider.notifier).removeFromCartWithSync(
                                    it.product.id,
                                    selectedAttributes: it.selectedAttributes,
                                  );
                                  
                                  // Показываем уведомление об успешном удалении
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(context.tr(
                                          'cart.removed',
                                          namedArgs: {'name': it.product.name},
                                        )),
                                        backgroundColor: Colors.green,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  BottomNavigationBarWidget.occupiedHeight(context) + 8,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.tr('cart.total'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${total.toStringAsFixed(0)} $currency',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
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
                          child: ElevatedButton(
                            onPressed: () {
                              context.push('/shipping');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              context.tr('cart.checkout'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  /// Создает чипсы с атрибутами товара (размер, цвет и т.д.)
  List<Widget> _buildAttributeChips(CartItem item) {
    final List<Widget> chips = [];
    
    // Если у продукта нет атрибутов, возвращаем пустой список
    if (item.product.attributes.isEmpty) {
      return chips;
    }
    
    for (final entry in item.selectedAttributes.entries) {
      final attributeId = entry.key;
      final valueId = entry.value;
      
      // Находим атрибут в продукте по id
      ProductAttribute? attribute;
      try {
        attribute = item.product.attributes.firstWhere(
          (attr) => attr.id == attributeId,
        );
      } catch (e) {
        // Если не нашли по id, пропускаем этот атрибут
        print('[DEBUG] CartScreen: Атрибут с id $attributeId не найден для товара ${item.product.name}');
        continue;
      }
      
      if (attribute == null || attribute.values.isEmpty) continue;
      
      // Находим значение атрибута по id
      ProductAttributeValue? value;
      try {
        value = attribute.values.firstWhere(
          (val) => val.id == valueId,
        );
      } catch (e) {
        // Если не нашли по id, пропускаем это значение
        print('[DEBUG] CartScreen: Значение атрибута с id $valueId не найдено для атрибута ${attribute.title}');
        continue;
      }
      
      if (value == null) continue;
      
      // Создаем чип с атрибутом (как на скриншоте - в красной рамке)
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.red.withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Text(
            value.title, // Показываем только значение (например, "L" или "M")
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    
    return chips;
  }
}
