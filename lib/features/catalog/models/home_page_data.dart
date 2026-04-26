import 'banner.dart';
import 'slider.dart';
import 'brand.dart';

class HomePageData {
  final List<SliderItem> mainSliders; // slider.main
  final List<Banner> banners; // Все баннеры (исключая 400x400)
  final List<Brand> brands; // Бренды для карусели
  
  // Исключаем right_top и right_bottom (400x400)
  // они не добавляются в эту структуру

  const HomePageData({
    required this.mainSliders,
    required this.banners,
    required this.brands,
  });

  factory HomePageData.fromJson(Map<String, dynamic> json) {
    // Парсим главный слайдер
    final sliderData = json['slider'] as Map<String, dynamic>? ?? {};
    final mainSlidersList = sliderData['main'] as List<dynamic>? ?? [];
    final mainSliders = mainSlidersList
        .where((item) => item is Map<String, dynamic>)
        .map((item) => SliderItem.fromJson(item as Map<String, dynamic>))
        .where((slider) => slider.isActive && slider.image.isNotEmpty)
        .toList();

    // Парсим баннеры (исключаем right_top и right_bottom)
    final bannersList = json['banners'] as List<dynamic>? ?? [];
    final banners = bannersList
        .where((item) => item is Map<String, dynamic>)
        .map((item) => Banner.fromJson(item as Map<String, dynamic>))
        .where((banner) => banner.isActive && banner.image.isNotEmpty)
        .toList();

    // Парсим бренды
    final brandsList = json['brands'] as List<dynamic>? ?? [];
    final brands = brandsList
        .where((item) => item is Map<String, dynamic>)
        .map((item) => Brand.fromJson(item as Map<String, dynamic>))
        .where((brand) => brand.isActive && brand.logo.isNotEmpty)
        .toList();

    return HomePageData(
      mainSliders: mainSliders,
      banners: banners,
      brands: brands,
    );
  }

  // Геттеры для фильтрации баннеров по размеру
  List<Banner> get mediumBanners => banners
      .where((banner) => banner.size == BannerSize.medium)
      .toList();

  Banner? get banner1600x800 {
    try {
      return banners.firstWhere(
        (banner) => banner.size == BannerSize.large1600x800,
      );
    } catch (e) {
      try {
        return banners.firstWhere((banner) => banner.type == 4);
      } catch (e) {
        return null;
      }
    }
  }

  Banner? get banner2000x300 {
    try {
      return banners.firstWhere(
        (banner) => banner.size == BannerSize.large2000x300,
      );
    } catch (e) {
      try {
        return banners.firstWhere((banner) => banner.type == 5);
      } catch (e) {
        return null;
      }
    }
  }

  Banner? get banner2000x250 {
    try {
      return banners.firstWhere(
        (banner) => banner.size == BannerSize.bottom2000x250,
      );
    } catch (e) {
      try {
        return banners.firstWhere(
          (banner) => banner.type == 8 || banner.type == 9,
        );
      } catch (e) {
        return null;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'mainSliders': mainSliders.map((s) => s.toJson()).toList(),
      'banners': banners.map((b) => b.toJson()).toList(),
      'brands': brands.map((b) => b.toJson()).toList(),
    };
  }
}

