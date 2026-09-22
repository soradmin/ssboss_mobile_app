import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../models/address.dart';
import '../repo/address_api.dart';
import '../../cart/repo/cart_api.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';

class ShippingScreen extends ConsumerStatefulWidget {
  const ShippingScreen({super.key});

  @override
  ConsumerState<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends ConsumerState<ShippingScreen> {
  List<Address> addresses = [];
  bool isLoading = true;
  String? error;
  String selectedDeliveryType = 'pickup'; // 'pickup' или 'delivery'
  Address? selectedAddress;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppConfig.ensureAuthTokensLoaded();
      if (!mounted) return;
      if (AppConfig.hasActiveToken()) {
        await _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Загружаем адреса
      await _loadAddresses();
      
      // Загружаем корзину через провайдер
      // Локальная корзина уже загружена
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadAddresses() async {
    try {
      await AppConfig.ensureAuthTokensLoaded();
      print('[DEBUG] ShippingScreen._loadAddresses: Начинаем загрузку адресов...');
      print(
        '[DEBUG] ShippingScreen._loadAddresses: token active=${AppConfig.hasActiveToken()}, '
        'mobile=${AppConfig.mobileBearer.isNotEmpty}, bearer=${AppConfig.bearer.isNotEmpty}',
      );

      final addressApi = AddressApi();
      final result = await addressApi.getAddresses();
      
      print('[DEBUG] ShippingScreen._loadAddresses: Результат загрузки: ${result.runtimeType}');
      
      if (result is Ok<List<Address>>) {
        addresses = result.value;
        print('[DEBUG] ShippingScreen._loadAddresses: Загружено ${addresses.length} адресов');
        
        // Выводим информацию о каждом адресе
        for (int i = 0; i < addresses.length; i++) {
          final addr = addresses[i];
          print('[DEBUG] ShippingScreen._loadAddresses: Адрес $i: ${addr.name} (${addr.type}) - ${addr.fullAddress}');
        }
        
        // Выбираем первый пункт выдачи по умолчанию
        if (addresses.isNotEmpty) {
          selectedAddress = addresses.firstWhere(
            (addr) => addr.type == 'pickup',
            orElse: () => addresses.first,
          );
          print('[DEBUG] ShippingScreen._loadAddresses: Выбран адрес по умолчанию: ${selectedAddress?.name}');
        }
      } else {
        error = (result as Err).message;
        print('[DEBUG] ShippingScreen._loadAddresses: Ошибка загрузки адресов: $error');
      }
    } catch (e) {
      error = e.toString();
      print('[DEBUG] ShippingScreen._loadAddresses: Исключение при загрузке адресов: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    final user = ref.watch(authProvider);
    final cartItems = ref.watch(cartProvider);
    final theme = Theme.of(context);
    
    // Получаем данные корзины из провайдера
    final totalQuantity = cartItems.fold(0, (sum, item) => sum + item.qty);
    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
    
    // Перезагружаем адреса после входа или смены пользователя
    ref.listen(authProvider, (previous, current) {
      final authReady = current.isAuthenticated && AppConfig.hasActiveToken();
      final wasReady =
          (previous?.isAuthenticated ?? false) && AppConfig.hasActiveToken();
      if (authReady && (!wasReady || previous?.id != current.id)) {
        print('[DEBUG] ShippingScreen: авторизация готова, перезагружаем адреса');
        _loadData();
      }
    });
    
    // Если пользователь не авторизован, показываем экран авторизации
    if (!user.isAuthenticated) {
      return _buildAuthRequiredScreen(context, theme);
    }

    return Scaffold(
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
          context.tr('checkout.title'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorScreen(context, theme)
              : _buildShippingContent(context, theme),
      extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 2),
    );
  }

  Widget _buildAuthRequiredScreen(BuildContext context, ThemeData theme) {
    return Scaffold(
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
          context.tr('checkout.title'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('checkout.need_login'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),
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
                    // Переходим на экран входа с информацией о том, что пришли с экрана оформления
                    context.go('/login?from=shipping');
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
                  child: Text(
                    context.tr('checkout.login_account'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 2),
    );
  }

  Widget _buildErrorScreen(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('catalog.load_error'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error ?? 'Неизвестная ошибка',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
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
                onPressed: _loadAddresses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.tr('common.retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingContent(BuildContext context, ThemeData theme) {
    final cartItems = ref.watch(cartProvider);
    final totalQuantity = cartItems.fold(0, (sum, item) => sum + item.qty);
    final totalAmount = cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
    final bottomPad = BottomNavigationBarWidget.occupiedHeight(context) + 16;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с количеством товаров
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    totalQuantity > 0
                        ? '$totalQuantity ${_getQuantityText(totalQuantity)}, ${totalAmount.toStringAsFixed(2)} ${context.tr('common.currency')}'
                        : context.tr('checkout.cart_empty'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Выбор способа доставки
          Text(
            context.tr('checkout.delivery_method'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          
          // Табы для выбора способа доставки
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedDeliveryType = 'pickup';
                            final pickups = addresses.where((a) => a.type == 'pickup');
                            selectedAddress = pickups.isEmpty ? null : pickups.first;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: selectedDeliveryType == 'pickup'
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF9C27B0),
                                      Color(0xFFE040FB),
                                    ],
                                  )
                                : null,
                            color: selectedDeliveryType == 'pickup'
                                ? null
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: selectedDeliveryType == 'pickup'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('checkout.pickup'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selectedDeliveryType == 'pickup'
                                      ? Colors.white
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selectedDeliveryType == 'pickup'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                              if (selectedDeliveryType == 'pickup') ...[
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('checkout.free'),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedDeliveryType = 'delivery';
                            final deliveries =
                                addresses.where((a) => a.type == 'delivery');
                            selectedAddress =
                                deliveries.isEmpty ? null : deliveries.first;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: selectedDeliveryType == 'delivery'
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF9C27B0),
                                      Color(0xFFE040FB),
                                    ],
                                  )
                                : null,
                            color: selectedDeliveryType == 'delivery'
                                ? null
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: selectedDeliveryType == 'delivery'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('checkout.courier'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selectedDeliveryType == 'delivery'
                                      ? Colors.white
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selectedDeliveryType == 'delivery'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Список адресов
          if (selectedDeliveryType == 'pickup') ...[
            _buildPickupAddresses(context, theme),
          ] else ...[
            _buildDeliveryAddresses(context, theme),
          ],
          
          const SizedBox(height: 32),
          
          // Кнопка продолжения
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: totalQuantity > 0
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF9C27B0),
                          Color(0xFFE040FB),
                        ],
                        stops: [0.0, 1.0],
                      )
                    : null,
                color: totalQuantity == 0 ? Colors.grey[300] : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: totalQuantity > 0 ? _proceedToPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.tr('checkout.go_to_payment'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPickupAddresses(BuildContext context, ThemeData theme) {
    final pickupAddresses = addresses.where((a) => a.type == 'pickup').toList();
    
    if (pickupAddresses.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('checkout.no_pickups'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Обратитесь в службу поддержки',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('checkout.select_pickup'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...pickupAddresses.map((address) => _buildAddressCard(context, theme, address)),
      ],
    );
  }

  Widget _buildDeliveryAddresses(BuildContext context, ThemeData theme) {
    final deliveryAddresses = addresses.where((a) => a.type == 'delivery').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('checkout.delivery_addresses'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (deliveryAddresses.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8E0EF)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('checkout.no_addresses'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('checkout.add_address_hint'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF9C27B0),
                          Color(0xFFE040FB),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _addNewAddress(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(context.tr('checkout.add_address'), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _addNewAddress(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('checkout.add_address')),
            ),
          ),
          ...deliveryAddresses.map((address) => _buildAddressCard(context, theme, address)),
        ],
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, ThemeData theme, Address address) {
    final isSelected = selectedAddress?.id == address.id;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedAddress = address;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF9C27B0), // Основной фиолетовый
                        Color(0xFFE040FB), // Светло-фиолетовый
                        Color(0xFFBA68C8), // Средний фиолетовый
                      ],
                      stops: [0.0, 0.5, 1.0],
                    )
                  : null,
              color: isSelected ? null : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF9C27B0)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF9C27B0).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    selectedDeliveryType == 'pickup' ? Icons.store : Icons.home,
                    color: isSelected ? Colors.white : theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        address.fullAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.phone != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.8)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              address.phone!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.8)
                                    : theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (address.type == 'delivery') ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _editAddress(context, address),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.2)
                                  : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getQuantityText(int quantity) {
    if (quantity % 10 == 1 && quantity % 100 != 11) {
      return context.tr('plurals.product_one');
    } else if ([2, 3, 4].contains(quantity % 10) && ![12, 13, 14].contains(quantity % 100)) {
      return context.tr('plurals.product_few');
    } else {
      return context.tr('plurals.product_many');
    }
  }

  void _addNewAddress(BuildContext context) {
    context.go('/address-form', extra: {
      'address': null,
      'onSaved': () {
        // Перезагружаем адреса после добавления
        _loadAddresses();
      },
    });
  }

  void _editAddress(BuildContext context, Address address) {
    context.go('/address-form', extra: {
      'address': address,
      'onSaved': () {
        // Перезагружаем адреса после редактирования
        _loadAddresses();
      },
    });
  }

  void _proceedToPayment() {
    final cartItems = ref.read(cartProvider);
    
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('checkout.cart_empty')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (selectedDeliveryType == 'delivery') {
      final hasDeliveryAddress =
          selectedAddress != null && selectedAddress!.type == 'delivery';
      if (!hasDeliveryAddress) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('checkout.need_address')),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    } else if (selectedAddress == null || selectedAddress!.type != 'pickup') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('checkout.select_pickup')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    print('[DEBUG] ShippingScreen._proceedToPayment: Переходим к оплате');
    print('[DEBUG] ShippingScreen._proceedToPayment: Выбранный адрес: ${selectedAddress!.name} (ID: ${selectedAddress!.id})');
    print('[DEBUG] ShippingScreen._proceedToPayment: Тип адреса: ${selectedAddress!.type}');
    print('[DEBUG] ShippingScreen._proceedToPayment: Способ доставки: $selectedDeliveryType');
    print('[DEBUG] ShippingScreen._proceedToPayment: Полный адрес: ${selectedAddress!.fullAddress}');
    print('[DEBUG] ShippingScreen._proceedToPayment: Город: ${selectedAddress!.city}');
    print('[DEBUG] ShippingScreen._proceedToPayment: Телефон: ${selectedAddress!.phone}');
    
    // Переход к экрану оплаты с полной информацией об адресе и способе доставки
    context.push(
      '/payment',
      extra: {
        'addressId': selectedAddress!.id,
        'addressName': selectedAddress!.name,
        'addressType': selectedAddress!.type,
        'addressFull': selectedAddress!.fullAddress,
        'addressCity': selectedAddress!.city,
        'addressPhone': selectedAddress!.phone,
        'deliveryType': selectedDeliveryType, // Передаем выбранный способ доставки
      },
    );
  }
}
