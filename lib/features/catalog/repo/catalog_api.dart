import 'package:dio/dio.dart';
import '../../../core/api_client.dart' show dio;
import '../../../core/result.dart';
import '../../../core/config.dart';
import '../models/product.dart';
import '../models/media.dart';
import '../models/slider.dart';
import '../models/review.dart';
import '../models/banner.dart';
import '../models/brand.dart';
import '../models/home_page_data.dart';
import '../models/flash_sale.dart';
import 'package:dio/dio.dart' show ResponseType;

List<ProductImage> parseProductImagesFromApi(
  List<dynamic> rawImgs,
  String Function(String raw) imgUrl,
) {
  return rawImgs
      .map((it) {
        if (it is String) {
          final u = imgUrl(it);
          return ProductImage(image: u, thumb: u);
        }
        if (it is Map) {
          final m = it.cast<String, dynamic>();
          final image = imgUrl(
            (m['image'] ?? m['url'] ?? m['src'] ?? m['file'] ?? '').toString(),
          );
          final thumb = imgUrl(
            (m['thumb'] ?? m['thumbnail'] ?? m['thumb_url'] ?? image).toString(),
          );
          return ProductImage.fromJson({
            'id': m['id'],
            'image': image,
            'thumb': thumb,
            'attributes': m['attributes'],
          });
        }
        return ProductImage(image: '', thumb: '');
      })
      .where((e) => e.image.isNotEmpty)
      .toList();
}

class CatalogApi {
  static String _cdnImageUrl(String raw) {
    raw = raw.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final base = AppConfig.cdnBaseUrl.isNotEmpty
        ? AppConfig.cdnBaseUrl
        : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
    if (raw.startsWith('/uploads/')) return '$base$raw';
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base/uploads$path';
  }

  List<Product> _mapRawProductList(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .map((p) {
          final normalizedImages = p.images
              .map(
                (img) => ProductImage(
                  image: _cdnImageUrl(img.image),
                  thumb: _cdnImageUrl(img.thumb),
                ),
              )
              .toList();
          final normalizedVideos = p.videos
              .map((v) => ProductVideo(video: _cdnImageUrl(v.video)))
              .toList();
          return Product(
            id: p.id,
            name: p.name,
            image: _cdnImageUrl(p.image),
            price: p.price,
            oldPrice: p.oldPrice,
            rating: p.rating,
            reviewCount: p.reviewCount,
            badge: p.badge,
            sellerName: p.sellerName,
            sellerRating: p.sellerRating,
            storeSlug: p.storeSlug,
            description: p.description,
            descriptionImages: p.descriptionImages,
            images: normalizedImages,
            videos: normalizedVideos,
            attributes: p.attributes,
          );
        })
        .toList();
  }

  /// Товары коллекции с блока главной страницы сайта (как «Трендовые товары»).
  Future<Result<List<Product>>> getHomeCollectionProducts({
    required String collectionId,
    List<String> titleKeywords = const [],
  }) async {
    try {
      final response = await dio.get('/home');
      if (response.statusCode != 200 || response.data == null) {
        return const Err('Не удалось загрузить главную страницу');
      }

      final data = response.data;
      Map<String, dynamic>? dataMap;
      if (data is Map<String, dynamic>) {
        if (data['data'] is Map<String, dynamic>) {
          dataMap = data['data'] as Map<String, dynamic>;
        } else {
          dataMap = data;
        }
      }
      if (dataMap == null) {
        return const Err('Неверный формат ответа /home');
      }

      final collections = dataMap['collections'];
      if (collections is! List) {
        return const Ok([]);
      }

      for (final item in collections) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString() ?? '';
        final title = (map['title'] ?? '').toString().toLowerCase();

        final idMatch = id == collectionId;
        final titleMatch = titleKeywords.any(
          (k) => k.isNotEmpty && title.contains(k.toLowerCase()),
        );
        if (!idMatch && !titleMatch) continue;

        final rawProducts = map['products'];
        if (rawProducts is! List || rawProducts.isEmpty) continue;

        final products = _mapRawProductList(rawProducts);
        print(
          '[DEBUG] getHomeCollectionProducts: collection id=$id '
          'title="${map['title']}" → ${products.length} товаров',
        );
        return Ok(products);
      }

      print(
        '[DEBUG] getHomeCollectionProducts: коллекция $collectionId не найдена в /home',
      );
      return const Ok([]);
    } on DioException catch (e) {
      return Err(e.message ?? 'Ошибка сети');
    } catch (e) {
      return Err(e.toString());
    }
  }

  Future<Result<List<Product>>> products({
    int page = 1,
    String? category,
    String? collection,
    String? search,
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'sortby': '',
        'shipping': '',
        'brand': '',
        'collection': '',
        'rating': 0,
        'max': 0,
        'min': 0,
        'q': search ?? '',
        'all_categories': 'true',
        'sidebar_data': 'true',
      };
      
      // Добавляем фильтры если они есть
      if (category != null && category.isNotEmpty) {
        // API: category — slug категории (endpoint /all)
        final trimmedSlug = category.trim();
        queryParams['category'] = trimmedSlug;
        print('[DEBUG] CatalogApi.products: category="$trimmedSlug", categoryId=$categoryId');
      }
      if (collection != null && collection.isNotEmpty) {
        // API: collection — id коллекции (Рекомендуемые=1, Тренды=2 на ssboss.shop)
        queryParams['collection'] = collection.trim();
        print('[DEBUG] CatalogApi.products: collection="${queryParams['collection']}"');
      }
      
      print('[DEBUG] API Request params: $queryParams');
      print('[DEBUG] CatalogApi.products: Финальный queryParams[category]=${queryParams['category']}');
      print('[DEBUG] CatalogApi.products: Финальный queryParams[collection]=${queryParams['collection']}');
      
      // Используем endpoint /all если указана категория, иначе /products
      // На сайте используется /all/{slug}, но API принимает category как query параметр
      Response res;
      if (category != null && category.isNotEmpty) {
        final trimmedSlug = category.trim();
        print('[DEBUG] CatalogApi.products: Используем endpoint /all с category="$trimmedSlug"');
        // Используем endpoint /all с параметром category в query string
        res = await dio.get('/all', queryParameters: queryParams);
      } else {
        res = await dio.get('/products', queryParameters: queryParams);
      }
      final data = res.data;
      
      // Логируем ответ API для отладки
      if (data is Map && data['data'] is Map) {
        final dataMap = data['data'] as Map;
        if (dataMap['category'] != null) {
          print('[DEBUG] CatalogApi.products: API вернул category=${dataMap['category']}');
        }
        if (dataMap['result'] is Map) {
          final result = dataMap['result'] as Map;
          if (result['data'] is List) {
            final productsList = result['data'] as List;
            print('[DEBUG] CatalogApi.products: API вернул ${productsList.length} товаров');
            if (productsList.isNotEmpty && productsList.first is Map) {
              final firstProduct = productsList.first as Map;
              print('[DEBUG] CatalogApi.products: Первый товар: title="${firstProduct['title']}", slug="${firstProduct['slug']}"');
            }
          }
        }
      }

      List list;
      if (data is Map && data['data'] is Map) {
        final d = data['data'] as Map;
        if (d['result'] is Map && (d['result'] as Map)['data'] is List) {
          list = (d['result'] as Map)['data'] as List;
        } else if (d['data'] is List) {
          list = d['data'] as List;
        } else {
          list = const [];
        }
      } else if (data is List) {
        list = data;
      } else {
        list = const [];
      }

      String _imgUrl(String raw) {
  // Убираем возможные пробелы и лишние символы
  raw = raw.trim();

  if (raw.isEmpty) return '';
  if (raw.startsWith('http')) return raw;

  final base = AppConfig.cdnBaseUrl.isNotEmpty
      ? AppConfig.cdnBaseUrl
      : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');

  // Проверяем, содержит ли путь уже префикс /uploads/
  if (raw.startsWith('/uploads/')) {
    // Если да, то просто добавляем базовый URL
    final path = raw; // raw уже начинается с /
    return '$base$path';
  }

  // Если нет, то добавляем префикс /uploads/
  final path = raw.startsWith('/') ? raw : '/$raw';
  return '$base/uploads$path';
}

      final items = list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .map((p) {
        // Нормализуем URL для основного изображения, галереи и видео
        final List<ProductImage> normalizedImages = p.images
            .map((img) => ProductImage(
                  image: _imgUrl(img.image),
                  thumb: _imgUrl(img.thumb),
                ))
            .toList();

        final List<ProductVideo> normalizedVideos = p.videos
            .map((v) => ProductVideo(
                  video: _imgUrl(v.video),
                ))
            .toList();

        return Product(
          id: p.id,
          name: p.name,
          image: _imgUrl(p.image),
          price: p.price,
          oldPrice: p.oldPrice,
          rating: p.rating,
          reviewCount: p.reviewCount,
          badge: p.badge, // preserve badge from API
          sellerName: p.sellerName,
          sellerRating: p.sellerRating,
          storeSlug: p.storeSlug,
          description: p.description,
          descriptionImages: p.descriptionImages,
          images: normalizedImages,
          videos: normalizedVideos,
          attributes: p.attributes, // preserve attributes from API
        );
      }).toList();

      return Ok(items);
    } on DioException catch (e) {
      return Err(e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }

  /// Поиск товаров (текст + артикул = id товара в каталоге).
  Future<Result<List<Product>>> searchProducts(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) return const Ok([]);

    final merged = <Product>[];
    final seen = <int>{};

    void addProduct(Product p) {
      if (p.id > 0 && seen.add(p.id)) merged.add(p);
    }

    // Артикул в приложении = products.id (см. «О товаре»).
    if (page <= 1) {
      final articleId = int.tryParse(q);
      if (articleId != null && articleId > 0) {
        final direct = await productById(articleId);
        if (direct is Ok<Product>) {
          addProduct(direct.value);
          print('[DEBUG] searchProducts: найден товар по артикулу $articleId');
        }
      }
    }

    // Endpoint поиска сайта (/search)
    try {
      final res = await dio.get('/search', queryParameters: {'q': q});
      final data = res.data;
      if (data is Map && data['data'] is Map) {
        final payload = data['data'] as Map;
        final productList = payload['product'];
        if (productList is List) {
          for (final item in productList) {
            if (item is Map) {
              addProduct(
                _mapRawProductList([item]).first,
              );
            }
          }
        }
      }
    } catch (e) {
      print('[DEBUG] searchProducts: /search — $e');
    }

    // Дополнительно — listing с параметром q (название, теги)
    final listRes = await products(page: page, search: q);
    if (listRes is Ok<List<Product>>) {
      for (final p in listRes.value) {
        addProduct(p);
      }
    }

    print('[DEBUG] searchProducts: "$q" → ${merged.length} товаров');
    return Ok(merged);
  }

  /// Получение категорий товаров с сайта
  Future<Result<List<Map<String, dynamic>>>> getCategories() async {
    try {
      // Попробуем разные варианты запроса для получения категорий
      Response? res;
      Map<String, dynamic>? data;
      List<Map<String, dynamic>> categories = [];
      
      // Сначала попробуем получить категории через специальные эндпоинты
      final categoryEndpoints = ['/api/v1/categories', '/categories', '/category', '/api/categories', '/api/category'];
      
      for (final endpoint in categoryEndpoints) {
        try {
          res = await dio.get(endpoint);
          data = res.data;
          print('[DEBUG] Categories endpoint $endpoint response: $data');
          if (data != null && data is Map && data.isNotEmpty) {
            // Специальная обработка для /api/v1/categories
            if (endpoint == '/api/v1/categories') {
              print('[DEBUG] Обрабатываем ответ от /api/v1/categories');
              print('[DEBUG] Структура ответа: data.keys = ${data.keys.toList()}');
              
              List? categoriesList;
              
              // Проверяем разные возможные структуры ответа
              // Структура из JSON: { "data": { "data": [...] } }
              if (data['data'] is Map) {
                final dataMap = data['data'] as Map;
                print('[DEBUG] data.data keys: ${dataMap.keys.toList()}');
                if (dataMap['data'] is List) {
                  categoriesList = dataMap['data'] as List;
                  print('[DEBUG] Найдены категории в data.data.data (List)');
                } else if (dataMap is List) {
                  categoriesList = dataMap as List;
                  print('[DEBUG] Найдены категории в data.data (List)');
                }
              } else if (data['data'] is List) {
                // Структура: { "data": [...] }
                categoriesList = data['data'] as List;
                print('[DEBUG] Найдены категории в data (List)');
              }
              
              if (categoriesList != null && categoriesList.isNotEmpty) {
                print('[DEBUG] Количество категорий: ${categoriesList.length}');
                
                // Обрабатываем каждую категорию
                for (int i = 0; i < categoriesList.length; i++) {
                  final category = categoriesList[i] as Map<String, dynamic>;
                  print('[DEBUG] Категория $i: keys=${category.keys.toList()}');
                  print('[DEBUG] Категория $i: title=${category['title']}, name=${category['name']}');
                  print('[DEBUG] Категория $i: slug=${category['slug']}, image=${category['image']}');
                }
                
                // Преобразуем в нужный формат
                categories = categoriesList.map((e) {
                  final category = e as Map<String, dynamic>;
                  // API возвращает 'title', поэтому приоритет у title
                  final title = category['title'] ?? category['name'] ?? 'Категория';
                  final slug = category['slug'] ?? category['id']?.toString() ?? '';
                  final image = category['image']?.toString();
                  
                  print('[DEBUG] Обрабатываем категорию: title="$title" (slug: $slug, image: $image)');
                  
                  return {
                    'name': title,
                    'slug': slug,
                    'id': category['id'],
                    'image': image != null && image.isNotEmpty 
                        ? (image.startsWith('http') ? image : 'https://ssboss.shop/uploads/$image')
                        : null,
                    'product_count': category['product_count'] ?? category['count'] ?? null,
                  };
                }).toList();
                
                print('[DEBUG] Обработано категорий: ${categories.length}');
                print('[DEBUG] Первые 3 категории:');
                for (int i = 0; i < categories.length && i < 3; i++) {
                  print('[DEBUG]   $i: name="${categories[i]['name']}", slug="${categories[i]['slug']}"');
                }
                break; // Выходим из цикла, так как нашли категории
              } else {
                print('[DEBUG] Категории не найдены в ожидаемой структуре');
              }
            } else if (data['data'] is Map && (data['data'] as Map)['data'] is List) {
              // Обработка для других endpoints
              break;
            } else if (data['data'] is List) {
              // Обработка для других endpoints
              break;
            }
          }
        } catch (e) {
          print('[DEBUG] Categories endpoint $endpoint failed: $e');
        }
      }
      
      // Если не получилось, попробуем через products с параметрами
      if (data == null || (data is Map && data.isEmpty)) {
        try {
          res = await dio.get('/products', queryParameters: {
            'all_categories': 'true',
            'sidebar_data': 'true',
            'page': '1',
          });
          data = res.data;
          print('[DEBUG] Products with categories response: $data');
        } catch (e) {
          print('[DEBUG] Products with categories failed: $e');
        }
      }
      
      // Попробуем также получить данные без параметров
      if (data == null || (data is Map && data.isEmpty)) {
        try {
          res = await dio.get('/products');
          data = res.data;
          print('[DEBUG] Simple products response: $data');
        } catch (e) {
          print('[DEBUG] Simple products failed: $e');
        }
      }
      
      // Если все еще нет данных, попробуем простой запрос к products
      if (data == null || (data is Map && data.isEmpty)) {
        try {
          res = await dio.get('/products', queryParameters: {
            'page': '1',
          });
          data = res.data;
          print('[DEBUG] Simple products response: $data');
        } catch (e) {
          print('[DEBUG] Simple products failed: $e');
          return Err('Не удалось загрузить категории: $e');
        }
      }

      // Отладочная информация
      print('[DEBUG] ========== API RESPONSE DEBUG ==========');
      print('[DEBUG] API Response: $data');
      print('[DEBUG] Response type: ${data.runtimeType}');
      if (data != null && data is Map) {
        print('[DEBUG] Response keys: ${data.keys.toList()}');
        print('[DEBUG] Response size: ${data.length}');
        
        // Выводим первые несколько ключей с их значениями
        int count = 0;
        for (final key in data.keys) {
          if (count < 5) {
            print('[DEBUG] Key "$key": ${data[key]}');
            count++;
          }
        }
      }
      print('[DEBUG] ========================================');

      if (data != null && data is Map) {
        print('[DEBUG] Data keys: ${data.keys.toList()}');
        
        // Ищем категории в различных возможных местах ответа
        if (data['categories'] is List) {
          print('[DEBUG] Found categories in data[\'categories\']');
          categories = (data['categories'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        } else if (data['sidebar_data'] is Map) {
          final sidebarData = data['sidebar_data'] as Map;
          print('[DEBUG] Sidebar data keys: ${sidebarData.keys.toList()}');
          if (sidebarData['categories'] is List) {
            print('[DEBUG] Found categories in sidebar_data[\'categories\']');
            categories = (sidebarData['categories'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        } else if (data['data'] is Map) {
          final dataMap = data['data'] as Map;
          print('[DEBUG] Data[\'data\'] keys: ${dataMap.keys.toList()}');
          if (dataMap['categories'] is List) {
            print('[DEBUG] Found categories in data[\'data\'][\'categories\']');
            categories = (dataMap['categories'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        }
        
        // Дополнительный поиск в data.data
        if (categories.isEmpty && data['data'] is Map) {
          final dataMap = data['data'] as Map;
          print('[DEBUG] Searching in data.data for categories...');
          print('[DEBUG] Data.data keys: ${dataMap.keys.toList()}');
          
          // Ищем категории в all_categories
          if (dataMap['all_categories'] is List) {
            print('[DEBUG] Found categories in data.data.all_categories');
            final allCategories = dataMap['all_categories'] as List;
            print('[DEBUG] All categories count: ${allCategories.length}');
            
            categories = allCategories.map((e) {
              final category = e as Map<String, dynamic>;
              // API возвращает 'title', поэтому приоритет у title
              final title = category['title'] ?? category['name'] ?? 'Категория';
              final slug = category['slug'] ?? category['id']?.toString() ?? '';
              
              print('[DEBUG] Обрабатываем категорию: $title (slug: $slug)');
              print('[DEBUG] Исходные данные категории: $category');
              
              // Сначала проверяем, есть ли изображение в исходных данных
              String? imageUrl = category['image']?.toString();
              if (imageUrl != null && imageUrl.isNotEmpty) {
                print('[DEBUG] Найдено изображение в исходных данных: $imageUrl');
                if (!imageUrl.startsWith('http')) {
                  imageUrl = 'https://ssboss.shop/uploads/$imageUrl';
                  print('[DEBUG] Преобразовано в полный URL: $imageUrl');
                }
              } else {
                // Если изображения нет в данных, используем хардкод на основе slug
                print('[DEBUG] Изображение не найдено в данных, используем хардкод для slug: $slug');
                if (slug == 'women-apparel') {
                  imageUrl = 'https://ssboss.shop/uploads/category-1760523981-3.png';
                } else if (slug == 'mens-wear') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'kids-apparel') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'shoes') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'home') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'beauty') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'accessories') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'electronics') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'toys') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'furniture') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'food') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'appliances') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                } else if (slug == 'pet-supplies') {
                  imageUrl = 'https://ssboss.shop/uploads/thumb-category-1758725932-7.png'; // Замените на реальное изображение
                }
              }
              
              print('[DEBUG] Финальное изображение для $title: $imageUrl');
              
              // Преобразуем структуру для соответствия нашему формату
              return {
                'name': title,
                'slug': slug,
                'id': category['id'],
                'image': imageUrl,
                'product_count': category['product_count'] ?? category['count'] ?? null,
              };
            }).toList();
          }
          
          // Если все еще нет категорий, ищем в других полях
          if (categories.isEmpty) {
            for (final key in dataMap.keys) {
              final value = dataMap[key];
              if (value is List && value.isNotEmpty) {
                print('[DEBUG] Found list in data.data.$key with ${value.length} items');
                if (value.first is Map) {
                  final firstItem = value.first as Map<String, dynamic>;
                  if (firstItem.containsKey('name') || firstItem.containsKey('title') || 
                      firstItem.containsKey('category_name') || firstItem.containsKey('category_title')) {
                    print('[DEBUG] This might be categories: data.data.$key');
                    categories = value.map((e) => e as Map<String, dynamic>).toList();
                    break;
                  }
                }
              }
            }
          }
        }
        
        // Дополнительный поиск по всем ключам
        for (final key in data.keys) {
          if (key.toString().toLowerCase().contains('categor')) {
            print('[DEBUG] Found category-related key: $key = ${data[key]}');
          }
        }
        
        // Если категории не найдены, попробуем извлечь их из других полей
        if (categories.isEmpty) {
          print('[DEBUG] No categories found, trying alternative approach...');
          
          // Попробуем найти любые данные, которые могут быть категориями
          for (final key in data.keys) {
            final value = data[key];
            if (value is List && value.isNotEmpty) {
              print('[DEBUG] Found list in key $key with ${value.length} items');
              // Проверим, может ли это быть категориями
              if (value.first is Map) {
                final firstItem = value.first as Map<String, dynamic>;
                if (firstItem.containsKey('name') || firstItem.containsKey('title')) {
                  print('[DEBUG] This might be categories: $key');
                  categories = value.map((e) => e as Map<String, dynamic>).toList();
                  break;
                }
              }
            }
          }
        }
        
        // Обрабатываем изображения категорий
        for (final category in categories) {
          if (category['image'] != null && category['image'].toString().isNotEmpty) {
            final imageUrl = category['image'].toString();
            print('[DEBUG] Обрабатываем изображение категории ${category['name']}: $imageUrl');
            if (!imageUrl.startsWith('http')) {
              // Если изображение не полный URL, добавляем базовый URL
              final fullUrl = 'https://ssboss.shop/uploads/$imageUrl';
              category['image'] = fullUrl;
              print('[DEBUG] Преобразовано в полный URL: $fullUrl');
            } else {
              print('[DEBUG] URL уже полный: $imageUrl');
            }
          } else {
            print('[DEBUG] У категории ${category['name']} нет изображения');
            
            // Специальная обработка для women-apparel
            if (category['slug'] == 'women-apparel') {
              category['image'] = 'https://ssboss.shop/uploads/category-1760523981-3.png';
              print('[DEBUG] Установлено специальное изображение для women-apparel');
            }
          }
        }
      }

      print('[DEBUG] Final categories count: ${categories.length}');
      
      // Если категории не найдены, возвращаем пустой список (fallback будет использован в UI)
      if (categories.isEmpty) {
        print('[DEBUG] No categories found in API response, will use fallback');
        return Ok([]);
      }
      
      return Ok(categories);
    } on DioException catch (e) {
      print('[DEBUG] DioException: ${e.message}');
      return Err(e.message ?? 'Network error');
    } catch (e) {
      print('[DEBUG] General error: $e');
      return Err(e.toString());
    }
  }

  Future<Result<Product>> productById(int id) async {
    try {
      print('[DEBUG] Запрос детальной информации для товара ID: $id');
      // iShop details endpoint
      final res = await dio.get('/product/$id', queryParameters: {'id': id, 'user_id': ''});
      final data = res.data;
      print('[DEBUG] Ответ API для товара $id: $data');

      Map<String, dynamic>? obj;
      if (data is Map && data['data'] is Map) {
        obj = (data['data'] as Map).cast<String, dynamic>();
      } else if (data is Map) {
        obj = data.cast<String, dynamic>();
      }

      if (obj == null) return const Err('Product not found');

      // Отладочная информация для детального просмотра товара
      print('[DEBUG] Product detail JSON keys: ${obj.keys.toList()}');
      for (final key in obj.keys) {
        if (key.toString().toLowerCase().contains('desc') || 
            key.toString().toLowerCase().contains('content') ||
            key.toString().toLowerCase().contains('detail')) {
          print('[DEBUG] Found potential description field "$key": ${obj[key]}');
        }
      }

      String _imgUrl(String raw) {
        raw = (raw ?? '').toString().trim();
        if (raw.isEmpty) return '';
        if (raw.startsWith('http')) return raw;
        final base = AppConfig.cdnBaseUrl.isNotEmpty
            ? AppConfig.cdnBaseUrl
            : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
        if (raw.startsWith('/uploads/')) return '$base$raw';
        final path = raw.startsWith('/') ? raw : '/$raw';
        return '$base/uploads$path';
      }

      final p = Product.fromJson(obj);

      // Галерея: приоритет product_image_names/product_images (с attributes для вариантов)
      List<ProductImage> normalizedImages = [];
      for (final key in [
        'product_image_names',
        'product_images',
        'images',
        'gallery',
        'photos',
        'media',
      ]) {
        if (obj[key] is List && (obj[key] as List).isNotEmpty) {
          normalizedImages = parseProductImagesFromApi(obj[key] as List, _imgUrl);
          if (normalizedImages.isNotEmpty) break;
        }
      }
      if (normalizedImages.isEmpty && p.images.isNotEmpty) {
        normalizedImages = p.images
            .map((img) => ProductImage(
                  id: img.id,
                  image: _imgUrl(img.image),
                  thumb: _imgUrl(img.thumb),
                  attributeValueIds: img.attributeValueIds,
                ))
            .toList();
      }

      // Если в карточке есть основное изображение — добавим в галерею первым
      final mainImg = _imgUrl(p.image);
      if (mainImg.isNotEmpty && (normalizedImages.isEmpty || normalizedImages.first.image != mainImg)) {
        normalizedImages = [ProductImage(image: mainImg, thumb: mainImg), ...normalizedImages];
      }

      // Видео: iShop отдает одиночные поля video/video_thumb
      List<ProductVideo> normalizedVideos = p.videos
          .map((v) => ProductVideo(video: _imgUrl(v.video), thumb: v.thumb != null ? _imgUrl(v.thumb!) : null))
          .toList();
      if (normalizedVideos.isEmpty) {
        final singleVideo = (obj['video'] ?? obj['product_video'])?.toString();
        if (singleVideo != null && singleVideo.isNotEmpty) {
          final vthumb = (obj['video_thumb'] ?? obj['product_video_thumb'])?.toString();
          normalizedVideos = [ProductVideo(video: _imgUrl(singleVideo), thumb: vthumb != null && vthumb.isNotEmpty ? _imgUrl(vthumb) : null)];
        } else {
          List<dynamic>? rawVids;
          for (final key in ['videos', 'product_videos', 'media_videos']) {
            if (obj[key] is List) {
              rawVids = obj[key] as List;
              break;
            }
          }
          if (rawVids != null) {
            normalizedVideos = rawVids.map((it) {
              if (it is String) {
                return ProductVideo(video: _imgUrl(it));
              } else if (it is Map) {
                final m = it.cast<String, dynamic>();
                final v = _imgUrl((m['video'] ?? m['url'] ?? m['src'] ?? m['file'] ?? '').toString());
                final t = (m['thumb'] ?? m['thumbnail'] ?? m['thumb_url']);
                return ProductVideo(video: v, thumb: t != null ? _imgUrl('$t') : null);
              } else {
                return ProductVideo(video: '');
              }
            }).where((e) => e.video.isNotEmpty).toList();
          }
        }
      }

      final full = Product(
        id: p.id,
        name: p.name,
        image: _imgUrl(p.image),
        price: p.price,
        oldPrice: p.oldPrice,
        rating: p.rating,
        reviewCount: p.reviewCount,
        badge: p.badge,
        sellerName: p.sellerName,
        sellerRating: p.sellerRating,
        storeSlug: p.storeSlug,
        description: p.description,
        descriptionImages: p.descriptionImages,
        images: normalizedImages,
        videos: normalizedVideos,
        attributes: p.attributes, // preserve attributes from API
      );

      return Ok(full);
    } on DioException catch (e) {
      return Err(e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }

  /// Fallback: если JSON-эндпоинта деталей нет, парсим HTML страницы товара
  Future<Result<(List<ProductImage>, List<ProductVideo>, String?)>> scrapeProductMedia(int id, {String? vendorSlug}) async {
    try {
      final base = AppConfig.cdnBaseUrl.isNotEmpty
          ? AppConfig.cdnBaseUrl
          : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');

      final candidates = <String>[
        '$base/test22/product/$id', // Специфичный путь для товара Test 22
        '$base/product/$id',
        if (vendorSlug != null && vendorSlug.isNotEmpty) '$base/$vendorSlug/product/$id',
        // Часто магазин использует путь с вендором; временно пробуем популярный пример
        '$base/tajjeans/product/$id',
      ];

      String? html;
      for (final url in candidates) {
        try {
          print('[DEBUG] Пробуем URL: $url');
          final r = await dio.get(url, options: Options(responseType: ResponseType.plain, followRedirects: true));
          print('[DEBUG] Ответ от $url: статус ${r.statusCode}, длина ${(r.data as String).length}');
          if (r.statusCode == 200 && r.data is String && (r.data as String).isNotEmpty) {
            html = r.data as String;
            print('[DEBUG] HTML получен от $url');
            break;
          }
        } catch (e) {
          print('[DEBUG] Ошибка для $url: $e');
        }
      }

      if (html == null || html.isEmpty) {
        return const Err('Product HTML not found');
      }

      print('[DEBUG] HTML получен, длина: ${html.length}');
      print('[DEBUG] Ищем описание в HTML...');
      
      // Показываем первые 500 символов HTML для отладки
      print('[DEBUG] Начало HTML: ${html.substring(0, html.length > 500 ? 500 : html.length)}...');
      
      // Ищем известные фрагменты описания
      if (html.contains('wewewewec')) {
        print('[DEBUG] Найден фрагмент "wewewewec" в HTML');
      }
      if (html.contains('sdf')) {
        print('[DEBUG] Найден фрагмент "sdf" в HTML');
      }
      if (html.contains('wef')) {
        print('[DEBUG] Найден фрагмент "wef" в HTML');
      }

      // Ищем все ссылки на изображения/видео в папке uploads
      final reg = RegExp(
        r'''/uploads/(?:thumb-product-[^"'\s]+\.jpg|wysiwyg-image-[^"'\s]+\.jpg|product-video-thumb-[^"'\s]+\.jpg|product-video-[^"'\s]+\.(?:mp4|webm))''',
        multiLine: true,
      );
      final matches = reg.allMatches(html).map((m) => m.group(0)!).toSet().toList();

      final List<ProductImage> images = [];
      final List<ProductVideo> videos = [];
      for (final path in matches) {
        final full = '$base$path';
        if (path.contains('product-video-') && (path.endsWith('.mp4') || path.endsWith('.webm'))) {
          videos.add(ProductVideo(video: full));
        } else {
          images.add(ProductImage(image: full, thumb: full));
        }
      }

      // Ищем описание товара в HTML
      String? description;
      final descriptionPatterns = [
        // Специфичные для iShop паттерны
        RegExp(r'<div[^>]*class="[^"]*product-description[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<div[^>]*class="[^"]*description[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<div[^>]*class="[^"]*content[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<div[^>]*class="[^"]*details[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<p[^>]*class="[^"]*description[^"]*"[^>]*>(.*?)</p>', multiLine: true, dotAll: true),
        RegExp(r'<div[^>]*id="[^"]*description[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        // Общие паттерны для текстового контента
        RegExp(r'<div[^>]*class="[^"]*product-info[^"]*"[^>]*>(.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<section[^>]*class="[^"]*description[^"]*"[^>]*>(.*?)</section>', multiLine: true, dotAll: true),
        // Ищем любой div с текстом, который может быть описанием
        RegExp(r'<div[^>]*>(.*?wewewewec.*?)</div>', multiLine: true, dotAll: true),
        // Более общие паттерны для поиска текстового контента
        RegExp(r'<div[^>]*>(.*?sdf.*?sdfg.*?)</div>', multiLine: true, dotAll: true),
        RegExp(r'<p[^>]*>(.*?sdf.*?sdfg.*?)</p>', multiLine: true, dotAll: true),
        RegExp(r'<span[^>]*>(.*?sdf.*?sdfg.*?)</span>', multiLine: true, dotAll: true),
        // Ищем любой текст, который содержит известные фрагменты описания
        RegExp(r'<[^>]*>(.*?wewewewec.*?wef.*?sdf.*?)</[^>]*>', multiLine: true, dotAll: true),
      ];

      for (int i = 0; i < descriptionPatterns.length; i++) {
        final pattern = descriptionPatterns[i];
        final match = pattern.firstMatch(html);
        if (match != null && match.group(1) != null) {
          final rawDescription = match.group(1)!.trim();
          print('[DEBUG] Паттерн $i нашел текст: ${rawDescription.substring(0, rawDescription.length > 100 ? 100 : rawDescription.length)}...');
          if (rawDescription.isNotEmpty && rawDescription.length > 20) {
            // Убираем HTML теги и очищаем текст
            description = rawDescription
                .replaceAll(RegExp(r'<[^>]*>'), ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            print('[DEBUG] Очищенное описание: ${description.substring(0, description.length > 100 ? 100 : description.length)}...');
            if (description.isNotEmpty) {
              print('[DEBUG] Описание найдено через паттерн $i');
              break;
            }
          }
        }
      }

      print('[DEBUG] Результат поиска: изображений=${images.length}, видео=${videos.length}, описание=${description != null ? "найдено" : "не найдено"}');
      if (description != null) {
        print('[DEBUG] Найденное описание: ${description.substring(0, description.length > 200 ? 200 : description.length)}...');
      }
      
      if (images.isEmpty && videos.isEmpty && description == null) {
        return const Err('No media or description found in HTML');
      }

      return Ok((images, videos, description));
    } catch (e) {
      return Err(e.toString());
    }
  }

  /// Получение слайдеров с главной страницы
  Future<Result<List<SliderItem>>> getSliders() async {
    try {
      print('[DEBUG] Запрос слайдеров с главной страницы...');
      
      // Пробуем разные endpoints для поиска слайдеров
      final endpoints = [
        '/home', 
        '/sliders', 
        '/banners', 
        '/carousel',
        '/slider',
        '/banner-sliders',
        '/home-sliders',
        '/main-sliders',
        '/carousel-sliders',
        '/footer-sliders',
        '/slider-images',
        '/main-slider',
        '/home-slider',
        '/api/v1/sliders',
        '/api/v1/carousel',
        '/api/v1/banners',
        '/api/v1/home',
        '/api/sliders',
        '/api/carousel',
        '/api/banners',
        '/api/home'
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('[DEBUG] Пробуем endpoint: $endpoint');
          final response = await dio.get(endpoint);
          
                if (response.statusCode == 200) {
                  final data = response.data;
                  print('[DEBUG] Ответ от $endpoint: ${data}');
                  
                  // Детальный анализ структуры данных
                  if (data is Map<String, dynamic>) {
                    print('[DEBUG] Ключи в data: ${data.keys.toList()}');
                    if (data['data'] is Map) {
                      print('[DEBUG] Ключи в data.data: ${(data['data'] as Map).keys.toList()}');
                      if (data['data']['banners'] is List) {
                        final banners = data['data']['banners'] as List;
                        print('[DEBUG] Количество баннеров: ${banners.length}');
                        for (int i = 0; i < banners.length; i++) {
                          if (banners[i] is Map) {
                            final banner = banners[i] as Map<String, dynamic>;
                            print('[DEBUG] Баннер $i: ${banner.keys.toList()}');
                            print('[DEBUG] Баннер $i image: ${banner['image']}');
                            print('[DEBUG] Баннер $i title: ${banner['title']}');
                          }
                        }
                      }
                    }
                  }
            
            if (data != null && data is Map<String, dynamic>) {
              List<SliderItem> sliders = [];
              
              // Ищем слайдеры в разных возможных местах
              if (data['data'] is Map && data['data']['sliders'] is List) {
                sliders = (data['data']['sliders'] as List)
                    .map((item) => item is Map<String, dynamic> 
                        ? SliderItem.fromJson(item) 
                        : SliderItem(id: 0, title: '', image: ''))
                    .toList();
              } else if (data['sliders'] is List) {
                sliders = (data['sliders'] as List)
                    .map((item) => item is Map<String, dynamic> 
                        ? SliderItem.fromJson(item) 
                        : SliderItem(id: 0, title: '', image: ''))
                    .toList();
              } else if (data['data'] is Map && data['data']['banners'] is List) {
                // Ищем слайдеры среди баннеров (с префиксом footer-)
                final banners = data['data']['banners'] as List;
                sliders = banners
                    .where((banner) => banner is Map<String, dynamic>)
                    .where((banner) {
                      final image = banner['image']?.toString() ?? '';
                      return image.contains('footer-') || image.contains('slider-');
                    })
                    .map((banner) => SliderItem.fromJson(banner as Map<String, dynamic>))
                    .toList();
                print('[DEBUG] Найдено слайдеров с footer-: ${sliders.length}');
                
                // Если не нашли слайдеры с footer-, используем все баннеры
                if (sliders.isEmpty) {
                  sliders = banners
                      .where((banner) => banner is Map<String, dynamic>)
                      .map((banner) => SliderItem.fromJson(banner as Map<String, dynamic>))
                      .toList();
                  print('[DEBUG] Используем все баннеры как слайдеры: ${sliders.length}');
                }
              }
              
              // Если нашли слайдеры, добавляем их к результату
              if (sliders.isNotEmpty) {
                sliders = sliders
                    .where((slider) => slider.isActive && slider.image.isNotEmpty)
                    .toList()
                  ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
                
                print('[DEBUG] Найдено слайдеров: ${sliders.length}');
                for (var slider in sliders) {
                  print('[DEBUG] Слайдер: ${slider.title} - ${slider.image}');
                }
                
                // Добавляем статичные слайдеры к найденным
                final staticSliders = [
                  SliderItem(
                    id: 1001,
                    title: 'Footer Slider 1',
                    image: 'https://ssboss.shop/uploads/footer-1757330066-5.jpg',
                    link: null,
                    order: 1001,
                    isActive: true,
                  ),
                  SliderItem(
                    id: 1002,
                    title: 'Footer Slider 2', 
                    image: 'https://ssboss.shop/uploads/footer-1757330081-2.jpg',
                    link: null,
                    order: 1002,
                    isActive: true,
                  ),
                  SliderItem(
                    id: 1003,
                    title: 'Footer Slider 3',
                    image: 'https://ssboss.shop/uploads/footer-1758979037-5.png',
                    link: null,
                    order: 1003,
                    isActive: true,
                  ),
                  SliderItem(
                    id: 1004,
                    title: 'Footer Slider 4',
                    image: 'https://ssboss.shop/uploads/footer-1758979325-3.jpg',
                    link: null,
                    order: 1004,
                    isActive: true,
                  ),
                ];
                
                // Объединяем API слайдеры и статичные
                final allSliders = [...sliders, ...staticSliders];
                allSliders.sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
                
                print('[DEBUG] Всего слайдеров (API + статичные): ${allSliders.length}');
                return Ok(allSliders);
              }
            }
          }
        } catch (e) {
          print('[DEBUG] Ошибка для endpoint $endpoint: $e');
          continue;
        }
      }
      
      // Если не нашли слайдеры через API, создаем статичные слайдеры
      print('[DEBUG] Создаем статичные слайдеры с footer-...');
      final staticSliders = [
        SliderItem(
          id: 1001,
          title: 'Footer Slider 1',
          image: 'https://ssboss.shop/uploads/footer-1757330066-5.jpg',
          link: null,
          order: 1001,
          isActive: true,
        ),
        SliderItem(
          id: 1002,
          title: 'Footer Slider 2', 
          image: 'https://ssboss.shop/uploads/footer-1757330081-2.jpg',
          link: null,
          order: 1002,
          isActive: true,
        ),
        SliderItem(
          id: 1003,
          title: 'Footer Slider 3',
          image: 'https://ssboss.shop/uploads/footer-1758979037-5.png',
          link: null,
          order: 1003,
          isActive: true,
        ),
        SliderItem(
          id: 1004,
          title: 'Footer Slider 4',
          image: 'https://ssboss.shop/uploads/footer-1758979325-3.jpg',
          link: null,
          order: 1004,
          isActive: true,
        ),
      ];
      
      print('[DEBUG] Создано статичных слайдеров: ${staticSliders.length}');
      return Ok(staticSliders);
      
    } catch (e) {
      print('[ERROR] Ошибка при получении слайдеров: $e');
      return Err('Ошибка при загрузке слайдеров: $e');
    }
  }

  /// Получить рекомендуемые товары для товара
  Future<Result<List<Product>>> getRecommendedProducts(int productId, {int page = 1}) async {
    try {
      print('[DEBUG] CatalogApi.getRecommendedProducts: Получаем рекомендуемые товары для товара $productId');
      
      // Пробуем разные эндпоинты для рекомендуемых товаров
      final endpoints = [
        '/product/$productId/recommended',
        '/product/$productId/recommended-products',
        '/api/v1/product/$productId/recommended',
        '/api/v1/products/recommended',
      ];
      
      List<Product> products = [];
      
      for (final endpoint in endpoints) {
        try {
          final response = await dio.get(endpoint, queryParameters: {
            'product_id': productId,
            'page': page,
          });
          
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            List<dynamic> productsList = [];
            
            if (data is List) {
              productsList = data;
            } else if (data is Map) {
              if (data['data'] is List) {
                productsList = data['data'] as List;
              } else if (data['products'] is List) {
                productsList = data['products'] as List;
              } else if (data['recommended'] is List) {
                productsList = data['recommended'] as List;
              }
            }
            
            if (productsList.isNotEmpty) {
              String _imgUrl(String raw) {
                raw = (raw ?? '').toString().trim();
                if (raw.isEmpty) return '';
                if (raw.startsWith('http')) return raw;
                final base = AppConfig.cdnBaseUrl.isNotEmpty
                    ? AppConfig.cdnBaseUrl
                    : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
                if (raw.startsWith('/uploads/')) return '$base$raw';
                final path = raw.startsWith('/') ? raw : '/$raw';
                return '$base/uploads$path';
              }
              
              products = productsList
                  .where((p) => p is Map<String, dynamic>)
                  .map((p) {
                    try {
                      final product = Product.fromJson(p as Map<String, dynamic>);
                      // Проверяем, что ID валидный
                      if (product.id <= 0) {
                        print('[WARNING] Товар с невалидным ID пропущен: ${p['id']}');
                        return null;
                      }
                      return Product(
                        id: product.id,
                        name: product.name,
                        image: _imgUrl(product.image),
                        price: product.price,
                        oldPrice: product.oldPrice,
                        rating: product.rating,
                        reviewCount: product.reviewCount,
                        badge: product.badge,
                        sellerName: product.sellerName,
                        sellerRating: product.sellerRating,
                        storeSlug: product.storeSlug,
                        description: product.description,
                        descriptionImages: product.descriptionImages,
                        images: product.images.map((img) => ProductImage(
                          image: _imgUrl(img.image),
                          thumb: _imgUrl(img.thumb),
                        )).toList(),
                        videos: product.videos,
                        attributes: product.attributes,
                      );
                    } catch (e) {
                      print('[ERROR] Ошибка парсинга товара: $e');
                      return null;
                    }
                  })
                  .whereType<Product>()
                  .toList();
              
              print('[DEBUG] CatalogApi.getRecommendedProducts: Найдено ${products.length} рекомендуемых товаров');
              return Ok(products);
            }
          }
        } catch (e) {
          print('[DEBUG] CatalogApi.getRecommendedProducts: Ошибка при запросе к $endpoint: $e');
          continue;
        }
      }
      
      // Если ни один эндпоинт не сработал, попробуем получить товары из той же категории или бренда
      try {
        // Получаем товары из общего списка
        final categoryProductsResult = await this.products(page: 1);
        
        // Обрабатываем результат
        Result<List<Product>> fallbackResult = const Ok([]);
        categoryProductsResult.when(
          ok: (allProducts) {
            // Фильтруем товары, исключая текущий
            final filteredProducts = allProducts
                .where((p) => p.id != productId)
                .take(10)
                .toList();
            if (filteredProducts.isNotEmpty) {
              print('[DEBUG] CatalogApi.getRecommendedProducts: Используем товары из списка (${filteredProducts.length})');
              fallbackResult = Ok(filteredProducts);
            } else {
              fallbackResult = const Ok(<Product>[]);
            }
          },
          err: (error) {
            print('[DEBUG] CatalogApi.getRecommendedProducts: Ошибка получения товаров из категории: $error');
            fallbackResult = Err('Ошибка получения товаров: $error');
          },
        );
        
        return fallbackResult;
      } catch (e) {
        print('[DEBUG] CatalogApi.getRecommendedProducts: Ошибка при получении товаров из категории: $e');
      }
      
      // Если ничего не найдено, возвращаем пустой список
      print('[DEBUG] CatalogApi.getRecommendedProducts: Рекомендуемые товары не найдены');
      return const Ok([]);
    } catch (e) {
      print('[DEBUG] CatalogApi.getRecommendedProducts: Общая ошибка: $e');
      return Err('Ошибка получения рекомендуемых товаров: ${e.toString()}');
    }
  }

  /// Получить товары, которые также просматривали
  Future<Result<List<Product>>> getAlsoViewedProducts(int productId, {int page = 1}) async {
    try {
      print('[DEBUG] CatalogApi.getAlsoViewedProducts: Получаем товары "смотрели также" для товара $productId');
      
      // Пробуем разные эндпоинты для товаров "смотрели также"
      final endpoints = [
        '/product/$productId/also-viewed',
        '/product/$productId/viewed-together',
        '/api/v1/product/$productId/also-viewed',
        '/api/v1/products/also-viewed',
      ];
      
      List<Product> products = [];
      
      for (final endpoint in endpoints) {
        try {
          final response = await dio.get(endpoint, queryParameters: {
            'product_id': productId,
            'page': page,
          });
          
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            List<dynamic> productsList = [];
            
            if (data is List) {
              productsList = data;
            } else if (data is Map) {
              if (data['data'] is List) {
                productsList = data['data'] as List;
              } else if (data['products'] is List) {
                productsList = data['products'] as List;
              } else if (data['also_viewed'] is List) {
                productsList = data['also_viewed'] as List;
              }
            }
            
            if (productsList.isNotEmpty) {
              String _imgUrl(String raw) {
                raw = (raw ?? '').toString().trim();
                if (raw.isEmpty) return '';
                if (raw.startsWith('http')) return raw;
                final base = AppConfig.cdnBaseUrl.isNotEmpty
                    ? AppConfig.cdnBaseUrl
                    : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
                if (raw.startsWith('/uploads/')) return '$base$raw';
                final path = raw.startsWith('/') ? raw : '/$raw';
                return '$base/uploads$path';
              }
              
              products = productsList
                  .where((p) => p is Map<String, dynamic>)
                  .map((p) {
                    try {
                      final product = Product.fromJson(p as Map<String, dynamic>);
                      // Проверяем, что ID валидный
                      if (product.id <= 0) {
                        print('[WARNING] Товар с невалидным ID пропущен: ${p['id']}');
                        return null;
                      }
                      return Product(
                        id: product.id,
                        name: product.name,
                        image: _imgUrl(product.image),
                        price: product.price,
                        oldPrice: product.oldPrice,
                        rating: product.rating,
                        reviewCount: product.reviewCount,
                        badge: product.badge,
                        sellerName: product.sellerName,
                        sellerRating: product.sellerRating,
                        storeSlug: product.storeSlug,
                        description: product.description,
                        descriptionImages: product.descriptionImages,
                        images: product.images.map((img) => ProductImage(
                          image: _imgUrl(img.image),
                          thumb: _imgUrl(img.thumb),
                        )).toList(),
                        videos: product.videos,
                        attributes: product.attributes,
                      );
                    } catch (e) {
                      print('[ERROR] Ошибка парсинга товара: $e');
                      return null;
                    }
                  })
                  .whereType<Product>()
                  .toList();
              
              print('[DEBUG] CatalogApi.getAlsoViewedProducts: Найдено ${products.length} товаров "смотрели также"');
              return Ok(products);
            }
          }
        } catch (e) {
          print('[DEBUG] CatalogApi.getAlsoViewedProducts: Ошибка при запросе к $endpoint: $e');
          continue;
        }
      }
      
      // Если ни один эндпоинт не сработал, попробуем получить товары из той же категории или бренда
      try {
        // Получаем товары из общего списка
        final categoryProductsResult = await this.products(page: 2);
        
        // Обрабатываем результат
        Result<List<Product>> fallbackResult = const Ok([]);
        categoryProductsResult.when(
          ok: (allProducts) {
            // Фильтруем товары, исключая текущий
            final filteredProducts = allProducts
                .where((p) => p.id != productId)
                .take(10)
                .toList();
            if (filteredProducts.isNotEmpty) {
              print('[DEBUG] CatalogApi.getAlsoViewedProducts: Используем товары из списка (${filteredProducts.length})');
              fallbackResult = Ok(filteredProducts);
            } else {
              fallbackResult = const Ok(<Product>[]);
            }
          },
          err: (error) {
            print('[DEBUG] CatalogApi.getAlsoViewedProducts: Ошибка получения товаров из категории: $error');
            fallbackResult = Err('Ошибка получения товаров: $error');
          },
        );
        
        return fallbackResult;
      } catch (e) {
        print('[DEBUG] CatalogApi.getAlsoViewedProducts: Ошибка при получении товаров из категории: $e');
      }
      
      // Если ничего не найдено, возвращаем пустой список
      print('[DEBUG] CatalogApi.getAlsoViewedProducts: Товары "смотрели также" не найдены');
      return const Ok([]);
    } catch (e) {
      print('[DEBUG] CatalogApi.getAlsoViewedProducts: Общая ошибка: $e');
      return Err('Ошибка получения товаров "смотрели также": ${e.toString()}');
    }
  }

  /// Получить отзывы товара
  Future<Result<List<Review>>> getProductReviews(int productId) async {
    try {
      print('[DEBUG] ========== CatalogApi.getProductReviews: НАЧАЛО ==========');
      print('[DEBUG] CatalogApi.getProductReviews: Получаем отзывы для товара $productId');
      
      // Получаем user_id если есть авторизация
      String? userId;
      String? userToken;
      try {
        final activeToken = AppConfig.getActiveBearerToken();
        if (activeToken.isNotEmpty) {
          // Пытаемся извлечь user_id из токена или использовать пустую строку
          userId = '';
          userToken = '';
        }
      } catch (e) {
        userId = '';
        userToken = '';
      }
      
      // Сначала пробуем правильный endpoint для отзывов
      // Пробуем разные endpoints для получения отзывов
      // baseUrl уже включает /api/v1, поэтому не добавляем его снова
      // Реальный endpoint: /api/v1/reviews/{productId}?id={productId}&time_zone=Asia/Tashkent&order_by=created_at&type=desc&get_total=true&page=1
      final endpoints = [
        // Реальный endpoint с productId в пути
        {
          'url': '/reviews/$productId',
          'queryParams': {
            'id': productId,
            'time_zone': 'Asia/Tashkent',
            'order_by': 'created_at',
            'type': 'desc',
            'get_total': 'true',
            'page': 1,
          }
        },
        // Вариант без дополнительных параметров
        {
          'url': '/reviews/$productId',
          'queryParams': {
            'id': productId,
            'page': 1,
          }
        },
        // Отдельный endpoint для отзывов с query параметром
        {
          'url': '/reviews',
          'queryParams': {'product_id': productId}
        },
        {
          'url': '/reviews',
          'queryParams': {'productId': productId}
        },
        // Endpoints с productId в пути (старые варианты)
        {
          'url': '/product/$productId/reviews',
          'queryParams': {}
        },
        {
          'url': '/reviews/product/$productId',
          'queryParams': {}
        },
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('[DEBUG] CatalogApi.getProductReviews: Пробуем endpoint: ${endpoint['url']} с параметрами: ${endpoint['queryParams']}');
          
          final response = await dio.get(
            endpoint['url'] as String,
            queryParameters: endpoint['queryParams'] as Map<String, dynamic>,
          );
          
          // Проверяем статус код
          if (response.statusCode != 200) {
            print('[DEBUG] CatalogApi.getProductReviews: HTTP статус ${response.statusCode} от ${endpoint['url']}, пропускаем');
            continue;
          }
          
          if (response.data != null) {
            final data = response.data;
            print('[DEBUG] CatalogApi.getProductReviews: Ответ от ${endpoint['url']}: ${data.runtimeType}');
            
            // Проверяем, что ответ не HTML (404 страница)
            if (data is String && (data.contains('<!DOCTYPE html>') || data.contains('<html'))) {
              print('[DEBUG] CatalogApi.getProductReviews: Ответ от ${endpoint['url']} - это HTML страница (404), пропускаем');
              continue;
            }
            
            List<dynamic> reviewsList = [];
            
            if (data is List) {
              reviewsList = data;
              print('[DEBUG] CatalogApi.getProductReviews: Ответ - это список из ${reviewsList.length} элементов');
            } else if (data is Map) {
              // Рекурсивная функция для поиска отзывов в структуре
              List<dynamic>? findReviewsInResponse(dynamic responseData, String path) {
                if (responseData == null) return null;
                
                if (responseData is List) {
                  // Если это список, проверяем, может ли это быть список отзывов
                  if (responseData.isNotEmpty && responseData.first is Map) {
                    final firstItem = responseData.first as Map;
                    final keys = firstItem.keys.toList();
                    // Исключаем известные не-отзывы
                    if (keys.any((k) => ['quantity', 'sku', 'price', 'inventory_attributes'].contains(k.toString().toLowerCase()))) {
                      print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path - это не отзывы (inventory/stock данные)');
                      return null;
                    }
                    // Проверяем, есть ли обязательные ключи отзыва: rating И (comment ИЛИ review ИЛИ user_name ИЛИ userName)
                    final hasRating = keys.any((k) => ['rating', 'rate', 'stars'].contains(k.toString().toLowerCase()));
                    final hasComment = keys.any((k) => ['comment', 'review', 'text', 'content', 'message'].contains(k.toString().toLowerCase()));
                    final hasUserName = keys.any((k) => ['user_name', 'username', 'name', 'user'].contains(k.toString().toLowerCase()));
                    
                    if (hasRating && (hasComment || hasUserName)) {
                      print('[DEBUG] CatalogApi.getProductReviews: Найден потенциальный список отзывов в $path (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                      return responseData;
                    } else {
                      print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path - недостаточно ключей отзыва (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                    }
                  }
                  return null;
                }
                
                if (responseData is Map) {
                  try {
                    // Безопасное преобразование Map
                    Map<String, dynamic> responseMap;
                    try {
                      responseMap = responseData.cast<String, dynamic>();
                    } catch (e) {
                      // Если не удалось преобразовать, пробуем другой способ
                      responseMap = Map<String, dynamic>.from(responseData);
                    }
                    
                    final keys = responseMap.keys.toList();
                    print('[DEBUG] CatalogApi.getProductReviews: Проверяем структуру в $path, ключи: $keys');
                    
                    // Проверяем прямые ключи для отзывов
                    // Реальная структура: data.all.data - список отзывов
                    if (responseMap['data'] is Map) {
                      final dataMap = responseMap['data'] as Map;
                      print('[DEBUG] CatalogApi.getProductReviews: Найден data в $path, ключи: ${dataMap.keys.toList()}');
                      
                      if (dataMap['all'] is Map) {
                        final allMap = dataMap['all'] as Map;
                        print('[DEBUG] CatalogApi.getProductReviews: Найден all в $path.data, ключи: ${allMap.keys.toList()}');
                        
                        if (allMap['data'] is List) {
                          final list = allMap['data'] as List;
                          print('[DEBUG] CatalogApi.getProductReviews: Найден data в $path.data.all, количество: ${list.length}');
                          if (list.isNotEmpty) {
                            print('[DEBUG] CatalogApi.getProductReviews: Первый элемент списка: ${list.first}');
                            print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.all.data: ${list.length}');
                            return list;
                          } else {
                            print('[DEBUG] CatalogApi.getProductReviews: Список data.all.data пуст');
                          }
                        } else {
                          print('[DEBUG] CatalogApi.getProductReviews: data.all.data не является List, тип: ${allMap['data'].runtimeType}');
                        }
                      } else {
                        print('[DEBUG] CatalogApi.getProductReviews: data.all не является Map, тип: ${dataMap['all'].runtimeType}');
                      }
                      // Также проверяем data.reviews или data.review
                      if (dataMap['reviews'] is List) {
                        final list = dataMap['reviews'] as List;
                        if (list.isNotEmpty) {
                          print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.reviews: ${list.length}');
                          return list;
                        }
                      }
                      if (dataMap['review'] is List) {
                        final list = dataMap['review'] as List;
                        if (list.isNotEmpty) {
                          print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.review: ${list.length}');
                          return list;
                        }
                      }
                    }
                    
                    // Проверяем другие возможные ключи
                    for (final key in ['reviews', 'review', 'product_reviews', 'product_review', 'reviews_list', 'review_list']) {
                      if (responseMap[key] is List) {
                        final list = responseMap[key] as List;
                        if (list.isNotEmpty) {
                          // Проверяем, может ли это быть список отзывов
                          if (list.first is Map) {
                            final firstItem = list.first as Map;
                            final itemKeys = firstItem.keys.toList();
                            // Исключаем известные не-отзывы
                            if (itemKeys.any((k) => ['quantity', 'sku', 'price', 'inventory_attributes'].contains(k.toString().toLowerCase()))) {
                              print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path.$key - это не отзывы (inventory/stock данные)');
                              continue;
                            }
                            // Проверяем, есть ли обязательные ключи отзыва: rating И (comment ИЛИ review ИЛИ user_name ИЛИ userName)
                            final hasRating = itemKeys.any((k) => ['rating', 'rate', 'stars'].contains(k.toString().toLowerCase()));
                            final hasComment = itemKeys.any((k) => ['comment', 'review', 'text', 'content', 'message'].contains(k.toString().toLowerCase()));
                            final hasUserName = itemKeys.any((k) => ['user_name', 'username', 'name', 'user'].contains(k.toString().toLowerCase()));
                            
                            if (hasRating && (hasComment || hasUserName)) {
                              print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.$key: ${list.length} (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                              return list;
                            } else {
                              print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path.$key - недостаточно ключей отзыва (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                            }
                          }
                        }
                      } else if (responseMap[key] is Map) {
                        // Рекурсивно ищем в вложенной структуре
                        final found = findReviewsInResponse(responseMap[key], '$path.$key');
                        if (found != null) return found;
                      }
                    }
                    
                    // Исключаем известные не-отзывы из рекурсивного поиска
                    final excludedKeys = ['inventory', 'stock', 'attributes', 'images', 'videos', 'category_data', 'current_categories', 'vouchers', 'shipping_rule', 'tax_rules', 'bundle_deal', 'store', 'brand'];
                    
                    // Рекурсивно ищем в других вложенных структурах
                    for (final key in keys) {
                      // Пропускаем исключенные ключи
                      if (excludedKeys.contains(key.toString().toLowerCase())) {
                        print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path.$key - исключенный ключ');
                        continue;
                      }
                      final value = responseMap[key];
                      if (value is Map || value is List) {
                        final found = findReviewsInResponse(value, '$path.$key');
                        if (found != null) return found;
                      }
                    }
                  } catch (e, stackTrace) {
                    print('[DEBUG] CatalogApi.getProductReviews: Ошибка при проверке структуры в $path: $e');
                    print('[DEBUG] CatalogApi.getProductReviews: Stack trace: $stackTrace');
                  }
                }
                
                return null;
              }
              
              // Ищем отзывы в структуре ответа
              final foundReviews = findReviewsInResponse(data, 'response');
              if (foundReviews != null) {
                reviewsList = foundReviews;
              }
            }
            
            if (reviewsList.isNotEmpty) {
              print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в ответе от ${endpoint['url']}: ${reviewsList.length}');
              if (reviewsList.isNotEmpty) {
                print('[DEBUG] CatalogApi.getProductReviews: Первый отзыв (сырые данные): ${reviewsList.first}');
              }
              final reviews = reviewsList
                  .where((r) => r is Map)
                  .map((r) {
                    try {
                      print('[DEBUG] CatalogApi.getProductReviews: Парсим отзыв: $r');
                      final reviewMap = (r as Map).cast<String, dynamic>();
                      print('[DEBUG] CatalogApi.getProductReviews: Ключи отзыва: ${reviewMap.keys.toList()}');
                      final review = Review.fromJson(reviewMap);
                      print('[DEBUG] CatalogApi.getProductReviews: Отзыв распарсен: id=${review.id}, rating=${review.rating}, comment=${review.comment}');
                      return review;
                    } catch (e, stackTrace) {
                      print('[ERROR] Ошибка парсинга отзыва: $e');
                      print('[ERROR] Stack trace: $stackTrace');
                      print('[ERROR] Данные отзыва: $r');
                      return null;
                    }
                  })
                  .whereType<Review>()
                  .toList();
              
              print('[DEBUG] CatalogApi.getProductReviews: Всего распарсено ${reviews.length} отзывов из ${reviewsList.length} из ${endpoint['url']}');
              if (reviews.isNotEmpty) {
                print('[DEBUG] ========== CatalogApi.getProductReviews: УСПЕХ (из ${endpoint['url']}) ==========');
                print('[DEBUG] CatalogApi.getProductReviews: Успешно распарсено ${reviews.length} отзывов из ${endpoint['url']}');
                for (var i = 0; i < reviews.length; i++) {
                  final r = reviews[i];
                  final commentPreview = r.comment != null && r.comment!.isNotEmpty
                      ? (r.comment!.length > 50 ? '${r.comment!.substring(0, 50)}...' : r.comment!)
                      : 'нет комментария';
                  print('[DEBUG] CatalogApi.getProductReviews: Отзыв $i: id=${r.id}, productId=${r.productId}, userName=${r.userName}, rating=${r.rating}, comment=$commentPreview');
                }
                return Ok(reviews);
              } else {
                print('[WARNING] CatalogApi.getProductReviews: Найдены отзывы в ${endpoint['url']}, но не удалось распарсить ни одного');
              }
            } else {
              print('[DEBUG] CatalogApi.getProductReviews: Отзывы не найдены в ответе от ${endpoint['url']}');
            }
          }
        } catch (e, stackTrace) {
          print('[DEBUG] CatalogApi.getProductReviews: Ошибка при запросе к ${endpoint['url']}: $e');
          print('[DEBUG] CatalogApi.getProductReviews: Stack trace: $stackTrace');
          // Продолжаем проверять другие endpoints
          continue;
        }
      }
      
      // Теперь пробуем получить отзывы из ответа детальной информации о товаре (как fallback)
      try {
        print('[DEBUG] CatalogApi.getProductReviews: Пробуем получить отзывы из ответа /product/$productId (fallback)');
        
        final productResponse = await dio.get('/product/$productId', queryParameters: {
          'id': productId,
          'user_id': userId ?? '',
        });
        
        print('[DEBUG] CatalogApi.getProductReviews: HTTP статус: ${productResponse.statusCode}');
        print('[DEBUG] CatalogApi.getProductReviews: Тип ответа: ${productResponse.data.runtimeType}');
        if (productResponse.data is Map) {
          print('[DEBUG] CatalogApi.getProductReviews: Ключи корневого объекта: ${(productResponse.data as Map).keys.toList()}');
        }
        print('[DEBUG] CatalogApi.getProductReviews: Полный ответ от /product/$productId: ${productResponse.data}');
        
        if (productResponse.statusCode == 200 && productResponse.data != null) {
          final productData = productResponse.data;
          
          // Рекурсивная функция для поиска отзывов в структуре
          List<dynamic>? findReviewsInStructure(dynamic data, String path) {
            if (data == null) return null;
            
            if (data is List) {
              // Если это список, проверяем, может ли это быть список отзывов
              if (data.isNotEmpty && data.first is Map) {
                final firstItem = data.first as Map;
                final keys = firstItem.keys.toList();
                // Исключаем известные не-отзывы
                if (keys.any((k) => ['quantity', 'sku', 'price', 'inventory_attributes'].contains(k.toString().toLowerCase()))) {
                  print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path - это не отзывы (inventory/stock данные)');
                  return null;
                }
                // Проверяем, есть ли обязательные ключи отзыва: rating И (comment ИЛИ review ИЛИ user_name ИЛИ userName)
                final hasRating = keys.any((k) => ['rating', 'rate', 'stars'].contains(k.toString().toLowerCase()));
                final hasComment = keys.any((k) => ['comment', 'review', 'text', 'content', 'message'].contains(k.toString().toLowerCase()));
                final hasUserName = keys.any((k) => ['user_name', 'username', 'name', 'user'].contains(k.toString().toLowerCase()));
                
                if (hasRating && (hasComment || hasUserName)) {
                  print('[DEBUG] CatalogApi.getProductReviews: Найден потенциальный список отзывов в $path (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                  return data;
                } else {
                  print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path - недостаточно ключей отзыва (hasRating=$hasRating, hasComment=$hasComment, hasUserName=$hasUserName)');
                }
              }
              return null;
            }
            
            if (data is Map) {
              try {
                // Безопасное преобразование Map
                Map<String, dynamic> dataMap;
                try {
                  dataMap = data.cast<String, dynamic>();
                } catch (e) {
                  // Если не удалось преобразовать, пробуем другой способ
                  dataMap = Map<String, dynamic>.from(data);
                }
                
                final keys = dataMap.keys.toList();
                print('[DEBUG] CatalogApi.getProductReviews: Проверяем структуру в $path, ключи: $keys');
                
                // Проверяем реальную структуру: data.all.data
                if (dataMap['data'] is Map) {
                  final innerDataMap = dataMap['data'] as Map;
                  print('[DEBUG] CatalogApi.getProductReviews: Найден data в $path, ключи: ${innerDataMap.keys.toList()}');
                  
                  if (innerDataMap['all'] is Map) {
                    final allMap = innerDataMap['all'] as Map;
                    print('[DEBUG] CatalogApi.getProductReviews: Найден all в $path.data, ключи: ${allMap.keys.toList()}');
                    
                    if (allMap['data'] is List) {
                      final list = allMap['data'] as List;
                      print('[DEBUG] CatalogApi.getProductReviews: Найден data в $path.data.all, количество: ${list.length}');
                      if (list.isNotEmpty) {
                        print('[DEBUG] CatalogApi.getProductReviews: Первый элемент списка: ${list.first}');
                        print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.all.data: ${list.length}');
                        return list;
                      } else {
                        print('[DEBUG] CatalogApi.getProductReviews: Список data.all.data пуст');
                      }
                    } else {
                      print('[DEBUG] CatalogApi.getProductReviews: data.all.data не является List, тип: ${allMap['data']?.runtimeType}');
                    }
                  } else {
                    print('[DEBUG] CatalogApi.getProductReviews: data.all не является Map, тип: ${innerDataMap['all']?.runtimeType}');
                  }
                  // Также проверяем data.reviews или data.review
                  if (innerDataMap['reviews'] is List) {
                    final list = innerDataMap['reviews'] as List;
                    if (list.isNotEmpty) {
                      print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.reviews: ${list.length}');
                      return list;
                    }
                  }
                  if (innerDataMap['review'] is List) {
                    final list = innerDataMap['review'] as List;
                    if (list.isNotEmpty) {
                      print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.data.review: ${list.length}');
                      return list;
                    }
                  }
                }
                
                // Проверяем прямые ключи для отзывов
                for (final key in ['reviews', 'review', 'product_reviews', 'product_review', 'reviews_list', 'review_list']) {
                  if (dataMap[key] is List) {
                    final list = dataMap[key] as List;
                    if (list.isNotEmpty) {
                      print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в $path.$key: ${list.length}');
                      return list;
                    }
                  }
                }
                
                // Исключаем известные не-отзывы из рекурсивного поиска
                final excludedKeys = ['inventory', 'stock', 'attributes', 'images', 'videos', 'category_data', 'current_categories', 'vouchers', 'shipping_rule', 'tax_rules', 'bundle_deal', 'store', 'brand'];
                
                // Рекурсивно ищем в вложенных структурах
                for (final key in keys) {
                  // Пропускаем исключенные ключи
                  if (excludedKeys.contains(key.toString().toLowerCase())) {
                    print('[DEBUG] CatalogApi.getProductReviews: Пропускаем $path.$key - исключенный ключ');
                    continue;
                  }
                  final value = dataMap[key];
                  if (value is Map || value is List) {
                    final found = findReviewsInStructure(value, '$path.$key');
                    if (found != null) return found;
                  }
                }
              } catch (e, stackTrace) {
                print('[DEBUG] CatalogApi.getProductReviews: Ошибка при проверке структуры в $path: $e');
                print('[DEBUG] CatalogApi.getProductReviews: Stack trace: $stackTrace');
              }
            }
            
            return null;
          }
          
          // Ищем отзывы в структуре ответа
          final reviewsList = findReviewsInStructure(productData, 'root');
          
          if (reviewsList != null && reviewsList.isNotEmpty) {
            print('[DEBUG] CatalogApi.getProductReviews: Найдены отзывы в ответе product/$productId: ${reviewsList.length}');
            print('[DEBUG] CatalogApi.getProductReviews: Первый отзыв (сырые данные): ${reviewsList.first}');
            
            final reviews = reviewsList
                .where((r) => r is Map)
                .map((r) {
                  try {
                    print('[DEBUG] CatalogApi.getProductReviews: Парсим отзыв: $r');
                    final reviewMap = (r as Map).cast<String, dynamic>();
                    print('[DEBUG] CatalogApi.getProductReviews: Ключи отзыва: ${reviewMap.keys.toList()}');
                    final review = Review.fromJson(reviewMap);
                    print('[DEBUG] CatalogApi.getProductReviews: Отзыв распарсен: id=${review.id}, rating=${review.rating}, comment=${review.comment}');
                    return review;
                  } catch (e, stackTrace) {
                    print('[ERROR] Ошибка парсинга отзыва: $e');
                    print('[ERROR] Stack trace: $stackTrace');
                    print('[ERROR] Данные отзыва: $r');
                    return null;
                  }
                })
                .whereType<Review>()
                .toList();
            
            print('[DEBUG] CatalogApi.getProductReviews: Всего распарсено ${reviews.length} отзывов из ${reviewsList.length}');
            if (reviews.isNotEmpty) {
              print('[DEBUG] ========== CatalogApi.getProductReviews: УСПЕХ (из product/$productId) ==========');
              print('[DEBUG] CatalogApi.getProductReviews: Успешно распарсено ${reviews.length} отзывов из ответа product/$productId');
              for (var i = 0; i < reviews.length; i++) {
                final r = reviews[i];
                final commentPreview = r.comment != null && r.comment!.isNotEmpty
                    ? (r.comment!.length > 50 ? '${r.comment!.substring(0, 50)}...' : r.comment!)
                    : 'нет комментария';
                print('[DEBUG] CatalogApi.getProductReviews: Отзыв $i: id=${r.id}, productId=${r.productId}, userName=${r.userName}, rating=${r.rating}, comment=$commentPreview');
              }
              return Ok(reviews);
            } else {
              print('[WARNING] CatalogApi.getProductReviews: Найдены отзывы, но не удалось распарсить ни одного');
            }
          } else {
            print('[DEBUG] CatalogApi.getProductReviews: Отзывы не найдены в ответе product/$productId');
          }
        }
      } catch (e, stackTrace) {
        print('[DEBUG] CatalogApi.getProductReviews: Не удалось получить отзывы из product/$productId: $e');
        print('[DEBUG] CatalogApi.getProductReviews: Stack trace: $stackTrace');
        // Продолжаем проверять другие endpoints
      }
      
      // Если ни один эндпоинт не сработал, возвращаем ошибку
      print('[DEBUG] ========== CatalogApi.getProductReviews: КОНЕЦ (не найдено) ==========');
      print('[DEBUG] CatalogApi.getProductReviews: Отзывы не найдены ни в одном endpoint');
      print('[DEBUG] CatalogApi.getProductReviews: Проверьте в Network tab браузера, какой endpoint используется на сайте для получения отзывов');
      return Err('Отзывы не найдены. Проверьте, какой endpoint используется на сайте для получения отзывов товара $productId');
    } catch (e, stackTrace) {
      print('[DEBUG] ========== CatalogApi.getProductReviews: ОШИБКА ==========');
      print('[DEBUG] CatalogApi.getProductReviews: Общая ошибка: $e');
      print('[DEBUG] CatalogApi.getProductReviews: Stack trace: $stackTrace');
      return Err('Ошибка получения отзывов: ${e.toString()}');
    }
  }

  // Новый метод для получения описания товара через API
  Future<Result<Map<String, dynamic>?>> getProductDescription(int id) async {
    try {
      print('[DEBUG] Запрос описания для товара ID: $id');
      
      // Пробуем разные API эндпоинты для получения описания
      final endpoints = [
        '/api/v1/product/$id', // Используем API эндпоинт, который возвращает JSON
        '/product/$id', // Используем тот же эндпоинт, что и в productById
        '/api/v1/product/$id/description',
        '/api/v1/product/$id/details',
        '/api/v1/product/$id/content',
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('[DEBUG] Пробуем эндпоинт: $endpoint');
          final response = endpoint == '/product/$id' 
            ? await dio.get(endpoint, queryParameters: {'id': id, 'user_id': ''})
            : await dio.get(endpoint);
          
          if (response.statusCode == 200) {
            final data = response.data;
            
            // Проверяем, что ответ - это JSON, а не HTML
            if (data is Map<String, dynamic>) {
              print('[DEBUG] Ответ от $endpoint: ${data.keys}');
              
              // Обрабатываем структуру данных как в productById
              Map<String, dynamic>? obj;
              if (data['data'] is Map) {
                obj = (data['data'] as Map).cast<String, dynamic>();
                print('[DEBUG] Найдены данные в поле data: ${obj.keys}');
              } else if (data is Map) {
                obj = data.cast<String, dynamic>();
                print('[DEBUG] Используем данные напрямую: ${obj.keys}');
              }
              
              if (obj != null) {
                print('[DEBUG] Обрабатываем данные товара: ${obj.keys}');
                
                // Ищем описание в различных полях
                for (final key in ['description', 'content', 'details', 'product_description', 'long_description', 'summary', 'about', 'text', 'body']) {
                  if (obj[key] != null && obj[key].toString().trim().isNotEmpty) {
                    final rawDescription = obj[key].toString().trim();
                    print('[DEBUG] Найдено описание в поле $key: ${rawDescription.substring(0, rawDescription.length > 200 ? 200 : rawDescription.length)}...');
                    print('[DEBUG] Полное сырое описание: $rawDescription');
                    
                    // Извлекаем изображения из HTML
                    final imageUrls = <String>[];
                    final imgRegex = RegExp('<img[^>]+src=["\']([^"\']+)["\'][^>]*>', caseSensitive: false);
                    final matches = imgRegex.allMatches(rawDescription);
                    
                    for (final match in matches) {
                      final imageUrl = match.group(1);
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        // Преобразуем относительные URL в абсолютные
                        final fullUrl = imageUrl.startsWith('http') 
                            ? imageUrl 
                            : 'https://ssboss.shop${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
                        imageUrls.add(fullUrl);
                        print('[DEBUG] Найдено изображение в описании: $fullUrl');
                      }
                    }
                    
                    // Очищаем HTML теги для текста
                    final cleanDescription = rawDescription
                        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Убираем все HTML теги
                        .replaceAll(RegExp(r'\s+'), ' ') // Заменяем множественные пробелы на одинарные
                        .trim(); // Убираем пробелы в начале и конце
                    
                    print('[DEBUG] Очищенное описание: ${cleanDescription.substring(0, cleanDescription.length > 200 ? 200 : cleanDescription.length)}...');
                    print('[DEBUG] Найдено изображений в описании: ${imageUrls.length}');
                    
                    // Возвращаем структуру с описанием и изображениями
                    return Ok({'description': cleanDescription, 'images': imageUrls});
                  }
                }
              }
            } else {
              print('[DEBUG] Ответ от $endpoint не является JSON (тип: ${data.runtimeType})');
            }
          }
        } catch (e) {
          print('[DEBUG] Ошибка для $endpoint: $e');
        }
      }
      
      print('[DEBUG] Описание не найдено ни в одном эндпоинте');
      return const Ok(null);
    } catch (e) {
      print('[DEBUG] Ошибка при получении описания: $e');
      return Err(e.toString());
    }
  }

  /// Получение данных главной страницы с баннерами и слайдерами
  Future<Result<HomePageData>> getHomePageData() async {
    try {
      print('[DEBUG] Запрос данных главной страницы...');
      
      final endpoints = [
        '/home',
        '/api/v1/home',
        '/api/home',
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('[DEBUG] Пробуем endpoint: $endpoint');
          final response = await dio.get(endpoint);
          
          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            
            if (data is Map<String, dynamic>) {
              // Проверяем структуру data.data
              Map<String, dynamic>? dataMap;
              if (data['data'] is Map<String, dynamic>) {
                dataMap = data['data'] as Map<String, dynamic>;
              } else {
                dataMap = data;
              }
              
              if (dataMap != null) {
                print('[DEBUG] Ключи в dataMap: ${dataMap.keys.toList()}');
                
                // Создаем HomePageData из структуры
                final homePageData = HomePageData.fromJson(dataMap);
                
                print('[DEBUG] Загружено главных слайдеров: ${homePageData.mainSliders.length}');
                print('[DEBUG] Загружено баннеров: ${homePageData.banners.length}');
                
                return Ok(homePageData);
              }
            }
          }
        } catch (e) {
          print('[DEBUG] Ошибка для endpoint $endpoint: $e');
          continue;
        }
      }
      
      // Если ничего не найдено, возвращаем пустые данные
      return Ok(const HomePageData(mainSliders: [], banners: [], brands: []));
    } catch (e) {
      print('[ERROR] Ошибка при получении данных главной страницы: $e');
      return Err('Ошибка при загрузке данных главной страницы: $e');
    }
  }

  /// Получение списка брендов
  Future<Result<List<Brand>>> getBrands({int page = 1}) async {
    try {
      print('[DEBUG] Запрос списка брендов (страница $page)...');
      
      // Базовый URL уже содержит /api/v1, поэтому используем просто /brands
      final response = await dio.get('/brands', queryParameters: {
        'page': page.toString(),
      });
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        print('[DEBUG] Ответ от /brands: ${data.runtimeType}');
        print('[DEBUG] Ключи в ответе: ${data is Map ? (data as Map).keys.toList() : 'не Map'}');
        
        List<Brand> brands = [];
        
        if (data is Map<String, dynamic>) {
          // Проверяем структуру data.data (согласно JSON из примера)
          Map<String, dynamic>? dataMap;
          if (data['data'] is Map<String, dynamic>) {
            dataMap = data['data'] as Map<String, dynamic>;
            print('[DEBUG] Ключи в data.data: ${dataMap.keys.toList()}');
            
            // Согласно JSON: data.data.data - это список брендов
            if (dataMap['data'] is List) {
              final brandsList = dataMap['data'] as List;
              print('[DEBUG] Найдено ${brandsList.length} брендов в data.data.data');
              
              brands = brandsList
                  .where((item) => item is Map<String, dynamic>)
                  .map((item) {
                    try {
                      // Адаптируем структуру API к модели Brand
                      final json = item as Map<String, dynamic>;
                      print('[DEBUG] Парсинг бренда: title=${json['title']}, image=${json['image']}');
                      return Brand(
                        id: (json['id'] ?? 0) as int,
                        name: (json['title'] ?? '').toString(),
                        logo: (json['image'] ?? '').toString(),
                        slug: json['slug']?.toString(),
                        status: 1,
                      );
                    } catch (e) {
                      print('[ERROR] Ошибка парсинга бренда: $e, данные: $item');
                      return null;
                    }
                  })
                  .whereType<Brand>()
                  .where((brand) => brand.logo.isNotEmpty && brand.name.isNotEmpty)
                  .toList();
            } else {
              print('[DEBUG] data.data.data не является List, тип: ${dataMap['data'].runtimeType}');
            }
          } else {
            print('[DEBUG] data.data не является Map, тип: ${data['data'].runtimeType}');
          }
        } else {
          print('[DEBUG] Ответ не является Map, тип: ${data.runtimeType}');
        }
        
        print('[DEBUG] Загружено брендов: ${brands.length}');
        return Ok(brands);
      }
      
      return Err('Не удалось получить список брендов: ${response.statusCode}');
    } catch (e) {
      print('[ERROR] Ошибка при получении списка брендов: $e');
      return Err('Ошибка при загрузке брендов: $e');
    }
  }

  /// Получение Flash Sale (Hot Deals)
  Future<Result<List<FlashSale>>> getFlashSale() async {
    try {
      print('[DEBUG] Запрос Flash Sale...');
      
      final response = await dio.get('/flash-sale');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        print('[DEBUG] Ответ от /flash-sale: ${data.runtimeType}');
        
        List<FlashSale> flashSales = [];
        
        if (data is Map<String, dynamic>) {
          if (data['data'] is List) {
            final flashSalesList = data['data'] as List;
            print('[DEBUG] Найдено ${flashSalesList.length} flash sales');
            
            flashSales = flashSalesList
                .where((item) => item is Map<String, dynamic>)
                .map((item) {
                  try {
                    return FlashSale.fromJson(item as Map<String, dynamic>);
                  } catch (e) {
                    print('[ERROR] Ошибка парсинга flash sale: $e');
                    return null;
                  }
                })
                .whereType<FlashSale>()
                .toList();
          }
        }
        
        print('[DEBUG] Успешно загружено ${flashSales.length} flash sales');
        return Ok(flashSales);
      }
      
      return Err('Не удалось получить Flash Sale: ${response.statusCode}');
    } catch (e) {
      print('[ERROR] Ошибка при получении Flash Sale: $e');
      return Err('Ошибка при загрузке Flash Sale: $e');
    }
  }
}

