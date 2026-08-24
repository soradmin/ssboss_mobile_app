import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/l10n/locale_controller.dart';
import '../../app_router.dart';

/// Данные о актуальной версии с сервера (`/app-version.json`).
class AppVersionInfo {
  final String latestVersion;
  final int latestBuild;
  final String minVersion;
  final int minBuild;
  final bool forceUpdate;
  final String androidStoreUrl;
  final String iosStoreUrl;
  final String message;

  const AppVersionInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minVersion,
    required this.minBuild,
    required this.forceUpdate,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    required this.message,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: (json['latest_version'] ?? '0.0.0').toString(),
      latestBuild: _asInt(json['latest_build']),
      minVersion: (json['min_version'] ?? '0.0.0').toString(),
      minBuild: _asInt(json['min_build']),
      forceUpdate: json['force_update'] == true,
      androidStoreUrl: (json['android_store_url'] ?? '').toString(),
      iosStoreUrl: (json['ios_store_url'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String get storeUrl {
    if (kIsWeb) return androidStoreUrl;
    if (Platform.isIOS) {
      return iosStoreUrl.isNotEmpty ? iosStoreUrl : androidStoreUrl;
    }
    return androidStoreUrl.isNotEmpty ? androidStoreUrl : iosStoreUrl;
  }
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _prefsSkipKey = 'app_update_skipped';
  static const _androidPackageId = 'com.ssboss.ssbossmp';
  bool _checkedThisSession = false;

  /// Сравнение semver: `a < b` → отрицательное.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split(RegExp(r'[^0-9]+'))
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final pa = parts(a);
    final pb = parts(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  Future<AppVersionInfo?> fetchRemoteVersion() async {
    final urls = <String>[
      '${AppConfig.cdnBaseUrl}/app-version.json',
      '${AppConfig.apiBaseUrl}/app-version',
    ];

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/json'},
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    for (final url in urls) {
      try {
        final res = await dio.get(url);
        if (res.statusCode == 200 && res.data != null) {
          final data = res.data is Map<String, dynamic>
              ? res.data as Map<String, dynamic>
              : jsonDecode(res.data is String ? res.data as String : '{}')
                  as Map<String, dynamic>;
          if (data['data'] is Map<String, dynamic>) {
            return AppVersionInfo.fromJson(data['data'] as Map<String, dynamic>);
          }
          return AppVersionInfo.fromJson(data);
        }
      } catch (e) {
        debugPrint('[AppUpdate] fetch $url failed: $e');
      }
    }
    return null;
  }

  Future<bool> _wasSkipped(String latestVersion, int latestBuild) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_prefsSkipKey);
    return skipped == '$latestVersion+$latestBuild';
  }

  Future<void> skipVersion(String latestVersion, int latestBuild) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSkipKey, '$latestVersion+$latestBuild');
  }

  /// Открыть магазин приложений (с запасными URL).
  Future<bool> openStore(AppVersionInfo remote) async {
    final candidates = <Uri>[];

    if (!kIsWeb && Platform.isAndroid) {
      candidates.add(Uri.parse('market://details?id=$_androidPackageId'));
      final https = remote.androidStoreUrl.isNotEmpty
          ? remote.androidStoreUrl
          : 'https://play.google.com/store/apps/details?id=$_androidPackageId';
      candidates.add(Uri.parse(https));
    } else if (!kIsWeb && Platform.isIOS) {
      if (remote.iosStoreUrl.isNotEmpty) {
        candidates.add(Uri.parse(remote.iosStoreUrl));
      }
      candidates.add(Uri.parse('https://apps.apple.com/app/id6759483309'));
      candidates.add(Uri.parse('https://apps.apple.com/search?term=SSBOSS'));
    } else if (remote.storeUrl.isNotEmpty) {
      candidates.add(Uri.parse(remote.storeUrl));
    }

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('[AppUpdate] launch $uri failed: $e');
      }
    }
    return false;
  }

  /// Проверить обновление и показать диалог при необходимости.
  Future<void> checkAndPrompt([BuildContext? context]) async {
    if (_checkedThisSession || kIsWeb) return;
    _checkedThisSession = true;

    try {
      final remote = await fetchRemoteVersion();
      if (remote == null) return;

      final info = await PackageInfo.fromPlatform();
      final localVersion = info.version;
      final localBuild = int.tryParse(info.buildNumber) ?? 0;

      final minCmp = compareVersions(localVersion, remote.minVersion);
      final latestCmp = compareVersions(localVersion, remote.latestVersion);

      final belowMin = minCmp < 0 ||
          (minCmp == 0 && localBuild < remote.minBuild);
      final belowLatest = latestCmp < 0 ||
          (latestCmp == 0 && localBuild < remote.latestBuild);

      if (!belowLatest && !belowMin) {
        debugPrint(
          '[AppUpdate] Актуальная версия: $localVersion+$localBuild',
        );
        return;
      }

      final force = remote.forceUpdate || belowMin;
      if (!force &&
          await _wasSkipped(remote.latestVersion, remote.latestBuild)) {
        debugPrint('[AppUpdate] Пользователь уже отложил это обновление');
        return;
      }

      final dialogContext = rootNavigatorKey.currentContext ?? context;
      if (dialogContext == null || !dialogContext.mounted) return;

      await _showDialog(
        dialogContext,
        remote: remote,
        localVersion: localVersion,
        localBuild: localBuild,
        force: force,
      );
    } catch (e) {
      debugPrint('[AppUpdate] check error: $e');
    }
  }

  Future<void> _showDialog(
    BuildContext context, {
    required AppVersionInfo remote,
    required String localVersion,
    required int localBuild,
    required bool force,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) {
        return PopScope(
          canPop: !force,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF9C27B0),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ctx.tr('update.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remote.message.isNotEmpty
                        ? remote.message
                        : ctx.tr('update.message'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ctx.tr(
                      'update.your_version',
                      namedArgs: {
                        'local': '$localVersion ($localBuild)',
                        'remote':
                            '${remote.latestVersion} (${remote.latestBuild})',
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final ok = await openStore(remote);
                        if (!ctx.mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(ctx.tr('update.store_failed')),
                            ),
                          );
                        }
                        // Даже при force не блокируем пользователя навсегда,
                        // если магазин не открылся — диалог можно закрыть.
                        if ((!force || !ok) && ctx.mounted) {
                          Navigator.of(ctx).pop();
                        }
                      },
                      child: Text(
                        ctx.tr('update.update'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Как на Авито: всегда даём мягкий отказ, кроме жёсткого force.
                  // Даже при force показываем «Нет, спасибо», чтобы не запирать UI,
                  // если кнопка «Обновить» не открыла магазин.
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF3E8FF),
                        foregroundColor: const Color(0xFF7B1FA2),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await skipVersion(
                          remote.latestVersion,
                          remote.latestBuild,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(
                        ctx.tr('update.no_thanks'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
