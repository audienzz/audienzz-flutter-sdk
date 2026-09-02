import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_with_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:flutter/foundation.dart';
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

    if (_smartRefreshBanner != null) {
      WidgetsBinding.instance.addObserver(this);
      // Reload this banner when a screen/route/tab becomes active again (fired by
      // AudienzzSdkFlutter.onScreenResumed) — but only if it's currently on
      // screen, so hidden tabs don't burn an auction.
      adInstanceManager.addScreenResumeReloader(_reloadOnScreenResume);
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
    _visibilityTimer?.cancel();
    if (_smartRefreshBanner != null) {
      WidgetsBinding.instance.removeObserver(this);
      adInstanceManager.removeScreenResumeReloader(_reloadOnScreenResume);
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

  /// Set by the `onScreenResumed` broadcast when the ad isn't on screen yet;
  /// the visibility poll performs the reload once it becomes visible.
  bool _pendingScreenResumeReload = false;

  /// Broadcast target for `onScreenResumed`: reload this banner when it's the
  /// active screen's on-screen ad. If it isn't on screen yet — the incoming
  /// tab/route may still be animating in — defer to [_evaluateVisibility] so the
  /// reload lands once the ad becomes visible instead of being dropped. In a
  /// single-host app the on-screen banners are the active screen's, so this
  /// reproduces the native "screen change → reload" without re-auctioning ads on
  /// background tabs/routes.
  void _reloadOnScreenResume() {
    final banner = _smartRefreshBanner;
    if (banner == null || !mounted) return;
    final adId = adInstanceManager.adIdFor(banner);
    if (adId == null) return;
    if (_isOnScreen()) {
      if (kDebugMode) {
        debugPrint('AudienzzReload → reload now (adId=$adId, on screen)');
      }
      banner.reload();
    } else {
      if (kDebugMode) {
        debugPrint('AudienzzReload → deferred (adId=$adId, off screen)');
      }
      _pendingScreenResumeReload = true;
    }
  }

  /// Whether at least [_visibleThreshold] of the ad's height is in the viewport.
  bool _isOnScreen() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return false;
    final size = renderBox.size;
    if (size.height == 0) return false;
    final position = renderBox.localToGlobal(Offset.zero);
    final widgetRect = position & size;
    final visibleHeight = (Offset.zero & _screenSize)
        .intersect(widgetRect)
        .height
        .clamp(0.0, size.height);
    return visibleHeight / size.height >= _visibleThreshold;
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

    // A screen-resume reload that arrived while the ad was still animating in
    // (e.g. the incoming tab) fires now that it's on screen — once.
    if (_pendingScreenResumeReload && onScreen) {
      _pendingScreenResumeReload = false;
      if (kDebugMode) {
        final adId = adInstanceManager.adIdFor(banner);
        debugPrint('AudienzzReload → deferred reload fired (adId=$adId, now on screen)');
      }
      banner.reload();
    }

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
        viewType: Constants.nativeViewName,
        surfaceFactory: (_, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: const {},
            // transparent — not opaque — is the correct choice for TLHC
            // (initAndroidView) inside scrollable content.
            //
            // With opaque + empty gestureRecognizers, AndroidViewGestureRecognizer
            // has no sub-recognizers, so on PointerDown it calls
            // resolve(GestureDisposition.accepted) immediately — claiming the
            // gesture before SingleChildScrollView's drag recognizer can even
            // evaluate movement direction. Every scroll that starts on the ad
            // is swallowed by the platform view and the page stops scrolling.
            //
            // With transparent, Flutter's hit test skips the platform view
            // entirely, so SingleChildScrollView wins vertical drag gestures
            // and scroll is smooth.
            //
            // Ad clicks are NOT lost: with TLHC (initAndroidView) the
            // AdManagerAdView lives in the real Android view hierarchy. Android's
            // input system dispatches taps to it directly, independently of
            // Flutter's hit test result. The onAdClicked callback still fires.
            //
            // A bonus: opaque was also causing event duplication — Flutter
            // injected synthetic events AND Android dispatched native events to
            // the same view simultaneously. transparent eliminates that.
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
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
      viewType: Constants.nativeViewName,
      creationParams: adInstanceManager.adIdFor(widget.ad),
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: _messageCodec,
    );
  }
}
