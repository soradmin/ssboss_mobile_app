import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../catalog/models/product.dart';

enum PreferenceAction {
  view,
  search,
  categoryBrowse,
  cartAdd,
  favorite,
}

class PreferenceEvent {
  final PreferenceAction action;
  final int? productId;
  final String? productName;
  final String? categorySlug;
  final String? sellerSlug;
  final String? searchQuery;
  final DateTime at;

  const PreferenceEvent({
    required this.action,
    this.productId,
    this.productName,
    this.categorySlug,
    this.sellerSlug,
    this.searchQuery,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'productId': productId,
        'productName': productName,
        'categorySlug': categorySlug,
        'sellerSlug': sellerSlug,
        'searchQuery': searchQuery,
        'at': at.toIso8601String(),
      };

  factory PreferenceEvent.fromJson(Map<String, dynamic> json) {
    return PreferenceEvent(
      action: PreferenceAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => PreferenceAction.view,
      ),
      productId: json['productId'] as int?,
      productName: json['productName'] as String?,
      categorySlug: json['categorySlug'] as String?,
      sellerSlug: json['sellerSlug'] as String?,
      searchQuery: json['searchQuery'] as String?,
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PreferenceProfile {
  final List<PreferenceEvent> events;

  const PreferenceProfile(this.events);

  bool get hasEnoughData => events.length >= 3;

  int get actionCount => events.length;
}

class UserPreferenceService {
  UserPreferenceService._();
  static final UserPreferenceService instance = UserPreferenceService._();

  static const _storagePrefix = 'user_preferences_v1_';
  static const _maxEvents = 250;

  static const _stopWords = {
    'для',
    'или',
    'при',
    'без',
    'под',
    'над',
    'the',
    'and',
    'for',
  };

  Future<String> resolveUserKey() async {
    await AppConfig.ensureAuthTokensLoaded();
    final token = AppConfig.getActiveBearerToken();
    if (token.isNotEmpty) {
      return 'auth_${token.hashCode}';
    }
    final guest = AppConfig.guestToken;
    return guest.isNotEmpty ? 'guest_$guest' : 'guest_anonymous';
  }

  Future<void> recordView(Product product) {
    return _append(
      PreferenceEvent(
        action: PreferenceAction.view,
        productId: product.id,
        productName: product.name,
        sellerSlug: product.storeSlug,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> recordSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return Future.value();
    return _append(
      PreferenceEvent(
        action: PreferenceAction.search,
        searchQuery: trimmed,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> recordCategoryBrowse({
    required String categorySlug,
    String? categoryTitle,
  }) {
    if (categorySlug.trim().isEmpty) return Future.value();
    return _append(
      PreferenceEvent(
        action: PreferenceAction.categoryBrowse,
        categorySlug: categorySlug.trim(),
        searchQuery: categoryTitle?.trim(),
        at: DateTime.now(),
      ),
    );
  }

  Future<void> recordCartAdd(Product product) {
    return _append(
      PreferenceEvent(
        action: PreferenceAction.cartAdd,
        productId: product.id,
        productName: product.name,
        sellerSlug: product.storeSlug,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> recordFavorite(Product product) {
    return _append(
      PreferenceEvent(
        action: PreferenceAction.favorite,
        productId: product.id,
        productName: product.name,
        sellerSlug: product.storeSlug,
        at: DateTime.now(),
      ),
    );
  }

  Future<PreferenceProfile> loadProfile() async {
    final key = await resolveUserKey();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$key');
    if (raw == null || raw.isEmpty) {
      return const PreferenceProfile([]);
    }
    try {
      final list = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => PreferenceEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return PreferenceProfile(list);
    } catch (_) {
      return const PreferenceProfile([]);
    }
  }

  Future<void> _append(PreferenceEvent event) async {
    final key = await resolveUserKey();
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_storagePrefix$key';

    List<PreferenceEvent> events = [];
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        events = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => PreferenceEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        events = [];
      }
    }

    events.insert(0, event);
    if (events.length > _maxEvents) {
      events = events.take(_maxEvents).toList();
    }

    await prefs.setString(
      storageKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  static List<String> extractKeywords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\d\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
  }

  static double _eventWeight(PreferenceEvent event) {
    final base = switch (event.action) {
      PreferenceAction.view => 2.0,
      PreferenceAction.search => 3.0,
      PreferenceAction.categoryBrowse => 4.0,
      PreferenceAction.cartAdd => 6.0,
      PreferenceAction.favorite => 5.0,
    };
    final days = DateTime.now().difference(event.at).inDays;
    final decay = days <= 7
        ? 1.0
        : days <= 30
            ? 0.75
            : 0.45;
    return base * decay;
  }

  static double scoreProduct(Product product, PreferenceProfile profile) {
    if (!profile.hasEnoughData) return 0;

    final nameLower = product.name.toLowerCase();
    var score = 0.0;

    for (final event in profile.events) {
      final weight = _eventWeight(event);

      if (event.productId != null && event.productId == product.id) {
        score += weight * 2.5;
      }

      if (event.sellerSlug != null &&
          event.sellerSlug!.isNotEmpty &&
          product.storeSlug != null &&
          product.storeSlug == event.sellerSlug) {
        score += weight * 0.6;
      }

      final query = event.searchQuery;
      if (query != null && query.isNotEmpty) {
        for (final kw in extractKeywords(query)) {
          if (nameLower.contains(kw)) {
            score += weight * 0.9;
          }
        }
      }

      final viewedName = event.productName;
      if (viewedName != null && viewedName.isNotEmpty) {
        for (final kw in extractKeywords(viewedName)) {
          if (nameLower.contains(kw)) {
            score += weight * 0.35;
          }
        }
      }

      final categorySlug = event.categorySlug;
      if (categorySlug != null && categorySlug.isNotEmpty) {
        for (final part in categorySlug.split(RegExp(r'[-_]'))) {
          if (part.length >= 4 && nameLower.contains(part)) {
            score += weight * 0.45;
          }
        }
      }
    }

    return score;
  }

  /// Сортирует товары: сначала релевантные интересам, остальные — в исходном порядке.
  static List<Product> personalizeProducts(
    List<Product> products,
    PreferenceProfile profile,
  ) {
    if (!profile.hasEnoughData || products.length < 2) {
      return products;
    }

    final scored = products
        .map((p) => (product: p, score: scoreProduct(p, profile)))
        .toList();

    final hasSignal = scored.any((e) => e.score > 0);
    if (!hasSignal) return products;

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.product.id.compareTo(b.product.id);
    });

    return scored.map((e) => e.product).toList();
  }
}
