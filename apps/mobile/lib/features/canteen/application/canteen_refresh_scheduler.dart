// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Implements the canteen refresh policy.
///
/// * refresh on app start,
/// * refresh on app resume,
/// * additionally at most once every [interval] while in the foreground.
///
/// **No timer ever runs in the background.** Leaving the foreground cancels the
/// periodic timer; returning schedules a fresh one. [dispose] cancels it too.
/// This is asserted by `test/features/canteen/canteen_refresh_scheduler_test.dart`.
class CanteenRefreshScheduler {
  CanteenRefreshScheduler({
    required this.onRefresh,
    this.interval = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Triggered by every refresh this policy decides on.
  final Future<void> Function() onRefresh;

  final DateTime Function() _clock;

  /// Minimum distance between two automatic foreground refreshes.
  final Duration interval;

  Timer? _timer;
  DateTime? _lastRefreshAt;
  bool _disposed = false;

  /// Whether a periodic timer is currently armed. Used by tests.
  bool get hasActiveTimer => _timer != null;

  /// Time of the last refresh this scheduler triggered.
  DateTime? get lastRefreshAt => _lastRefreshAt;

  /// Called once when the screen is first shown: refresh now, then arm the
  /// periodic timer.
  void start() {
    if (_disposed) return;
    _refreshNow();
    _arm();
  }

  /// Feeds the platform lifecycle into the policy.
  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _refreshNow();
        _arm();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _cancel();
    }
  }

  /// Cancels the timer. After this the scheduler is inert.
  void dispose() {
    _disposed = true;
    _cancel();
  }

  void _arm() {
    _cancel();
    _timer = Timer.periodic(interval, (Timer _) => _refreshIfDue());
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _refreshIfDue() {
    if (_disposed) return;
    final DateTime? last = _lastRefreshAt;
    if (last != null && _clock().difference(last) < interval) return;
    _refreshNow();
  }

  void _refreshNow() {
    _lastRefreshAt = _clock();
    unawaited(onRefresh());
  }
}
