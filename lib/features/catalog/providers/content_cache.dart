import '../models/brand.dart';
import '../models/flash_sale.dart';
import '../models/home_page_data.dart';
import '../models/product.dart';
import '../models/slider.dart';

/// In-memory cache so main tabs do not refetch and show skeletons on every visit.
class HomeContentCache {
  HomeContentCache._();
  static final HomeContentCache instance = HomeContentCache._();

  List<Product> newProducts = const [];
  List<Product> recommendedProducts = const [];
  List<Product> trendingProducts = const [];
  List<Product> discountedProducts = const [];
  List<SliderItem> sliders = const [];
  HomePageData? homePageData;
  List<Brand> brands = const [];
  List<FlashSale> flashSales = const [];
  DateTime? loadedAt;

  bool get hasData => newProducts.isNotEmpty || sliders.isNotEmpty;

  bool get isStale {
    if (loadedAt == null) return true;
    return DateTime.now().difference(loadedAt!) > const Duration(minutes: 10);
  }

  void save({
    required List<Product> newProducts,
    required List<SliderItem> sliders,
    HomePageData? homePageData,
    required List<Brand> brands,
    required List<FlashSale> flashSales,
  }) {
    this.newProducts = newProducts;
    this.sliders = sliders;
    this.homePageData = homePageData;
    this.brands = brands;
    this.flashSales = flashSales;
    loadedAt = DateTime.now();
  }

  void saveTabProducts({
    List<Product>? recommended,
    List<Product>? trending,
    List<Product>? discounted,
  }) {
    if (recommended != null) recommendedProducts = recommended;
    if (trending != null) trendingProducts = trending;
    if (discounted != null) discountedProducts = discounted;
  }
}

class CatalogCategoriesCache {
  CatalogCategoriesCache._();
  static final CatalogCategoriesCache instance = CatalogCategoriesCache._();

  List<Map<String, dynamic>> categories = const [];
  DateTime? loadedAt;

  bool get hasData => categories.isNotEmpty && !_looksBroken(categories);

  bool get isStale {
    if (loadedAt == null) return true;
    if (_looksBroken(categories)) return true;
    return DateTime.now().difference(loadedAt!) > const Duration(minutes: 30);
  }

  static bool _looksBroken(List<Map<String, dynamic>> list) {
    if (list.isEmpty) return false;
    final placeholders = {'', 'категория', 'category'};
    final broken = list.where((c) {
      final name = (c['name'] ?? c['title'] ?? '').toString().trim().toLowerCase();
      return placeholders.contains(name);
    }).length;
    return broken >= (list.length / 2).ceil();
  }

  void save(List<Map<String, dynamic>> value) {
    categories = value;
    loadedAt = DateTime.now();
  }

  void clear() {
    categories = const [];
    loadedAt = null;
  }
}
