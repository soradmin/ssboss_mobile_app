// lib/crypto/aes_zero.dart
import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;

/// Ключ/IV — из веба (тот самый ZeroPadding CBC)
const _keyHex = '0123456470abcdef0123456789abcdef';
const _ivHex  = 'abcdef1876343516abcdef9876543210';

String _zeroPadUtf8(String s) {
  final b = utf8.encode(s);
  final r = b.length % 16;
  if (r == 0) return s;
  return s + String.fromCharCodes(List.filled(16 - r, 0));
}

String _stripZeroPadding(List<int> bytes) {
  var i = bytes.length;
  while (i > 0 && bytes[i - 1] == 0) i--;
  return utf8.decode(bytes.sublist(0, i));
}

/// Шифрование в формат, который ждёт API: base64(AES-CBC(ZeroPadding))
String encryptMap(Map<String, dynamic> payload) {
  final key = enc.Key.fromBase16(_keyHex);
  final iv  = enc.IV.fromBase16(_ivHex);
  final aes = enc.AES(key, mode: enc.AESMode.cbc, padding: null);
  final encrypter = enc.Encrypter(aes);

  final jsonStr = jsonEncode(payload);
  final padded  = _zeroPadUtf8(jsonStr);
  final encrypted = encrypter.encryptBytes(utf8.encode(padded), iv: iv);
  return base64.encode(encrypted.bytes);
}

/// Расшифровка — удобно для локальной отладки
String decryptB64(String cipherB64) {
  final key = enc.Key.fromBase16(_keyHex);
  final iv  = enc.IV.fromBase16(_ivHex);
  final aes = enc.AES(key, mode: enc.AESMode.cbc, padding: null);
  final encrypter = enc.Encrypter(aes);

  final bytes = encrypter.decryptBytes(enc.Encrypted.fromBase64(cipherB64), iv: iv);
  return _stripZeroPadding(bytes);
}
