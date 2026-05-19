import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_with_view.dart';
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

final class _AdWidgetState extends State<AdWidget> {
  bool _adIdAlreadyMounted = false;
  bool _adLoadNotCalled = false;

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
  }

  @override
  void dispose() {
    final adId = adInstanceManager.adIdFor(widget.ad);
    if (adId != null) {
      adInstanceManager.unmountWidgetAdId(adId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
