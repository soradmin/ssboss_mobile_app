import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bottom_navigation_bar.dart';

/// Оболочка главных вкладок: одно меню + плавная смена контента.
class MainShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageAnim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late int _lastIndex;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.navigationShell.currentIndex;
    _pageAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    final curved = CurvedAnimation(
      parent: _pageAnim,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0.035, 0),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.navigationShell.currentIndex;
    if (next != _lastIndex) {
      _lastIndex = next;
      _pageAnim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: BottomNavigationBarWidget(
        selectedIndex: widget.navigationShell.currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}
