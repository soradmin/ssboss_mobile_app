import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bottom_navigation_bar.dart';

/// Оболочка главных вкладок: одно меню + мгновенная смена контента.
///
/// По Emil Kowalski / animate-expo: вкладки — peers, не иерархия.
/// Slide/fade на смене табов платится десятки раз за сессию и ощущается
/// как задержка; платформенный default — без анимации страницы.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBarWidget(
        selectedIndex: navigationShell.currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}
