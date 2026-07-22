import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus {
  /// Есть сеть (Wi‑Fi / мобильный).
  online,

  /// Нет активного подключения.
  offline,

  /// Сеть есть, но запросы падают по таймауту / connection error.
  poor,
}

class NetworkState {
  final NetworkStatus status;
  final DateTime updatedAt;

  const NetworkState({
    required this.status,
    required this.updatedAt,
  });

  bool get isOffline => status == NetworkStatus.offline;
  bool get isPoor => status == NetworkStatus.poor;
  bool get hasIssue => isOffline || isPoor;

  NetworkState copyWith({NetworkStatus? status}) {
    return NetworkState(
      status: status ?? this.status,
      updatedAt: DateTime.now(),
    );
  }
}

class NetworkNotifier extends StateNotifier<NetworkState> {
  NetworkNotifier()
      : super(NetworkState(
          status: NetworkStatus.online,
          updatedAt: DateTime.now(),
        )) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _poorResetTimer;
  bool _initialized = false;

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyConnectivity(results, notifyChange: false);
      _sub = _connectivity.onConnectivityChanged.listen(_applyConnectivity);
      _initialized = true;
    } catch (e) {
      debugPrint('[Network] init error: $e');
    }
  }

  void _applyConnectivity(
    List<ConnectivityResult> results, {
    bool notifyChange = true,
  }) {
    final hasLink = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );

    final next = hasLink ? NetworkStatus.online : NetworkStatus.offline;
    if (!notifyChange && !_initialized) {
      state = state.copyWith(status: next);
      return;
    }
    if (state.status == next) return;

    // С сети «плохое» не перетираем offline, но online после offline — ок.
    if (state.status == NetworkStatus.poor && next == NetworkStatus.online) {
      return;
    }

    state = state.copyWith(status: next);
    if (next == NetworkStatus.online) {
      _poorResetTimer?.cancel();
    }
  }

  /// Вызывается из Dio при timeout / connectionError.
  void reportPoorConnection() {
    if (state.status == NetworkStatus.offline) return;

    state = state.copyWith(status: NetworkStatus.poor);
    _poorResetTimer?.cancel();
    // Если запросы снова пойдут — статус сбросится через reportSuccess / online.
    _poorResetTimer = Timer(const Duration(seconds: 12), () {
      if (state.status == NetworkStatus.poor) {
        state = state.copyWith(status: NetworkStatus.online);
      }
    });
  }

  void reportSuccess() {
    if (state.status == NetworkStatus.poor) {
      _poorResetTimer?.cancel();
      state = state.copyWith(status: NetworkStatus.online);
    }
  }

  /// Ручная перепроверка (кнопка «Обновить» на баннере).
  Future<void> recheck() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyConnectivity(results);
    } catch (e) {
      debugPrint('[Network] recheck error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poorResetTimer?.cancel();
    super.dispose();
  }
}

final networkProvider =
    StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});

/// Глобальный доступ для Dio interceptor (вне Riverpod-контекста).
NetworkNotifier? networkNotifierRef;
