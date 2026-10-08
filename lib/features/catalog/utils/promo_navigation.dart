import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banner.dart' as promo;
import '../models/slider.dart';

/// Навигация с баннеров / слайдеров (source_type + url/slug).
///
/// Константы сервера: CATEGORY=1, SUB_CATEGORY=2, TAG=3, BRAND=4, PRODUCT=5, URL=6.
///
/// Важно: у HomeSlider поле `slug`/`url` — это название промо, а не slug категории.
/// Категории/бренды/товары лежат в source_* и на сайте открываются через `home_spm`.
class PromoNavigation {
  PromoNavigation._();

  static Future<void> openBanner(BuildContext context, promo.Banner banner) async {
    final title = banner.title.trim();
    final source = banner.sourceType;
    final slug = banner.slug?.trim();
    final url = banner.url?.trim();

    if (source == 5 && slug != null && slug.isNotEmpty) {
      final id = int.tryParse(slug);
      if (id != null && id > 0) {
        context.push('/product/$id');
        return;
      }
    }

    if (source == 4 && slug != null && slug.isNotEmpty) {
      final brandId = int.tryParse(slug);
      if (brandId != null && brandId > 0) {
        final q = <String, String>{
          'brand': '$brandId',
          if (title.isNotEmpty) 'brand_title': title,
        };
        context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
        return;
      }
    }

    // Категория: slug баннера часто = title промо. Надёжнее фильтр `banner`.
    if ((source == 1 || source == 2 || source == 3) && banner.id > 0) {
      final q = <String, String>{
        'banner': '${banner.id}',
        if (title.isNotEmpty) 'title': title,
      };
      context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
      return;
    }

    if (await _tryOpenInternalOrExternal(context, url)) return;
    if (await _tryOpenInternalOrExternal(context, slug)) return;

    if (banner.id > 0) {
      final q = <String, String>{
        'banner': '${banner.id}',
        if (title.isNotEmpty) 'title': title,
      };
      context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
    }
  }

  static Future<void> openSlider(BuildContext context, SliderItem slider) async {
    final title = slider.title.trim();
    final source = slider.sourceType;
    final link = slider.link?.trim();

    if (source == 5) {
      final id = int.tryParse(link ?? '') ??
          int.tryParse(RegExp(r'/product[s]?/(\d+)').firstMatch(link ?? '')?.group(1) ?? '');
      if (id != null && id > 0) {
        context.push('/product/$id');
        return;
      }
      // PRODUCT без явного id — список товаров слайдера (source_products).
      if (slider.id > 0) {
        _openSliderProducts(context, slider.id, title);
        return;
      }
    }

    if (source == 4) {
      final brandId = int.tryParse(link ?? '');
      if (brandId != null && brandId > 0) {
        final q = <String, String>{
          'brand': '$brandId',
          if (title.isNotEmpty) 'brand_title': title,
        };
        context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
        return;
      }
      if (slider.id > 0) {
        _openSliderProducts(context, slider.id, title);
        return;
      }
    }

    // CATEGORY / SUB_CATEGORY / TAG — как на сайте: /products?home_spm={id}
    // Нельзя подставлять slider.slug как category (это title промо).
    if (source == 1 || source == 2 || source == 3) {
      if (slider.id > 0) {
        _openSliderProducts(context, slider.id, title);
        return;
      }
    }

    if (await _tryOpenInternalOrExternal(context, link)) return;

    if (slider.id > 0) {
      _openSliderProducts(context, slider.id, title);
    }
  }

  static void _openSliderProducts(BuildContext context, int sliderId, String title) {
    final q = <String, String>{
      'home_spm': '$sliderId',
      if (title.isNotEmpty) 'title': title,
    };
    context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
  }

  static Future<bool> _tryOpenInternalOrExternal(
    BuildContext context,
    String? raw,
  ) async {
    if (raw == null || raw.isEmpty) return false;
    final value = raw.trim();

    final productMatch = RegExp(r'/product[s]?/(\d+)').firstMatch(value);
    if (productMatch != null) {
      context.push('/product/${productMatch.group(1)}');
      return true;
    }

    final categoryMatch =
        RegExp(r'/(?:all|category|categories)/([^/?#]+)').firstMatch(value);
    if (categoryMatch != null) {
      context.push(
        Uri(
          path: '/catalog/products',
          queryParameters: {'category': Uri.decodeComponent(categoryMatch.group(1)!)},
        ).toString(),
      );
      return true;
    }

    final brandMatch = RegExp(r'/brand[s]?/(\d+)').firstMatch(value);
    if (brandMatch != null) {
      context.push(
        Uri(
          path: '/catalog/products',
          queryParameters: {'brand': brandMatch.group(1)!},
        ).toString(),
      );
      return true;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      final uri = Uri.tryParse(value);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    }

    return false;
  }
}
