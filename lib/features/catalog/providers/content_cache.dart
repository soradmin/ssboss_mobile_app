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

  bool get hasData => categories.isNotEmpty;

  bool get isStale {
    if (loadedAt == null) return true;
    return DateTime.now().difference(loadedAt!) > const Duration(minutes: 30);
  }

  void save(List<Map<String, dynamic>> value) {
    categories = value;
    loadedAt = DateTime.now();
  }
}
