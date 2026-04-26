import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../controllers/cart_controller.dart';
import '../models/cart_item.dart';
import '../../catalog/models/product.dart';
import '../../../theme.dart';
import '../../../core/config.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: const Text(
          'Корзина',
          style: TextStyle(
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
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Синхронизация корзины...'),
                      ],
                    ),
                    duration: Duration(seconds: 2),
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
                    content: Text('Корзина синхронизирована. Товаров: ${currentItems.length}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Синхронизировать с сервером',
          ),
        ],
      ),
      body: _LocalCartView(items: localItems, total: totalLocal),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 2),
    );
  }
}

class _LocalCartView extends ConsumerWidget {
  final List<CartItem> items;
  final double total;
  const _LocalCartView({required this.items, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'Ваша корзина пуста',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте товары из каталога',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Column(
            children: [
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
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: () {
                                    final imageUrl = AppConfig.imageUrl(it.product.image);
                                    print('[DEBUG] CartScreen: Товар ${it.product.name}, изображение: ${it.product.image} -> URL: $imageUrl');
                                    return imageUrl;
                                  }(),
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
                              title: Text(
                                it.product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Отображаем атрибуты товара (размер, цвет и т.д.)
                                  if (it.selectedAttributes.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: _buildAttributeChips(it),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  // Цена и количество
                                  Text(
                                    '${it.product.price.toStringAsFixed(0)} с. × ${it.qty}',
                                    style: const TextStyle(
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
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
                                    title: const Text('Удалить товар?'),
                                    content: Text('Вы уверены, что хотите удалить "${it.product.name}" из корзины?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Удалить'),
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
                                        content: Text('${it.product.name} удален из корзины'),
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
              SafeArea(
                minimum: const EdgeInsets.all(16),
                child: Container(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Итого:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                '${total.toStringAsFixed(0)} с.',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            onPressed: () {
                              // Переход к экрану оформления заказа
                              context.push('/shipping');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Оформить заказ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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