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
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          final platformViewService =
              PlatformViewsService.initSurfaceAndroidView(
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
