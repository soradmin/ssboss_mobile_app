import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';

class ServerCartLine {
  final int id;
  final int productId;
  final int inventoryId;
  final int quantity;

  // обогащение для UI
  final String name;
  final String image;
  final double price;

  ServerCartLine({
    required this.id,
    required this.productId,
    required this.inventoryId,
    required this.quantity,
    this.name = '',
    this.image = '',
    this.price = 0.0,
  });

  ServerCartLine copyWith({String? name, String? image, double? price}) => ServerCartLine(
    id: id,
    productId: productId,
    inventoryId: inventoryId,
    quantity: quantity,
    name: name ?? this.name,
    image: image ?? this.image,
    price: price ?? this.price,
  );
}

class CartApi {
  /// Уже есть у тебя — добавление в серверную корзину
  Future<Result<void>> add(int productId, int qty) async {
    try {
      final invId = await _getInventoryId(productId);
      if (invId == null) return const Err('Не найден inventory_id');

      final res = await dio.post(
        '/cart/action',
        queryParameters: {'user_token': AppConfig.guestToken},
        data: {'product_id': productId, 'inventory_id': invId, 'quantity': qty},
      );
      return res.statusCode == 200 ? const Ok(null) : Err('HTTP ${res.statusCode}');
    } on DioException catch (e) {
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }

  /// 👇 Новое: чтение серверной корзины
  Future<Result<List<ServerCartLine>>> getCart() async {
    try {
      final res = await dio.get('/cart', queryParameters: {'user_token': AppConfig.guestToken});
      final data = res.data;

      // Ищем массив строк корзины в типичных местах
      List list = const [];
      if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else if (data is Map && data['data'] is Map && (data['data'] as Map)['cart'] is List) {
        list = (data['data'] as Map)['cart'] as List;
      } else if (data is List) {
        list = data;
      }

      // Грубый парс базовых полей
      final lines = list.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return ServerCartLine(
          id: int.tryParse('${m['id'] ?? 0}') ?? 0,
          productId: int.tryParse('${m['product_id'] ?? m['productId'] ?? 0}') ?? 0,
          inventoryId: int.tryParse('${m['inventory_id'] ?? m['inventoryId'] ?? 0}') ?? 0,
          quantity: int.tryParse('${m['quantity'] ?? m['qty'] ?? 0}') ?? 0,
          // иногда API сразу отдаёт product/name/price/image — попробуем вытащить
          name: (m['product']?['name'] ?? m['name'] ?? '').toString(),
          image: (m['product']?['image'] ?? m['image'] ?? '').toString(),
          price: _toDouble(m['product']?['price'] ?? m['price'] ?? 0),
        );
      }).toList();

      // Обогатим тем, чего не хватает (имя/картинка/цена) — дотянем из Product API
      final enriched = <ServerCartLine>[];
      for (final ln in lines) {
        if (ln.name.isNotEmpty && ln.image.isNotEmpty && ln.price > 0) {
          enriched.add(ln);
          continue;
        }
        final details = await _getProductDetails(ln.productId);
        if (details == null) {
          enriched.add(ln);
        } else {
          enriched.add(ln.copyWith(
            name: details['name'] ?? ln.name,
            image: details['image'] ?? ln.image,
            price: details['price'] ?? ln.price,
          ));
        }
      }

      return Ok(enriched);
    } on DioException catch (e) {
      return Err(e.response?.data?.toString() ?? e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }

  // ---- helpers ----

  Future<int?> _getInventoryId(int productId) async {
    // пробуем два распространённых пути
    final paths = ['/products/$productId', '/product/$productId'];
    for (final p in paths) {
      try {
        final r = await dio.get(p);
        final d = r.data;
        List? invs;
        if (d is Map && d['data'] is Map) {
          final mm = d['data'] as Map;
          invs = (mm['inventories'] as List?) ?? (mm['inventory'] as List?);
        } else if (d is Map && d['inventories'] is List) {
          invs = d['inventories'] as List;
        }
        if (invs != null && invs.isNotEmpty) {
          final first = invs.first;
          if (first is Map && first['id'] != null) {
            return int.tryParse('${first['id']}');
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getProductDetails(int id) async {
    try {
      final paths = ['/products/$id', '/product/$id'];
      for (final p in paths) {
        try {
          final r = await dio.get(p);
          final d = r.data;
          Map? m;
          if (d is Map && d['data'] is Map) m = d['data'] as Map;
          else if (d is Map) m = d;
          if (m != null) {
            final name = (m['name'] ?? m['title'] ?? '').toString();
            final image = (m['image'] ?? m['thumbnail'] ?? m['thumb'] ?? '').toString();
            final price = _toDouble(m['price'] ?? m['offered'] ?? m['selling'] ?? 0);
            return {'name': name, 'image': _fullImageUrl(image), 'price': price};
          }
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _fullImageUrl(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    final base = AppConfig.cdnBaseUrl.isNotEmpty
        ? AppConfig.cdnBaseUrl
        : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base$path';
  }

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
}
