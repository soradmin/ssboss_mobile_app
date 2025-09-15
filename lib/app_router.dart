import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/catalog/screens/home_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/catalog/models/product.dart';
import 'features/catalog/screens/product_details_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'product/:id',
          builder: (context, state) {
            final p = state.extra as Product?;
            if (p == null) return const Scaffold(body: Center(child: Text('Товар не найден')));
            return ProductDetailsScreen(p: p);
          },
        ),
        GoRoute(path: 'cart',    builder: (_, __) => const CartScreen()),
        GoRoute(path: 'orders',  builder: (_, __) => const OrdersScreen()),
        GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
  ],
);
