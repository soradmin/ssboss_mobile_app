import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../../checkout/models/address.dart';
import '../../checkout/repo/address_api.dart';
import '../../../core/result.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  List<Address> addresses = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final addressApi = AddressApi();
      final result = await addressApi.getAddresses();
      
      if (result is Ok<List<Address>>) {
        setState(() {
          addresses = result.value;
          isLoading = false;
        });
      } else {
        setState(() {
          error = (result as Err).message;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(Address address) async {
    // Нельзя удалить пункт выдачи
    if (address.type == 'pickup') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя удалить пункт выдачи'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить адрес?'),
        content: Text('Вы уверены, что хотите удалить адрес "${address.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final addressApi = AddressApi();
        // Используем userAddressId если он есть, иначе id
        // userAddressId - это реальный ID из базы данных
        final addressIdToDelete = address.userAddressId ?? address.id;
        print('[DEBUG] AddressesScreen._deleteAddress: Удаляем адрес с ID=$addressIdToDelete (userAddressId=${address.userAddressId}, id=${address.id})');
        
        final result = await addressApi.deleteAddress(addressIdToDelete);
        
        if (result is Ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Адрес удален!'),
                backgroundColor: Colors.green,
              ),
            );
            // Небольшая задержка перед обновлением списка, чтобы сервер успел обработать запрос
            await Future.delayed(const Duration(milliseconds: 300));
            _loadAddresses(); // Перезагружаем список
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка: ${(result as Err).message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _addNewAddress() {
    context.push('/address-form', extra: {
      'address': null,
      'onSaved': () {
        _loadAddresses(); // Перезагружаем список после добавления
      },
    });
  }

  void _editAddress(Address address) {
    // Нельзя редактировать пункт выдачи
    if (address.type == 'pickup') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя редактировать пункт выдачи'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.push('/address-form', extra: {
      'address': address,
      'onSaved': () {
        _loadAddresses(); // Перезагружаем список после редактирования
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF9C27B0);
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
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
          'Мои адреса',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            onPressed: _addNewAddress,
            icon: const Icon(Icons.add, color: Colors.white, size: 26),
            tooltip: 'Добавить адрес',
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : error != null
              ? _buildErrorScreen(context, theme)
              : _buildAddressesList(context, theme),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
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
              'Ошибка загрузки адресов',
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
                child: const Text('Повторить'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    if (addresses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_outlined,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Нет сохраненных адресов',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Добавьте адрес для быстрого оформления заказов',
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
                child: ElevatedButton.icon(
                  onPressed: _addNewAddress,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить адрес'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Разделяем адреса по типам
    final pickupAddresses = addresses.where((a) => a.type == 'pickup').toList();
    final deliveryAddresses = addresses.where((a) => a.type == 'delivery').toList();

    return RefreshIndicator(
      onRefresh: _loadAddresses,
      color: const Color(0xFF9C27B0),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        children: [
          // Пункты выдачи
          if (pickupAddresses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Пункты выдачи',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.grey[800],
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...pickupAddresses.map((address) => _buildAddressCard(context, theme, address)),
            const SizedBox(height: 32),
          ],

          // Адреса доставки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Адреса доставки',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.grey[800],
                  letterSpacing: -0.5,
                ),
              ),
              InkWell(
                onTap: _addNewAddress,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: const Color(0xFF9C27B0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          color: const Color(0xFF9C27B0),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (deliveryAddresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 40,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет адресов доставки',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white : Colors.grey[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте адрес для доставки курьером',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...deliveryAddresses.map((address) => _buildAddressCard(context, theme, address)),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, ThemeData theme, Address address) {
    final isPickup = address.type == 'pickup';
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF9C27B0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isPickup ? null : () => _editAddress(address),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPickup ? Icons.store_rounded : Icons.home_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  address.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: isDark ? Colors.white : Colors.grey[800],
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (address.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9C27B0),
                                        Color(0xFFE040FB),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'По умолчанию',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            address.fullAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          if (address.phone != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 16,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  address.phone!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isPickup) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _editAddress(address);
                              break;
                            case 'delete':
                              _deleteAddress(address);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18, color: Colors.grey[700]),
                                const SizedBox(width: 12),
                                Text(
                                  'Редактировать',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red[400]),
                                const SizedBox(width: 12),
                                Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red[400]),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
