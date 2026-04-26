import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../repo/catalog_api.dart';
import '../../../core/result.dart';
import '../../../theme.dart';
import '../../cart/controllers/cart_controller.dart';

// Провайдер для количества товаров в корзине
final cartTotalQuantityProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.qty);
});

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final api = CatalogApi();
    final result = await api.getCategories();
    
    print('[DEBUG] CategoriesScreen._loadCategories: Результат загрузки категорий: ${result.runtimeType}');
    
    if (result is Ok<List<Map<String, dynamic>>>) {
      final categories = result.value;
      print('[DEBUG] CategoriesScreen._loadCategories: Загружено категорий: ${categories.length}');
      
      // Логируем первые несколько категорий для отладки
      for (int i = 0; i < categories.length && i < 3; i++) {
        final cat = categories[i];
        print('[DEBUG] CategoriesScreen._loadCategories: Категория $i: name=${cat['name']}, title=${cat['title']}, slug=${cat['slug']}');
      }
      
      if (categories.isNotEmpty) {
        setState(() {
          _categories = categories;
          _loading = false;
        });
      } else {
        print('[DEBUG] CategoriesScreen._loadCategories: Список категорий пуст, используем fallback');
        // Если API не вернул категории, используем fallback
        setState(() {
          _categories = _getFallbackCategories();
          _loading = false;
        });
      }
    } else {
      final error = (result as Err).message;
      print('[DEBUG] CategoriesScreen._loadCategories: Ошибка загрузки категорий: $error');
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackCategories() {
    return [
      {
        'name': 'Только избранные',
        'subtitle': 'бренды',
        'image': null,
        'product_count': null,
        'slug': 'favorite-brands',
        'color': Colors.black,
        'textColor': Colors.white,
        'icon': Icons.check_circle_outline,
        'isSpecial': true,
      },
      {
        'name': 'Туры, отели и авиабилеты',
        'subtitle': 'travel',
        'image': null,
        'product_count': null,
        'slug': 'travel',
        'color': const Color(0xFFFF6B35),
        'textColor': Colors.white,
        'icon': Icons.flight_takeoff,
        'isSpecial': true,
      },
      {
        'name': 'Женщинам',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/category-1760523981-3.png',
        'product_count': 1250,
        'slug': 'women-apparel',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Обувь',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/shoes.jpg',
        'product_count': 890,
        'slug': 'shoes',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Детям',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/kids.jpg',
        'product_count': 650,
        'slug': 'kids-apparel',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Мужчинам',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/men-fashion.jpg',
        'product_count': 980,
        'slug': 'mens-wear',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Дом',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/home.jpg',
        'product_count': 750,
        'slug': 'home',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Красота',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/beauty.jpg',
        'product_count': 420,
        'slug': 'beauty',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Аксессуары',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/accessories.jpg',
        'product_count': 320,
        'slug': 'accessories',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Электроника',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/electronics.jpg',
        'product_count': 1500,
        'slug': 'electronics',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Игрушки',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/toys.jpg',
        'product_count': 680,
        'slug': 'toys',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Мебель',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/furniture.jpg',
        'product_count': 450,
        'slug': 'furniture',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Продукты',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/food.jpg',
        'product_count': 1200,
        'slug': 'food',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Бытовая техника',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/appliances.jpg',
        'product_count': 380,
        'slug': 'appliances',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
      {
        'name': 'Зоотовары',
        'subtitle': null,
        'image': 'https://ssboss.shop/uploads/pet-supplies.jpg',
        'product_count': 250,
        'slug': 'pet-supplies',
        'color': Colors.white,
        'textColor': Colors.black,
        'icon': null,
        'isSpecial': false,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        title: InkWell(
          onTap: () {
            // Открываем поиск
            showSearch(
              context: context,
              delegate: _CategorySearchDelegate(_categories),
            );
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search,
                  color: Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Поиск',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.camera_alt,
                  color: Colors.grey[700],
                  size: 20,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadCategories,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: _buildNavItem(Icons.home, Icons.home, 'Главная', 0, false)),
            Expanded(child: _buildNavItem(Icons.grid_view_outlined, Icons.grid_view, 'Каталог', 1, true)),
            Expanded(child: _buildNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Корзина', 2, false)),
            Expanded(child: _buildNavItem(Icons.favorite_border, Icons.favorite, 'Избранное', 3, false)),
            Expanded(child: _buildNavItem(Icons.person_outline, Icons.person, 'Профиль', 4, false)),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData selectedIcon, String label, int index, bool isSelected) {
    return Consumer(
      builder: (context, ref, child) {
        // Получаем количество товаров в корзине для иконки корзины
        final cartQuantity = index == 2 ? ref.watch(cartTotalQuantityProvider) : 0;
        
        return GestureDetector(
          onTap: () {
            switch (index) {
              case 0: context.go('/'); break;
              case 1: context.go('/catalog'); break;
              case 2: context.go('/cart'); break;
              case 3: context.go('/favorites'); break;
              case 4: context.go('/profile'); break;
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF9C27B0).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Иконка с бейджем для корзины
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? const Color(0xFF9C27B0) : const Color(0xFF718096),
                      size: 20,
                    ),
                    // Бейдж с количеством товаров (только для корзины)
                    if (index == 2 && cartQuantity > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            cartQuantity > 99 ? '99+' : cartQuantity.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF9C27B0) : const Color(0xFF718096),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8813BA)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка загрузки категорий',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                        onPressed: _loadCategories,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Повторить', style: TextStyle(color: Colors.white)),
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
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Категории не найдены',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Попробуйте обновить страницу',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: const Color(0xFF8813BA),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 100, // Отступ для нижней навигации
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final category = _categories[i];
                return _CategoryTile(
                  name: (category['name'] ?? category['title'] ?? 'Категория').toString(),
                  subtitle: category['subtitle']?.toString(),
                  image: category['image']?.toString(),
                  productCount: category['product_count'] as int?,
                  slug: category['slug']?.toString(),
                  categoryId: category['id'] as int?,
                  color: category['color'] as Color? ?? Colors.white,
                  textColor: category['textColor'] as Color? ?? Colors.black,
                  icon: category['icon'] as IconData?,
                  isSpecial: category['isSpecial'] as bool? ?? false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String? image;
  final int? productCount;
  final String? slug;
  final int? categoryId;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool isSpecial;

  const _CategoryTile({
    required this.name,
    this.subtitle,
    this.image,
    this.productCount,
    this.slug,
    this.categoryId,
    this.color = Colors.white,
    this.textColor = Colors.black,
    this.icon,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Переходим к товарам категории используя slug
        final categoryParam = slug ?? name.toLowerCase().replaceAll(' ', '-');
        print('[DEBUG] CategoriesScreen: Переход к категории: name="$name", slug="$slug", categoryId="$categoryId", categoryParam="$categoryParam"');
        final queryParams = <String, String>{
          'category': categoryParam,
          'title': name,
        };
        if (categoryId != null) {
          queryParams['category_id'] = categoryId.toString();
        }
        final queryString = queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
        context.push('/catalog/products?$queryString');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: isSpecial ? _buildSpecialCard() : _buildRegularCard(),
      ),
    );
  }

  Widget _buildSpecialCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  color: textColor,
                  size: 24,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegularCard() {
    return Stack(
      children: [
        // Фоновый цвет как в Яндекс Маркете
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // Изображение категории
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: image != null && image!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: image!.startsWith('http') 
                      ? image! 
                      : 'https://ssboss.shop/uploads/$image',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFFF2F2F2),
                    child: const Center(
                      child: Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFF2F2F2),
                    child: const Center(
                      child: Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFFF2F2F2),
                  child: const Center(
                    child: Icon(
                      Icons.category_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                ),
        ),
        // Название категории в верхнем левом углу без фона
        Positioned(
          top: 8,
          left: 8,
          right: productCount != null && productCount! > 0 ? 60 : 8,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
        ),
        // Количество товаров в правом верхнем углу (если есть)
        if (productCount != null && productCount! > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8813BA),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$productCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategorySearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> categories;

  _CategorySearchDelegate(this.categories);

  @override
  String get searchFieldLabel => 'Поиск категорий';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final filteredCategories = categories.where((category) {
      final name = category['name']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();

    if (filteredCategories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Категории не найдены',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Попробуйте другой поисковый запрос',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return InkWell(
          onTap: () {
            final categoryParam = category['slug']?.toString() ?? 
                category['name']?.toString().toLowerCase().replaceAll(' ', '-') ?? 'unknown';
            final categoryTitle = (category['name'] ?? category['title'] ?? 'Категория').toString();
            final categoryId = category['id'] as int?;
            final queryParams = <String, String>{
              'category': categoryParam,
              'title': categoryTitle,
            };
            if (categoryId != null) {
              queryParams['category_id'] = categoryId.toString();
            }
            final queryString = queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
            context.push('/catalog/products?$queryString');
            close(context, '');
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Фоновый цвет как в Яндекс Маркете
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Изображение категории
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: category['image'] != null && category['image'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: category['image'].toString().startsWith('http') 
                              ? category['image'].toString()
                              : 'https://ssboss.shop/uploads/${category['image']}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFF2F2F2),
                            child: const Center(
                              child: Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFF2F2F2),
                            child: const Center(
                              child: Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF2F2F2),
                          child: const Center(
                            child: Icon(
                              Icons.category_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
                // Название категории в верхнем левом углу без фона
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (category['name'] ?? category['title'] ?? 'Категория').toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
