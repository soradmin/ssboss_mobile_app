import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/banner.dart' as promo;
import '../models/slider.dart';

/// Навигация с баннеров / слайдеров (source_type + url/slug).
///
/// Константы сервера: CATEGORY=1, SUB_CATEGORY=2, TAG=3, BRAND=4, PRODUCT=5, URL=6.
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

    if ((source == 1 || source == 2) && slug != null && slug.isNotEmpty) {
      final q = <String, String>{
        'category': slug,
        if (title.isNotEmpty) 'title': title,
      };
      context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
      return;
    }

    if (await _tryOpenInternalOrExternal(context, url)) return;
    if (await _tryOpenInternalOrExternal(context, slug)) return;

    // Fallback: отфильтрованный список товаров по banner id.
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
    }

    if (source == 1 || source == 2) {
      if (link != null && link.isNotEmpty && !link.startsWith('http')) {
        final q = <String, String>{
          'category': link,
          if (title.isNotEmpty) 'title': title,
        };
        context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
        return;
      }
    }

    if (await _tryOpenInternalOrExternal(context, link)) return;

    if (slider.id > 0) {
      final q = <String, String>{
        'home_spm': '${slider.id}',
        if (title.isNotEmpty) 'title': title,
      };
      context.push(Uri(path: '/catalog/products', queryParameters: q).toString());
    }
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
