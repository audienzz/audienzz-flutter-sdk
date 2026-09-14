import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_with_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
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

  /// Polling cadence — matches the native FBannerAd refresh-check interval.
  static const Duration _pollInterval = Duration(milliseconds: 500);

  Timer? _visibilityTimer;

  /// Shadow of the last state pushed to the platform, so we only call
  /// pause/resume on an actual transition.
  bool _refreshPaused = false;

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

    if (_smartRefreshBanner != null) {
      WidgetsBinding.instance.addObserver(this);
      _visibilityTimer = Timer.periodic(
        _pollInterval,
        (_) {
          if (mounted) _evaluateVisibility();
        },
      );
    }
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
    _smartRefreshBanner?.pauseAutoRefresh();
    adInstanceManager.pageEpoch.removeListener(_onPageEpochChanged);
    _visibilityTimer?.cancel();
    if (_smartRefreshBanner != null) {
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
    if (renderBox == null || !renderBox.hasSize) return;
    final size = renderBox.size;
    if (size.height == 0) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenRect = Offset.zero & _screenSize;
    final widgetRect = position & size;
    final visibleHeight =
        screenRect.intersect(widgetRect).height.clamp(0.0, size.height);
    final fraction = visibleHeight / size.height;

    final routeIsCurrent = _route?.isCurrent ?? true;
    final onScreen = fraction >= _visibleThreshold;

    // Only worth a hit-test when the ad is geometrically on screen.
    final occluded = onScreen && _isOccludedAtCenter(renderBox);
    final shouldBeActive =
        _appResumed && routeIsCurrent && onScreen && !occluded;

    if (!shouldBeActive && !_refreshPaused) {
      _refreshPaused = true;
      banner.pauseAutoRefresh();
      if (kDebugMode) {
        debugPrint(
          'AudienzzSmartRefresh → PAUSE '
          '(fraction=${fraction.toStringAsFixed(2)}, '
          'routeCurrent=$routeIsCurrent, occluded=$occluded, '
          'appResumed=$_appResumed)',
        );
      }
    } else if (shouldBeActive && _refreshPaused) {
      _refreshPaused = false;
      banner.resumeAutoRefresh();
      if (kDebugMode) {
        debugPrint(
          'AudienzzSmartRefresh → RESUME '
          '(fraction=${fraction.toStringAsFixed(2)}, '
          'routeCurrent=$routeIsCurrent, occluded=$occluded, '
          'appResumed=$_appResumed)',
        );
      }
    }
  }

  /// Best-effort occlusion check: hit-test the ad's centre point. If our
  /// RenderBox isn't reachable in the hit path, an opaque, hit-testable cover
  /// (e.g. an [OverlayEntry] or a stacked widget) is painted on top. Covers
  /// wrapped in [IgnorePointer] or fully transparent to hit-tests can't be
  /// detected this way — use `pauseAllAutoRefresh()` for those.
  bool _isOccludedAtCenter(RenderBox box) {
    final view = View.maybeOf(context);
    if (view == null) return false;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, center, view.viewId);
    if (result.path.isEmpty) return false;

    // The ad's own render-object chain (itself + ancestors). A hit that lands on
    // any of these means nothing foreign covers the ad — it's either the ad
    // itself or one of the scrollables/gesture layers CONTAINING it. The latter
    // matters on iOS: while a finger is down the UiKitView drops out of the hit
    // path and the enclosing scrollable's gesture layer is hit instead, which
    // previously read as "occluded" and paused a fully-visible ad mid-scroll.
    final ownChain = <RenderObject>{};
    RenderObject? node = box;
    while (node != null) {
      ownChain.add(node);
      final parent = node.parent;
      node = parent is RenderObject ? parent : null;
    }
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderObject && ownChain.contains(target)) {
        return false; // ad or one of its ancestors reachable → not occluded
      }
    }
    // A real overlay (e.g. OverlayEntry) is a SIBLING subtree, not an ancestor,
    // so it won't be in ownChain — such a genuine cover still pauses refresh.
    return true;
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
