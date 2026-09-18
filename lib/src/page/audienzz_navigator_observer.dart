import 'package:audienzz_sdk_flutter/src/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_handle.dart';
import 'package:flutter/widgets.dart';

/// Navigation adapter. Wire it once:
///
/// ```dart
/// MaterialApp(navigatorObservers: [AudienzzNavigatorObserver()], …)
/// ```
///
/// The `Route` object is its own per-instance identity, so two article routes
/// are two pages even though both are named "article" — the distinction the
/// page coordinator needs and a screen name cannot provide.
///
/// It covers every operation that changes which route is on top, not only push
/// and pop: a `pushReplacement` or a `removeRoute` changes the visible screen
/// just as much, and missing them leaves the departed page's banners live.
///
/// Destinations that carry no ads are reported too. That is what releases the
/// previous page's banners; deactivation needs no fabricated ad event.
class AudienzzNavigatorObserver extends NavigatorObserver {
  /// Last route reported by THIS adapter, so its own repeated callbacks are
  /// deduplicated. An explicit `pageImpression`/`activatePage` from app code is
  /// untouched — suppressing all repeated reports would break a deliberate one.
  Route<dynamic>? _lastReported;

  /// Falls back to the route's type when `RouteSettings.name` is unset, so an
  /// unnamed route still reports something stable rather than being skipped.
  String _nameOf(Route<dynamic> route) =>
      route.settings.name ?? route.runtimeType.toString();

  void _report(Route<dynamic>? route) {
    if (route is! PageRoute) {
      return;
    }
    if (identical(route, _lastReported)) {
      return;
    }
    _lastReported = route;
    AudienzzSdkFlutter.instance
        .activatePage(audienzzPageForObject(route, _nameOf(route)));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Removing the route that is on top reveals the one beneath it. Removing a
    // buried route changes nothing visible, and `_lastReported` keeps that a
    // no-op.
    _report(previousRoute);
  }

  /// Test/host-restart hook: forget what this adapter last reported.
  @visibleForTesting
  void resetForTesting() => _lastReported = null;
}
