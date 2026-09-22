import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme.dart';
import '../../../core/date_formatter.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../models/order.dart';
import '../repo/order_api.dart';
import '../order_action_limit_service.dart';
import '../../catalog/repo/catalog_api.dart';
import '../../../core/result.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailsScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  Order? _order;
  bool _isLoading = true;
  bool _isRepeatingOrder = false;
  int _remainingActions = OrderActionLimitService.maxActionsPerOrder;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('[DEBUG] OrderDetailsScreen: Загрузка деталей заказа, ID: ${widget.orderId} (тип: ${widget.orderId.runtimeType})');
    
    // Проверяем, что ID валидный
    if (widget.orderId <= 0) {
      print('[ERROR] OrderDetailsScreen: Невалидный ID заказа: ${widget.orderId}');
      setState(() {
        _errorMessage = 'Неверный ID заказа';
        _isLoading = false;
      });
      return;
    }

    final orderApi = ref.read(orderApiProvider);
    final result = await orderApi.getOrderDetails(widget.orderId);

    result.when(
      ok: (order) async {
        print('[DEBUG] OrderDetailsScreen: Заказ успешно загружен, ID: ${order.id}, номер: ${order.orderNumber}');
        final remaining = await OrderActionLimitService.getRemainingActions(order.id);
        setState(() {
          _order = order;
          _remainingActions = remaining;
          _isLoading = false;
        });
      },
      err: (error) {
        print('[ERROR] OrderDetailsScreen: Ошибка загрузки заказа: $error');
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _cancelOrder() async {
    if (_order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('orders.cancel_order')),
        content: Text(context.tr('orders.cancel_order') + '?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('orders.cancel_no')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('orders.cancel_yes')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final orderApi = ref.read(orderApiProvider);
      final result = await orderApi.cancelOrder(_order!.id);

      result.when(
        ok: (_) async {
          final remaining = await OrderActionLimitService.getRemainingActions(_order!.id);
          setState(() {
            _order = _order!.copyWith(isCancelled: true);
            _remainingActions = remaining;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('orders.order_cancelled')),
              backgroundColor: Colors.green,
            ),
          );
          _loadOrderDetails();
        },
        err: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.tr('common.error')}: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    }
  }

  Future<void> _repeatOrder() async {
    if (_order == null || _isRepeatingOrder) return;

    if (_remainingActions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Лимит исчерпан: отменить или повторить этот заказ можно не более 3 раз'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('orders.reorder')),
        content: Text(
          '${context.tr('orders.reorder')}\n'
          '$_remainingActions / ${OrderActionLimitService.maxActionsPerOrder}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('orders.to_cart')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRepeatingOrder = true);

    final orderApi = ref.read(orderApiProvider);
    final result = await orderApi.repeatOrder(_order!);

    if (!mounted) return;

    setState(() => _isRepeatingOrder = false);

    result.when(
      ok: (addedCount) async {
        final remaining = await OrderActionLimitService.getRemainingActions(_order!.id);
        setState(() => _remainingActions = remaining);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('orders.added_to_cart', namedArgs: {'count': '$addedCount'})),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/cart');
      },
      err: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  bool get _canCancelOrder =>
      _order != null && _order!.canCancel && _remainingActions > 0;

  bool get _canRepeatOrder =>
      _order != null && _order!.canRepeatOrder && _remainingActions > 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    if (_isLoading) {
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
            context.tr('orders.details'),
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
        body: const Center(child: CircularProgressIndicator()),
        extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
      );
    }

    if (_errorMessage != null) {
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
            context.tr('orders.details'),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                context.tr('catalog.load_error'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
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
                  onPressed: _loadOrderDetails,
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
        extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
      );
    }

    if (_order == null) {
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
            context.tr('orders.details'),
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
          child: Text(context.tr('orders.not_found')),
        ),
      );
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
          context.tr('orders.details'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: _loadOrderDetails,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          BottomNavigationBarWidget.occupiedHeight(context) + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(),
            if (_order!.isCancelled) ...[
              const SizedBox(height: 16),
              _buildCancelledBanner(),
            ],
            const SizedBox(height: 20),
            _buildOrderStatus(),
            const SizedBox(height: 20),
            _buildOrderInfo(),
            if (_order!.address != null) ...[
              const SizedBox(height: 20),
              _buildAddressInfo(),
            ],
            const SizedBox(height: 20),
            _buildOrderItems(),
            const SizedBox(height: 20),
            _buildOrderSummary(),
            if (_canCancelOrder) ...[
              const SizedBox(height: 24),
              _buildCancelButton(),
            ],
            if (_canRepeatOrder) ...[
              const SizedBox(height: 24),
              _buildRepeatOrderButton(),
            ],
            if (_order!.isCancelled && !_canRepeatOrder) ...[
              const SizedBox(height: 16),
              _buildLimitReachedInfo(),
            ],
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9C27B0),
            Color(0xFFE040FB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('orders.order'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _order!.orderNumber.isNotEmpty ? _order!.orderNumber : 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildHeaderInfo(
                  Icons.calendar_today,
                  _formatDate(_order!.orderDate),
                ),
                const SizedBox(width: 20),
                _buildHeaderInfo(
                  Icons.account_balance_wallet,
                  '${_order!.totalAmount.toStringAsFixed(2)} ${context.tr('common.currency')}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    return AppDateFormatter.formatDateString(dateString);
  }

  Widget _buildOrderStatus() {
    final currentStatus = _order!.effectiveStatus;
    final statusIcon = _getStatusIcon(currentStatus);
    final statusText = _order!.displayStatus;
    final statusColor = _getStatusColor(currentStatus);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('orders.status'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_order!.isCancelled) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _showStatusTimeline(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timeline,
                        color: Color(0xFF9C27B0),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('orders.view_steps'),
                        style: const TextStyle(
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: Color(0xFFD32F2F)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('orders.cancelled_note'),
              style: TextStyle(
                color: Colors.red[800],
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.access_time;
      case 'confirmed':
        return Icons.check_circle;
      case 'picked_up':
      case 'picked up':
        return Icons.work;
      case 'on_the_way':
      case 'on the way':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help;
    }
  }

  void _showStatusTimeline() {
    final statuses = [
      {'key': 'pending', 'name': context.tr('orders.pending'), 'icon': Icons.access_time},
      {'key': 'confirmed', 'name': context.tr('orders.confirmed'), 'icon': Icons.check_circle},
      {'key': 'picked_up', 'name': context.tr('orders.processing'), 'icon': Icons.work},
      {'key': 'on_the_way', 'name': context.tr('orders.shipped'), 'icon': Icons.local_shipping},
      {'key': 'delivered', 'name': context.tr('orders.delivered'), 'icon': Icons.done_all},
    ];
    
    final currentStatus = _order!.status.toLowerCase();
    final currentIndex = statuses.indexWhere((s) => s['key'] == currentStatus);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                context.tr('orders.steps'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  final isCompleted = index <= currentIndex;
                  final isCurrent = index == currentIndex;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCompleted ? primaryColor : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? Icon(
                                    status['icon'] as IconData,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status['name'] as String,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCompleted ? primaryColor : Colors.grey[600],
                                ),
                              ),
                              if (isCurrent)
                                Text(
                                  context.tr('orders.current_step'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: primaryColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (index < statuses.length - 1)
                          Container(
                            width: 2,
                            height: 30,
                            margin: const EdgeInsets.only(left: 20),
                            color: isCompleted ? primaryColor : Colors.grey[300],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: Container(
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      context.tr('common.close'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9C27B0).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.tr('orders.info'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Карточки с информацией
        _buildInfoCard(
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF2196F3),
          iconBackground: const Color(0xFF2196F3).withOpacity(0.1),
          label: context.tr('orders.delivery_status'),
          value: _order!.displayDeliveryStatus,
          valueColor: _getStatusColor(_order!.effectiveStatus),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.payment_rounded,
          iconColor: const Color(0xFF4CAF50),
          iconBackground: const Color(0xFF4CAF50).withOpacity(0.1),
          label: context.tr('orders.payment_method'),
          value: _order!.displayPaymentMethod,
          valueColor: const Color(0xFF1A1A1A),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFFFF9800),
          iconBackground: const Color(0xFFFF9800).withOpacity(0.1),
          label: context.tr('orders.payment_status'),
          value: _order!.displayPaymentStatus,
          valueColor: _getPaymentStatusColor(_order!.displayPaymentStatus),
        ),
        if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoCard(
            icon: Icons.note_rounded,
            iconColor: const Color(0xFF9C27B0),
            iconBackground: const Color(0xFF9C27B0).withOpacity(0.1),
            label: context.tr('orders.notes'),
            value: _order!.notes!,
            valueColor: const Color(0xFF1A1A1A),
            isMultiline: true,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String label,
    required String value,
    required Color valueColor,
    bool isMultiline = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            // Иконка с градиентным фоном
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Текстовая информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  isMultiline
                      ? Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: valueColor,
                            height: 1.4,
                          ),
                        )
                      : Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: valueColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ],
              ),
            ),
            // Декоративная стрелка (опционально)
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[300],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    // Поддержка русского и английского языков
    if (lowerStatus.contains('подтвержден') || lowerStatus.contains('confirmed')) {
      return const Color(0xFF4CAF50); // Зеленый
    } else if (lowerStatus.contains('в пути') || lowerStatus.contains('shipped') || 
               lowerStatus.contains('on the way') || lowerStatus.contains('on_the_way')) {
      return const Color(0xFF2196F3); // Синий
    } else if (lowerStatus.contains('доставлен') || lowerStatus.contains('delivered')) {
      return const Color(0xFF4CAF50); // Зеленый
    } else if (lowerStatus.contains('отменен') || lowerStatus.contains('cancelled')) {
      return const Color(0xFFF44336); // Красный
    } else if (lowerStatus.contains('ожидает') || lowerStatus.contains('pending')) {
      return const Color(0xFFFF9800); // Оранжевый
    } else if (lowerStatus.contains('picked up') || lowerStatus.contains('picked_up')) {
      return const Color(0xFF9C27B0); // Фиолетовый
    }
    return Colors.grey; // Серый по умолчанию
  }

  Color _getPaymentStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('оплачен') || lowerStatus.contains('paid') || 
        lowerStatus.contains('оплачено')) {
      return const Color(0xFF4CAF50);
    } else if (lowerStatus.contains('не оплачен') || lowerStatus.contains('unpaid') || 
               lowerStatus.contains('не оплачено')) {
      return const Color(0xFFF44336);
    } else if (lowerStatus.contains('ожидает') || lowerStatus.contains('pending')) {
      return const Color(0xFFFF9800);
    }
    return const Color(0xFF1A1A1A);
  }

  Widget _buildAddressInfo() {
    if (_order!.address == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF9C27B0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('orders.delivery_address'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _order!.address!.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.home, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _order!.address!.fullAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        _order!.address!.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  if (_order!.address!.email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _order!.address!.email,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    color: Color(0xFF9C27B0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('orders.items_in_order'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_order!.items.length}',
                    style: const TextStyle(
                      color: Color(0xFF9C27B0),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._order!.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildOrderItem(item),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return InkWell(
      onTap: () async {
        // Переход на страницу товара
        if (item.productId > 0) {
          // Загружаем товар по ID перед навигацией
          final catalogApi = CatalogApi();
          final productResult = await catalogApi.productById(item.productId);
          
          productResult.when(
            ok: (product) {
              // Переходим на страницу товара с объектом Product
              context.push('/product/${item.productId}', extra: product);
            },
            err: (error) {
              // Если не удалось загрузить товар, показываем сообщение
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${context.tr('common.error')}: $error'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение товара
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: Builder(
                  builder: (context) {
                    if (item.image != null && item.image!.isNotEmpty) {
                      print('[DEBUG] OrderDetailsScreen: Загрузка изображения для товара ${item.name}: ${item.image}');
                      return CachedNetworkImage(
                        imageUrl: item.image!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          print('[DEBUG] OrderDetailsScreen: Ошибка загрузки изображения $url: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                          );
                        },
                      );
                    } else {
                      print('[DEBUG] OrderDetailsScreen: Изображение отсутствует для товара ${item.name}, productId: ${item.productId}');
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400], size: 32),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Информация о товаре
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.size != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${context.tr('orders.size')} ${item.size}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '× ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9C27B0),
                          ),
                        ),
                      ),
                      Text(
                        '${item.total.toStringAsFixed(2)} ${context.tr('common.currency')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ],
                  ),
                  if (_order!.isDelivered) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showWriteReview(item),
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: Text(context.tr('orders.write_review')),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9C27B0),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Иконка стрелки для указания кликабельности
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWriteReview(OrderItem item) async {
    var rating = 5;
    final commentCtrl = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('orders.write_review'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('orders.review_hint'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setModal(() => rating = star),
                        icon: Icon(
                          star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFFC107),
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('orders.review_comment'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(context.tr('orders.send_review')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (submitted != true || !mounted || _order == null) {
      commentCtrl.dispose();
      return;
    }

    final result = await ref.read(orderApiProvider).rateProduct(
      _order!.id,
      item.productId,
      rating,
      commentCtrl.text.trim(),
    );
    commentCtrl.dispose();
    if (!mounted) return;
    if (result is Ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('orders.review_sent')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((result as Err).message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9C27B0),
            Color(0xFFE040FB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('orders.total'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_order!.totalAmount.toStringAsFixed(2)} ${context.tr('common.currency')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.payments,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFC94F4F),
              Color(0xFFE85A5A),
            ],
            stops: [0.0, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          onPressed: _cancelOrder,
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
            context.tr('orders.cancel_order'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatOrderButton() {
    return Center(
      child: Column(
        children: [
          Container(
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
            child: ElevatedButton(
              onPressed: _isRepeatingOrder ? null : _repeatOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isRepeatingOrder
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      context.tr('orders.reorder'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Осталось попыток: $_remainingActions из ${OrderActionLimitService.maxActionsPerOrder}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitReachedInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Text(
        'Лимит отмены/повтора для этого заказа исчерпан (максимум ${OrderActionLimitService.maxActionsPerOrder} раза).',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.orange[900], fontSize: 13),
      ),
    );
  }
}
