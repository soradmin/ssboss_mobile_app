import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';

/// Коды языков приложения.
class AppLocale {
  static const ru = 'ru';
  static const tg = 'tg';
  static const supported = [ru, tg];
  static const prefsKey = 'app_locale';
}

class LocaleState {
  final String code;
  final Map<String, dynamic> strings;

  const LocaleState({required this.code, required this.strings});

  String get languageHeader => code == AppLocale.tg ? 'tg' : 'ru';
}

class LocaleController extends StateNotifier<LocaleState> {
  LocaleController() : super(const LocaleState(code: AppLocale.ru, strings: {}));

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppLocale.prefsKey);
    final code = AppLocale.supported.contains(saved) ? saved! : AppLocale.ru;
    await _load(code);
  }

  Future<void> setLocale(String code) async {
    if (!AppLocale.supported.contains(code) || code == state.code) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppLocale.prefsKey, code);
    await _load(code);
  }

  Future<void> _load(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/translations/$code.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = LocaleState(code: code, strings: map);
      dio.options.headers['language'] = code == AppLocale.tg ? 'tg' : 'ru';
      debugPrint('[L10n] Loaded locale=$code');
    } catch (e) {
      debugPrint('[L10n] Failed to load $code: $e');
      if (code != AppLocale.ru) {
        await _load(AppLocale.ru);
      }
    }
  }

  String tr(String key, {Map<String, String>? namedArgs}) {
    final value = _resolve(state.strings, key);
    if (value == null) return key;
    var text = value;
    if (namedArgs != null) {
      namedArgs.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  String? _resolve(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic cur = map;
    for (final p in parts) {
      if (cur is Map<String, dynamic> && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur?.toString();
  }
}

final localeControllerProvider =
    StateNotifierProvider<LocaleController, LocaleState>((ref) {
  return LocaleController();
});

/// Удобный доступ: `ref.tr('nav.home')` или `context.tr('nav.home')`.
extension LocaleTrRef on WidgetRef {
  String tr(String key, {Map<String, String>? namedArgs}) {
    return read(localeControllerProvider.notifier).tr(key, namedArgs: namedArgs);
  }
}

extension LocaleTrContext on BuildContext {
  String tr(String key, {Map<String, String>? namedArgs}) {
    // Через ProviderScope — безопасный доступ без ref.
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      return container
          .read(localeControllerProvider.notifier)
          .tr(key, namedArgs: namedArgs);
    } catch (_) {
      return key;
    }
  }
}
