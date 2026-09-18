import 'dart:async';

import 'package:audienzz_sdk_flutter/src/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_handle.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_registry.dart';
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

  /// Every `PageRoute` currently on this navigator, oldest first, so a removal
  /// or replacement below the top can be recognised as not changing what the
  /// reader sees.
  final List<Route<dynamic>> _stack = <Route<dynamic>>[];

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
    // Deferred to after this frame for two reasons. A wrapper on this route is
    // the authority on what the page is called and which instance it is, and it
    // binds itself while the route's content builds — which happens after this
    // callback. And activating through the shared registry lets the wrapper's
    // own activation for the same navigation be recognised as the same event
    // rather than a second transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!identical(route, _lastReported)) {
        return; // superseded before the frame landed
      }
      final bound = AudienzzPageRegistry.instance.handleFor(route);
      // Per route INSTANCE, always. This observer belongs to the managed
      // integration, where two article routes must own their banners
      // separately without the publisher configuring anything. Name identity
      // stays where compatibility needs it: the legacy `pageImpression(name)`.
      final page = bound ?? audienzzPageForObject(route, _nameOf(route));
      unawaited(
        AudienzzPageRegistry.instance.activateOnce(
          page,
          AudienzzSdkFlutter.instance.activatePage,
        ),
      );
    });
  }

  /// Report whatever is on top now. Deriving the destination from the callback's
  /// `previousRoute` is wrong for anything below the top: removing a buried
  /// route hands us the route beneath IT, and reporting that released the
  /// banners of the screen the reader is actually looking at.
  void _reportTop() {
    if (_stack.isEmpty) {
      return;
    }
    _report(_stack.last);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _stack.add(route);
    }
    _reportTop();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _reportTop();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute is PageRoute) {
        _stack[index] = newRoute;
      } else {
        _stack.removeAt(index);
      }
    } else if (newRoute is PageRoute) {
      _stack.add(newRoute);
    }
    _reportTop();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _reportTop();
  }

  /// Test/host-restart hook: forget what this adapter last reported.
  @visibleForTesting
  void resetForTesting() {
    _lastReported = null;
    _stack.clear();
  }
}
