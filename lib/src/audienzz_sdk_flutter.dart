import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_targeting.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:audienzz_sdk_flutter/src/refresh/smart_refresh_policy.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class AudienzzSdkFlutter {
  const AudienzzSdkFlutter._();

  static final _instance = const AudienzzSdkFlutter._().._init();

  static AudienzzSdkFlutter get instance => _instance;

  /// Guards the remote-config init path so the native SDK is initialized at
  /// most once, whether initialization completes on the initial fetch or later
  /// via background polling. (The class is a const singleton, so this is a
  /// static field rather than an instance field.)
  static bool _remoteNativeInitialized = false;

  /// Required to initialize the SDK.
  Future<InitializationStatus> initialize({
    required String companyId,
  }) {
    return adInstanceManager.initialize(
      companyId: companyId,
    );
  }

  /// Required to initialize the SDK with remote configuration.
  Future<InitializationStatus> initializeRemote({
    required String publisherId,
    required String remoteUrl,
    bool enablePolling = true,
  }) async {
    final audienzzRemoteConfig = AudienzzRemoteConfig.instance
      ..configureRemote(
        remoteUrl: remoteUrl,
        publisherId: publisherId,
      );
    _remoteNativeInitialized = false;
    try {
      await audienzzRemoteConfig.fetchPublisherConfig(
        enablePolling: enablePolling,
        // If the initial fetch fails with no usable cache, this fires once
        // background polling later succeeds so the native SDK still gets
        // initialized instead of the session staying ad-less forever.
        onPollingSuccess: () {
          _applyConfigAndInitialize(audienzzRemoteConfig.publisherConfig);
        },
      );
    } catch (e) {
      log('Audienzz SDK: Remote config unavailable: $e');
      return enablePolling
          ? InitializationStatus.fallbackPolling
          : InitializationStatus.fail;
    }

    return _applyConfigAndInitialize(audienzzRemoteConfig.publisherConfig);
  }

  /// Applies the publisher config's targeting and initializes the native SDK.
  /// Idempotent: only the first invocation reaches the native initializer, so
  /// the initial-fetch path and the background-polling path never double-init.
  Future<InitializationStatus> _applyConfigAndInitialize(
    RemotePublisherConfiguration? config,
  ) async {
    if (_remoteNativeInitialized) {
      return InitializationStatus.success;
    }
    _remoteNativeInitialized = true;

    if (config != null) {
      final ortb = config.ortb;
      await AudienzzTargeting.setPublisherName(ortb.publisherName);

      if (ortb.domain != null) {
        await AudienzzTargeting.setDomain(ortb.domain!);
      }

      final advertisingSystemDomain = ortb.schain?.advertisingSystemDomain;
      final sellerId = ortb.schain?.sellerId;

      if (advertisingSystemDomain != null && sellerId != null) {
        await setSchainObject('''
                        { "source":
                            { "schain": {
                                "ver": "1.0",
                                "complete": 1,
                                "nodes": [
                                    {
                                        "asi": "$advertisingSystemDomain",
                                        "sid": "$sellerId",
                                        "hp": 1
                                    }
                                  ]
                                }
                            }
                        }
                    ''');
      }

      if (Platform.isAndroid && config.android != null) {
        await AudienzzTargeting.setBundleName(config.android!.ortb.bundleName);

        if (config.android?.ortb.storeUrl != null) {
          await AudienzzTargeting.setStoreUrl(config.android!.ortb.storeUrl!);
        }
      } else if (Platform.isIOS && config.ios != null) {
        await AudienzzTargeting.setItunesID(config.ios!.ortb.bundleId);
        await AudienzzTargeting.setBundleName(config.ios!.ortb.sourceApp);

        if (config.ios?.ortb.storeUrl != null) {
          await AudienzzTargeting.setStoreUrl(config.ios!.ortb.storeUrl!);
        }
      }
    }

    return adInstanceManager.initialize(
      companyId: config?.ortb.schain?.sellerId ?? '1',
      prebidServerUrl: config?.prebidServer.url,
      // Flutter fetches the publisher config in Dart, so the native SDK never sees it and cannot
      // read these itself. Absent values stay null and native applies its own default (enabled).
      ppidEnabled: config?.ppidEnabled,
      automaticPpidEnabled: config?.automaticPpidEnabled,
    );
  }

  Future<void> _init() async {
    try {
      await adInstanceManager.methodChannel.invokeMethod('_init');
    } on PlatformException catch (e) {
      log('Exception while initialization of AudienzzSdkFlutter'
          ' instance: ${e.message} ${e.details}');
    }
  }

  Future<void> setSchainObject(String schain) {
    return adInstanceManager.methodChannel.invokeMethod(
      'setSchainObject',
      {'schain': schain},
    );
  }

  /// Force smart-refresh v2 on/off, overriding the backend `smartRefreshV2`
  /// config for the rest of the session. v2 uses the directional viewport gate
  /// (top fully on screen, at most half off the bottom); v1 uses the legacy
  /// ≥20%-visible gate. Call before creating banners. Omit to defer to backend.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setSmartRefreshV2Enabled(bool enabled) {
    // Recorded on the Dart side as well as forwarded. Flutter's banner gate is
    // evaluated in Dart, so forwarding alone left the documented directional
    // rule unreachable from Flutter.
    SmartRefreshPolicy.instance.setOverride(enabled);
    return adInstanceManager.methodChannel.invokeMethod(
      'setSmartRefreshV2Enabled',
      {'enabled': enabled},
    );
  }

  /// When true, a banner blanks its slot during a screen-resume reload
  /// (native `blankOnScreenReload`). Default false. Call before creating
  /// banners.
  ///
  /// NOTE: the Flutter reload path recreates the platform view, so the slot
  /// already blanks for a frame regardless; this flag additionally drives the
  /// native banners' own reload behavior for parity with iOS/Android.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setBlankOnScreenReload(bool enabled) {
    return adInstanceManager.methodChannel.invokeMethod(
      'setBlankOnScreenReload',
      {'enabled': enabled},
    );
  }

  /// Report an ad-bearing screen, dialog, or popup. Pass a [context] (the
  /// screen name is derived from its route's `settings.name`, else the
  /// enclosing widget type) and/or an explicit [name]; at least one is
  /// required. Fires a `pageImpression` and a fresh page-impression id that
  /// ties all ad events on this visit together. Call it on each navigation to
  /// an ad-bearing screen — e.g. from a [RouteObserver] or a route's `build`.
  Future<void> pageImpression({BuildContext? context, String? name}) {
    assert(
      context != null || name != null,
      'pageImpression requires a context or a name',
    );
    final screenName = name ?? _deriveScreenName(context!);
    // Stamp every ad created from here on with this page, and force mounted
    // Stamp synchronously so ads created right after this call belong to this
    // page — the documented ordering is "report the page, then create its ads",
    // and waiting for native's asynchronous echo would stamp them with the
    // previous page, permanently.
    //
    // The epoch bump that drives remounting is NOT done here: it happens once,
    // when native echoes the impression back, so it also covers the automatic
    // foreground impression which never passes through this method.
    adInstanceManager.currentPage = screenName;
    return adInstanceManager.methodChannel.invokeMethod(
      'pageImpression',
      {'name': screenName},
    );
  }

  /// Derive a stable screen name from a [BuildContext]: the current route's
  /// `settings.name` when set (named routes / go_router), else the enclosing
  /// widget's type.
  String _deriveScreenName(BuildContext context) =>
      ModalRoute.of(context)?.settings.name ??
      context.widget.runtimeType.toString();

  /// Pauses Prebid auto-refresh for ALL currently loaded banner ads.
  ///
  /// Smart-refresh banners auto-pause for scroll visibility, Navigator routes,
  /// and app backgrounding. They CANNOT auto-detect same-route covers (an
  /// `OverlayEntry`, a custom stacked widget, etc.), because Flutter exposes no
  /// occlusion signal. Call this when such an overlay is shown, and
  /// [resumeAllAutoRefresh] when it is dismissed.
  Future<void> pauseAllAutoRefresh() =>
      adInstanceManager.pauseAllBannerAutoRefresh();

  /// Resumes Prebid auto-refresh for all loaded banner ads previously paused
  /// via [pauseAllAutoRefresh].
  Future<void> resumeAllAutoRefresh() =>
      adInstanceManager.resumeAllBannerAutoRefresh();

  /// Sets the global GMA ad audio volume for all ad types (banner, interstitial, rewarded).
  ///
  /// [volume] must be in range [0.0, 1.0]:
  /// - 0.0 = fully muted
  /// - 1.0 = full device volume
  ///
  /// Values outside [0.0, 1.0] are clamped automatically.
  ///
  /// The SDK already defaults to 0.0 (muted) on initialization. Call this method
  /// explicitly if you need to override the volume mid-session or after any other
  /// SDK has modified the GMA audio state.
  Future<void> setAppVolume(double volume) {
    return adInstanceManager.methodChannel.invokeMethod<void>(
      'setAppVolume',
      {'volume': volume.clamp(0.0, 1.0)},
    );
  }
}

