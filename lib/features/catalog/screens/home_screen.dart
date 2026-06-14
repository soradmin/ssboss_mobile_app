import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_item.dart';
import '../../cart/widgets/cart_badge.dart';
import '../../cart/providers/background_sync_provider.dart';
import '../../profile/repo/profile_api.dart';
import '../repo/catalog_api.dart';
import '../models/product.dart';
import '../models/slider.dart';
import '../models/banner.dart' as banner_model;
import '../models/brand.dart';
import '../models/home_page_data.dart';
import '../models/flash_sale.dart';
import '../widgets/product_grid_card.dart';
import '../providers/content_cache.dart';
import '../../personalization/user_preference_service.dart';
import '../../../core/result.dart';         // Ok/Err
import '../../cart/repo/cart_api.dart';    // серверная корзина
import '../../../core/config.dart';        // AppConfig
import '../../../theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../favorites/repo/favorites_api.dart';

final _api = CatalogApi();

// Провайдер для количества товаров в корзине
final cartTotalQuantityProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.qty);
});

/// Показывает bottom sheet для выбора атрибутов товара
Future<void> _showAttributeSelectionBottomSheet(BuildContext context, WidgetRef ref, Product product) async {
  // Всегда загружаем детали товара, чтобы получить актуальные атрибуты
  Product productWithAttributes = product;
  
  // Показываем индикатор загрузки
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  // Загружаем детали товара
  final result = await _api.productById(product.id);
  
  // Закрываем индикатор загрузки
  if (context.mounted) {
    Navigator.of(context).pop();
  }
  
  result.when(
    ok: (loadedProduct) {
      productWithAttributes = loadedProduct;
    },
    err: (error) {
      print('[DEBUG] HomeScreen: Ошибка загрузки деталей товара: $error');
      // Если не удалось загрузить, используем исходный товар
    },
  );

  // Если атрибутов нет, добавляем без выбора
  if (productWithAttributes.attributes.isEmpty) {
    await ref.read(cartProvider.notifier).addToCartWithSync(productWithAttributes, 1);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар добавлен в корзину'),
          duration: Duration(milliseconds: 900),
        ),
      );
    }
    return;
  }

  // Показываем bottom sheet для выбора атрибутов
  if (context.mounted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _AttributeSelectionBottomSheet(
        product: productWithAttributes,
        onAddToCart: (selectedAttributes) async {
          // Добавляем товар в корзину с выбранными атрибутами (синхронизация с сервером)
          await ref.read(cartProvider.notifier).addToCartWithSync(
            productWithAttributes,
            1,
            selectedAttributes: selectedAttributes,
          );
          if (context.mounted) {
            Navigator.of(context).pop(); // Закрываем bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Товар добавлен в корзину'),
                duration: Duration(milliseconds: 900),
              ),
            );
          }
        },
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> 
    with TickerProviderStateMixin {
  List<Product> _products = const [];
  List<Product> _newProducts = const []; // Новинки (последние опубликованные)
  List<Product> _recommendedProducts = const []; // Рекомендуемые (collection=1)
  List<Product> _trendingProducts = const []; // Тренды (collection=2)
  List<Product> _discountedProducts = const []; // Товары со скидкой (offered < selling)
  List<SliderItem> _sliders = const [];
  HomePageData? _homePageData;
  List<Brand> _brands = [];
  List<FlashSale> _flashSales = [];
  bool _loading = true;
  bool _slidersLoading = true;
  bool _flashSaleLoading = false;
  bool _tabLoading = false; // Загрузка при переключении вкладок
  int _currentPage = 1;
  Map<String, dynamic>? _profileData;
  static const int _newProductsPageSizeHint = 20;
  int _newProductsPage = 1;
  bool _newProductsHasMore = true;
  bool _newProductsLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentSliderIndex = 0;
  String _selectedTab = 'Новинки'; // Изменено с 'Популярное' на 'Новинки'

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    
    final cache = HomeContentCache.instance;
    if (cache.hasData) {
      unawaited(_applyHomeCache(cache));
      if (cache.isStale) {
        unawaited(_load(showLoading: false));
      }
    } else {
      _load(showLoading: true);
    }
    _loadProfile();
    _animationController.forward();
    _scrollController.addListener(_onHomeScroll);
    
    // Синхронизируем корзину при возвращении в приложение
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backgroundSyncProvider.notifier).syncOnAppResume();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onHomeScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onHomeScroll() {
    if (_selectedTab != 'Новинки') return;
    if (_newProductsLoadingMore || !_newProductsHasMore || _loading) return;

    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    if (position.pixels < position.maxScrollExtent - 500) return;

    _loadMoreNewProducts();
  }

  void _resetNewProductsPagination() {
    _newProductsPage = 1;
    _newProductsHasMore = true;
    _newProductsLoadingMore = false;
  }

  bool _hasMoreNewProductsBatch(List<Product> batch) {
    return batch.isNotEmpty && batch.length >= _newProductsPageSizeHint;
  }

  List<Product> _mergeNewProducts(List<Product> current, List<Product> batch) {
    if (batch.isEmpty) return current;
    final existingIds = current.map((p) => p.id).toSet();
    final uniqueBatch = batch.where((p) => !existingIds.contains(p.id)).toList();
    if (uniqueBatch.isEmpty) return current;
    return [...current, ...uniqueBatch];
  }

  Future<Result<List<Product>>> _fetchNewProductsPage(int page) {
    return _api.products(page: page);
  }

  Future<void> _applyFirstNewProductsPage(List<Product> batch) async {
    final profile = await UserPreferenceService.instance.loadProfile();
    final personalized = UserPreferenceService.personalizeProducts(batch, profile);
    if (!mounted) return;
    setState(() {
      _newProducts = personalized;
      _products = personalized;
      _newProductsPage = 1;
      _newProductsHasMore = _hasMoreNewProductsBatch(batch);
      _newProductsLoadingMore = false;
    });
  }

  Future<void> _loadMoreNewProducts() async {
    if (_selectedTab != 'Новинки' ||
        _newProductsLoadingMore ||
        !_newProductsHasMore ||
        _loading) {
      return;
    }

    setState(() => _newProductsLoadingMore = true);

    final nextPage = _newProductsPage + 1;
    final result = await _fetchNewProductsPage(nextPage);

    if (!mounted) return;

    if (result is Ok<List<Product>>) {
      final batch = result.value;
      setState(() {
        _newProducts = _mergeNewProducts(_newProducts, batch);
        _products = _newProducts;
        _newProductsPage = nextPage;
        _newProductsHasMore = _hasMoreNewProductsBatch(batch);
        _newProductsLoadingMore = false;
      });
      print(
        '[DEBUG] _loadMoreNewProducts: страница $nextPage, +${batch.length}, '
        'всего ${_newProducts.length}, hasMore=$_newProductsHasMore',
      );
    } else {
      setState(() => _newProductsLoadingMore = false);
      print('[DEBUG] _loadMoreNewProducts: ошибка ${(result as Err).message}');
    }
  }

  // Метод для обновления страницы по свайпу
  Future<void> _onRefresh() async {
    print('[DEBUG] HomeScreen: Начинаем обновление страницы...');
    
    try {
      // Перезапускаем анимацию
      _animationController.reset();
      _animationController.forward();
      
      // Обновляем данные параллельно
      final futures = [
        _load(showLoading: false, force: true),
        _loadProfile(),
        ref.read(cartProvider.notifier).syncWithServer(),
      ];
      
      await Future.wait(futures);
      
      print('[DEBUG] HomeScreen: Обновление завершено успешно');
      
      // Показываем уведомление об успешном обновлении
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Страница обновлена'),
            backgroundColor: Color(0xFF9C27B0),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('[DEBUG] HomeScreen: Ошибка при обновлении: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка обновления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _applyHomeCache(HomeContentCache cache) async {
    final profile = await UserPreferenceService.instance.loadProfile();
    final personalized = UserPreferenceService.personalizeProducts(
      cache.newProducts,
      profile,
    );
    if (!mounted) return;
    setState(() {
      _newProducts = personalized;
      _products = personalized;
      _newProductsPage = 1;
      _newProductsHasMore = _hasMoreNewProductsBatch(cache.newProducts);
      _newProductsLoadingMore = false;
      _recommendedProducts = cache.recommendedProducts;
      _trendingProducts = cache.trendingProducts;
      _discountedProducts = cache.discountedProducts;
      _sliders = cache.sliders;
      _homePageData = cache.homePageData;
      _brands = cache.brands;
      _flashSales = cache.flashSales;
      _loading = false;
      _slidersLoading = false;
    });
  }

  Future<void> _load({bool showLoading = true, bool force = false}) async {
    final cache = HomeContentCache.instance;
    if (!force && cache.hasData && !cache.isStale) return;

    final showSkeleton = showLoading && !cache.hasData;
    if (showSkeleton) {
      setState(() => _loading = true);
    }
    
    try {
    // Слайдеры, главная, бренды, Flash Sale и первая страница «Новинки»
    _resetNewProductsPagination();
    final productsFuture = _fetchNewProductsPage(1);
    final slidersFuture = _api.getSliders();
    final homePageDataFuture = _api.getHomePageData();
    final brandsFuture = _api.getBrands(page: 1);
    final flashSaleFuture = _api.getFlashSale();
    
    final productsRes = await productsFuture;
    final slidersRes = await slidersFuture;
    final homePageDataRes = await homePageDataFuture;
    final brandsRes = await brandsFuture;
    final flashSaleRes = await flashSaleFuture;
    
    if (productsRes is Ok<List<Product>>) {
        await _applyFirstNewProductsPage(productsRes.value);
        print(
          '[DEBUG] Загружено ${productsRes.value.length} товаров (Новинки, стр. 1), '
          'hasMore=$_newProductsHasMore',
        );
    } else {
      final msg = (productsRes as Err).message;
      print('[DEBUG] _load: Ошибка загрузки товаров: $msg');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки товаров: $msg')),
      );
    }
    
    if (slidersRes is Ok<List<SliderItem>>) {
      setState(() => _sliders = slidersRes.value);
        print('[DEBUG] Загружено ${slidersRes.value.length} слайдеров');
    } else {
      print('[DEBUG] Ошибка загрузки слайдеров: ${(slidersRes as Err).message}');
      }
    
    // Загружаем данные главной страницы (баннеры и главные слайдеры)
    if (homePageDataRes is Ok<HomePageData>) {
      setState(() {
        _homePageData = homePageDataRes.value;
        // Используем главные слайдеры из HomePageData
        if (_homePageData!.mainSliders.isNotEmpty) {
          _sliders = _homePageData!.mainSliders;
        }
        print('[DEBUG] Загружено данных главной страницы: ${_homePageData!.mainSliders.length} слайдеров, ${_homePageData!.banners.length} баннеров');
      });
    } else {
      print('[DEBUG] Ошибка загрузки данных главной страницы: ${(homePageDataRes as Err).message}');
    }
    
    // Загружаем бренды для секции категорий
    if (brandsRes is Ok<List<Brand>>) {
      setState(() {
        _brands = brandsRes.value;
        print('[DEBUG] Загружено ${_brands.length} брендов');
      });
    } else {
      print('[DEBUG] Ошибка загрузки брендов: ${(brandsRes as Err).message}');
    }
    
    // Загружаем Flash Sale
    if (flashSaleRes is Ok<List<FlashSale>>) {
      setState(() {
        _flashSales = flashSaleRes.value;
        print('[DEBUG] Загружено ${_flashSales.length} flash sales');
        for (var sale in _flashSales) {
          print('[DEBUG] Flash Sale: id=${sale.id}, title=${sale.title}, status=${sale.status}, products=${sale.products.length}');
        }
      });
    } else {
      print('[DEBUG] Ошибка загрузки Flash Sale: ${(flashSaleRes as Err).message}');
    }
    } catch (e) {
      print('[ERROR] Критическая ошибка загрузки: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки данных: $e')),
      );
    }
    
    if (mounted) {
      HomeContentCache.instance.save(
        newProducts: _newProducts,
        sliders: _sliders,
        homePageData: _homePageData,
        brands: _brands,
        flashSales: _flashSales,
      );
      HomeContentCache.instance.saveTabProducts(
        recommended: _recommendedProducts,
        trending: _trendingProducts,
        discounted: _discountedProducts,
      );
      setState(() {
        _loading = false;
        _slidersLoading = false;
        print('[DEBUG] _load: Установлено _loading = false, _products.length = ${_products.length}');
      });
    }
  }

  // Первая страница «Новинки» (остальные — по скроллу)
  Future<void> _loadNewProducts() async {
    print('[DEBUG] Загрузка новинок (страница 1)...');
    _resetNewProductsPagination();
    final result = await _fetchNewProductsPage(1);
    if (result is Ok<List<Product>>) {
      await _applyFirstNewProductsPage(result.value);
    }
  }

  /// Товары из коллекции на сайте (как блоки на главной веб-страницы).
  Future<List<Product>> _loadProductsByCollection(
    String collectionId, {
    List<String> titleKeywords = const [],
  }) async {
    final fromHome = await _api.getHomeCollectionProducts(
      collectionId: collectionId,
      titleKeywords: titleKeywords,
    );
    if (fromHome is Ok<List<Product>> && fromHome.value.isNotEmpty) {
      return fromHome.value;
    }

    final allProducts = <Product>[];
    var page = 1;
    var hasMorePages = true;

    while (hasMorePages && page <= 10) {
      final result = await _api.products(page: page, collection: collectionId);
      if (result is Ok<List<Product>>) {
        final products = result.value;
        if (products.isEmpty) {
          hasMorePages = false;
        } else {
          allProducts.addAll(products);
          page++;
        }
      } else {
        print(
          '[DEBUG] _loadProductsByCollection($collectionId) стр.$page: '
          '${(result as Err).message}',
        );
        hasMorePages = false;
      }
    }
    return allProducts;
  }

  // Загрузка рекомендуемых товаров (коллекция id=1, как на вебе)
  Future<void> _loadRecommendedProducts() async {
    print('[DEBUG] Загрузка рекомендуемых товаров (collection=1)...');
    try {
      final allProducts = await _loadProductsByCollection(
        '1',
        titleKeywords: const ['рекомен', 'featured', 'popular', 'популяр'],
      );
      setState(() {
        _recommendedProducts = allProducts;
      });
      HomeContentCache.instance.saveTabProducts(recommended: allProducts);
      print('[DEBUG] Загружено ${allProducts.length} рекомендуемых товаров');
    } catch (e) {
      print('[ERROR] Ошибка загрузки рекомендуемых товаров: $e');
    }
  }

  // Загрузка трендовых товаров (коллекция id=2 — «Трендовые товары» на вебе)
  Future<void> _loadTrendingProducts() async {
    print('[DEBUG] Загрузка трендовых товаров (collection=2)...');
    try {
      final allProducts = await _loadProductsByCollection(
        '2',
        titleKeywords: const ['тренд', 'trend', 'trending'],
      );
      setState(() {
        _trendingProducts = allProducts;
      });
      HomeContentCache.instance.saveTabProducts(trending: allProducts);
      print('[DEBUG] Загружено ${allProducts.length} трендовых товаров');
    } catch (e) {
      print('[ERROR] Ошибка загрузки трендовых товаров: $e');
    }
  }

  /// Товары с перечёркнутой старой ценой (поля selling / offered с API).
  Future<void> _loadDiscountedProducts() async {
    print('[DEBUG] Загрузка товаров со скидкой...');
    try {
      if (_flashSales.isEmpty) {
        await _loadFlashSale();
      }

      final seen = <int>{};
      final discounted = <Product>[];

      for (final sale in _flashSales) {
        for (final item in sale.products) {
          final p = item.productData;
          if (p.hasDiscount && seen.add(p.id)) {
            discounted.add(p);
          }
        }
      }

      var page = 1;
      var hasMore = true;
      while (hasMore && page <= 15) {
        final result = await _api.products(page: page);
        if (result is Ok<List<Product>>) {
          final batch = result.value;
          if (batch.isEmpty) {
            hasMore = false;
          } else {
            for (final p in batch) {
              if (p.hasDiscount && seen.add(p.id)) {
                discounted.add(p);
              }
            }
            page++;
          }
        } else {
          hasMore = false;
        }
      }

      if (mounted) {
        setState(() {
          _discountedProducts = discounted;
        });
        HomeContentCache.instance.saveTabProducts(discounted: discounted);
      }
      print('[DEBUG] Загружено ${discounted.length} товаров со скидкой');
    } catch (e) {
      print('[ERROR] Ошибка загрузки товаров со скидкой: $e');
    }
  }

  // Загрузка Flash Sale (для вкладки "Скидки")
  Future<void> _loadFlashSale() async {
    print('[DEBUG] Загрузка Flash Sale...');
    setState(() => _flashSaleLoading = true);
    try {
      final result = await _api.getFlashSale();
      if (result is Ok<List<FlashSale>>) {
        setState(() {
          _flashSales = result.value;
          _flashSaleLoading = false;
        });
        print('[DEBUG] Загружено ${_flashSales.length} flash sales');
      } else {
        print('[DEBUG] Ошибка загрузки Flash Sale: ${(result as Err).message}');
        setState(() => _flashSaleLoading = false);
      }
    } catch (e) {
      print('[ERROR] Ошибка загрузки Flash Sale: $e');
      setState(() => _flashSaleLoading = false);
    }
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      unawaited(UserPreferenceService.instance.recordSearch(query));
      context.go('/catalog/products?search=$query');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profileApi = ref.read(profileApiProvider);
      final result = await profileApi.getUserProfile();
      
      if (result is Ok) {
        setState(() {
          _profileData = (result as Ok).value;
        });
        print('[DEBUG] HomeScreen: Загружен профиль: ${_profileData?['name']}');
      } else {
        print('[DEBUG] HomeScreen: Ошибка загрузки профиля: ${result}');
      }
    } catch (e) {
      print('[DEBUG] HomeScreen: Ошибка загрузки профиля: $e');
    }
  }

  String _getDisplayName(user) {
    // Сначала пробуем имя из профиля (более полная информация)
    if (_profileData != null && _profileData!['name'] != null && _profileData!['name'].toString().isNotEmpty) {
      return _profileData!['name'].toString();
    }
    
    // Затем пробуем имя из authProvider
    if (user.name != null && user.name.isNotEmpty) {
      return user.name;
    }
    
    // Если нет имени, пробуем email (до символа @)
    if (user.email != null && user.email.isNotEmpty) {
      final emailParts = user.email.split('@');
      if (emailParts.isNotEmpty && emailParts[0].isNotEmpty) {
        return emailParts[0];
      }
    }
    
    // Если ничего нет, возвращаем "Пользователь"
    return 'Пользователь';
  }

  /// iPhone 15 и похожие экраны (~852pt) — компактнее отступы между блоками.
  bool _isCompactPhone(BuildContext context) {
    return MediaQuery.of(context).size.height < 900;
  }

  double _sectionBottomGap(BuildContext context) =>
      _isCompactPhone(context) ? 8.0 : 16.0;

  double _productsLoaderPadding(BuildContext context) =>
      _isCompactPhone(context) ? 12.0 : 32.0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final cart = ref.watch(cartProvider);
    
    // Отладочная информация
    print('[DEBUG] HomeScreen: user.name = "${user.name}"');
    print('[DEBUG] HomeScreen: user.isAuthenticated = ${user.isAuthenticated}');
    print('[DEBUG] HomeScreen: user.email = "${user.email}"');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: true,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF9C27B0),
        backgroundColor: Colors.white,
        strokeWidth: 2.0,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Современная шапка с персонализацией (на всю ширину, включая область камеры)
              _buildModernHeader(user, cart),
              
              // Остальной контент с отступами
              Padding(
                padding: EdgeInsets.only(
                  top: 20,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 100, // Отступ для нижней навигации
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Поисковая строка
                    _buildSearchSection(),
                    
                    // Промо баннер
                    _buildPromoBanner(),
                    
                    // Категории
                    _buildCategoriesSection(),
                    
                    // Вкладки с товарами
                    _buildTabsSection(),
                    
                    // Сетка товаров (для вкладки "Скидки" показываются блоки акций)
                    _buildProductsSection(),
                    
                    // Дополнительный отступ для безопасности
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // Современная шапка с персонализацией
  Widget _buildModernHeader(user, cart) {
    return Container(
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20, // Отступ для статус-бара + дополнительный отступ
          left: 20,
          right: 20,
          bottom: 30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Левая часть с аватаркой и приветствием
                Expanded(
                  child: Row(
                    children: [
                      // Аватарка пользователя (кликабельная)
                      GestureDetector(
                        onTap: () {
                          context.go('/profile');
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Текст приветствия
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Добро пожаловать,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getDisplayName(user)} 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Найдите то, что ищете',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Правая часть с кнопками
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Уведомления
                    _buildNotificationButton(),
                    const SizedBox(width: 12),
                    // Сообщения
                    _buildMessageButton(),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Кнопка уведомлений
  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        // Открываем экран со списком уведомлений
        context.push('/notifications');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.notifications_none,
              color: Colors.white,
              size: 22,
            ),
          ),
          // Индикатор уведомлений
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Кнопка WhatsApp
  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: () async {
        // Открываем WhatsApp с номером телефона
        const phoneNumber = '992990990955';
        final whatsappUrl = 'https://wa.me/$phoneNumber';
        
        try {
          final uri = Uri.parse(whatsappUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            // Если WhatsApp не установлен, пытаемся открыть через браузер
            final webUrl = 'https://web.whatsapp.com/send?phone=$phoneNumber';
            await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          print('[ERROR] Не удалось открыть WhatsApp: $e');
          // Показываем сообщение об ошибке
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось открыть WhatsApp'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              FontAwesomeIcons.whatsapp,
              color: Colors.white,
              size: 22,
            ),
          ),
          // Индикатор (можно убрать или оставить)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF25D366), // Цвет WhatsApp
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

                  // Поисковая строка
  Widget _buildSearchSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
        borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _performSearch(),
                          decoration: InputDecoration(
          hintText: 'Искать товары, бренды и магазины…',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9C27B0),
            size: 24,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 1,
                height: 24,
                color: Colors.grey[300],
              ),
              IconButton(
                icon: const Icon(
                  Icons.tune,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
                                    onPressed: () {
                  // TODO: Implement filters
                                    },
              ),
            ],
          ),
                            border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
                          ),
                        ),
                      ),
    );
  }

  /// Размеры баннера/слайдера с учётом плотности экрана (чёткие изображения на Retina).
  ({double width, double height, int cacheWidth, int cacheHeight}) _bannerImageLayout(
    BuildContext context, {
    double horizontalPadding = 32,
    double widthToHeight = 2, // 1000×500, как на сайте
  }) {
    final layoutWidth = MediaQuery.sizeOf(context).width - horizontalPadding;
    final layoutHeight = layoutWidth / widthToHeight;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (
      width: layoutWidth,
      height: layoutHeight,
      cacheWidth: (layoutWidth * dpr).round(),
      cacheHeight: (layoutHeight * dpr).round(),
    );
  }

  // Универсальный метод для отображения баннера с одинаковым размером
  Widget _buildStandardBanner(String imageUrl, {VoidCallback? onTap}) {
    final layout = _bannerImageLayout(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: layout.height,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: AppConfig.imageUrl(imageUrl),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            width: double.infinity,
            height: layout.height,
            memCacheHeight: layout.cacheHeight,
            memCacheWidth: layout.cacheWidth,
            placeholder: (context, url) => Container(
              width: double.infinity,
              height: layout.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.1),
                    const Color(0xFF9C27B0).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9C27B0),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: double.infinity,
              height: layout.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.1),
                    const Color(0xFF9C27B0).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.error,
                  color: Color(0xFF9C27B0),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Карусель баннеров 1000×500 (между секциями товаров, как на сайте)
  Widget _buildBannersCarousel(List<banner_model.Banner> banners) {
    if (banners.isEmpty) return const SizedBox.shrink();
    
    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 32.0; // 16px слева и справа
    final bannerWidth = screenWidth - padding;
    // Пропорции оригинала 1000×500 — без обрезки, как на вебе
    const mediumBannerAspectRatio = 1000 / 500;
    final bannerHeight = bannerWidth / mediumBannerAspectRatio;
    
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (bannerWidth * dpr).round();
    final cacheHeight = (bannerHeight * dpr).round();
    
    return Container(
      margin: EdgeInsets.zero, // Убираем отступ снизу баннера
      child: CarouselSlider.builder(
        itemCount: banners.length,
        itemBuilder: (context, index, realIndex) {
          final banner = banners[index];
          return GestureDetector(
            onTap: () {
              if (banner.url != null && banner.url!.isNotEmpty) {
                print('[DEBUG] Переход по ссылке баннера: ${banner.url}');
                // TODO: Реализовать переход по ссылке
              } else if (banner.slug != null && banner.slug!.isNotEmpty) {
                print('[DEBUG] Переход по slug баннера: ${banner.slug}');
                // TODO: Реализовать переход по slug
              }
            },
            child: Container(
              width: bannerWidth,
              height: bannerHeight,
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: AppConfig.imageUrl(banner.image),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  width: bannerWidth,
                  height: bannerHeight,
                  memCacheHeight: cacheHeight,
                  memCacheWidth: cacheWidth,
                  alignment: Alignment.center,
                  placeholder: (context, url) => Container(
                    width: bannerWidth,
                    height: bannerHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A1B9A).withOpacity(0.1),
                          const Color(0xFF9C27B0).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9C27B0),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: bannerWidth,
                    height: bannerHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A1B9A).withOpacity(0.1),
                          const Color(0xFF9C27B0).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.error,
                        color: Color(0xFF9C27B0),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        options: CarouselOptions(
          height: bannerHeight,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          autoPlayAnimationDuration: const Duration(milliseconds: 1000),
          autoPlayCurve: Curves.easeInOut,
          enlargeCenterPage: false,
          viewportFraction: 1.0,
        ),
      ),
    );
  }

  // Карусель брендов с баннером 1600x800 (как на сайте: слева бренды, справа баннер)
  Widget _buildBrandsAndBanner1600x800(List<Brand> brands, banner_model.Banner? banner1600x800) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 32.0; // Отступы слева и справа (16px * 2)
    final availableWidth = screenWidth - padding;
    
    // Левая часть (карусель брендов) - примерно 40% ширины
    final brandsWidth = availableWidth * 0.4;
    // Правая часть (баннер) - примерно 60% ширины
    final bannerWidth = availableWidth * 0.6;
    final bannerHeight = (bannerWidth * 800 / 1600); // Сохраняем пропорции 1600x800
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Карусель брендов слева
        if (brands.isNotEmpty)
          SizedBox(
            width: brandsWidth,
            child: _buildBrandsCarousel(brands),
          ),
        
        // Отступ между брендами и баннером
        const SizedBox(width: 12),
        
        // Баннер 1600x800 справа
        if (banner1600x800 != null)
          Expanded(
            child: _buildBanner1600x800(banner1600x800, bannerWidth, bannerHeight),
          ),
      ],
    );
  }

  // Карусель брендов
  Widget _buildBrandsCarousel(List<Brand> brands) {
    if (brands.isEmpty) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок "Featured Brands"
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured Brands',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Переход на страницу всех брендов
                  },
                  child: const Text(
                    'Show all',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9C27B0),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Карусель с логотипами брендов
          SizedBox(
            height: 200, // Высота карусели брендов
            child: CarouselSlider.builder(
              itemCount: brands.length,
              itemBuilder: (context, index, realIndex) {
                final brand = brands[index];
                return GestureDetector(
                  onTap: () {
                    if (brand.slug != null && brand.slug!.isNotEmpty) {
                      print('[DEBUG] Переход к бренду: ${brand.slug}');
                      // TODO: Реализовать переход к товарам бренда
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Логотип бренда
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          child: ClipOval(
                            child: brand.logo.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: AppConfig.imageUrl(brand.logo),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF9C27B0),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Center(
                                      child: Icon(
                                        Icons.business,
                                        color: Colors.grey[400],
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.business,
                                      color: Colors.grey[400],
                                      size: 32,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Название бренда
                        Text(
                          brand.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D3748),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: 200,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 3),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.easeInOut,
                enlargeCenterPage: false,
                viewportFraction: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Баннер 1600x800
  Widget _buildBanner1600x800(banner_model.Banner banner, double width, double height) {
    // Получаем размеры экрана для адаптивной вырезки (как в баннерах сверху)
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 32.0; // Отступы слева и справа (16px * 2)
    
    // Адаптивная ширина и высота на основе экрана
    final bannerWidth = width; // Используем переданную ширину (60% от доступной ширины)
    // Высота рассчитывается на основе пропорций 1600x800
    final bannerHeight = (bannerWidth * 800 / 1600);
    
    // Размеры кэша для адаптивной вырезки (как в других баннерах)
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (bannerWidth * dpr).round();
    final cacheHeight = (bannerHeight * dpr).round();
    
    return GestureDetector(
      onTap: () {
        if (banner.url != null && banner.url!.isNotEmpty) {
          print('[DEBUG] Переход по ссылке баннера 1600x800: ${banner.url}');
          // TODO: Реализовать переход по ссылке
        } else if (banner.slug != null && banner.slug!.isNotEmpty) {
          print('[DEBUG] Переход по slug баннера 1600x800: ${banner.slug}');
          // TODO: Реализовать переход по slug
        }
      },
      child: Container(
        width: bannerWidth,
        height: bannerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: AppConfig.imageUrl(banner.image),
            // BoxFit.cover для адаптивной вырезки под все устройства (как в баннерах сверху)
            fit: BoxFit.cover,
            width: bannerWidth,
            height: bannerHeight,
            // Адаптивные размеры кэша для разных устройств
            memCacheHeight: cacheHeight,
            memCacheWidth: cacheWidth,
            filterQuality: FilterQuality.high,
            alignment: Alignment.center, // Центрируем вырезку
            placeholder: (context, url) => Container(
              width: bannerWidth,
              height: bannerHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.1),
                    const Color(0xFF9C27B0).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9C27B0),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: bannerWidth,
              height: bannerHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A1B9A).withOpacity(0.1),
                    const Color(0xFF9C27B0).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.error,
                  color: Color(0xFF9C27B0),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Промо баннер (главный слайдер)
  Widget _buildPromoBanner() {
    if (_sliders.isEmpty) return const SizedBox.shrink();

    final layout = _bannerImageLayout(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: CarouselSlider.builder(
        itemCount: _sliders.length,
        itemBuilder: (context, index, realIndex) {
          final slider = _sliders[index];
          return GestureDetector(
            onTap: () {
              if (slider.link != null && slider.link!.isNotEmpty) {
                print('[DEBUG] Переход по ссылке слайдера: ${slider.link}');
                // TODO: Реализовать переход по ссылке
              }
            },
            child: Container(
              width: double.infinity,
              height: layout.height,
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: AppConfig.imageUrl(slider.image),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  width: double.infinity,
                  height: layout.height,
                  memCacheHeight: layout.cacheHeight,
                  memCacheWidth: layout.cacheWidth,
                  placeholder: (context, url) => Container(
                    width: double.infinity,
                    height: layout.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A1B9A).withOpacity(0.1),
                          const Color(0xFF9C27B0).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF9C27B0),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: layout.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A1B9A).withOpacity(0.1),
                          const Color(0xFF9C27B0).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.error,
                        color: Color(0xFF9C27B0),
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        options: CarouselOptions(
          height: layout.height,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          autoPlayAnimationDuration: const Duration(milliseconds: 1000),
          autoPlayCurve: Curves.easeInOut,
          enlargeCenterPage: false,
          viewportFraction: 1.0,
          onPageChanged: (index, reason) {
            setState(() {
              _currentSliderIndex = index;
            });
          },
        ),
      ),
    );
  }

  // Категории
  Widget _buildCategoriesSection() {
    // Используем бренды вместо категорий
    final compact = _isCompactPhone(context);
    final brandsHeight = compact ? 92.0 : 100.0;

    if (_brands.isEmpty) {
      // Если бренды не загружены, показываем placeholder
      return Container(
        height: brandsHeight,
        margin: EdgeInsets.only(bottom: _sectionBottomGap(context)),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF9C27B0),
          ),
        ),
      );
    }

    return Container(
      height: brandsHeight,
      margin: EdgeInsets.only(bottom: _sectionBottomGap(context)),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return GestureDetector(
            onTap: () {
              if (brand.slug != null && brand.slug!.isNotEmpty) {
                print('[DEBUG] Переход к бренду: ${brand.slug}');
                // TODO: Реализовать переход к товарам бренда
              }
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  // Логотип бренда
                  Container(
                    width: 50,
                    height: compact ? 46 : 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: brand.logo.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: CachedNetworkImage(
                                imageUrl: AppConfig.imageUrl(brand.logo),
                                fit: BoxFit.contain,
                                width: 50,
                                height: 50,
                                placeholder: (context, url) => Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFF9C27B0).withOpacity(0.5),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(
                                    Icons.business,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.business,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Название бренда
                  Text(
                    brand.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Секция Hot Deals
  Widget _buildHotDealsSection() {
    if (_flashSales.isEmpty) return const SizedBox.shrink();
    
    // Берем первый активный Flash Sale
    final activeFlashSale = _flashSales.firstWhere(
      (sale) => sale.status == 1,
      orElse: () => _flashSales.first,
    );
    
    if (activeFlashSale.products.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE91E63), // Розовый
                        Color(0xFFFF5722), // Оранжево-красный
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🔥 Hot Deals',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activeFlashSale.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Горизонтальная прокрутка товаров
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: activeFlashSale.products.length,
              itemBuilder: (context, index) {
                final flashProduct = activeFlashSale.products[index];
                return _buildFlashSaleProductCard(flashProduct);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Отображение блоков Flash Sale для вкладки "Скидки"
  Widget _buildFlashSalesBlocks() {
    print('[DEBUG] _buildFlashSalesBlocks: Всего Flash Sale: ${_flashSales.length}');
    for (var sale in _flashSales) {
      print('[DEBUG] Flash Sale: id=${sale.id}, title=${sale.title}, status=${sale.status}, products=${sale.products.length}');
    }
    
    // Фильтруем только активные акции (status == 1)
    final activeFlashSales = _flashSales.where((sale) => sale.status == 1).toList();
    print('[DEBUG] _buildFlashSalesBlocks: Активных Flash Sale: ${activeFlashSales.length}');
    
    if (activeFlashSales.isEmpty) {
      // Показываем все Flash Sale, если нет активных (для отладки)
      if (_flashSales.isNotEmpty) {
        print('[DEBUG] Нет активных Flash Sale, но есть неактивные. Показываем все для отладки.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _flashSales.map((flashSale) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildFlashSaleBlock(flashSale),
            );
          }).toList(),
        );
      }
      
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: Text(
            'Нет активных скидок',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF718096),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: activeFlashSales.map((flashSale) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildFlashSaleBlock(flashSale),
        );
      }).toList(),
    );
  }

  // Блок одной Flash Sale акции
  Widget _buildFlashSaleBlock(FlashSale flashSale) {
    if (flashSale.products.isEmpty) {
      return const SizedBox.shrink();
    }

    // Показываем первые 8 товаров в горизонтальной прокрутке
    final productsToShow = flashSale.products.take(8).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и таймер
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    flashSale.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                // Таймер обратного отсчета
                _buildCountdownTimer(flashSale.endTime),
              ],
            ),
          ),
          
          // Горизонтальная прокрутка товаров
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: productsToShow.length,
              itemBuilder: (context, index) {
                final flashProduct = productsToShow[index];
                return _buildFlashSaleProductCard(flashProduct);
              },
            ),
          ),
          
          // Кнопка "Показать все"
          if (flashSale.products.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    // Открываем веб-страницу Flash Sale в браузере
                    final url = Uri.parse('https://ssboss.shop/flash-sale/${flashSale.id}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Не удалось открыть страницу акции'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Показать все',
                    style: TextStyle(
                      color: Color(0xFF9C27B0),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Таймер обратного отсчета
  Widget _buildCountdownTimer(String endTime) {
    return _FlashSaleCountdownTimer(endTime: endTime);
  }

  // Карточка товара из Flash Sale
  Widget _buildFlashSaleProductCard(FlashSaleProduct flashProduct) {
    final product = flashProduct.productData;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32) * 0.45; // 45% ширины экрана минус отступы
    
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.push('/product/${product.id}', extra: product);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение товара
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: AppConfig.imageUrl(product.image),
                    width: cardWidth,
                    height: cardWidth * 0.8,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: cardWidth,
                      height: cardWidth * 0.8,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: cardWidth,
                      height: cardWidth * 0.8,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                  // Бейдж скидки
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFFF5722)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${((product.price - flashProduct.price) / product.price * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Бейдж товара
                  if (product.badge != null && product.badge!.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Цена (сразу после изображения)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flashProduct.price.toStringAsFixed(0)} с.',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                  if (product.price > flashProduct.price)
                    Text(
                      '${product.price.toStringAsFixed(0)} с.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ),
            
            // Информация о товаре
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Название товара
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Рейтинг
                    if (product.rating > 0)
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (product.reviewCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${product.reviewCount})',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вкладки с товарами
  Widget _buildTabsSection() {
    // Изменены названия: 'Популярное' → 'Новинки', 'Новинки' → 'Рекомендуемые'
    final tabs = ['Новинки', 'Скидки', 'Рекомендуемые', 'Тренды'];
    final compact = _isCompactPhone(context);
    
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 4 : _sectionBottomGap(context)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedTab == tab;
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  _onTabChanged(tab);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: compact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF9C27B0) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF9C27B0) : Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFF9C27B0).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ] : null,
                  ),
                  child: Text(
                    tab,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF2D3748),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Обработка переключения вкладок
  Future<void> _onTabChanged(String tab) async {
    if (_selectedTab == tab) return;

    final cache = HomeContentCache.instance;
    var needsNetwork = false;
    switch (tab) {
      case 'Новинки':
        needsNetwork = _newProducts.isEmpty;
        break;
      case 'Скидки':
        if (_discountedProducts.isEmpty && cache.discountedProducts.isNotEmpty) {
          _discountedProducts = List<Product>.from(cache.discountedProducts);
        }
        needsNetwork = _discountedProducts.isEmpty;
        break;
      case 'Рекомендуемые':
        if (_recommendedProducts.isEmpty && cache.recommendedProducts.isNotEmpty) {
          _recommendedProducts = List<Product>.from(cache.recommendedProducts);
        }
        needsNetwork = _recommendedProducts.isEmpty;
        break;
      case 'Тренды':
        if (_trendingProducts.isEmpty && cache.trendingProducts.isNotEmpty) {
          _trendingProducts = List<Product>.from(cache.trendingProducts);
        }
        needsNetwork = _trendingProducts.isEmpty;
        break;
    }

    setState(() {
      _selectedTab = tab;
      _tabLoading = needsNetwork;
    });

    if (!needsNetwork) return;

    try {
      switch (tab) {
        case 'Новинки':
          if (_newProducts.isEmpty) {
            await _loadNewProducts();
          }
          break;
        case 'Скидки':
          await _loadDiscountedProducts();
          break;
        case 'Рекомендуемые':
          await _loadRecommendedProducts();
          break;
        case 'Тренды':
          await _loadTrendingProducts();
          break;
      }
    } catch (e) {
      print('[DEBUG] Ошибка загрузки данных для вкладки $tab: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _tabLoading = false;
        });
      }
    }
  }

  // Секция товаров
  Widget _buildProductsSection() {
    final loaderPadding = _productsLoaderPadding(context);

    // Показываем индикатор загрузки при переключении вкладок
    if (_tabLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: loaderPadding),
          child: const CircularProgressIndicator(
            color: Color(0xFF9C27B0),
          ),
        ),
      );
    }

    // Получаем список товаров в зависимости от выбранной вкладки
    List<Product> productsToShow = [];
    switch (_selectedTab) {
      case 'Новинки':
        productsToShow = _newProducts;
        break;
      case 'Скидки':
        productsToShow = _discountedProducts;
        break;
      case 'Рекомендуемые':
        productsToShow = _recommendedProducts;
        break;
      case 'Тренды':
        productsToShow = _trendingProducts;
        break;
      default:
        productsToShow = _newProducts;
    }

    final screenWidth = MediaQuery.of(context).size.width;

    int crossAxisCount = 2;
    if (screenWidth > 600) {
      crossAxisCount = 3;
    }

    if (_loading && productsToShow.isEmpty && !HomeContentCache.instance.hasData) {
      final skeletonCount = crossAxisCount * 4;
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: ProductGridCard.gridChildAspectRatio,
          crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
          mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
        ),
        itemCount: skeletonCount,
        itemBuilder: (context, index) => const ProductGridCardSkeleton(),
      );
    }

    if (productsToShow.isEmpty) {
      final emptyMessage = switch (_selectedTab) {
        'Скидки' => 'Нет товаров со скидкой',
        'Тренды' => 'Нет трендовых товаров',
        'Рекомендуемые' => 'Нет рекомендуемых товаров',
        _ => 'Товары не найдены',
      };
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: loaderPadding),
          child: Text(
            emptyMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF718096),
            ),
          ),
        ),
      );
    }

    // Получаем баннеры размером 1000x500 (средние баннеры) для вставки между сетками
    final mediumBanners = _homePageData?.mediumBanners ?? [];
    final bannersForInsertion = mediumBanners.take(3).toList(); // Берем первые 3 баннера
    
    // Получаем баннер 1600x800 (type == 4) и бренды для вставки между 16-й и 17-й строкой (32 товара = 16 строк)
    final allBanners = _homePageData?.banners ?? [];
    final banner1600x800 = allBanners.where((b) => b.type == 4).firstOrNull;
    final brands = _homePageData?.brands ?? [];
    
    print('[DEBUG] Баннер 1600x800: ${banner1600x800 != null ? "найден (type: ${banner1600x800!.type}, title: ${banner1600x800!.title})" : "не найден"}');
    print('[DEBUG] Всего баннеров: ${allBanners.length}, типы: ${allBanners.map((b) => b.type).toList()}');

    // Разделяем товары на части:
    // - Первые 16 товаров (8 сеток по 2 товара) - до первых баннеров 1000x500
    // - Следующие 16 товаров (8 сеток) - до баннера 1600x800 с брендами (между 16-й и 17-й строкой)
    // - Остальные товары после баннера 1600x800
    final productsBeforeSmallBanners = productsToShow.take(16).toList(); // Первые 16 товаров (8 строк)
    final productsBeforeLargeBanner = productsToShow.skip(16).take(16).toList(); // Следующие 16 товаров (8 строк) - всего 32 товара = 16 строк
    final productsAfterLargeBanner = productsToShow.skip(32).toList(); // Остальные товары после 32-го товара (16 строк)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Первые 16 товаров (8 сеток по 2 товара)
        if (productsBeforeSmallBanners.isNotEmpty)
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: ProductGridCard.gridChildAspectRatio,
              crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
              mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
            ),
            itemCount: productsBeforeSmallBanners.length,
            itemBuilder: (context, index) {
              final product = productsBeforeSmallBanners[index];
              return ProductGridCard(
                product: product,
                onAddToCart: _showAttributeSelectionBottomSheet,
              );
            },
          ),
        
        // Баннеры между восьмой и девятой сеткой (карусель)
        if (bannersForInsertion.isNotEmpty) ...[
          const SizedBox(height: 12), // Уменьшили отступ сверху
          _buildBannersCarousel(bannersForInsertion),
          const SizedBox(height: 12), // Уменьшили отступ снизу
        ],
        
        // Следующие 32 товара (16 строк) - перед баннером 1600x800
        if (productsBeforeLargeBanner.isNotEmpty)
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: ProductGridCard.gridChildAspectRatio,
              crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
              mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
            ),
            itemCount: productsBeforeLargeBanner.length,
            itemBuilder: (context, index) {
              final product = productsBeforeLargeBanner[index];
              return ProductGridCard(
                product: product,
                onAddToCart: _showAttributeSelectionBottomSheet,
              );
            },
          ),
        
        // Баннер 1600x800 с каруселью брендов между 16-й и 17-й строкой (после 32 товаров)
        if (banner1600x800 != null || brands.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildBrandsAndBanner1600x800(brands, banner1600x800),
          const SizedBox(height: 12),
        ],
        
        // Остальные товары (после баннера 1600x800)
        if (productsAfterLargeBanner.isNotEmpty)
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: ProductGridCard.gridChildAspectRatio,
              crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
              mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
            ),
            itemCount: productsAfterLargeBanner.length,
            itemBuilder: (context, index) {
              final product = productsAfterLargeBanner[index];
              return ProductGridCard(
                product: product,
                onAddToCart: _showAttributeSelectionBottomSheet,
              );
            },
          ),

        if (_selectedTab == 'Новинки' && _newProductsLoadingMore)
          Padding(
            padding: EdgeInsets.symmetric(vertical: loaderPadding),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
            ),
          ),
      ],
    );
  }

  // Оптимизированная карточка товара (старая версия)
  Widget _buildOptimizedProductCard(Product product) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ключевое изменение!
          children: [
            // Изображение товара
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF9C27B0).withOpacity(0.1),
                          const Color(0xFFE1BEE7).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: CachedNetworkImage(
                        imageUrl: AppConfig.imageUrl(product.image),
                        fit: BoxFit.cover,
                        memCacheHeight: 120,
                        memCacheWidth: 120,
                        maxHeightDiskCache: 120,
                        maxWidthDiskCache: 120,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF9C27B0),
                            strokeWidth: 1.5,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.image,
                            color: Color(0xFF9C27B0),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Бейдж
                  if (product.badge != null && product.badge!.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: product.badge == 'New' 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // Кнопка избранного
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: Color(0xFF9C27B0),
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Цена (сразу после изображения)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                '${product.price.toStringAsFixed(0)} с.',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9C27B0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Информация о товаре
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                        height: 1.0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber[600],
                          size: 8,
                        ),
                        const SizedBox(width: 1),
                        Text(
                          '${product.rating}',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Color(0xFF718096),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Text(
                          '(${product.reviewCount})',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Современная карточка товара (устаревшая версия)
  Widget _buildModernProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Изображение товара
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF9C27B0).withOpacity(0.1),
                        const Color(0xFFE1BEE7).withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: AppConfig.imageUrl(product.image),
                      fit: BoxFit.cover,
                      memCacheHeight: 300, // Ограничиваем размер в памяти
                      memCacheWidth: 300,
                      maxHeightDiskCache: 300,
                      maxWidthDiskCache: 300,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.image,
                          color: Color(0xFF9C27B0),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                // Бейдж
                if (product.badge != null && product.badge!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.badge == 'New' 
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE91E63),
                        borderRadius: BorderRadius.circular(12),
                      ),
                          child: Text(
                            product.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                  ),
                // Кнопка избранного
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFF9C27B0),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Цена (сразу после изображения)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              '${product.price.toStringAsFixed(0)} с.',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9C27B0),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Информация о товаре
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                    height: 1.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Colors.amber[600],
                      size: 9,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${product.rating}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '(${product.reviewCount})',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Современное нижнее меню
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
            Expanded(child: _buildNavItem(Icons.home, Icons.home, 'Главная', 0, true)),
            Expanded(child: _buildNavItem(Icons.grid_view_outlined, Icons.grid_view, 'Каталог', 1, false)),
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

  // Метод для правильного склонения слова "оценка"
  String _getReviewCountText(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'оценка';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'оценки';
    } else {
      return 'оценок';
    }
  }
}

class _SlidersWidget extends StatelessWidget {
  final List<SliderItem> sliders;
  
  const _SlidersWidget({required this.sliders});

  @override
  Widget build(BuildContext context) {
    if (sliders.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 180,
          viewportFraction: 1.0,
          autoPlay: true,
          autoPlayInterval: const Duration(seconds: 4),
          enlargeCenterPage: false,
        ),
        items: sliders.map((slider) => _SliderItem(slider: slider)).toList(),
      ),
    );
  }
}

class _SliderItem extends StatelessWidget {
  final SliderItem slider;
  
  const _SliderItem({required this.slider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (slider.link != null && slider.link!.isNotEmpty) {
          // Здесь можно добавить логику перехода по ссылке
          print('[DEBUG] Переход по ссылке слайдера: ${slider.link}');
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: AppConfig.imageUrl(slider.image),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: backgroundColor,
              child: const Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: backgroundColor,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: textSecondary,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Виджет таймера обратного отсчета для Flash Sale
class _FlashSaleCountdownTimer extends StatefulWidget {
  final String endTime;

  const _FlashSaleCountdownTimer({required this.endTime});

  @override
  State<_FlashSaleCountdownTimer> createState() => _FlashSaleCountdownTimerState();
}

class _FlashSaleCountdownTimerState extends State<_FlashSaleCountdownTimer> {
  Duration _remaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    try {
      // Парсим дату окончания (формат: "2026-12-21 03:32:00")
      final endDate = DateTime.parse(widget.endTime.replaceAll(' ', 'T'));
      final now = DateTime.now();
      
      if (endDate.isAfter(now)) {
        _remaining = endDate.difference(now);
      } else {
        _remaining = Duration.zero;
      }
    } catch (e) {
      print('[ERROR] Ошибка парсинга даты окончания: $e');
      _remaining = Duration.zero;
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return '${days.toString().padLeft(2, '0')}:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative || _remaining == Duration.zero) {
      return const Text(
        'Акция завершена',
        style: TextStyle(
          fontSize: 12,
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9C27B0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _formatDuration(_remaining),
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9C27B0),
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.8)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              icon,
              color: Colors.white,
              size: 64,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories = [
    {'name': 'Женщинам', 'icon': Icons.woman, 'color': accentColor},
    {'name': 'Мужчинам', 'icon': Icons.man, 'color': primaryColor},
    {'name': 'Детям', 'icon': Icons.child_care, 'color': secondaryColor},
    {'name': 'Обувь', 'icon': Icons.shopping_bag, 'color': Colors.orange},
    {'name': 'Аксессуары', 'icon': Icons.watch, 'color': Colors.purple},
    {'name': 'Красота', 'icon': Icons.face, 'color': Colors.pink},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return InkWell(
          onTap: () => context.go('/catalog'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (category['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: category['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category['name'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom sheet для выбора атрибутов товара
class _AttributeSelectionBottomSheet extends StatefulWidget {
  final Product product;
  final Function(Map<int, int>) onAddToCart;

  const _AttributeSelectionBottomSheet({
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<_AttributeSelectionBottomSheet> createState() => _AttributeSelectionBottomSheetState();
}

class _AttributeSelectionBottomSheetState extends State<_AttributeSelectionBottomSheet> {
  final Map<int, int> _selectedAttributes = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.6; // Максимальная высота - 60% экрана
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Индикатор перетаскивания
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          // Список атрибутов
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: widget.product.attributes.map((attr) {
                    final selectedValueId = _selectedAttributes[attr.id];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attr.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: attr.values.map((v) {
                            final isSelected = selectedValueId == v.attributeValueId;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAttributes[attr.id] = v.attributeValueId;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor.withOpacity(0.15)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  v.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),
                ),
              ),
              
              // Кнопка добавления в корзину
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          // Проверяем, что все атрибуты выбраны
                          final missingAttributes = widget.product.attributes.where(
                            (attr) => !_selectedAttributes.containsKey(attr.id) || 
                                     _selectedAttributes[attr.id] == null ||
                                     _selectedAttributes[attr.id]! <= 0,
                          ).toList();
                          
                          if (missingAttributes.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Пожалуйста, выберите ${missingAttributes.map((a) => a.title.toLowerCase()).join(', ')}',
                                ),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          
                          // Добавляем в корзину
                          widget.onAddToCart(_selectedAttributes);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Добавить в корзину',
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
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product p;
  const _ProductCard({required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/product/${p.id}', extra: p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение товара с кнопкой корзины внутри
            AspectRatio(
              aspectRatio: 1.0, // Квадратное изображение
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: p.image.isEmpty
                        ? Container(
                            color: backgroundColor,
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                color: textSecondary,
                                size: 32,
                              ),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: AppConfig.imageUrl(p.image),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Container(
                              color: backgroundColor,
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  color: textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: backgroundColor,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: textSecondary,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Бейдж товара
                  if (p.badge != null && p.badge!.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Кнопка корзины внутри изображения (стиль Wildberries)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: CartBadge(
                      productId: p.id,
                      child: Container(
                        decoration: BoxDecoration(
                          color: primaryColor, // #8813BA
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            // Всегда проверяем наличие атрибутов через загрузку деталей товара
                            await _showAttributeSelectionBottomSheet(context, ref, p);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Цена (сразу после изображения)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${p.price.toStringAsFixed(0)} с.',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            // Информация о товаре
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название товара
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Рейтинг
                    if (p.rating > 0)
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < p.rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 12,
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            '(${p.reviewCount})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ], 
                ), 
              ), 
            ), 
          ], 
        ), 
      ), 
    ); 
  } 
}

// Виджет кнопки избранного
class _FavoriteButton extends ConsumerStatefulWidget {
  final Product product;
  
  const _FavoriteButton({required this.product});
  
  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _isFavorite = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // Можно загрузить начальное состояние избранного при необходимости
    // Для простоты используем локальное состояние
  }
  
  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final favoritesApi = ref.read(favoritesApiProvider);
      
      // Переключаем статус избранного
      if (_isFavorite) {
        final result = await favoritesApi.removeFromFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = false;
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.product.name} удален из избранного'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      } else {
        final result = await favoritesApi.addToFavorites(widget.product.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = true;
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.product.name} добавлен в избранное'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleFavorite,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.black87,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
