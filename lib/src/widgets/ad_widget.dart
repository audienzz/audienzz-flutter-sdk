import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_with_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/refresh/smart_refresh_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const _messageCodec = StandardMessageCodec();

/// Flutter widget for displaying native ads
final class AdWidget extends StatefulWidget {
  const AdWidget({
    required this.ad,
    super.key,
  });

  ///Unique ad instance, needs to be loaded before using
  final AdWithView ad;

  @override
  State<AdWidget> createState() => _AdWidgetState();
}

/// Three-valued because a hit test can prove the ad was hit, prove something foreign was hit, or
/// establish neither — and the third case is common enough (mid-scroll on iOS) that folding it
/// into either of the others causes a visible bug.
enum _CoverVerdict { visible, covered, unknown }

final class _AdWidgetState extends State<AdWidget> with WidgetsBindingObserver {
  bool _adIdAlreadyMounted = false;
  bool _adLoadNotCalled = false;

  // ── SmartRefresh visibility management (handled by the SDK, not the app) ──
  //
  // When the ad is a [BannerAd] with `smartRefresh: true`, the SDK itself
  // decides when auto-refresh should run so publishers don't have to write any
  // visibility code. Refresh is active only when ALL of these hold:
  //   1. at least [_visibleThreshold] of the ad height is on screen (scrolling),
  //   2. the ad's route is the top-most one (no screen pushed on top),
  //   3. the app is in the foreground.
  // Otherwise auto-refresh is paused, so ads never refresh while hidden.

  /// Minimum visible fraction (0–1) for the ad to count as on-screen.
  static const double _visibleThreshold = 0.2;

  /// How much of the ad's height may hang below the viewport under the v2
  /// directional rule before it stops being refresh-eligible.
  static const double _maxBottomOffscreenFraction = 0.5;

  /// Logical-pixel slack on the "top fully on screen" test, matching the
  /// 1-pixel tolerance the native gates use.
  static const double _edgeTolerance = 1.0;

  /// Polling cadence — matches the native FBannerAd refresh-check interval.
  static const Duration _pollInterval = Duration(milliseconds: 500);

  Timer? _visibilityTimer;

  /// The last verdict actually pushed to the platform, so we only call
  /// pause/resume on a real transition.
  ///
  /// `null` means *unsynchronized*: this widget has never told native anything.
  /// It must not be initialised to a guess. A retained ad can be unmounted and
  /// remounted — `dispose` sends `visible:false` for the old widget, and a new
  /// widget that assumed native was already resumed never sent `visible:true`,
  /// leaving refresh paused until some later hide/show cycle happened to
  /// produce a transition. Starting unsynchronized forces the first evaluation
  /// to publish whatever it computes.
  bool? _lastReportedVisible;

  /// Whether the app is currently in the foreground.
  bool _appResumed = true;

  /// Cached in [build] so the timer never touches InheritedWidgets directly.
  Size _screenSize = Size.zero;
  ModalRoute<dynamic>? _route;

  /// Page epoch this platform view was built for. Bumping it re-keys the
  /// platform view, forcing Flutter to tear it down and build a new one: an
  /// in-place re-auction does NOT repaint an AndroidViewSurface or UiKitView,
  /// so without this a recreated ad would keep showing the old creative.
  /// Only advanced for the route that is current, so kept-mounted routes
  /// don't churn their platform views on every page impression.
  int _viewEpoch = 0;

  /// Stable per-ad key component, so re-keying only ever affects this ad.
  String get _adKeySuffix =>
      '${adInstanceManager.adIdFor(widget.ad)}:$_viewEpoch';

  void _onPageEpochChanged() {
    if (!mounted) {
      return;
    }
    // Remount only when the page being reported is THIS ad's page. Testing
    // `ModalRoute.isCurrent` instead would remount whichever route happens to
    // be on top when the notification arrives — e.g. reporting "A" while B is
    // still on top remounted B and left A un-repaired.
    final adPage = adInstanceManager.pageFor(widget.ad);
    if (adPage == null || adPage != adInstanceManager.lastReportedPage) {
      return;
    }
    final epoch = adInstanceManager.pageEpoch.value;
    if (epoch == _viewEpoch) {
      return;
    }
    setState(() => _viewEpoch = epoch);
  }

  /// The ad as a smart-refresh banner, or null when smart refresh doesn't apply.
  BannerAd? get _smartRefreshBanner {
    final ad = widget.ad;
    return ad is BannerAd && ad.smartRefresh ? ad : null;
  }

  @override
  void initState() {
    super.initState();
    final adId = adInstanceManager.adIdFor(widget.ad);
    if (adId != null) {
      if (adInstanceManager.isWidgetAdIdMounted(adId)) {
        _adIdAlreadyMounted = true;
      }
      adInstanceManager.mountWidgetAdId(adId);
    } else {
      _adLoadNotCalled = true;
    }

    _viewEpoch = adInstanceManager.pageEpoch.value;
    adInstanceManager.pageEpoch.addListener(_onPageEpochChanged);

    _syncVisibilityObservation();
  }

  /// Starts or stops the poll and the lifecycle observer to match the ad this
  /// widget is currently showing.
  ///
  /// Called from `initState` AND `didUpdateWidget`, because the ad can change.
  /// Doing it only at initialization meant that replacing a non-smart ad with a
  /// RemoteBanner at the same widget position left the new banner with no timer
  /// and no lifecycle observer: it reported one initial verdict and then never
  /// updated, so its last native verdict stayed `visible` however far it
  /// scrolled away. On Flutter Android that verdict is the only viewport gate
  /// there is, so refresh continued unseen.
  void _syncVisibilityObservation() {
    final wanted = _smartRefreshBanner != null;
    final running = _visibilityTimer != null;
    if (wanted == running) {
      return;
    }
    if (wanted) {
      WidgetsBinding.instance.addObserver(this);
      _visibilityTimer = Timer.periodic(
        _pollInterval,
        (_) {
          if (mounted) _evaluateVisibility();
        },
      );
      // Publish the current verdict as soon as there is geometry to read,
      // rather than waiting up to one poll interval. Combined with the
      // unsynchronized initial state, this is what re-synchronizes a retained
      // ad that is remounted into a new widget.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _evaluateVisibility();
      });
    } else {
      _visibilityTimer?.cancel();
      _visibilityTimer = null;
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didUpdateWidget(AdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.ad, widget.ad)) {
      return;
    }
    // The same widget position now hosts a different ad. The outgoing ad keeps
    // its native refresh running unless we pause it here, and the incoming ad
    // has never been told anything by this widget.
    final previous = oldWidget.ad;
    if (previous is BannerAd && previous.smartRefresh) {
      unawaited(
        adInstanceManager.setBannerViewportVisible(previous, visible: false),
      );
    }
    final previousId = adInstanceManager.adIdFor(previous);
    if (previousId != null) {
      adInstanceManager.unmountWidgetAdId(previousId);
    }
    final nextId = adInstanceManager.adIdFor(widget.ad);
    if (nextId != null) {
      adInstanceManager.mountWidgetAdId(nextId);
    }
    _lastReportedVisible = null;
    _syncVisibilityObservation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluateVisibility();
    });
  }

  @override
  void dispose() {
    // Pause BEFORE cancelling the poll. The timer is the only thing that can
    // pause this banner, so unmounting while it was resumed (the normal case
    // when navigating away from a visible ad) used to leave the native
    // auto-refresh running forever against a detached ad view — auctions and
    // GAM loads that could never become impressions. Page-scoping catches this
    // too, but only once the app reports the next pageImpression; this is the
    // backstop that does not depend on that.
    final banner = _smartRefreshBanner;
    if (banner != null) {
      unawaited(
        adInstanceManager.setBannerViewportVisible(banner, visible: false),
      );
    }
    adInstanceManager.pageEpoch.removeListener(_onPageEpochChanged);
    // Keyed off the timer, not off the current ad: the ad may have been swapped
    // for a non-smart one, in which case the observer was already removed.
    if (_visibilityTimer != null) {
      _visibilityTimer!.cancel();
      _visibilityTimer = null;
      WidgetsBinding.instance.removeObserver(this);
    }
    final adId = adInstanceManager.adIdFor(widget.ad);
    if (adId != null) {
      adInstanceManager.unmountWidgetAdId(adId);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _evaluateVisibility();
  }

  /// Decide whether auto-refresh should be running and push the transition to
  /// the platform. Combines scroll visibility, route occlusion and app
  /// lifecycle into a single "active" decision.
  void _evaluateVisibility() {
    final banner = _smartRefreshBanner;
    if (banner == null) return;
    // Only manage a banner that has actually been registered natively.
    if (adInstanceManager.adIdFor(banner) == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final routeIsCurrent = _route?.isCurrent ?? true;
    // Hit testing cannot see a cover that deliberately passes pointers through — an IgnorePointer
    // veil, a CustomPaint overlay or a plain decoration paints over the ad and leaves the hit path
    // untouched. `reportObscured` is the publisher's way to say so; see BannerAd.reportObscured.
    final obscured = adInstanceManager.isBannerObscured(banner);

    // Geometry is evaluated first because several of its outcomes are
    // *definitive hidden* rather than "no information". A missing render
    // object, an unlaid-out box, a collapsed slot, a slot moved off the side
    // of the screen, a clipped-away slot and an ancestor that does not paint
    // its child all mean the same thing to the ad server: nothing can be
    // rendered here. Returning early on any of them left the last verdict —
    // usually `true` — standing, so native kept auctioning into a banner
    // nobody could see.
    final Rect? painted =
        (renderBox != null && renderBox.hasSize && !renderBox.size.isEmpty)
            ? _paintedRectInGlobal(renderBox)
            : null;
    final Size size =
        (renderBox?.hasSize ?? false) ? renderBox!.size : Size.zero;

    var fraction = 0.0;
    var onScreen = false;
    if (painted != null && renderBox != null && !size.isEmpty) {
      final screenRect = Offset.zero & _screenSize;
      final visible = painted.intersect(screenRect);
      // Two-dimensional: a banner translated off the left or right edge has a
      // perfectly healthy intersection *height* and zero intersection width.
      // Measuring height alone reported it visible.
      if (visible.width > 0 && visible.height > 0) {
        // The ad's own rect, before any clip but AFTER every ancestor
        // transform. `painted` and `visible` are transformed, so pairing them
        // with the untransformed local size compared two different coordinate
        // spaces: under Transform.scale(0.4) a fully visible 320x50 banner has
        // a 20-pixel painted height and a 50-pixel nominal one, and the
        // directional rule rejected it.
        final adRect = MatrixUtils.transformRect(
          renderBox.getTransformTo(null),
          Offset.zero & size,
        );
        fraction = (visible.height / adRect.height).clamp(0.0, 1.0);
        onScreen = _satisfiesViewportRule(adRect: adRect, visible: visible);
      }
    }

    // Only worth a hit-test when the ad is geometrically on screen.
    final covered = onScreen &&
        renderBox != null &&
        _coverAtCenter(renderBox) == _CoverVerdict.covered;
    final shouldBeActive =
        _appResumed && routeIsCurrent && onScreen && !covered && !obscured;

    if (_lastReportedVisible == shouldBeActive) {
      return;
    }
    _lastReportedVisible = shouldBeActive;
    unawaited(
      adInstanceManager.setBannerViewportVisible(
        banner,
        visible: shouldBeActive,
      ),
    );
    if (kDebugMode) {
      debugPrint(
        'AudienzzSmartRefresh → ${shouldBeActive ? 'RESUME' : 'PAUSE'} '
        '(fraction=${fraction.toStringAsFixed(2)}, '
        'routeCurrent=$routeIsCurrent, covered=$covered, obscured=$obscured, '
        'appResumed=$_appResumed)',
      );
    }
  }

  /// Whether the visible part of the ad satisfies the active viewport rule.
  ///
  /// v1 (the legacy gate): at least [_visibleThreshold] of the ad's height is
  /// on screen, in any direction.
  ///
  /// v2 (the directional gate the public API documents): the ad's top edge is
  /// fully on screen, and no more than half its height is below the viewport.
  /// Thresholds and the 1-logical-pixel tolerance match the native rule in
  /// `ViewUtil.isRefreshEligible` / `VisibleView.computeRefreshEligible`, so
  /// the same banner is judged the same way on every platform.
  bool _satisfiesViewportRule({
    required Rect adRect,
    required Rect visible,
  }) {
    if (!SmartRefreshPolicy.instance.isV2Enabled) {
      return visible.height / adRect.height >= _visibleThreshold;
    }
    final topOffscreen = visible.top - adRect.top;
    final bottomOffscreen = adRect.bottom - visible.bottom;
    final topFullyOnScreen = topOffscreen < _edgeTolerance;
    final bottomWithinHalf =
        bottomOffscreen <= adRect.height * _maxBottomOffscreenFraction;
    return topFullyOnScreen && bottomWithinHalf;
  }

  /// The ad's rect in global coordinates after every ancestor clip has been
  /// applied, or `null` when an ancestor does not paint it at all.
  ///
  /// `Offstage` is the motivating case: the child is laid out and has a real
  /// size and position, so pure geometry says it is on screen, but nothing is
  /// ever painted. `RenderObject.paintsChild` is what reports that, and
  /// `describeApproximatePaintClip` is what reports a clipping ancestor — a
  /// slot scrolled out of a `ClipRect` viewport keeps its global rect long
  /// after it stops being drawn.
  Rect? _paintedRectInGlobal(RenderBox box) {
    // `bounds` is expressed in the coordinate space of `boundsSpace`.
    var bounds = Offset.zero & box.size;
    RenderObject boundsSpace = box;
    RenderObject node = box;
    var parent = node.parent;
    while (parent != null) {
      if (!parent.paintsChild(node)) {
        return null;
      }
      final clip = parent.describeApproximatePaintClip(node);
      if (clip != null) {
        final inParent = MatrixUtils.transformRect(
          boundsSpace.getTransformTo(parent),
          bounds,
        );
        bounds = inParent.intersect(clip);
        if (bounds.isEmpty) {
          return null;
        }
        boundsSpace = parent;
      }
      node = parent;
      parent = node.parent;
    }
    return MatrixUtils.transformRect(
      boundsSpace.getTransformTo(null),
      bounds,
    );
  }

  /// Best-effort occlusion check: hit-test the ad's centre point. If our
  /// RenderBox isn't reachable in the hit path, an opaque, hit-testable cover
  /// (e.g. an [OverlayEntry] or a stacked widget) is painted on top. Covers
  /// wrapped in [IgnorePointer] or fully transparent to hit-tests can't be
  /// detected this way — use `pauseAllAutoRefresh()` for those.
  /// What a hit test at the ad's centre can actually establish.
  ///
  /// Three-valued on purpose. Treating "an ancestor took the hit" as proof of visibility — which
  /// is what the previous check did — let any cover that shares a Stack, Scaffold or scrollable
  /// with the ad read as visible, because the hit path always contains those shared ancestors.
  /// Collapsing that back to a boolean in either direction reintroduces one of the two bugs.
  _CoverVerdict _coverAtCenter(RenderBox box) {
    final view = View.maybeOf(context);
    if (view == null) return _CoverVerdict.unknown;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, center, view.viewId);
    if (result.path.isEmpty) return _CoverVerdict.unknown;

    // Ancestors only — the ad itself is deliberately excluded, since being an ancestor proves
    // nothing about what is painted on top.
    final ancestors = <RenderObject>{};
    RenderObject? node = box.parent is RenderObject ? box.parent : null;
    while (node != null) {
      ancestors.add(node);
      final parent = node.parent;
      node = parent is RenderObject ? parent : null;
    }

    var sawForeign = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;
      if (identical(target, box) || _isInsideAd(target, box)) {
        // The ad itself took the hit: nothing hit-testable is above it.
        return _CoverVerdict.visible;
      }
      if (!ancestors.contains(target)) sawForeign = true;
    }
    // Only shared ancestors were hit, which establishes nothing either way. That is what happens
    // on iOS while a finger is down — the UiKitView drops out of the hit path and the enclosing
    // scrollable's gesture layer takes it — and also when an AbsorbPointer wrapping both the ad
    // and a cover swallows the hit without descending. Treated as inconclusive rather than
    // covered, because pausing here paused a fully visible ad mid-scroll; the AbsorbPointer case
    // is undecidable by hit testing and is what BannerAd.reportObscured exists for.
    return sawForeign ? _CoverVerdict.covered : _CoverVerdict.unknown;
  }

  /// Whether [target] sits inside the ad's own subtree.
  static bool _isInsideAd(RenderObject target, RenderBox ad) {
    RenderObject? node = target.parent is RenderObject ? target.parent : null;
    while (node != null) {
      if (identical(node, ad)) return true;
      final parent = node.parent;
      node = parent is RenderObject ? parent : null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Cache visibility inputs here (not in the timer) so the InheritedWidget
    // dependencies are registered correctly and updated on rotation/navigation.
    if (_smartRefreshBanner != null) {
      _screenSize = MediaQuery.sizeOf(context);
      _route = ModalRoute.of(context);
    }

    if (_adIdAlreadyMounted) {
      throw FlutterError.fromParts(
        [
          ErrorSummary('This AdWidget is already in the Widget tree'),
          ErrorHint(
            'If you placed this AdWidget in a list,'
            ' make sure you create a new instance '
            'in the builder function with a unique ad object.',
          ),
          ErrorHint(
            'Make sure you are not using the same ad'
            ' object in more than one AdWidget.',
          ),
        ],
      );
    }
    if (_adLoadNotCalled) {
      throw FlutterError.fromParts(
        [
          ErrorSummary(
            'AdWidget requires Ad.load to be called'
            ' before AdWidget is inserted into the tree',
          ),
          ErrorHint(
            'Parameter ad is not loaded. Call Ad.load'
            ' before AdWidget is inserted into the tree.',
          ),
        ],
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        key: ValueKey<String>('audienzz-ad-$_adKeySuffix'),
        viewType: Constants.nativeViewName,
        surfaceFactory: (_, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            // Two settings together make the banner reliably clickable while
            // still letting the page scroll when a drag starts on the ad.
            //
            // hitTestBehavior: opaque
            //   With TLHC (initAndroidView) the embedded AdManagerAdView is
            //   composited UNDER Flutter's surface, which consumes all touches.
            //   Flutter forwards pointer events to the embedded view only when
            //   its render box is in the hit-test path — and only opaque (or
            //   translucent) put it there. `transparent` removes it from the
            //   hit test entirely (see RenderAndroidView.hitTest), so the ad
            //   gets NO touch events and taps never reach it. That is why the
            //   ad was completely dead before.
            //
            // gestureRecognizers: Tap + LongPress
            //   An EMPTY set gives the platform view only a passive recognizer
            //   that wins the gesture arena solely when every other recognizer
            //   rejects. Inside a ListView/ScrollView the scrollable's
            //   vertical-drag recognizer competes too, so a tap with even a few
            //   pixels of finger drift is claimed as a drag and the click is
            //   swallowed — the "sometimes not clickable" symptom.
            //   Registering Tap (and LongPress) makes the platform view an
            //   ACTIVE competitor for those gestures: a tap is forwarded to the
            //   ad even amid slight movement, while a real vertical drag still
            //   goes to the scrollable. We deliberately do NOT use
            //   EagerGestureRecognizer — it claims on pointer-down and would
            //   swallow scrolls that begin on the ad.
            // NB: each Factory must carry the CONCRETE recognizer type as its
            // type argument. Flutter keys the set by Factory<T>.type (== T), so
            // two Factory<OneSequenceGestureRecognizer> entries collapse to one
            // type and trip the "multiple factories for the same type"
            // assertion. Covariance still lets these fit the declared set type.
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
              Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
              Factory<LongPressGestureRecognizer>(
                LongPressGestureRecognizer.new,
              ),
            },
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          // Use Texture Layer Hybrid Composition (initAndroidView).
          //
          // initAndroidView (TLHC) is Flutter's recommended platform-view mode
          // for scrollable content. It embeds the Android View in the real view
          // hierarchy (so input events work natively) and renders its content
          // via a SurfaceProducer texture layer positioned by Flutter's raster
          // thread — no platform-thread hop needed during scroll.
          //
          // Why not initExpensiveAndroidView (HC)?
          // HC positions the Android View by posting LayoutParams updates from
          // the raster thread to the Android main thread on every scroll frame.
          // That async thread hop causes the platform view to visibly trail the
          // Flutter content by 1–2 frames during fast scrolling. Flutter docs
          // explicitly warn: "initExpensiveAndroidView should not be used in
          // lists or scrollable content."
          //
          // Why not initSurfaceAndroidView (Virtual Display)?
          // VD is equivalent to TLHC on Flutter 3.22+ (both use
          // ImageTextureEntry / SurfaceProducer internally). TLHC is preferred
          // because the Android View is in the real hierarchy — giving correct
          // touch dispatch and accessibility support.
          //
          // Fence-sync note:
          // On Android < 33 (API 32, Android 12) SurfaceProducer cannot use
          // hardware EGL fence synchronization, so Flutter logs
          // "ImageTextureEntry can't wait on the fence on Android < 33" on
          // every frame. For static banner ads this is harmless: the ad buffer
          // doesn't change frame-to-frame, so skipping the fence sync has no
          // visible effect. The Stack spinner overlay works correctly because
          // TLHC allows Flutter to render above the texture layer.
          final platformViewService =
              PlatformViewsService.initAndroidView(
            id: params.id,
            viewType: Constants.nativeViewName,
            layoutDirection: TextDirection.ltr,
            creationParams: adInstanceManager.adIdFor(widget.ad),
            creationParamsCodec: _messageCodec,
          )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated);

          unawaited(platformViewService.create());

          return platformViewService;
        },
      );
    }

    return UiKitView(
      key: ValueKey<String>('audienzz-ad-$_adKeySuffix'),
      viewType: Constants.nativeViewName,
      creationParams: adInstanceManager.adIdFor(widget.ad),
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: _messageCodec,
    );
  }
}
