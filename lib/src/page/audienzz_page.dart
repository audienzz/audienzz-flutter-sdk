import 'dart:async';

import 'package:audienzz_sdk_flutter/src/audienzz_diagnostics.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_handle.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_registry.dart';
import 'package:flutter/widgets.dart';

/// What a managed banner needs to know about the page it is on.
///
/// [isActive] is deliberately separate from mounting. A retained tab stays
/// mounted while another tab is on screen, and an `IndexedStack` builds every
/// child. Mounting is not navigating.
@immutable
class AudienzzPageScope extends InheritedWidget {
  const AudienzzPageScope({
    required this.page,
    required this.isActive,
    required super.child,
    super.key,
  });

  final AudienzzPageHandle page;
  final bool isActive;

  static AudienzzPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudienzzPageScope>();

  @override
  bool updateShouldNotify(AudienzzPageScope oldWidget) =>
      oldWidget.page != page || oldWidget.isActive != isActive;
}

/// Binds everything inside it to one page instance.
///
/// The handle is minted once per mounted route instance and published through
/// the element tree, so a descendant banner learns which page owns it while it
/// is being built — not from whichever page a parent happened to report last.
///
/// Activation happens in a post-frame callback rather than during build,
/// because reporting a page is a side effect and `build` must not have any. A
/// managed banner creates nothing until [AudienzzPageScope.isActive] is true,
/// so the page is always reported before its ads exist.
class AudienzzPage extends StatefulWidget {
  const AudienzzPage({
    required this.name,
    required this.child,
    this.id,
    this.active = true,
    super.key,
  });

  /// Analytics screen name. Also the page identity unless [id] is given.
  final String name;

  /// Page identity, when a host wants to choose it — a custom router that
  /// already has a stable per-instance key.
  ///
  /// Not needed for the default setup: a managed page is uniquely owned per
  /// route instance on its own, and [AudienzzNavigatorObserver] resolves this
  /// same handle through the shared registry rather than deriving one of its
  /// own. Name identity lives only where compatibility needs it — the legacy
  /// `pageImpression(name:)`.
  final String? id;

  /// An extra condition on top of navigation focus. Defaults to `true`.
  ///
  /// Focus itself is the navigator's: a page on a route that is no longer the
  /// topmost one is not active, however it is built. That is what stops a
  /// screen whose content finishes loading after the reader has already moved
  /// on from reclaiming the foreground, and it restores the page on a genuine
  /// return without any extra wiring.
  ///
  /// Set this when the host has its own reason to stand a page down — the
  /// unselected tab of an `IndexedStack`, which shares one route with the
  /// selected tab, or a wizard step that is built but not yet reached.
  final bool active;

  final Widget child;

  @override
  State<AudienzzPage> createState() => _AudienzzPageState();
}

class _AudienzzPageState extends State<AudienzzPage> {
  AudienzzPageHandle? _handle;
  bool _isActive = false;
  bool _activationScheduled = false;

  /// Whether this page's route is the topmost one on its navigator. True for a
  /// page outside any route, which has no navigator to defer to.
  bool _focused = true;

  /// Cancels a scheduled activation whose page has since been replaced.
  int _generation = 0;

  AudienzzPageHandle get _page => _handle ??= _resolveHandle();

  /// The identity is the ROUTE INSTANCE's whenever there is one, so this
  /// wrapper and the navigator observer describe the same visit even when this
  /// wrapper is built long after the route was first reported. A second wrapper
  /// on the same route — the other tab of an `IndexedStack` — is a separate
  /// page and mints its own.
  AudienzzPageHandle _resolveHandle() {
    if (widget.id != null) {
      return AudienzzPageHandle(id: widget.id!, name: widget.name);
    }
    final route = _route;
    if (route != null) {
      final claimed =
          AudienzzPageRegistry.instance.claimRouteIdentity(route, this);
      if (claimed != null) {
        _identityRoute = route;
        return AudienzzPageHandle(id: claimed, name: widget.name);
      }
    }
    return createManagedAudienzzPage(widget.name);
  }

  /// Reading this registers a dependency on the enclosing route's modal scope,
  /// so [didChangeDependencies] runs again whenever this route stops being — or
  /// becomes again — the topmost one. That is the navigator telling us about
  /// focus through its own machinery; no second observer and no delay.
  ModalRoute<dynamic>? get _route => ModalRoute.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = _route;
    _focused = route?.isCurrent ?? true;
    // Bind while the route's content builds, which is BEFORE the observer's
    // deferred activation runs — that is how the observer finds this handle
    // instead of deriving one of its own.
    if (_shouldBeActive) {
      _bindToRoute();
      _maybeActivate();
    } else {
      _standDown(rebuild: false);
    }
  }

  bool get _shouldBeActive => widget.active && _focused;

  @override
  void didUpdateWidget(AudienzzPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      // A different identity is a different page: retire the old owner
      // completely — including its route binding, under the OLD handle — and
      // activate the new one even if focus never dropped. Resetting _isActive
      // alone stranded the replacement, because activation was only scheduled
      // on a false -> true transition.
      _unbindFromRoute();
      AudienzzPageRegistry.instance.forgetManagedActivation(_page);
      _releaseRouteIdentity();
      _generation++;
      _handle = null;
      _isActive = false;
      _activationScheduled = false;
      if (_shouldBeActive) {
        _bindToRoute();
      }
      _maybeActivate();
      return;
    }
    if (oldWidget.name != widget.name) {
      // A LABEL, not an identity. Renaming what analytics calls this screen is not a
      // navigation: the reader has not gone anywhere, the route is the same one, and the slots
      // on it are the same slots. Retiring the page here reported a second visit and
      // re-auctioned every banner on it.
      //
      // The handle is rebuilt so the NEXT report carries the new label, keeping the same id —
      // which is what identity, route binding, the managed-activation dedupe and a banner's slot
      // key are all matched on, so nothing downstream moves.
      //
      // Deliberately NOT a `return`: one rebuild can change the label AND the selection, which is
      // exactly what a tab bar that names its tabs from data does. Returning here swallowed the
      // focus change — selecting the page left its slot empty, deselecting it left the banner's
      // owner live. No setState either; didUpdateWidget is always followed by a build.
      final renamed = AudienzzPageHandle(id: _page.id, name: widget.name);
      _handle = renamed;
      final route = _boundRoute;
      if (route != null) {
        AudienzzPageRegistry.instance.bind(route, renamed);
      }
    }
    if (!widget.active && oldWidget.active) {
      _standDown();
      return;
    }
    if (widget.active && !oldWidget.active) {
      _maybeActivate();
    }
  }

  /// Revoked, not sticky. A page that loses focus — an unselected tab, or a
  /// route the reader has navigated away from — must stop reporting itself
  /// active: otherwise a banner added to it afterwards is created as if it were
  /// on the foreground page, and it can never be re-activated on a return.
  void _standDown({bool rebuild = true}) {
    // The reason matters more than the fact: "not focused" is the navigator
    // having moved on, "host" is the app's own `active: false`. Reading a log
    // back, those two look identical without this.
    AudienzzDiagnostics.log('page', 'standDown', {
      'id': _page.id,
      'name': _page.name,
      'reason': !_focused ? 'notFocused' : 'host',
    });
    _activationScheduled = false;
    // Hand the route back, so a sibling tab that gains focus becomes the
    // authority for it, and forget the managed activation so returning here
    // counts as a new visit.
    _unbindFromRoute();
    AudienzzPageRegistry.instance.forgetManagedActivation(_page);
    if (!_isActive) {
      return;
    }
    if (rebuild) {
      setState(() => _isActive = false);
    } else {
      // Called from didChangeDependencies, where a build already follows.
      _isActive = false;
    }
  }

  void _maybeActivate() {
    if (!_shouldBeActive || _isActive || _activationScheduled) {
      return;
    }
    _activationScheduled = true;
    final token = _generation;
    // After the frame, so this never runs during build. Descendants that were
    // built in the same frame have not created an ad yet, because they wait on
    // `isActive`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Focus is rechecked HERE, not only when this was scheduled: a push can
      // land between the two, and the deferred callback would otherwise hand
      // the foreground to a route the reader has already left.
      if (!widget.active || !(_route?.isCurrent ?? true) ||
          token != _generation) {
        _activationScheduled = false;
        return;
      }
      _bindToRoute();
      AudienzzDiagnostics.log('page', 'activate', {
        'id': _page.id,
        'name': _page.name,
        'focused': _focused,
        'hostActive': widget.active,
      });
      unawaited(
        AudienzzPageRegistry.instance.activateOnce(
          _page,
          AudienzzSdkFlutter.instance.activatePage,
        ),
      );
      setState(() {
        _isActive = true;
        _activationScheduled = false;
      });
    });
  }

  /// The route this page lives on, so navigation and this wrapper resolve the
  /// same handle. Null for a page outside any route.
  Route<dynamic>? _boundRoute;

  /// The route whose canonical identity this wrapper holds, so it can be handed
  /// back on disposal even after the element is detached.
  Route<dynamic>? _identityRoute;

  void _bindToRoute() {
    final route = _route;
    if (route == null) {
      return;
    }
    _boundRoute = route;
    AudienzzPageRegistry.instance.bind(route, _page);
  }

  void _unbindFromRoute() {
    final route = _boundRoute;
    if (route != null) {
      AudienzzPageRegistry.instance.unbind(route, _page);
      _boundRoute = null;
    }
  }

  void _releaseRouteIdentity() {
    final route = _identityRoute;
    if (route != null) {
      AudienzzPageRegistry.instance.releaseRouteIdentity(route, this);
      _identityRoute = null;
    }
  }

  @override
  void dispose() {
    _unbindFromRoute();
    _releaseRouteIdentity();
    AudienzzPageRegistry.instance.forgetManagedActivation(_page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AudienzzPageScope(
        page: _page,
        isActive: _isActive,
        child: widget.child,
      );
}
