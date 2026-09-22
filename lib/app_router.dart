import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/widgets/main_shell.dart';
import 'features/catalog/screens/home_screen.dart';
import 'features/catalog/screens/categories_screen.dart';
import 'features/catalog/screens/products_screen.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/favorites/screens/favorites_screen.dart';
import 'features/catalog/models/product.dart';
import 'features/catalog/screens/product_details_loader.dart';
import 'features/notifications/screens/notification_settings_screen.dart';
import 'features/checkout/screens/shipping_screen.dart';
import 'features/checkout/screens/address_form_screen.dart';
import 'features/checkout/screens/payment_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/otp_verify_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/profile/screens/addresses_screen.dart';
import 'features/orders/screens/orders_screen.dart';
import 'features/orders/screens/order_details_screen.dart';
import 'features/stores/screens/favorite_stores_screen.dart';
import 'features/stores/screens/store_details_screen.dart';
import 'features/compare/screens/compare_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/notifications/screens/notification_details_screen.dart';
import 'features/notifications/screens/notifications_list_screen.dart';

/// Корневой Navigator — для диалогов поверх всего UI (обновление приложения и т.п.).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Widget _productsFromState(GoRouterState state) {
  final category = state.uri.queryParameters['category'];
  final search = state.uri.queryParameters['search'];
  final categoryTitle = state.uri.queryParameters['title'];
  final categoryIdStr = state.uri.queryParameters['category_id'];
  final categoryId = categoryIdStr != null ? int.tryParse(categoryIdStr) : null;
  final brandIdStr = state.uri.queryParameters['brand'];
  final brandId = brandIdStr != null ? int.tryParse(brandIdStr) : null;
  final brandTitle = state.uri.queryParameters['brand_title'];
  final bannerId = int.tryParse(state.uri.queryParameters['banner'] ?? '');
  final sliderId = int.tryParse(state.uri.queryParameters['home_spm'] ?? '');
  return ProductsScreen(
    category: category,
    searchQuery: search,
    categoryTitle: categoryTitle,
    categoryId: categoryId,
    brandId: brandId,
    brandTitle: brandTitle,
    bannerId: bannerId,
    sliderId: sliderId,
  );
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Главные 5 вкладок — IndexedStack + одно живое меню (пузырь анимируется).
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (_, __) => const CatalogScreen(),
              routes: [
                GoRoute(
                  path: 'products',
                  builder: (context, state) => _productsFromState(state),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cart',
              builder: (_, __) => const CartScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (_, __) => const FavoritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final extra = state.extra is Product ? state.extra as Product : null;
        return ProductDetailsLoader(productId: id, initial: extra);
      },
    ),
    GoRoute(path: '/shipping', builder: (_, __) => const ShippingScreen()),
    GoRoute(
      path: '/payment',
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
      path: '/address-form',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AddressFormScreen(
          address: extra?['address'],
          onSaved: extra?['onSaved'],
        );
      },
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: '/otp-verify',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phone = extra?['phone']?.toString() ?? '';
        if (phone.isEmpty) return const LoginScreen();
        return OtpVerifyScreen(
          phone: phone,
          name: extra?['name']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/register',
      redirect: (_, __) => '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final email = state.extra is String
            ? state.extra as String
            : (state.uri.queryParameters['email'] ?? '');
        if (email.isEmpty) return const ForgotPasswordScreen();
        return ResetPasswordScreen(email: email);
      },
    ),
    GoRoute(path: '/compare', builder: (_, __) => const CompareScreen()),
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>?;
        return EditProfileScreen(
          currentName: extra?['name'] ?? '',
          currentEmail: extra?['email'] ?? '',
          currentPhone: extra?['phone'] ?? '',
        );
      },
    ),
    GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
    GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
    GoRoute(
      path: '/order/:orderId',
      builder: (context, state) {
        final orderId = int.tryParse(state.pathParameters['orderId'] ?? '') ?? 0;
        return OrderDetailsScreen(orderId: orderId);
      },
    ),
    GoRoute(
      path: '/favorite-stores',
      builder: (_, __) => const FavoriteStoresScreen(),
    ),
    GoRoute(
      path: '/store/:storeSlug',
      builder: (context, state) {
        final storeSlug = state.pathParameters['storeSlug'] ?? '';
        return StoreDetailsScreen(storeSlug: storeSlug);
      },
    ),
    GoRoute(
      path: '/notification-details',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return NotificationDetailsScreen(
          title: extra?['title'] ?? 'Уведомление',
          htmlBody: extra?['htmlBody'],
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsListScreen(),
    ),
    GoRoute(
      path: '/notification-settings',
      builder: (_, __) => const NotificationSettingsScreen(),
    ),
  ],
);
