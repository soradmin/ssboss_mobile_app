import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:video_player/video_player.dart'; 
import 'package:chewie/chewie.dart'; 
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_controller.dart' as cs;
import '../../../core/date_formatter.dart';
import '../../cart/models/cart_item.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../../../core/config.dart';
import '../repo/catalog_api.dart';
import '../../../core/result.dart';
import '../models/media.dart';
import '../widgets/product_price_row.dart';
import '../widgets/product_grid_card.dart';
import '../../favorites/repo/favorites_api.dart';
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
    _images = List<ProductImage>.from(widget.p.images);
    _videos = List<ProductVideo>.from(widget.p.videos);
    // Инициализируем контроллеры для видео
    _chewieControllers.addAll(List.generate(_videos.length, (_) => null));
    // Подтягиваем полные данные (галерея + привязка фото к вариантам)
    _applyDefaultAttributeSelections(widget.p);
    _loadDetails();
    unawaited(UserPreferenceService.instance.recordView(widget.p));
    super.initState();
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
        _isLoadingFavorite = false;
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
        _images = full.images;
        _videos = full.videos;
        _chewieControllers.clear();
        _chewieControllers.addAll(List.generate(_videos.length, (_) => null));
        
        // Сохраняем информацию о продавце и рейтинге из полного ответа API
        _currentProduct = Product(
          id: widget.p.id,
          name: widget.p.name,
          image: widget.p.image,
          price: widget.p.price,
          oldPrice: widget.p.oldPrice,
          rating: full.rating > 0 ? full.rating : widget.p.rating,
          reviewCount: full.reviewCount > 0 ? full.reviewCount : widget.p.reviewCount,
          badge: widget.p.badge,
          sellerName: full.sellerName ?? widget.p.sellerName,
          sellerRating: full.sellerRating ?? widget.p.sellerRating,
          storeSlug: full.storeSlug ?? widget.p.storeSlug,
          description: widget.p.description,
          descriptionImages: widget.p.descriptionImages,
          images: full.images,
          videos: full.videos,
          attributes: full.attributes.isNotEmpty ? full.attributes : widget.p.attributes, // preserve attributes
        );
        _applyDefaultAttributeSelections(_currentProduct!);
      });
    }
    // Загружаем рекомендуемые товары по умолчанию
    _loadRecommendedProducts();
    
    // Всегда пробуем получить описание через API (даже если уже есть)
    // Это нужно для получения изображений описания
    {
      print('[DEBUG] Текущее описание товара: ${widget.p.description}');
      print('[DEBUG] Текущие изображения описания: ${widget.p.descriptionImages.length}');
      print('[DEBUG] Загружаем описание для товара ID: ${widget.p.id}');
      final descriptionResult = await CatalogApi().getProductDescription(widget.p.id);
      if (!mounted) return;
      
      print('[DEBUG] Результат получения описания: $descriptionResult');
      
      if (descriptionResult is Ok<Map<String, dynamic>?>) {
        final result = descriptionResult.value;
        print('[DEBUG] Полученные данные: $result');
        
        String? description;
        List<String> descriptionImages = [];
        
        // Обрабатываем новую структуру данных
        if (result is Map<String, dynamic>) {
          description = result['description']?.toString();
          if (result['images'] is List) {
            descriptionImages = (result['images'] as List)
                .map((e) => e.toString())
                .where((url) => url.isNotEmpty)
                .toList();
          }
          print('[DEBUG] Найдено описание: ${description?.substring(0, description.length > 100 ? 100 : description.length)}...');
          print('[DEBUG] Найдено изображений: ${descriptionImages.length}');
        } else if (result is String) {
          description = result;
          print('[DEBUG] Получено строковое описание: ${description?.substring(0, description.length > 100 ? 100 : description.length)}...');
        }
        
        // Обновляем товар, если получены новые данные (описание или изображения)
        if ((description != null && description.isNotEmpty) || descriptionImages.isNotEmpty) {
          print('[DEBUG] Обновляем товар с описанием и изображениями');
          setState(() {
            // Создаем обновленный товар с описанием и изображениями
            final updatedProduct = Product(
              id: widget.p.id,
              name: widget.p.name,
              image: widget.p.image,
              price: widget.p.price,
              oldPrice: widget.p.oldPrice,
              rating: widget.p.rating,
              reviewCount: widget.p.reviewCount,
              badge: widget.p.badge,
              sellerName: (_currentProduct ?? widget.p).sellerName,
              sellerRating: (_currentProduct ?? widget.p).sellerRating,
              storeSlug: (_currentProduct ?? widget.p).storeSlug,
              description: description ?? widget.p.description, // Используем новое описание или существующее
              descriptionImages: descriptionImages, // Добавляем изображения описания
              images: widget.p.images,
              videos: widget.p.videos,
              attributes: (_currentProduct ?? widget.p).attributes, // preserve attributes
            );
            // Обновляем локальную переменную для отображения
            _currentProduct = updatedProduct;
          });
        } else {
          print('[DEBUG] Описание и изображения не найдены');
        }
      } else {
        print('[DEBUG] Ошибка получения описания: $descriptionResult');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    // Отладочная информация
    final product = _currentProduct ?? widget.p;
    print('[DEBUG] Отображение товара: ID=${product.id}, описание=${product.description != null ? 'есть' : 'нет'}, изображения описания=${product.descriptionImages.length}');
    // Создаем общий список медиа (изображения и видео)
    final List<Widget> mediaItems = [];
    final List<Widget> thumbnailItems = [];

    // Добавляем изображения
    for (int i = 0; i < _images.length; i++) {
      final img = _images[i];
      final fullImageUrl = AppConfig.imageUrl(img.image);
      final thumbUrl = (img.thumb.isNotEmpty)
          ? AppConfig.imageUrl(img.thumb)
          : fullImageUrl;

      mediaItems.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: fullImageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0x11000000),
              child: Center(child: Icon(Icons.image_not_supported_outlined)),
            ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: widget.p.image.isEmpty
              ? const ColoredBox(color: Color(0x11000000), child: Center(child: Icon(Icons.image_not_supported_outlined)))
              : CachedNetworkImage(
            imageUrl: AppConfig.imageUrl(widget.p.image),
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0x11000000),
              child: Center(child: Icon(Icons.image_not_supported_outlined)),
            ),
          ),
        ),
      );
    }

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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Кнопка избранного
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleFavorite,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: _isLoadingFavorite
                    ? const Padding(
                        padding: EdgeInsets.all(10.0),
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
          ),
          // Кнопка поделиться
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _shareProduct,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.share_outlined,
                  color: Colors.black87,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Карусель медиа
          Stack(
            children: [
              CarouselSlider(
                carouselController: _carouselController,
                items: mediaItems,
                options: CarouselOptions(
                  aspectRatio: 1,
                  enlargeCenterPage: true,
                  enableInfiniteScroll: mediaItems.length > 1,
                  viewportFraction: 1.0,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _current = index;
                    });
                  },
                ),
              ),
              // Индикатор страницы (не обязателен, если есть миниатюры)
              // Positioned(
              //   bottom: 10,
              //   left: 0,
              //   right: 0,
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: mediaItems.asMap().entries.map((entry) {
              //       return Container(
              //         width: 8.0,
              //         height: 8.0,
              //         margin: const EdgeInsets.symmetric(horizontal: 4.0),
              //         decoration: BoxDecoration(
              //           shape: BoxShape.circle,
              //           color: _current == entry.key ? Theme.of(context).primaryColor : Colors.grey,
              //         ),
              //       );
              //     }).toList(),
              //   ),
              // ),
            ],
          ),
          // Миниатюры
          if (thumbnailItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: thumbnailItems,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Отладочный вывод для атрибутов
          Builder(
            builder: (context) {
              print('[DEBUG ATTR] Атрибутов в товаре: ${product.attributes.length}');
              for (var attr in product.attributes) {
                print('[DEBUG ATTR] Атрибут: ${attr.title}, значений: ${attr.values.length}');
                for (var val in attr.values) {
                  print('[DEBUG ATTR]   Значение: ${val.title}');
                }
              }
              return const SizedBox.shrink();
            },
          ),
          if (product.attributes.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: product.attributes.map((attr) {
                final selectedValueId = _selectedAttributes[attr.id];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attr.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attr.values.map((v) {
                        final isSelected = selectedValueId == v.attributeValueId;
                        return GestureDetector(
                          onTap: () => _onAttributeValueSelected(
                            attr.id,
                            v.attributeValueId,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              v.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ),
          ],
          Text(widget.p.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ProductPriceRow(
            price: (_currentProduct ?? widget.p).price,
            oldPrice: (_currentProduct ?? widget.p).oldPrice,
            priceFontSize: 20,
            oldPriceFontSize: 14,
          ),
          
          // Рейтинг и отзывы товара
          if ((_currentProduct ?? widget.p).rating > 0 || (_currentProduct ?? widget.p).reviewCount > 0) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                _showReviewsModal(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 20,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (_currentProduct ?? widget.p).rating > 0 ? (_currentProduct ?? widget.p).rating.toStringAsFixed(1) : '0',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((_currentProduct ?? widget.p).reviewCount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${(_currentProduct ?? widget.p).reviewCount} ${_getReviewCountText((_currentProduct ?? widget.p).reviewCount)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          // Краткое описание + ссылка «о товаре» (как на WB)
          const SizedBox(height: 12),
          _buildProductAboutPreview(context, _currentProduct ?? widget.p),

          // Продавец + избранное (как на WB)
          if ((_currentProduct ?? widget.p).sellerName != null &&
              (_currentProduct ?? widget.p).sellerName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSellerRow(context, _currentProduct ?? widget.p),
          ],
          
          // Секции с рекомендуемыми товарами и товарами "смотрели также"
          const SizedBox(height: 24),
          _buildRecommendedAndAlsoViewedSection(),
          
          const SizedBox(height: 88), // отступ под закрепленные кнопки
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Consumer(
            builder: (context, ref, child) {
              final cartItems = ref.watch(cartProvider);
              final cartItem = cartItems.firstWhere(
                (item) => item.product.id == widget.p.id,
                orElse: () => CartItem(product: widget.p, qty: 0),
              );
              final isInCart = cartItem.qty > 0;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Кнопка "Купить сейчас" (всегда видна)
                  Flexible(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFC94F4F), // Темно-красный
                              Color(0xFFE85A5A), // Светло-красный
                            ],
                            stops: [0.0, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(Colors.transparent),
                            shadowColor: WidgetStateProperty.all(Colors.transparent),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          onPressed: () async {
                            // Проверяем, что все атрибуты выбраны
                            final product = _currentProduct ?? widget.p;
                            if (product.attributes.isNotEmpty) {
                              final missingAttributes = <ProductAttribute>[];
                              for (final attr in product.attributes) {
                                if (!_selectedAttributes.containsKey(attr.id) || 
                                    _selectedAttributes[attr.id] == null ||
                                    _selectedAttributes[attr.id]! <= 0) {
                                  missingAttributes.add(attr);
                                }
                              }
                              
                              if (missingAttributes.isNotEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Пожалуйста, выберите ${missingAttributes.map((a) => a.title.toLowerCase()).join(', ')}',
                                      ),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            
                            // Сохраняем выбранные атрибуты в лог для отладки
                            print('[DEBUG] Добавляем товар с атрибутами: $_selectedAttributes');
                            
                            // Добавляем в локальную корзину
                            ref.read(cartProvider.notifier).addToCart(
                              widget.p,
                              1,
                              selectedAttributes: _selectedAttributes,
                            );
                            
                            // Синхронизируем с сервером в фоне
                            ref.read(cartProvider.notifier).addToCartWithSync(
                              widget.p,
                              1,
                              selectedAttributes: _selectedAttributes,
                            );
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар добавлен в корзину')));
                              // перейти в корзину
                              context.go('/cart');
                            }
                          },
                          child: const Text('Купить сейчас'),
                        ),
                      ),
                    ),
                  ),
                  
                  // Кнопка "В корзину" (только если товар не в корзине)
                  if (!isInCart) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
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
                          child: FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(Colors.transparent),
                              shadowColor: WidgetStateProperty.all(Colors.transparent),
                              foregroundColor: WidgetStateProperty.all(Colors.white),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            onPressed: () {
                              // Проверяем, что все атрибуты выбраны
                              final product = _currentProduct ?? widget.p;
                              if (product.attributes.isNotEmpty) {
                                final missingAttributes = <ProductAttribute>[];
                                for (final attr in product.attributes) {
                                  if (!_selectedAttributes.containsKey(attr.id) || 
                                      _selectedAttributes[attr.id] == null ||
                                      _selectedAttributes[attr.id]! <= 0) {
                                    missingAttributes.add(attr);
                                  }
                                }
                                
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
                              }
                              
                              // Сохраняем выбранные атрибуты в лог для отладки
                              print('[DEBUG] Добавляем товар с атрибутами: $_selectedAttributes');
                              
                              // Добавляем в локальную корзину
                              ref.read(cartProvider.notifier).addToCart(
                                widget.p,
                                1,
                                selectedAttributes: _selectedAttributes,
                              );
                              
                              // Синхронизируем с сервером в фоне
                              ref.read(cartProvider.notifier).addToCartWithSync(
                                widget.p,
                                1,
                                selectedAttributes: _selectedAttributes,
                              );
                              
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар добавлен в корзину')));
                            },
                            child: const Text('В корзину'),
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Показываем статус "В корзине" если товар уже добавлен
                  if (isInCart) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: InkWell(
                          onTap: () {
                            // Переходим в корзину
                            context.go('/cart');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8813BA).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF8813BA)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shopping_cart,
                                  color: Color(0xFF8813BA),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'В корзине (${cartItem.qty})',
                                    style: const TextStyle(
                                      color: Color(0xFF8813BA),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF8813BA),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static const Color _wbAccent = Color(0xFF8813BA);

  String _plainText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _shortProductPreview(Product product, {int maxLen = 140}) {
    final desc = _plainText(product.description);
    if (desc.isNotEmpty) {
      if (desc.length <= maxLen) return desc;
      return '${desc.substring(0, maxLen).trim()}…';
    }
    if (product.attributes.isNotEmpty) {
      final parts = product.attributes
          .take(4)
          .map((a) {
            final values = a.values.map((v) => v.title).where((t) => t.isNotEmpty);
            if (values.isEmpty) return a.title;
            return '${a.title}: ${values.join(', ')}';
          })
          .where((s) => s.isNotEmpty)
          .toList();
      final joined = parts.join(' · ');
      if (joined.length <= maxLen) return joined;
      return '${joined.substring(0, maxLen).trim()}…';
    }
    return '';
  }

  Widget _buildProductAboutPreview(BuildContext context, Product product) {
    final preview = _shortProductPreview(product);
    const previewStyle = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: Color(0xFF4A5568),
    );
    const linkStyle = TextStyle(
      fontSize: 14,
      height: 1.45,
      color: _wbAccent,
      fontWeight: FontWeight.w500,
    );

    // На iOS WidgetSpan внутри Text.rich с maxLines/ellipsis часто не рисуется.
    // Ссылку выносим отдельно — она всегда видна на обеих платформах.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.isNotEmpty)
          Text(
            preview,
            style: previewStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        GestureDetector(
          onTap: () => _showProductInfoModal(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(top: preview.isNotEmpty ? 4 : 0),
            child: const Text('о товаре', style: linkStyle),
          ),
        ),
      ],
    );
  }

  void _openSellerStore(BuildContext context, Product product) {
    String? slug = product.storeSlug;
    if (slug == null || slug.isEmpty) {
      slug = product.sellerName!
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'[\s_-]+'), '-')
          .trim();
    }
    if (slug.isNotEmpty) {
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

  Widget _buildSellerRow(BuildContext context, Product product) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openSellerStore(context, product),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.sellerName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Продавец',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (product.sellerRating != null && product.sellerRating! > 0) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.star, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 2),
                      Text(
                        product.sellerRating!.toStringAsFixed(1).replaceAll('.', ','),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleFavorite,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoadingFavorite
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.black87,
                      size: 22,
                    ),
            ),
          ),
        ),
      ],
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
        // Кнопки-табы для переключения между секциями
        Row(
          children: [
            Expanded(
              child: _buildTabButton(
                title: 'Смотрите также',
                isActive: _activeTabIsRecommended,
                onTap: () {
                  setState(() {
                    _activeTabIsRecommended = true;
                  });
                  // Загружаем рекомендуемые товары, если еще не загружены
                  if (_recommendedProducts.isEmpty && !_recommendedLoading) {
                    _loadRecommendedProducts();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTabButton(
                title: 'Покупают вместе',
                isActive: !_activeTabIsRecommended,
                onTap: () {
                  setState(() {
                    _activeTabIsRecommended = false;
                  });
                  // Загружаем товары "смотрели также", если еще не загружены
                  if (_alsoViewedProducts.isEmpty && !_alsoViewedLoading) {
                    _loadAlsoViewedProducts();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Показываем только активную секцию
        if (_activeTabIsRecommended)
          _buildProductHorizontalList(
            title: 'Смотрите также',
            products: _recommendedProducts,
            isLoading: _recommendedLoading,
          )
        else
          _buildProductHorizontalList(
            title: 'Покупают вместе',
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF9C27B0).withOpacity(0.1) // Очень легкий фиолетовый фон для активной
              : Colors.transparent, // Прозрачный фон для неактивной
          border: Border.all(
            color: isActive 
                ? const Color(0xFF9C27B0).withOpacity(0.3) // Легкая фиолетовая обводка для активной
                : Colors.grey[300]!, // Серая обводка для неактивной
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive 
                ? const Color(0xFF9C27B0) // Фиолетовый текст для активной
                : Colors.grey[600], // Серый текст для неактивной
          ),
        ),
      ),
    );
  }

  Widget _buildProductHorizontalList({
    required String title,
    required List<Product> products,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : products.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Нет товаров',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < products.length - 1 ? 12 : 0,
                          ),
                          child: SizedBox(
                            width: 160,
                            child: ProductGridCard(product: product),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// Модальное окно с информацией о товаре
class _ProductInfoModal extends StatefulWidget {
  final Product product;
  final ScaffoldMessengerState messenger;

  const _ProductInfoModal({
    required this.product,
    required this.messenger,
  });

  @override
  State<_ProductInfoModal> createState() => _ProductInfoModalState();
}

class _ProductInfoModalState extends State<_ProductInfoModal> with SingleTickerProviderStateMixin {
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
                const Text(
                  'О товаре',
                  style: TextStyle(
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
              tabs: const [
                Tab(text: 'Характеристики'),
                Tab(text: 'Описание'),
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
            'Артикул',
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
          _buildCharacteristicRow('Цена', '${product.price.toStringAsFixed(2)} с.'),
        if (product.sellerName != null && product.sellerName!.isNotEmpty)
          _buildCharacteristicRow('Продавец', product.sellerName!),
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
            product.description!,
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Описание отсутствует',
                style: TextStyle(
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
                        const SnackBar(
                          content: Text('Артикул скопирован'),
                          duration: Duration(seconds: 2),
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
    return 'Не указано';
  }

  String _extractColors(String name) {
    // Попытка извлечь цвета из названия
    final colors = <String>[];
    if (name.toLowerCase().contains('белый') || name.toLowerCase().contains('white')) colors.add('белый');
    if (name.toLowerCase().contains('черный') || name.toLowerCase().contains('black')) colors.add('черный');
    if (name.toLowerCase().contains('красный') || name.toLowerCase().contains('red')) colors.add('красный');
    if (name.toLowerCase().contains('синий') || name.toLowerCase().contains('blue')) colors.add('синий');
    if (name.toLowerCase().contains('фиолетовый') || name.toLowerCase().contains('purple')) colors.add('фиолетовый');
    return colors.isEmpty ? 'Не указано' : colors.join('; ');
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
        err: (error) {
          print('[ERROR] ========== _ReviewsModal._loadReviews: ОШИБКА ==========');
          print('[ERROR] _ReviewsModal._loadReviews: Ошибка загрузки отзывов: $error');
          if (mounted) {
            setState(() {
              _error = error;
              _isLoading = false;
            });
            print('[DEBUG] _ReviewsModal._loadReviews: Состояние обновлено: _error=$_error, _isLoading=$_isLoading');
          }
        },
      );
    } catch (e, stackTrace) {
      print('[ERROR] ========== _ReviewsModal._loadReviews: ИСКЛЮЧЕНИЕ ==========');
      print('[ERROR] _ReviewsModal._loadReviews: Исключение при загрузке отзывов: $e');
      print('[ERROR] _ReviewsModal._loadReviews: Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Ошибка: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
    
    print('[DEBUG] ========== _ReviewsModal._loadReviews: КОНЕЦ ==========');
  }

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Отзывы',
                      style: TextStyle(
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
                                        'Отзывов пока нет',
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