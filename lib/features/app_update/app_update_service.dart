import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
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
      message: (json['message'] ??
              'Доступна новая версия приложения. Обновите его в магазине.')
          .toString(),
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

      final dialogContext =
          rootNavigatorKey.currentContext ?? context;
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
    final storeName = (!kIsWeb && Platform.isIOS) ? 'App Store' : 'Google Play';

    return showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) {
        return PopScope(
          canPop: !force,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Доступно обновление',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remote.message,
                  style: const TextStyle(height: 1.4, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ваша версия: $localVersion ($localBuild)\n'
                  'Новая версия: ${remote.latestVersion} (${remote.latestBuild})\n'
                  'Обновите приложение в $storeName.',
                  style: TextStyle(
                    height: 1.4,
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () async {
                    await skipVersion(remote.latestVersion, remote.latestBuild);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Позже'),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final url = Uri.tryParse(remote.storeUrl);
                  if (url != null && await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                  if (!force && ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Обновить'),
              ),
            ],
          ),
        );
      },
    );
  }
}
