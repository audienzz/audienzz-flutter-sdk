import 'dart:async';

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

  /// Page identity, when it must differ from the name — two article routes
  /// that should own their banners separately, for example.
  ///
  /// Opt-in on **both** sides: construct [AudienzzNavigatorObserver] with
  /// `perInstance: true` and pass the same key here, or the observer and this
  /// wrapper will disagree about which page a banner is on and each will
  /// release the other's banners.
  final String? id;

  /// Whether this page currently owns the screen. The default is right for a
  /// plain route, where building *is* navigating. For a tab or an
  /// `IndexedStack`, pass whether this tab is the selected one, so a
  /// pre-built tab does not claim the active page.
  final bool active;

  final Widget child;

  @override
  State<AudienzzPage> createState() => _AudienzzPageState();
}

class _AudienzzPageState extends State<AudienzzPage> {
  late AudienzzPageHandle _page = _resolveHandle();
  bool _isActive = false;
  bool _activationScheduled = false;

  /// Cancels a scheduled activation whose page has since been replaced.
  int _generation = 0;

  /// Unique by default. Two article routes must own their banners separately
  /// without the publisher configuring matching ids in two places; the observer
  /// resolves this same handle through the registry.
  AudienzzPageHandle _resolveHandle() => widget.id == null
      ? createManagedAudienzzPage(widget.name)
      : AudienzzPageHandle(id: widget.id!, name: widget.name);

  @override
  void initState() {
    super.initState();
    _maybeActivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bind while the route's content builds, which is BEFORE the observer's
    // deferred activation runs — that is how the observer finds this handle
    // instead of deriving one of its own.
    if (widget.active) {
      _bindToRoute();
    }
  }

  @override
  void didUpdateWidget(AudienzzPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.name != widget.name) {
      // A different identity is a different page: retire the old owner
      // completely — including its route binding, under the OLD handle — and
      // activate the new one even if focus never dropped. Resetting _isActive
      // alone stranded the replacement, because activation was only scheduled
      // on a false -> true transition.
      _unbindFromRoute();
      AudienzzPageRegistry.instance.forgetManagedActivation(_page);
      _generation++;
      _page = _resolveHandle();
      _isActive = false;
      _activationScheduled = false;
      _maybeActivate();
      return;
    }
    if (!widget.active && oldWidget.active) {
      // Revoked, not sticky. A retained tab that loses focus must stop
      // reporting itself active: otherwise a banner added to it afterwards is
      // created as if it were on the foreground page, and the tab can never be
      // re-activated when the reader comes back.
      _activationScheduled = false;
      // Hand the route back, so a sibling tab that gains focus becomes the
      // authority for it, and forget the managed activation so returning here
      // counts as a new visit.
      _unbindFromRoute();
      AudienzzPageRegistry.instance.forgetManagedActivation(_page);
      if (_isActive) {
        setState(() => _isActive = false);
      }
      return;
    }
    if (widget.active && !oldWidget.active) {
      _maybeActivate();
    }
  }

  void _maybeActivate() {
    if (!widget.active || _isActive || _activationScheduled) {
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
      if (!widget.active || token != _generation) {
        // Focus was withdrawn, or this page was replaced, before the frame
        // landed.
        _activationScheduled = false;
        return;
      }
      _bindToRoute();
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

  void _bindToRoute() {
    final route = ModalRoute.of(context);
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

  @override
  void dispose() {
    _unbindFromRoute();
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
