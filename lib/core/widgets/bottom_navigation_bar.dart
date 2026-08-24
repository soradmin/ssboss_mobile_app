import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/catalog/screens/home_screen.dart';
import '../l10n/locale_controller.dart';

/// Общая позиция bubble между экранами (каждый таб — свой Scaffold).
class _NavBubbleMemory {
  static int index = 0;
}

/// Плавающее «стеклянное» нижнее меню: bubble охватывает иконку + подпись.
class BottomNavigationBarWidget extends ConsumerStatefulWidget {
  final int selectedIndex;

  const BottomNavigationBarWidget({
    super.key,
    this.selectedIndex = 0,
  });

  static const _iconColor = Color(0xFF1A1A1A);
  static const _mutedColor = Color(0xFF5C5C5C);
  static const _itemCount = 5;

  static const double barHeight = 72;
  static const double bubbleHeight = 60;
  /// Горизонтальные поля bubble относительно ширины ячейки.
  static const double bubbleHInset = 4;

  /// Высота слота меню + системная панель (для отступа контента при extendBody).
  static double occupiedHeight(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return barHeight + 6 + 12 + bottomInset;
  }

  @override
  ConsumerState<BottomNavigationBarWidget> createState() =>
      _BottomNavigationBarWidgetState();
}

class _BottomNavigationBarWidgetState
    extends ConsumerState<BottomNavigationBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _indexAnim;
  late int _fromIndex;
  late int _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = _NavBubbleMemory.index;
    _toIndex = widget.selectedIndex;
    _NavBubbleMemory.index = widget.selectedIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _indexAnim = Tween<double>(
      begin: _fromIndex.toDouble(),
      end: _toIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.3, 0.64, 1),
    ));

    if (_fromIndex != _toIndex) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant BottomNavigationBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateTo(widget.selectedIndex);
    }
  }

  void _animateTo(int next) {
    _fromIndex = _indexAnim.value.round().clamp(0, 4);
    _toIndex = next;
    _NavBubbleMemory.index = next;
    _indexAnim = Tween<double>(
      begin: _fromIndex.toDouble(),
      end: _toIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.3, 0.64, 1),
    ));
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    // viewPadding — системная панель (кнопки / gesture), не сбрасывается клавиатурой.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Раньше при inset > 0 добавляли только 8px и меню уезжало под кнопки навигации.
    final bottomPad = bottomInset + 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final itemWidth = barWidth / BottomNavigationBarWidget._itemCount;
          const inset = BottomNavigationBarWidget.bubbleHInset;
          final bubbleWidth = itemWidth - inset * 2;
          const bubbleTop =
              (BottomNavigationBarWidget.barHeight -
                  BottomNavigationBarWidget.bubbleHeight) /
              2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: ColoredBox(
                      color: const Color(0xFFF5F5F5).withValues(alpha: 0.72),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.55),
                            width: 0.9,
                          ),
                        ),
                        child: const SizedBox(
                          height: BottomNavigationBarWidget.barHeight,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Bubble: иконка + название раздела
              AnimatedBuilder(
                animation: _indexAnim,
                builder: (context, _) {
                  final idx = _indexAnim.value;
                  final left = idx * itemWidth + inset;
                  return Positioned(
                    left: left,
                    top: bubbleTop,
                    width: bubbleWidth,
                    height: BottomNavigationBarWidget.bubbleHeight,
                    child: const _GlassBubble(),
                  );
                },
              ),
              SizedBox(
                height: BottomNavigationBarWidget.barHeight,
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: context.tr('nav.home'),
                          index: 0,
                          selected: widget.selectedIndex == 0,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.grid_view_outlined,
                          selectedIcon: Icons.grid_view_rounded,
                          label: context.tr('nav.catalog'),
                          index: 1,
                          selected: widget.selectedIndex == 1,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.shopping_cart_outlined,
                          selectedIcon: Icons.shopping_cart_rounded,
                          label: context.tr('nav.cart'),
                          index: 2,
                          selected: widget.selectedIndex == 2,
                          badgeCount: ref.watch(cartTotalQuantityProvider),
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.favorite_border_rounded,
                          selectedIcon: Icons.favorite_rounded,
                          label: context.tr('nav.favorites'),
                          index: 3,
                          selected: widget.selectedIndex == 3,
                        ),
                      ),
                      Expanded(
                        child: _NavItem(
                          icon: Icons.person_outline_rounded,
                          selectedIcon: Icons.person_rounded,
                          label: context.tr('nav.profile'),
                          index: 4,
                          selected: widget.selectedIndex == 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassBubble extends StatelessWidget {
  const _GlassBubble();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B4EFF).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  const Color(0xFFF0ECF8).withValues(alpha: 0.58),
                  Colors.white.withValues(alpha: 0.42),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.88),
                width: 1.4,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final bool selected;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.selected,
    this.badgeCount = 0,
  });

  void _go(BuildContext context) {
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
  Widget build(BuildContext context) {
    final color = selected
        ? BottomNavigationBarWidget._iconColor
        : BottomNavigationBarWidget._mutedColor;

    return InkWell(
      onTap: () => _go(context),
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.black.withValues(alpha: 0.04),
      highlightColor: Colors.black.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 360),
                    curve: const Cubic(0.34, 1.3, 0.64, 1),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 24,
                      color: color,
                    ),
                  ),
                  if (index == 2 && badgeCount > 0)
                    Positioned(
                      right: -6,
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
                          badgeCount > 99 ? '99+' : '$badgeCount',
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
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
                height: 1.1,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
