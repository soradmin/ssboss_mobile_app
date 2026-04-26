import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../../theme.dart';
import '../models/payment_method.dart';
import '../repo/payment_api.dart';
import '../../cart/controllers/cart_controller.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final int selectedAddressId;
  final String selectedAddressName;
  final String? addressType;
  final String? addressFull;
  final String? addressCity;
  final String? addressPhone;
  final String? deliveryType; // 'pickup' или 'delivery'

  const PaymentScreen({
    super.key,
    required this.selectedAddressId,
    required this.selectedAddressName,
    this.addressType,
    this.addressFull,
    this.addressCity,
    this.addressPhone,
    this.deliveryType,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  List<PaymentMethod> _paymentMethods = [];
  PaymentMethod? _selectedMethod;
  bool _isLoading = true;
  String? _error;
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await PaymentApi.getPaymentMethods();
    
    setState(() {
      _isLoading = false;
    });

    result.when(
      ok: (methods) {
        setState(() {
          _paymentMethods = methods;
          // Автоматически выбираем первый доступный метод оплаты
          if (methods.isNotEmpty) {
            _selectedMethod = methods.first;
          }
        });
      },
      err: (error) {
        setState(() {
          _error = error;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка загрузки методов оплаты: $error')),
          );
        }
      },
    );
  }

  Future<void> _createOrder() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите метод оплаты')),
      );
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    final cartItems = ref.read(cartProvider);
    
    print('[DEBUG] PaymentScreen._createOrder: Создаем заказ с адресом:');
    print('[DEBUG] PaymentScreen._createOrder: - ID: ${widget.selectedAddressId}');
    print('[DEBUG] PaymentScreen._createOrder: - Название: ${widget.selectedAddressName}');
    print('[DEBUG] PaymentScreen._createOrder: - Тип: ${widget.addressType ?? 'не указан'}');
    print('[DEBUG] PaymentScreen._createOrder: - Полный адрес: ${widget.addressFull ?? 'не указан'}');
    print('[DEBUG] PaymentScreen._createOrder: - Город: ${widget.addressCity ?? 'не указан'}');
    print('[DEBUG] PaymentScreen._createOrder: - Телефон: ${widget.addressPhone ?? 'не указан'}');
    
    final result = await PaymentApi.createOrder(
      paymentMethodId: _selectedMethod!.id,
      addressId: widget.selectedAddressId,
      cartItems: cartItems.map((item) => {
        'product_id': item.product.id,
        'name': item.product.name,
        'image': _extractImageFilename(item.product.image),
        'quantity': item.qty,
        'price': item.product.price,
        'size': null, // Можно добавить размер если есть
        'color': null, // Можно добавить цвет если есть
      }).toList(),
      totalAmount: cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
      totalQuantity: cartItems.fold(0, (sum, item) => sum + item.qty),
      deliveryType: widget.deliveryType, // Передаем выбранный способ доставки
    );

    setState(() {
      _isCreatingOrder = false;
    });

    result.when(
      ok: (orderData) async {
        if (mounted) {
          print('[DEBUG] PaymentScreen: Заказ создан успешно, данные: $orderData');
          
          // Извлекаем ID заказа из ответа
          String? orderId;
          if (orderData is Map<String, dynamic>) {
            orderId = orderData['id']?.toString() ?? 
                     orderData['order_id']?.toString() ??
                     orderData['data']?['id']?.toString();
          }
          
          print('[DEBUG] PaymentScreen: Извлеченный orderId = $orderId');
          
          if (orderId != null && orderId.isNotEmpty) {
            // Пытаемся подтвердить заказ на сервере
            try {
              print('[DEBUG] PaymentScreen: Подтверждаем заказ $orderId...');
              final confirmResult = await PaymentApi.confirmOrder(int.parse(orderId));
              
              confirmResult.when(
                ok: (confirmData) async {
                  print('[DEBUG] PaymentScreen: Заказ подтвержден на сервере');
                  
                  // Очищаем корзину после успешного заказа (сразу, не ждем email)
                  ref.read(cartProvider.notifier).clearCart();
                  
                  // Отправляем email уведомление асинхронно в фоне (не блокируем UI)
                  // Используем unawaited, чтобы не ждать завершения
                  PaymentApi.sendOrderEmail(int.parse(orderId!)).then((emailResult) {
                    emailResult.when(
                      ok: (emailData) {
                        print('[DEBUG] PaymentScreen: Email уведомление отправлено');
                      },
                      err: (emailError) {
                        print('[DEBUG] PaymentScreen: Ошибка отправки email: $emailError');
                        // Не критично, продолжаем
                      },
                    );
                  }).catchError((e) {
                    print('[DEBUG] PaymentScreen: Исключение при отправке email: $e');
                    // Не критично, продолжаем
                  });
                  
                  // Показываем сообщение об успехе
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заказ успешно создан и подтвержден!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  
                  // Переходим к экрану деталей заказа
                  print('[DEBUG] PaymentScreen: Переходим к экрану заказа /order/$orderId');
                  GoRouter.of(context).go('/order/$orderId');
                },
                err: (error) {
                  print('[DEBUG] PaymentScreen: Ошибка подтверждения заказа: $error');
                  
                  // Очищаем корзину даже если подтверждение не удалось
                  ref.read(cartProvider.notifier).clearCart();
                  
                  // Показываем предупреждение, но заказ создан
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Заказ создан, но не удалось подтвердить на сервере: $error'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  
                  // Переходим к экрану деталей заказа
                  GoRouter.of(context).go('/order/$orderId');
                },
              );
            } catch (e) {
              print('[DEBUG] PaymentScreen: Исключение при подтверждении заказа: $e');
              
              // Очищаем корзину
              ref.read(cartProvider.notifier).clearCart();
              
              // Показываем предупреждение
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Заказ создан, но произошла ошибка при подтверждении: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
              
              // Переходим к экрану деталей заказа
              GoRouter.of(context).go('/order/$orderId');
            }
          } else {
            print('[DEBUG] PaymentScreen: orderId не найден, переходим на главную');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Заказ создан, но не удалось получить номер заказа'),
                backgroundColor: Colors.orange,
              ),
            );
            GoRouter.of(context).go('/');
          }
        }
      },
      err: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка создания заказа: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Widget _buildPaymentMethodTile(PaymentMethod method) {
    final isSelected = _selectedMethod?.id == method.id;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? primaryColor.withOpacity(0.1) : null,
      child: ListTile(
        leading: _getPaymentIcon(method.type),
        title: Text(
          method.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryColor : null,
          ),
        ),
        subtitle: method.description != null 
          ? Text(method.description!)
          : null,
        trailing: Radio<PaymentMethod>(
          value: method,
          groupValue: _selectedMethod,
          onChanged: (value) {
            setState(() {
              _selectedMethod = value;
            });
          },
          activeColor: primaryColor,
        ),
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
      ),
    );
  }

  Widget _getPaymentIcon(String type) {
    IconData iconData;
    Color iconColor = primaryColor;

    switch (type) {
      case 'cash_on_delivery':
        iconData = Icons.money;
        break;
      case 'bank_transfer':
        iconData = Icons.account_balance;
        break;
      case 'paypal':
        iconData = Icons.payment;
        break;
      default:
        iconData = Icons.payment;
    }

    return Icon(iconData, color: iconColor, size: 28);
  }

  Widget _buildOrderSummary() {
    final cartItems = ref.watch(cartProvider);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сводка заказа',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.addressType == 'pickup' ? 'Пункт выдачи' : 'Адрес доставки'}:'),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.selectedAddressName,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (widget.addressFull != null && widget.addressFull!.isNotEmpty)
                        Text(
                          widget.addressFull!,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Товаров: ${cartItems.fold(0, (sum, item) => sum + item.qty)}'),
                Text('${cartItems.fold(0.0, (sum, item) => sum + item.subtotal).toStringAsFixed(2)} с.'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Итого:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cartItems.fold(0.0, (sum, item) => sum + item.subtotal).toStringAsFixed(2)} с.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Способ оплаты',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._paymentMethods.map((method) => _buildPaymentMethodTile(method)),
        ],
      ),
    );
  }

  /// Извлекает имя файла изображения из полного URL
  String _extractImageFilename(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    
    // Если это уже имя файла (без http), возвращаем как есть
    if (!imageUrl.startsWith('http')) {
      return imageUrl;
    }
    
    // Извлекаем имя файла из URL
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final filename = pathSegments.last;
        print('[DEBUG] PaymentScreen: Извлечено имя файла из URL: $imageUrl -> $filename');
        return filename;
      }
    } catch (e) {
      print('[DEBUG] PaymentScreen: Ошибка парсинга URL $imageUrl: $e');
    }
    
    return imageUrl;
  }

  @override
  Widget build(BuildContext context) {
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
          'Оплата',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 2),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
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
                onPressed: _loadPaymentMethods,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderSummary(),
                const SizedBox(height: 16),
                _buildPaymentMethodsSection(),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _isCreatingOrder
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF9C27B0), // Основной фиолетовый
                            Color(0xFFE040FB), // Светло-фиолетовый
                          ],
                          stops: [0.0, 1.0],
                        ),
                  color: _isCreatingOrder ? Colors.grey[300] : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isCreatingOrder ? null : _createOrder,
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
                  child: _isCreatingOrder
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Оформить заказ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
