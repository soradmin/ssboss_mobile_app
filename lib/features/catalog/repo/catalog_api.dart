import 'package:dio/dio.dart';
import '../../../core/api_client.dart';
import '../../../core/result.dart';
import '../../../core/config.dart';
import '../models/product.dart';

class CatalogApi {
  Future<Result<List<Product>>> products({int page = 1}) async {
    try {
      final res = await dio.get('/products', queryParameters: {'page': page});
      final data = res.data;

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
        if (raw.isEmpty) return '';
        if (raw.startsWith('http')) return raw;
        final base = AppConfig.cdnBaseUrl.isNotEmpty
            ? AppConfig.cdnBaseUrl
            : AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?v?\d*/*$'), '');
        final path = raw.startsWith('/') ? raw : '/$raw';
        return '$base$path';
      }

      final items = list.map((e) => Product.fromJson(e as Map<String, dynamic>)).map((p) => Product(
        id: p.id, name: p.name, image: _imgUrl(p.image), price: p.price, oldPrice: p.oldPrice, rating: p.rating
      )).toList();

      return Ok(items);
    } on DioException catch (e) {
      return Err(e.message ?? 'Network error');
    } catch (e) {
      return Err(e.toString());
    }
  }
}
