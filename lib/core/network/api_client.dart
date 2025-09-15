import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../crypto/aes_zero.dart';

class ApiClient {
  final String base = dotenv.get('API_BASE');

  Future<http.Response> postEncrypted(String path, Map<String, dynamic> payload) {
    final data = encryptMap(payload);
    final uri  = Uri.parse('$base$path');
    return http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': data}),
    );
  }
}
