import 'dart:developer';
import 'dart:io';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_targeting.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';

final class AudienzzSdkFlutter {
  const AudienzzSdkFlutter._();

  static final _instance = const AudienzzSdkFlutter._().._init();

  static AudienzzSdkFlutter get instance => _instance;

  /// Required to initialize the SDK.
  Future<InitializationStatus> initialize({
    required String companyId,
    bool isAutomaticPpidEnabled = false,
  }) {
    return adInstanceManager.initialize(
      companyId: companyId,
      isAutomaticPpidEnabled: isAutomaticPpidEnabled,
    );
  }

  /// Required to initialize the SDK with remote configuration.
  Future<InitializationStatus> initializeRemote({
    required String publisherId,
    required String remoteUrl,
    bool isAutomaticPpidEnabled = false,
    bool enablePolling = true,
  }) async {
    final audienzzRemoteConfig = AudienzzRemoteConfig.instance
      ..configureRemote(
        remoteUrl: remoteUrl,
        publisherId: publisherId,
      );
    try {
      await audienzzRemoteConfig.fetchPublisherConfig(
        enablePolling: enablePolling,
      );
    } catch (e) {
      log('Audienzz SDK: Remote config unavailable: $e');
      return enablePolling
          ? InitializationStatus.fallbackPolling
          : InitializationStatus.fail;
    }

    final config = audienzzRemoteConfig.publisherConfig;
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
                                        "asi": $advertisingSystemDomain,
                                        "sid": $sellerId,
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
      isAutomaticPpidEnabled: isAutomaticPpidEnabled,
      prebidServerUrl: audienzzRemoteConfig.publisherConfig?.prebidServer.url,
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

  /// Opens Google's **Ad Inspector** — an in-app diagnostic overlay that lists
  /// recent ad requests and, per request, whether it filled and (if not) why.
  ///
  /// Use it to diagnose no-fill: it reports the auction outcome, AdX/AdSense/
  /// Open Bidding fill, latency, and mediation results directly on the device,
  /// with no Google Ad Manager access required. The overlay is presented by the
  /// native Google Mobile Ads SDK; the returned future completes when the
  /// inspector is closed.
  ///
  /// Diagnostic use only — do not ship a production UI entry point for it.
  Future<void> openAdInspector() {
    return adInstanceManager.methodChannel.invokeMethod<void>(
      'openAdInspector',
    );
  }

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
