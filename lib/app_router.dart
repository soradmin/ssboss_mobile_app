import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/catalog/screens/home_screen.dart';
import 'features/catalog/screens/categories_screen.dart';
import 'features/catalog/screens/products_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/catalog/models/product.dart';
import 'features/catalog/screens/product_details_screen.dart';
import 'features/checkout/screens/shipping_screen.dart';
import 'features/checkout/screens/address_form_screen.dart';
import 'features/checkout/screens/payment_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/profile/screens/addresses_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/orders/screens/order_details_screen.dart';
import 'features/stores/screens/favorite_stores_screen.dart';
import 'features/stores/screens/store_details_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/compare/screens/compare_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/notifications/screens/notification_details_screen.dart';
import 'features/notifications/screens/notifications_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'catalog',
          builder: (_, __) => const CatalogScreen(),
          routes: [
            GoRoute(
              path: 'products',
              builder: (context, state) {
                final category = state.uri.queryParameters['category'];
                final search = state.uri.queryParameters['search'];
                final categoryTitle = state.uri.queryParameters['title'];
                final categoryIdStr = state.uri.queryParameters['category_id'];
                final categoryId = categoryIdStr != null ? int.tryParse(categoryIdStr) : null;
                return ProductsScreen(
                  category: category,
                  searchQuery: search,
                  categoryTitle: categoryTitle,
                  categoryId: categoryId,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: 'product/:id',
          builder: (context, state) {
            final p = state.extra as Product?;
            if (p == null) return const Scaffold(body: Center(child: Text('Товар не найден')));
            return ProductDetailsScreen(p: p);
          },
        ),
        GoRoute(path: 'cart',    builder: (_, __) => const CartScreen()),
        GoRoute(path: 'shipping', builder: (_, __) => const ShippingScreen()),
        GoRoute(
          path: 'payment',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return PaymentScreen(
              selectedAddressId: extra?['addressId'] ?? 0,
              selectedAddressName: extra?['addressName'] ?? '',
              addressType: extra?['addressType'],
              addressFull: extra?['addressFull'],
              addressCity: extra?['addressCity'],
              addressPhone: extra?['addressPhone'],
              deliveryType: extra?['deliveryType'],
            );
          },
        ),
        GoRoute(
          path: 'address-form',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return AddressFormScreen(
              address: extra?['address'],
              onSaved: extra?['onSaved'],
            );
          },
        ),
                GoRoute(path: 'login', builder: (_, __) => const LoginScreen()),
                GoRoute(path: 'register', builder: (_, __) => const RegisterScreen()),
                GoRoute(path: 'favorites', builder: (_, __) => const FavoritesScreen()),
                GoRoute(path: 'compare', builder: (_, __) => const CompareScreen()),
                GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
                GoRoute(
                  path: 'edit-profile',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, String>?;
                    return EditProfileScreen(
                      currentName: extra?['name'] ?? '',
                      currentEmail: extra?['email'] ?? '',
                    );
                  },
                ),
                GoRoute(path: 'addresses', builder: (_, __) => const AddressesScreen()),
                GoRoute(path: 'orders', builder: (_, __) => const OrdersScreen()),
                GoRoute(
                  path: 'order/:orderId',
                  builder: (context, state) {
                    final orderIdParam = state.pathParameters['orderId'] ?? '0';
                    print('[DEBUG] Router: Парсинг orderId из URL: "$orderIdParam"');
                    final orderId = int.tryParse(orderIdParam) ?? 0;
                    print('[DEBUG] Router: Распарсенный orderId: $orderId');
                    if (orderId <= 0) {
                      print('[ERROR] Router: Невалидный orderId: $orderIdParam -> $orderId');
                    }
                    return OrderDetailsScreen(orderId: orderId);
                  },
                ),
                GoRoute(path: 'favorite-stores', builder: (_, __) => const FavoriteStoresScreen()),
                GoRoute(
                  path: 'store/:storeSlug',
                  builder: (context, state) {
                    final storeSlug = state.pathParameters['storeSlug'] ?? '';
                    return StoreDetailsScreen(storeSlug: storeSlug);
                  },
                ),
                GoRoute(
                  path: 'notification-details',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return NotificationDetailsScreen(
                      title: extra?['title'] ?? 'Уведомление',
                      htmlBody: extra?['htmlBody'],
                    );
                  },
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (_, __) => const NotificationsListScreen(),
                ),
                GoRoute(path: 'favorites', builder: (_, __) => const FavoritesScreen()),
      ],
    ),
  ],
);
