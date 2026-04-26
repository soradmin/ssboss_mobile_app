import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';
import '../models/address.dart';
import '../repo/address_api.dart';
import '../../../core/result.dart';
import '../../profile/repo/profile_api.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final Address? address; // null для создания нового адреса
  final VoidCallback? onSaved; // Callback при успешном сохранении

  const AddressFormScreen({
    super.key,
    this.address,
    this.onSaved,
  });

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Список стран с кодами ISO 3166-1 alpha-2
  final List<Map<String, String>> _countries = [
    {'code': 'TJ', 'name': 'Tajikistan'},
    {'code': 'UZ', 'name': 'Uzbekistan'},
    {'code': 'KZ', 'name': 'Kazakhstan'},
    {'code': 'KG', 'name': 'Kyrgyzstan'},
    {'code': 'RU', 'name': 'Russia'},
    {'code': 'AF', 'name': 'Afghanistan'},
    {'code': 'IR', 'name': 'Iran'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'TR', 'name': 'Turkey'},
  ];
  
  // Выбранная страна (по умолчанию Tajikistan)
  String _selectedCountryCode = 'TJ';
  
  // Список областей Таджикистана
  final List<Map<String, String>> _regions = [
    {'code': 'DU', 'name': 'Душанбе'},
    {'code': 'KT', 'name': 'Хатлон'},
    {'code': 'GB', 'name': 'Кухистони Бадахшон'},
    {'code': 'SU', 'name': 'Согд'},
  ];
  
  // Выбранная область (по умолчанию Душанбе)
  String? _selectedRegionCode = 'DU';

  bool get isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _fillFormWithAddress(widget.address!);
    } else {
      // Для нового адреса устанавливаем значения по умолчанию
      _cityController.text = 'Душанбе';
      _postalCodeController.text = '734042';
      _loadUserName();
    }
  }
  
  Future<void> _loadUserName() async {
    try {
      final profileApi = ref.read(profileApiProvider);
      final result = await profileApi.getUserProfile();
      
      if (result is Ok<Map<String, dynamic>>) {
        final name = result.value['name'] as String?;
        if (name != null && name.isNotEmpty && _nameController.text.isEmpty) {
          setState(() {
            _nameController.text = name;
          });
        }
      }
    } catch (e) {
      print('[DEBUG] AddressFormScreen: Ошибка загрузки имени пользователя: $e');
    }
  }

  void _fillFormWithAddress(Address address) {
    _nameController.text = address.name;
    _addressController.text = address.address;
    _cityController.text = address.city;
    _postalCodeController.text = address.postalCode ?? '';
    _phoneController.text = address.phone ?? '';
    // Устанавливаем страну из адреса, если она есть, иначе оставляем значение по умолчанию 'TJ'
    if (address.country != null && address.country!.isNotEmpty) {
      _selectedCountryCode = address.country!;
    }
    // Устанавливаем область из адреса
    if (address.region != null && address.region!.isNotEmpty) {
      // Ищем код области по названию
      final region = _regions.firstWhere(
        (r) => r['name'] == address.region || r['code'] == address.region,
        orElse: () => _regions[0], // По умолчанию Душанбе
      );
      _selectedRegionCode = region['code'];
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addressApi = AddressApi();
      Result<Address> result;

      // Получаем название области по коду
      final regionName = _selectedRegionCode != null
          ? _regions.firstWhere((r) => r['code'] == _selectedRegionCode)['name']
          : null;
      
      if (isEditing) {
        result = await addressApi.updateAddress(
          id: widget.address!.id,
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          region: regionName,
          postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          country: _selectedCountryCode,
          type: 'delivery',
        );
      } else {
        result = await addressApi.createAddress(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          region: regionName,
          postalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          country: _selectedCountryCode,
          type: 'delivery',
        );
      }

      if (result is Ok<Address>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Адрес обновлен!' : 'Адрес добавлен!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Вызываем callback если есть
          widget.onSaved?.call();
          
          // Возвращаемся назад
          context.pop(result.value);
        }
      } else {
        setState(() {
          _errorMessage = (result as Err).message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
          isEditing ? 'Редактировать адрес' : 'Добавить адрес',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Название адреса
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Название адреса *',
                  hintText: 'Например: Дом, Работа',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите название адреса';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 2. Страна
              DropdownButtonFormField<String>(
                value: _selectedCountryCode,
                decoration: const InputDecoration(
                  labelText: 'Страна *',
                  border: OutlineInputBorder(),
                ),
                items: _countries.map((country) {
                  return DropdownMenuItem<String>(
                    value: country['code'],
                    child: Text(country['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountryCode = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Выберите страну';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 3. Область
              DropdownButtonFormField<String>(
                value: _selectedRegionCode,
                decoration: const InputDecoration(
                  labelText: 'Область *',
                  border: OutlineInputBorder(),
                ),
                items: _regions.map((region) {
                  return DropdownMenuItem<String>(
                    value: region['code'],
                    child: Text(region['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRegionCode = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Выберите область';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 4. Город
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Город *',
                  hintText: 'Душанбе',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите город';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 5. Адрес
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Адрес *',
                  hintText: 'Улица, дом, квартира',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите адрес';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // 6. Почтовый индекс
              TextFormField(
                controller: _postalCodeController,
                decoration: const InputDecoration(
                  labelText: 'Почтовый индекс',
                  hintText: '734042',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 16),
              
              // 7. Телефон
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Телефон',
                  hintText: '+992 XX XXX XXXX',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              
              const SizedBox(height: 24),
              
              // Сообщение об ошибке
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Кнопка сохранения
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
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                        isEditing ? 'Сохранить изменения' : 'Добавить адрес',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Примечание
              Text(
                '* - обязательные поля',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 4),
    );
  }
}
