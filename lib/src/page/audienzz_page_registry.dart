import 'package:audienzz_sdk_flutter/src/page/audienzz_page_handle.dart';
import 'package:flutter/widgets.dart';

/// Which page handle owns a given route, so navigation and the page wrapper
/// cannot disagree.
///
/// Without this they each mint their own: the observer derives an id from the
/// route (its `RouteSettings.name`, or its type when unnamed) and
/// [AudienzzPage] uses its `name` argument. For `MaterialApp(home:)` — which
/// has no route name — those are never equal, so navigating away and back
/// activated an id that did not match the banners already on the screen, and
/// they stayed released.
///
/// [AudienzzPage] binds its handle to the enclosing route while it is active;
/// the observer asks here first. A tab wrapper binds and unbinds as focus
/// moves, so the registry always holds the handle of the page the reader is
/// actually looking at inside that route.
class AudienzzPageRegistry {
  AudienzzPageRegistry._();

  static final AudienzzPageRegistry instance = AudienzzPageRegistry._();

  /// Expando rather than a Map: a route must not be kept alive by this.
  final Expando<AudienzzPageHandle> _byRoute = Expando<AudienzzPageHandle>();

  void bind(Route<dynamic> route, AudienzzPageHandle page) {
    _byRoute[route] = page;
  }

  /// Releases the binding only if [page] still owns it, so a wrapper that has
  /// already handed the route to its successor cannot clear it on the way out.
  void unbind(Route<dynamic> route, AudienzzPageHandle page) {
    if (_byRoute[route] == page) {
      _byRoute[route] = null;
    }
  }

  AudienzzPageHandle? handleFor(Route<dynamic> route) => _byRoute[route];

  AudienzzPageHandle? _lastManagedActivation;

  /// Activate [page] unless the managed integration already activated it.
  ///
  /// The observer and the wrapper are two reporters of one navigation: sharing
  /// an id stopped them disagreeing, but both still called `activatePage`, and
  /// two page impressions are two real transitions — each releases and
  /// re-auctions, so one navigation bought two replacements.
  ///
  /// This deduplicates the MANAGED path only. `AudienzzSdkFlutter.activatePage`
  /// and `pageImpression` are untouched, so a deliberate repeat report from app
  /// code still works; blanket suppression would break that.
  Future<void> activateOnce(
    AudienzzPageHandle page,
    Future<void> Function(AudienzzPageHandle) activate,
  ) async {
    if (_lastManagedActivation == page) {
      return;
    }
    _lastManagedActivation = page;
    await activate(page);
  }

  /// Forget the managed activation when its page goes away, so returning to it
  /// is a new visit rather than a silent no-op.
  void forgetManagedActivation(AudienzzPageHandle page) {
    if (_lastManagedActivation == page) {
      _lastManagedActivation = null;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _lastManagedActivation = null;
  }
}
