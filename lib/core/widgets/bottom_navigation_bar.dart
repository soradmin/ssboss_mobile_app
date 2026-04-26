import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/cart/providers/background_sync_provider.dart';
import '../../features/catalog/screens/home_screen.dart'; // для cartTotalQuantityProvider

/// Общий виджет нижнего меню навигации для всех экранов
class BottomNavigationBarWidget extends ConsumerWidget {
  final int selectedIndex;

  const BottomNavigationBarWidget({
    super.key,
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: _buildNavItem(context, ref, Icons.home, Icons.home, 'Главная', 0, selectedIndex == 0)),
            Expanded(child: _buildNavItem(context, ref, Icons.grid_view_outlined, Icons.grid_view, 'Каталог', 1, selectedIndex == 1)),
            Expanded(child: _buildNavItem(context, ref, Icons.shopping_cart_outlined, Icons.shopping_cart, 'Корзина', 2, selectedIndex == 2)),
            Expanded(child: _buildNavItem(context, ref, Icons.favorite_border, Icons.favorite, 'Избранное', 3, selectedIndex == 3)),
            Expanded(child: _buildNavItem(context, ref, Icons.person_outline, Icons.person, 'Профиль', 4, selectedIndex == 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, WidgetRef ref, IconData icon, IconData selectedIcon, String label, int index, bool isSelected) {
    // Получаем количество товаров в корзине для иконки корзины
    final cartQuantity = index == 2 ? ref.watch(cartTotalQuantityProvider) : 0;
    
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            context.go('/');
            break;
          case 1:
            context.go('/catalog');
            break;
          case 2:
            context.go('/cart');
            break;
          case 3:
            context.go('/favorites');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9C27B0).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка с бейджем для корзины
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected ? const Color(0xFF9C27B0) : const Color(0xFF718096),
                  size: 20,
                ),
                // Бейдж с количеством товаров (только для корзины)
                if (index == 2 && cartQuantity > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cartQuantity > 99 ? '99+' : cartQuantity.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF9C27B0) : const Color(0xFF718096),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

