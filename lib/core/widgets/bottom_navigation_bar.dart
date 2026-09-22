import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/screens/home_screen.dart';
import '../l10n/locale_controller.dart';

/// Плавающее нижнее меню: frosted glass + скользящий пузырь (Telegram-стиль).
class BottomNavigationBarWidget extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int>? onTabSelected;

  const BottomNavigationBarWidget({
    super.key,
    this.selectedIndex = 0,
    this.onTabSelected,
  });

  static const double barHeight = 64;
  static const double _hPad = 16;
  static const double _topPad = 6;
  static const double _bottomExtra = 12;

  /// Высота слота меню + системная панель (для отступа контента при extendBody).
  static double occupiedHeight(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return barHeight + _topPad + _bottomExtra + bottomInset;
  }

  void _go(BuildContext context, int index) {
    if (onTabSelected != null) {
      onTabSelected!(index);
      return;
    }
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/catalog');
      case 2:
        context.go('/cart');
      case 3:
        context.go('/favorites');
      case 4:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeControllerProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final screenW = MediaQuery.sizeOf(context).width;
    final barWidth = (screenW - _hPad * 2).clamp(280.0, 560.0);
    final cartBadge = ref.watch(cartTotalQuantityProvider);
    final index = selectedIndex.clamp(0, 4);

    final items = <_NavItem>[
      _NavItem(
        label: context.tr('nav.home'),
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _NavItem(
        label: context.tr('nav.catalog'),
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view_rounded,
      ),
      _NavItem(
        label: context.tr('nav.cart'),
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart_rounded,
        badgeCount: cartBadge,
      ),
      _NavItem(
        label: context.tr('nav.favorites'),
        icon: Icons.favorite_border_rounded,
        selectedIcon: Icons.favorite_rounded,
      ),
      _NavItem(
        label: context.tr('nav.profile'),
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    // Важно: фиксированная высота — иначе Scaffold меряет бар на весь экран
    // и тело вкладок схлопывается в пустоту.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _hPad,
        _topPad,
        _hPad,
        bottomInset + _bottomExtra,
      ),
      child: SizedBox(
        height: barHeight,
        child: Center(
          child: SizedBox(
            width: barWidth,
            height: barHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(barHeight / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: ColoredBox(
                    color: const Color(0xE6FFFFFF),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(barHeight / 2),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.06),
                          width: 0.8,
                        ),
                      ),
                      child: _LiquidBubbleNav(
                        items: items,
                        selectedIndex: index,
                        onChanged: (i) => _go(context, i),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount = 0,
  });
}

class _LiquidBubbleNav extends StatefulWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _LiquidBubbleNav({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<_LiquidBubbleNav> createState() => _LiquidBubbleNavState();
}

class _LiquidBubbleNavState extends State<_LiquidBubbleNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _fromIndex;
  late double _toIndex;

  static const _curve = Cubic(0.22, 1.0, 0.36, 1.0);

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = _fromIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _LiquidBubbleNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _fromIndex = _currentIndex;
      _toIndex = widget.selectedIndex.toDouble();
      _controller.forward(from: 0);
    }
  }

  double get _currentIndex {
    final t = _curve.transform(_controller.value);
    return _fromIndex + (_toIndex - _fromIndex) * t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final bubbleIndex = _currentIndex;
        // Лёгкий «подскок» пузыря в середине пути.
        final travel = (_controller.value * (1 - _controller.value) * 4)
            .clamp(0.0, 1.0);
        final scaleY = 1.0 - (travel * 0.08);
        final scaleX = 1.0 + (travel * 0.06);

        return LayoutBuilder(
          builder: (context, constraints) {
            final slotW = constraints.maxWidth / count;
            final bubbleW = slotW - 10;
            final bubbleH = constraints.maxHeight - 12;
            final left = bubbleIndex * slotW + (slotW - bubbleW) / 2;
            final top = (constraints.maxHeight - bubbleH) / 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: bubbleW,
                  height: bubbleH,
                  child: Transform.scale(
                    scaleX: scaleX,
                    scaleY: scaleY,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x229C27B0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _NavTabButton(
                          item: widget.items[i],
                          selected: i == widget.selectedIndex,
                          onTap: () => widget.onChanged(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  static const _brand = Color(0xFF9C27B0);
  static const _muted = Color(0xFF5C5C5C);

  @override
  Widget build(BuildContext context) {
    final color = selected ? _brand : _muted;

    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      key: ValueKey(selected),
                      size: selected ? 24 : 22,
                      color: color,
                    ),
                  ),
                  if (item.badgeCount > 0)
                    Positioned(
                      right: 0,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          item.badgeCount > 99 ? '99+' : '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
