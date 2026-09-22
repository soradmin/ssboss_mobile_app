import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:video_player/video_player.dart'; 
import 'package:chewie/chewie.dart';
import 'package:carousel_slider/carousel_controller.dart' as cs;
import '../../../core/date_formatter.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../cart/models/cart_item.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../../../core/config.dart';
import '../repo/catalog_api.dart';
import '../../../core/result.dart';
import '../models/media.dart';
import '../widgets/product_price_row.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/product_detail_mono.dart';
import '../widgets/product_image_gallery_viewer.dart';
import '../../favorites/repo/favorites_api.dart';
import '../../stores/repo/store_api.dart';
import '../../stores/models/store.dart';
import '../../personalization/user_preference_service.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product p;
  const ProductDetailsScreen({super.key, required this.p});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  late cs.CarouselSliderController _carouselController;
  int _current = 0;
  final List<ChewieController?> _chewieControllers = [];
  late List<ProductImage> _images;
  late List<ProductVideo> _videos;
  Product? _currentProduct; // Локальная переменная для обновленного товара
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  Store? _store;
  bool _descriptionExpanded = false;
  List<Review> _reviews = [];
  // Храним выбранные значения атрибутов: ключ - id атрибута, значение - id выбранного значения
  final Map<int, int> _selectedAttributes = {};
  // Рекомендуемые товары и товары "смотрели также"
  List<Product> _recommendedProducts = [];
  List<Product> _alsoViewedProducts = [];
  bool _recommendedLoading = false;
  bool _alsoViewedLoading = false;
  // Активная вкладка: true = "Смотрите также", false = "Покупают вместе"
  bool _activeTabIsRecommended = true;

  @override
  void initState() {
    _carouselController = cs.CarouselSliderController();
    _images = _seedImages(widget.p);
    _videos = List<ProductVideo>.from(widget.p.videos);
    _chewieControllers.addAll(List.generate(_videos.length, (_) => null));
    _applyDefaultAttributeSelections(widget.p);
    unawaited(_loadDetails());
    unawaited(_loadStoreFollowStatus(widget.p));
    unawaited(UserPreferenceService.instance.recordView(widget.p));
    super.initState();
  }

  /// Сразу показываем фото из карточки каталога — без пустого shimmer и без скачка.
  List<ProductImage> _seedImages(Product p) {
    if (p.images.isNotEmpty) {
      return List<ProductImage>.from(p.images);
    }
    if (p.image.isNotEmpty) {
      return [ProductImage(image: p.image, thumb: p.image)];
    }
    return const [];
  }

  @override
  void dispose() {
    // Освобождаем ресурсы видео
    for (var controller in _chewieControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_isLoadingFavorite) return;
    
    setState(() {
      _isLoadingFavorite = true;
    });
    
    try {
      final favoritesApi = ref.read(favoritesApiProvider);
      
      if (_isFavorite) {
        final result = await favoritesApi.removeFromFavorites(widget.p.id);
        result.when(
          ok: (_) {
            setState(() {
              _isFavorite = false;
              _isLoadingFavorite = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.p.name} удален из избранного'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoadingFavorite = false;
            });
            if (mounted) _showFavoriteError(error);
          },
        );
      } else {
        final result = await favoritesApi.addToFavorites(widget.p.id);
        result.when(
          ok: (_) {
            unawaited(
              UserPreferenceService.instance.recordFavorite(
                _currentProduct ?? widget.p,
              ),
            );
            setState(() {
              _isFavorite = true;
              _isLoadingFavorite = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.p.name} добавлен в избранное'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
          err: (error) {
            setState(() {
              _isLoadingFavorite = false;
            });
            if (mounted) _showFavoriteError(error);
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingFavorite = false;
      });
      if (mounted) _showFavoriteError('$e');
    }
  }

  bool _isAuthFavoriteError(String error) {
    final e = error.toLowerCase();
    return error == FavoritesApi.needAuth ||
        e.contains('401') ||
        e.contains('unauthorized') ||
        e.contains('unauthenticated') ||
        !AppConfig.hasActiveToken();
  }

  void _showFavoriteError(String error) {
    final needAuth = _isAuthFavoriteError(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          needAuth
              ? context.tr('favorites.login_required')
              : context.tr('common.error'),
        ),
        backgroundColor: needAuth ? const Color(0xFF8813BA) : Colors.red,
        duration: const Duration(seconds: 3),
        action: needAuth
            ? SnackBarAction(
                label: context.tr('auth.login'),
                textColor: Colors.white,
                onPressed: () => context.push('/login'),
              )
            : null,
      ),
    );
  }

  String? _resolveStoreSlug(Product product) {
    String? slug = product.storeSlug;
    if (slug == null || slug.isEmpty) {
      final name = product.sellerName?.trim() ?? '';
      if (name.isEmpty) return null;
      slug = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'[\s_-]+'), '-')
          .trim();
    }
    if (slug.isEmpty) return null;
    return slug;
  }

  Future<void> _loadStoreFollowStatus(Product product) async {
    final slug = _resolveStoreSlug(product);
    if (slug == null) return;

    final result = await ref.read(storeApiProvider).getStoreBySlug(slug);
    if (!mounted) return;
    result.when(
      ok: (store) {
        setState(() {
          _store = store;
        });
      },
      err: (_) {},
    );
  }

  Future<void> _shareProduct() async {
    try {
      final product = _currentProduct ?? widget.p;
      final productUrl = 'https://ssboss.shop/product/${product.id}';
      final shareText = '${product.name}\n${product.price.toStringAsFixed(2)} с.\n\n$productUrl';
      
      await Share.share(
        shareText,
        subject: product.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при попытке поделиться: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadDetails() async {
    final api = CatalogApi();
    final res = await api.productById(widget.p.id);
    if (!mounted) return;

    if (res is Ok<Product>) {
      final full = res.value;
      setState(() {
        // Мягко обновляем галерею: не мигаем, если первое фото то же.
        if (full.images.isNotEmpty) {
          _images = full.images;
        }
        _videos = full.videos;
        _chewieControllers
          ..clear()
          ..addAll(List.generate(_videos.length, (_) => null));

        _currentProduct = full.copyWith(
          name: full.name.isNotEmpty ? full.name : widget.p.name,
          image: full.image.isNotEmpty ? full.image : widget.p.image,
          price: full.price > 0 ? full.price : widget.p.price,
          oldPrice: full.oldPrice ?? widget.p.oldPrice,
          rating: full.rating > 0 ? full.rating : widget.p.rating,
          reviewCount:
              full.reviewCount > 0 ? full.reviewCount : widget.p.reviewCount,
          badge: full.badge ?? widget.p.badge,
          sellerName: full.sellerName ?? widget.p.sellerName,
          sellerRating: full.sellerRating ?? widget.p.sellerRating,
          storeSlug: full.storeSlug ?? widget.p.storeSlug,
          sellerLogo: full.sellerLogo ?? widget.p.sellerLogo,
          description: (full.description != null &&
                  full.description!.trim().isNotEmpty)
              ? full.description
              : widget.p.description,
          descriptionImages: full.descriptionImages.isNotEmpty
              ? full.descriptionImages
              : widget.p.descriptionImages,
        );
        _applyDefaultAttributeSelections(_currentProduct!);
      });
      unawaited(_loadStoreFollowStatus(_currentProduct!));
    }

    // Параллельно: отзывы + рекомендации (не блокируют первый кадр).
    unawaited(_loadReviews());
    unawaited(_loadRecommendedProducts());
  }

  // Загрузка рекомендуемых товаров
  Future<void> _loadRecommendedProducts() async {
    setState(() {
      _recommendedLoading = true;
    });

    final catalogApi = CatalogApi();
    final result = await catalogApi.getRecommendedProducts(widget.p.id);

    result.when(
      ok: (products) {
        if (mounted) {
          setState(() {
            _recommendedProducts = products;
            _recommendedLoading = false;
          });
        }
      },
      err: (error) {
        print('[DEBUG] Ошибка загрузки рекомендуемых товаров: $error');
        if (mounted) {
          setState(() {
            _recommendedLoading = false;
          });
        }
      },
    );
  }

  // Загрузка товаров "смотрели также"
  Future<void> _loadAlsoViewedProducts() async {
    setState(() {
      _alsoViewedLoading = true;
    });

    final catalogApi = CatalogApi();
    final result = await catalogApi.getAlsoViewedProducts(widget.p.id);

    result.when(
      ok: (products) {
        if (mounted) {
          setState(() {
            _alsoViewedProducts = products;
            _alsoViewedLoading = false;
          });
        }
      },
      err: (error) {
        print('[DEBUG] Ошибка загрузки товаров "смотрели также": $error');
        if (mounted) {
          setState(() {
            _alsoViewedLoading = false;
          });
        }
      },
    );
  }

  Future<void> _loadReviews() async {
    final result = await CatalogApi().getProductReviews(widget.p.id);
    if (!mounted) return;
    result.when(
      ok: (reviews) {
        setState(() => _reviews = reviews);
      },
      err: (_) {},
    );
  }

  // Функция для создания ChewieController
  /// Как на вебе: ищем фото с максимальным совпадением выбранных attribute_value_id.
  int? _findBestMatchingImageIndex(List<int> selectedValueIds) {
    if (selectedValueIds.isEmpty || _images.isEmpty) return null;

    int? bestIndex;
    var bestScore = -1;
    for (var i = 0; i < _images.length; i++) {
      final linkedIds = _images[i].attributeValueIds;
      if (linkedIds.isEmpty) continue;

      var score = 0;
      for (final id in selectedValueIds) {
        if (linkedIds.contains(id)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _switchToVariantImage() {
    final selectedIds = _selectedAttributes.values.where((id) => id > 0).toList();
    final imageIndex = _findBestMatchingImageIndex(selectedIds);
    if (imageIndex == null || imageIndex < 0 || imageIndex >= _images.length) {
      return;
    }

    setState(() => _current = imageIndex);
    if (_images.length + _videos.length > 1) {
      _carouselController.animateToPage(
        imageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onAttributeValueSelected(int attributeId, int attributeValueId) {
    setState(() {
      _selectedAttributes[attributeId] = attributeValueId;
    });
    _switchToVariantImage();
  }

  void _applyDefaultAttributeSelections(Product product) {
    if (product.attributes.isEmpty) return;

    var changed = false;
    for (final attr in product.attributes) {
      if (_selectedAttributes.containsKey(attr.id)) continue;
      if (attr.values.isEmpty) continue;
      _selectedAttributes[attr.id] = attr.values.first.attributeValueId;
      changed = true;
    }

    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _switchToVariantImage();
      });
    }
  }

  Future<void> _initializeVideoPlayer(int index) async {
    if (_chewieControllers[index] != null) return; // Уже инициализирован

    final videoUrl = AppConfig.imageUrl(widget.p.videos[index].video);
    final videoPlayerController = VideoPlayerController.network(videoUrl);

    await videoPlayerController.initialize();

    final chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: false,
      looping: true,
      aspectRatio: videoPlayerController.value.aspectRatio,
      // Добавьте другие настройки по желанию
    );

    setState(() {
      _chewieControllers[index] = chewieController;
    });
  }

  List<ProductAttribute> _missingAttributes(Product product) {
    final missing = <ProductAttribute>[];
    for (final attr in product.attributes) {
      final selected = _selectedAttributes[attr.id];
      if (selected == null || selected <= 0) missing.add(attr);
    }
    return missing;
  }

  bool _ensureAttributesSelected(Product product) {
    final missing = _missingAttributes(product);
    if (missing.isEmpty) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'product.select_please',
            namedArgs: {
              'name': missing.map((a) => a.title.toLowerCase()).join(', '),
            },
          ),
        ),
        backgroundColor: ProductDetailMono.onyx,
        duration: const Duration(seconds: 2),
      ),
    );
    return false;
  }

  void _addProductToCart({required bool goToCart}) {
    final product = _currentProduct ?? widget.p;
    if (!_ensureAttributesSelected(product)) return;

    ref.read(cartProvider.notifier).addToCart(
          widget.p,
          1,
          selectedAttributes: _selectedAttributes,
        );
    ref.read(cartProvider.notifier).addToCartWithSync(
          widget.p,
          1,
          selectedAttributes: _selectedAttributes,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('home.added_to_cart'))),
    );
    if (goToCart) context.go('/cart');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    final product = _currentProduct ?? widget.p;
    final List<Widget> mediaItems = [];
    final List<Widget> thumbnailItems = [];
    final screenW = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final heroCacheW = (screenW * dpr).round().clamp(480, 1400);
    final heroCacheH = (heroCacheW * 5 / 4).round();
    final seedUrl = widget.p.image.isNotEmpty
        ? AppConfig.imageUrl(widget.p.image)
        : '';

    final List<String> galleryImageUrls = _images
        .map((img) => AppConfig.imageUrl(img.image))
        .where((url) => url.isNotEmpty)
        .toList();
    if (galleryImageUrls.isEmpty && seedUrl.isNotEmpty) {
      galleryImageUrls.add(seedUrl);
    }

    void openGalleryAt(int imageIndex) {
      ProductImageGalleryViewer.open(
        context,
        imageUrls: galleryImageUrls,
        initialIndex: imageIndex,
      );
    }

    Widget heroImage(String url, {String? placeholderUrl}) {
      final ph = (placeholderUrl != null &&
              placeholderUrl.isNotEmpty &&
              placeholderUrl != url)
          ? placeholderUrl
          : seedUrl;
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        memCacheWidth: heroCacheW,
        memCacheHeight: heroCacheH,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (context, _) {
          if (ph.isNotEmpty) {
            return CachedNetworkImage(
              imageUrl: ph,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: heroCacheW,
              memCacheHeight: heroCacheH,
              errorWidget: (_, __, ___) => const ColoredBox(
                color: ProductDetailMono.heroBg,
              ),
            );
          }
          return const ColoredBox(color: ProductDetailMono.heroBg);
        },
        errorWidget: (context, url, error) => const ColoredBox(
          color: ProductDetailMono.heroBg,
          child: Center(child: Icon(Icons.image_not_supported_outlined)),
        ),
      );
    }

    // Добавляем изображения
    for (int i = 0; i < _images.length; i++) {
      final img = _images[i];
      final fullImageUrl = AppConfig.imageUrl(img.image);
      final thumbUrl = (img.thumb.isNotEmpty)
          ? AppConfig.imageUrl(img.thumb)
          : fullImageUrl;

      mediaItems.add(
        GestureDetector(
          onTap: () => openGalleryAt(i),
          child: ColoredBox(
            color: ProductDetailMono.heroBg,
            child: heroImage(fullImageUrl, placeholderUrl: thumbUrl),
          ),
        ),
      );

      // Миниатюры для индикатора
      thumbnailItems.add(
        GestureDetector(
          onTap: () => _carouselController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.linear),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _current == i ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                memCacheWidth: 120,
                memCacheHeight: 120,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Container(color: Colors.grey[300]),
              ),
            ),
          ),
        ),
      );
    }

    // Добавляем видео (с миниатюрой). Видео инициализируем по клику, без прелоада
    for (int i = 0; i < _videos.length; i++) {
      final vid = _videos[i];
      final videoIndex = i + _images.length; // Индекс видео в общем списке

      mediaItems.add(
        GestureDetector(
          onTap: () async {
            await _initializeVideoPlayer(i);
            if (mounted) setState(() {});
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _chewieControllers[i] != null
                ? Chewie(controller: _chewieControllers[i]!)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      if ((vid.thumb ?? '').isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: AppConfig.imageUrl(vid.thumb!),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.black12),
                          errorWidget: (context, url, error) => Container(color: Colors.black12),
                        )
                      else
                        Container(color: Colors.black26),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
          ),
        ),
      );

      // Миниатюра для видео
      thumbnailItems.add(
        GestureDetector(
          onTap: () => _carouselController.animateToPage(videoIndex, duration: const Duration(milliseconds: 300), curve: Curves.linear),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _current == videoIndex ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if ((vid.thumb ?? '').isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: AppConfig.imageUrl(vid.thumb!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.black12),
                      errorWidget: (context, url, error) => Container(color: Colors.black12),
                    )
                  else
                    Container(color: Colors.black26),
                  const Icon(Icons.play_circle_fill, color: Colors.white70, size: 30),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Если нет дополнительных медиа, отображаем старое основное изображение
    if (mediaItems.isEmpty) {
      mediaItems.add(
        GestureDetector(
          onTap: galleryImageUrls.isEmpty ? null : () => openGalleryAt(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.p.image.isEmpty
                ? const ColoredBox(
                    color: Color(0x11000000),
                    child: Center(child: Icon(Icons.image_not_supported_outlined)),
                  )
                : heroImage(AppConfig.imageUrl(widget.p.image)),
          ),
        ),
      );
    }

    final topPad = MediaQuery.paddingOf(context).top;
    final productTag = () {
      final badge = product.badge?.trim();
      if (badge != null && badge.isNotEmpty) return badge.toUpperCase();
      return 'SSBOSS';
    }();
    final priceText = '${product.price.toStringAsFixed(0)} с.';

    return Scaffold(
      backgroundColor: ProductDetailMono.white,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // —— Hero 4:5 ——
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ColoredBox(
                  color: ProductDetailMono.heroBg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (mediaItems.isEmpty)
                        const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: ProductDetailMono.platinum,
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return CarouselSlider(
                              carouselController: _carouselController,
                              items: mediaItems,
                              options: CarouselOptions(
                                height: constraints.maxHeight,
                                enlargeCenterPage: false,
                                enableInfiniteScroll: mediaItems.length > 1,
                                viewportFraction: 1.0,
                                padEnds: false,
                                autoPlay: false,
                                onPageChanged: (index, reason) {
                                  setState(() => _current = index);
                                },
                              ),
                            );
                          },
                        ),
                      if (mediaItems.length > 1)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 32,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(mediaItems.length, (i) {
                              final active = _current == i;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: ProductDetailMono.curve,
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active
                                      ? ProductDetailMono.onyx
                                      : const Color(0xFFD1D5DB),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // —— Header: tag + title | price + rating ——
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(productTag, style: ProductDetailMono.tag()),
                          const SizedBox(height: 10),
                          Text(
                            product.name,
                            style: ProductDetailMono.h1(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(priceText, style: ProductDetailMono.price()),
                        if (ProductPriceRow.shouldShowOldPrice(
                          product.oldPrice,
                          product.price,
                        )) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${product.oldPrice!.toStringAsFixed(0)} с.',
                            style: ProductPriceRow.oldPriceTextStyle(13),
                          ),
                        ],
                        if (product.rating > 0 || product.reviewCount > 0) ...[
                          const SizedBox(height: 8),
                          HapticScale(
                            onTap: () => _showReviewsModal(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: ProductDetailMono.star,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  product.rating > 0
                                      ? product.rating.toStringAsFixed(1)
                                      : '0',
                                  style: ProductDetailMono.label(
                                    ProductDetailMono.onyx,
                                  ),
                                ),
                                if (product.reviewCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${product.reviewCount})',
                                    style: ProductDetailMono.label(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // —— Variant selector ——
              if (product.attributes.isNotEmpty) ...[
                const SizedBox(height: 28),
                ...product.attributes.map((attr) {
                  final selectedValueId = _selectedAttributes[attr.id];
                  final attrLabel = attr.title.trim().isNotEmpty
                      ? attr.title.trim()
                      : context.tr('product.variant');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          attrLabel.toUpperCase(),
                          style: ProductDetailMono.tag(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: attr.values.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final v = attr.values[index];
                            final valueLabel = v.title.trim().isNotEmpty
                                ? v.title.trim()
                                : '${index + 1}';
                            final isSelected =
                                selectedValueId == v.attributeValueId;
                            // «Варианты / 1» → в тексте только «вариант», цифра уже в кружке
                            final isNumericValue =
                                RegExp(r'^\d+$').hasMatch(valueLabel);
                            final isVariantAttr = RegExp(
                              r'вариант',
                              caseSensitive: false,
                            ).hasMatch(attrLabel);
                            final cardLabel = isVariantAttr
                                ? context.tr('product.variant').toLowerCase()
                                : attrLabel;
                            final showValueText =
                                !isNumericValue || !isVariantAttr;
                            final circleText = valueLabel.length <= 3
                                ? valueLabel
                                : valueLabel.substring(0, 1);
                            return HapticScale(
                              onTap: () => _onAttributeValueSelected(
                                attr.id,
                                v.attributeValueId,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: ProductDetailMono.curve,
                                constraints: const BoxConstraints(minWidth: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? ProductDetailMono.ghost
                                      : ProductDetailMono.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? ProductDetailMono.brand
                                        : ProductDetailMono.platinum,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? ProductDetailMono.brand
                                                .withValues(alpha: 0.12)
                                            : ProductDetailMono.platinum
                                                .withValues(alpha: 0.7),
                                        border: Border.all(
                                          color: isSelected
                                              ? ProductDetailMono.brand
                                              : ProductDetailMono.platinum,
                                        ),
                                      ),
                                      child: Text(
                                        circleText,
                                        style: ProductDetailMono.body(
                                          isSelected
                                              ? ProductDetailMono.brand
                                              : ProductDetailMono.onyx,
                                        ).copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cardLabel,
                                          style: ProductDetailMono.body(
                                            ProductDetailMono.onyx,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (showValueText) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            valueLabel,
                                            style: ProductDetailMono.tag(
                                              ProductDetailMono.slate,
                                            ).copyWith(fontSize: 10),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: ProductDetailMono.brand,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),
              ],

              // —— Description ——
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _buildProductAboutPreview(context, product),
              ),

              // —— Seller ——
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSellerRow(context, product),
              ),

              // —— Ratings ——
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildRatingsBlock(context, product),
              ),

              // —— See also / Bought together ——
              const SizedBox(height: 24),
              _buildRecommendedAndAlsoViewedSection(),
              const SizedBox(height: 120),
            ],
          ),

          // —— Floating glass nav ——
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                GlassCircleButton(
                  icon: Icons.ios_share_rounded,
                  onTap: _shareProduct,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              border: const Border(
                top: BorderSide(color: ProductDetailMono.platinum, width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Consumer(
                  builder: (context, ref, _) {
                    final cartItems = ref.watch(cartProvider);
                    final cartItem = cartItems.firstWhere(
                      (item) => item.product.id == widget.p.id,
                      orElse: () => CartItem(product: widget.p, qty: 0),
                    );
                    final isInCart = cartItem.qty > 0;
                    final ctaLabel = isInCart
                        ? context.tr(
                            'product.in_cart',
                            namedArgs: {'qty': '${cartItem.qty}'},
                          )
                        : '${context.tr('product.add_to_cart')}  ·  $priceText';

                    return Row(
                      children: [
                        GlassCircleButton(
                          size: 56,
                          icon: _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: _isFavorite
                              ? const Color(0xFFDC2626)
                              : ProductDetailMono.onyx,
                          onTap: _isLoadingFavorite ? null : _toggleFavorite,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HapticScale(
                            onTap: () {
                              if (isInCart) {
                                context.go('/cart');
                              } else {
                                _addProductToCart(goToCart: false);
                              }
                            },
                            child: Container(
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF8813BA),
                                    Color(0xFFB02FE0),
                                    Color(0xFFE040FB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: ProductDetailMono.brand
                                        .withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                ctaLabel,
                                style: ProductDetailMono.cta(),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  String _plainText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildProductAboutPreview(BuildContext context, Product product) {
    final preview = _plainText(product.description);
    final previewStyle = ProductDetailMono.body(const Color(0xFF4B5563));
    final hasImages = product.descriptionImages.isNotEmpty;
    final collapsed = !_descriptionExpanded && preview.length > 220;
    final shown = collapsed ? '${preview.substring(0, 220).trim()}…' : preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty)
          Text(shown, style: previewStyle),
        if (hasImages && _descriptionExpanded) ...[
          const SizedBox(height: 12),
          ...product.descriptionImages.take(4).map(
                (url) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
        ],
        if (preview.isNotEmpty || hasImages)
          HapticScale(
            onTap: () {
              if (preview.length > 220 || hasImages) {
                setState(() => _descriptionExpanded = !_descriptionExpanded);
              } else {
                _showProductInfoModal(context);
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _descriptionExpanded
                        ? context.tr('product.show_less')
                        : context.tr('product.show_more'),
                    style: ProductDetailMono.body(ProductDetailMono.brand)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Icon(
                    _descriptionExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ProductDetailMono.brand,
                    size: 20,
                  ),
                ],
              ),
            ),
          )
        else
          HapticScale(
            onTap: () => _showProductInfoModal(context),
            child: Text(
              context.tr('product.about'),
              style: ProductDetailMono.body(ProductDetailMono.onyx).copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  void _openSellerStore(BuildContext context, Product product) {
    final slug = _resolveStoreSlug(product);
    if (slug != null && slug.isNotEmpty) {
      context.push('/store/$slug');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Информация о магазине недоступна'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  bool _isUnknownStoreName(String? name) {
    if (name == null) return true;
    final t = name.trim();
    if (t.isEmpty) return true;
    final l = t.toLowerCase();
    return l == 'неизвестный магазин' || l == 'unknown store';
  }

  String _displayStoreName(Product product) {
    if (!_isUnknownStoreName(_store?.name)) return _store!.name.trim();
    if (!_isUnknownStoreName(product.sellerName)) {
      return product.sellerName!.trim();
    }
    return 'SSBOSS';
  }

  Widget _buildSellerRow(BuildContext context, Product product) {
    final name = _displayStoreName(product);
    final rating = _store != null && _store!.rating > 0
        ? _store!.rating
        : (product.sellerRating ?? 0);
    final rawLogo = _store?.logo ?? product.sellerLogo;
    final logoUrl = (rawLogo != null && rawLogo.isNotEmpty)
        ? (rawLogo.startsWith('http') ? rawLogo : AppConfig.imageUrl(rawLogo))
        : '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openSellerStore(context, product),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ProductDetailMono.platinum),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF3E8FF),
                backgroundImage:
                    logoUrl.isNotEmpty ? CachedNetworkImageProvider(logoUrl) : null,
                child: logoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: const TextStyle(
                          color: Color(0xFF8813BA),
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProductDetailMono.body(ProductDetailMono.onyx)
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('product.verified_seller'),
                      style: ProductDetailMono.label(),
                    ),
                  ],
                ),
              ),
              if (rating > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFF5B400)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: ProductDetailMono.label(ProductDetailMono.onyx)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsBlock(BuildContext context, Product product) {
    final rating = product.rating > 0
        ? product.rating
        : (_reviews.isEmpty
            ? 0.0
            : _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                _reviews.length);
    final count = product.reviewCount > 0 ? product.reviewCount : _reviews.length;
    final preview = _reviews.isNotEmpty ? _reviews.first : null;
    final filled = rating.round().clamp(0, 5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProductDetailMono.platinum),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : '—',
                style: ProductDetailMono.h1().copyWith(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < filled
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 18,
                          color: const Color(0xFFF5B400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count ${context.tr('product.ratings_and_reviews')}',
                      style: ProductDetailMono.label(),
                    ),
                  ],
                ),
              ),
              HapticScale(
                onTap: () => _showReviewsModal(context),
                child: Text(
                  context.tr('product.all_reviews'),
                  style: ProductDetailMono.body(ProductDetailMono.brand)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFF3E8FF),
                  child: Text(
                    (preview.userName ?? 'U').isNotEmpty
                        ? (preview.userName ?? 'U')[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Color(0xFF8813BA),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.userName ?? context.tr('product.reviews'),
                        style: ProductDetailMono.body(ProductDetailMono.onyx)
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < preview.rating.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 14,
                            color: const Color(0xFFF5B400),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (preview.comment != null && preview.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                preview.comment!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: ProductDetailMono.body(const Color(0xFF4B5563)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Показать модальное окно с информацией о товаре
  void _showProductInfoModal(BuildContext context) {
    final product = _currentProduct ?? widget.p;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductInfoModal(
        product: product,
        messenger: messenger,
      ),
    );
  }

  // Показать модальное окно с отзывами
  void _showReviewsModal(BuildContext context) {
    final product = _currentProduct ?? widget.p;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReviewsModal(productId: product.id),
    );
  }

  Widget _buildRecommendedAndAlsoViewedSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  title: context.tr('product.see_also'),
                  isActive: _activeTabIsRecommended,
                  onTap: () {
                    setState(() {
                      _activeTabIsRecommended = true;
                    });
                    if (_recommendedProducts.isEmpty && !_recommendedLoading) {
                      _loadRecommendedProducts();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTabButton(
                  title: context.tr('product.bought_together'),
                  isActive: !_activeTabIsRecommended,
                  onTap: () {
                    setState(() {
                      _activeTabIsRecommended = false;
                    });
                    if (_alsoViewedProducts.isEmpty && !_alsoViewedLoading) {
                      _loadAlsoViewedProducts();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_activeTabIsRecommended)
          _buildProductHorizontalList(
            products: _recommendedProducts,
            isLoading: _recommendedLoading,
          )
        else
          _buildProductHorizontalList(
            products: _alsoViewedProducts,
            isLoading: _alsoViewedLoading,
          ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return HapticScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: ProductDetailMono.curve,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? ProductDetailMono.ghost : ProductDetailMono.white,
          border: Border.all(
            color: isActive
                ? ProductDetailMono.onyx
                : ProductDetailMono.platinum,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: ProductDetailMono.body(
            isActive ? ProductDetailMono.onyx : ProductDetailMono.slate,
          ).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildProductHorizontalList({
    required List<Product> products,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Нет товаров',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: ProductGridCard.gridMainAxisSpacing,
          crossAxisSpacing: ProductGridCard.gridCrossAxisSpacing,
          childAspectRatio: ProductGridCard.gridChildAspectRatio,
        ),
        itemBuilder: (context, index) {
          return ProductGridCard(product: products[index]);
        },
      ),
    );
  }
}

// Модальное окно с информацией о товаре
class _ProductInfoModal extends ConsumerStatefulWidget {
  final Product product;
  final ScaffoldMessengerState messenger;

  const _ProductInfoModal({
    required this.product,
    required this.messenger,
  });

  @override
  ConsumerState<_ProductInfoModal> createState() => _ProductInfoModalState();
}

class _ProductInfoModalState extends ConsumerState<_ProductInfoModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Заголовок и кнопка закрытия
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('product.about'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Вкладки
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF8813BA),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.zero,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[700],
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              tabs: [
                Tab(text: context.tr('product.specs')),
                Tab(text: context.tr('product.description')),
              ],
            ),
          ),
          // Содержимое вкладок
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Вкладка "Характеристики"
                _buildCharacteristicsTab(),
                // Вкладка "Описание"
                _buildDescriptionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicsTab() {
    final product = widget.product;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Основные
        const Text(
          'Основные',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        if (product.id > 0)
          _buildCharacteristicRow(
            context.tr('product.sku'),
            product.id.toString(),
            showCopy: true,
          ),
        const SizedBox(height: 16),
        
        // Основная информация
        const Text(
          'Основная информация',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        if (product.description != null && product.description!.isNotEmpty)
          _buildCharacteristicRow('Состав', _extractComposition(product.description!)),
        if (product.name.toLowerCase().contains('белый') || 
            product.name.toLowerCase().contains('черный') ||
            product.name.toLowerCase().contains('красный') ||
            product.name.toLowerCase().contains('синий'))
          _buildCharacteristicRow('Цвет', _extractColors(product.name)),
        const SizedBox(height: 16),
        
        // Дополнительная информация
        const Text(
          'Дополнительная информация',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        if (product.price > 0)
          _buildCharacteristicRow(context.tr('product.price'), '${product.price.toStringAsFixed(2)} ${context.tr('common.currency')}'),
        if (product.sellerName != null && product.sellerName!.isNotEmpty)
          _buildCharacteristicRow(context.tr('product.seller'), product.sellerName!),
      ],
    );
  }

  Widget _buildDescriptionTab() {
    final product = widget.product;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (product.description != null && product.description!.isNotEmpty) ...[
          Text(
            product.description!
                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                .replaceAll(RegExp(r'&nbsp;'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim(),
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Изображения описания
        if (product.descriptionImages.isNotEmpty) ...[
          ...product.descriptionImages.map((imageUrl) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              )),
        ],
        if (product.description == null || product.description!.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.tr('product.no_description'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCharacteristicRow(String label, String value, {bool showCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8813BA),
                    ),
                  ),
                ),
                if (showCopy)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Color(0xFF8813BA)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      widget.messenger.showSnackBar(
                        SnackBar(
                          content: Text(context.tr('product.sku_copied')),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _extractComposition(String description) {
    // Попытка извлечь информацию о составе из описания
    final lowerDesc = description.toLowerCase();
    if (lowerDesc.contains('хлопок')) return 'хлопок';
    if (lowerDesc.contains('полиэстер')) return 'полиэстер';
    if (lowerDesc.contains('шерсть')) return 'шерсть';
    return context.tr('common.not_specified');
  }

  String _extractColors(String name) {
    // Попытка извлечь цвета из названия
    final colors = <String>[];
    if (name.toLowerCase().contains('белый') || name.toLowerCase().contains('white')) colors.add('белый');
    if (name.toLowerCase().contains('черный') || name.toLowerCase().contains('black')) colors.add('черный');
    if (name.toLowerCase().contains('красный') || name.toLowerCase().contains('red')) colors.add('красный');
    if (name.toLowerCase().contains('синий') || name.toLowerCase().contains('blue')) colors.add('синий');
    if (name.toLowerCase().contains('фиолетовый') || name.toLowerCase().contains('purple')) colors.add('фиолетовый');
    return colors.isEmpty ? context.tr('common.not_specified') : colors.join('; ');
  }
}

// Модальное окно с отзывами
class _ReviewsModal extends ConsumerStatefulWidget {
  final int productId;

  const _ReviewsModal({required this.productId});

  @override
  ConsumerState<_ReviewsModal> createState() => _ReviewsModalState();
}

class _ReviewsModalState extends ConsumerState<_ReviewsModal> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    print('[DEBUG] ========== _ReviewsModal._loadReviews: НАЧАЛО ==========');
    print('[DEBUG] _ReviewsModal._loadReviews: Загружаем отзывы для товара ${widget.productId}');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catalogApi = CatalogApi();
      print('[DEBUG] _ReviewsModal._loadReviews: CatalogApi создан, вызываем getProductReviews(${widget.productId})');
      
      final result = await catalogApi.getProductReviews(widget.productId);
      
      print('[DEBUG] _ReviewsModal._loadReviews: getProductReviews вернул результат');

      result.when(
        ok: (reviews) {
          print('[DEBUG] ========== _ReviewsModal._loadReviews: УСПЕХ ==========');
          print('[DEBUG] _ReviewsModal._loadReviews: Получено ${reviews.length} отзывов');
          if (reviews.isNotEmpty) {
            print('[DEBUG] _ReviewsModal._loadReviews: Первый отзыв: id=${reviews.first.id}, productId=${reviews.first.productId}, userName=${reviews.first.userName}, rating=${reviews.first.rating}, comment=${reviews.first.comment?.substring(0, reviews.first.comment!.length > 50 ? 50 : reviews.first.comment!.length)}');
            for (var i = 0; i < reviews.length; i++) {
              final r = reviews[i];
              final commentPreview = r.comment != null && r.comment!.isNotEmpty
                  ? (r.comment!.length > 50 ? '${r.comment!.substring(0, 50)}...' : r.comment!)
                  : 'нет комментария';
              print('[DEBUG] _ReviewsModal._loadReviews: Отзыв $i: id=${r.id}, productId=${r.productId}, userName=${r.userName}, rating=${r.rating}, comment=$commentPreview');
            }
          } else {
            print('[WARNING] _ReviewsModal._loadReviews: Получен пустой список отзывов');
          }
          if (mounted) {
            setState(() {
              _reviews = reviews;
              _isLoading = false;
            });
            print('[DEBUG] _ReviewsModal._loadReviews: Состояние обновлено: _reviews.length=${_reviews.length}, _isLoading=$_isLoading');
          }
        },
        err: (_) {
          print('[ERROR] _ReviewsModal._loadReviews: нет отзывов');
          if (mounted) {
            setState(() {
              _reviews = [];
              _error = null;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e, stackTrace) {
      print('[ERROR] ========== _ReviewsModal._loadReviews: ИСКЛЮЧЕНИЕ ==========');
      print('[ERROR] _ReviewsModal._loadReviews: Исключение при загрузке отзывов: $e');
      print('[ERROR] _ReviewsModal._loadReviews: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = null;
          _isLoading = false;
        });
      }
    }
    
    print('[DEBUG] ========== _ReviewsModal._loadReviews: КОНЕЦ ==========');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      context.tr('product.reviews'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Содержимое
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _reviews.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.reviews_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        context.tr('product.no_reviews'),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _reviews.length,
                                itemBuilder: (context, index) {
                                  final review = _reviews[index];
                                  return _buildReviewCard(review);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок отзыва (имя пользователя и рейтинг)
            Row(
              children: [
                // Иконка пользователя
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName ?? 'Анонимный пользователь',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < review.rating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Дата
                if (review.createdAt != null)
                  Text(
                    _formatDate(review.createdAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
            // Комментарий
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Сегодня';
      } else if (difference.inDays == 1) {
        return 'Вчера';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн. назад';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} нед. назад';
      } else if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()} мес. назад';
      } else {
        return AppDateFormatter.formatDate(date);
      }
    } catch (e) {
      return dateStr;
    }
  }
}