import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ads/base/ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_without_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/rewarded_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/ad_size_required_exception.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/sdk_initialization_failed_exception.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/entities/reward_item.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

final adInstanceManager = AdInstanceManager();

final class AdInstanceManager {
  AdInstanceManager() {
    methodChannel.setMethodCallHandler(
      (call) async {
        if (call.method != 'onAdEvent') {
          log('Unsupported ad event method: ${call.method}');
          return;
        }

        final args = call.arguments as Map<dynamic, dynamic>?;

        final adId = args?['adId'] as int?;
        final eventName = args?['eventName'] as String?;

        final ad = adFor(adId);

        if (ad != null && eventName != null) {
          _onAdEvent(ad, eventName, args);
        } else {
          log('$Ad with id $adId is not available for $eventName');
        }
      },
    );
  }

  int _nextAdId = 0;
  final _loadedAds = <int, Ad>{};

  Ad? adFor(int? adId) => _loadedAds[adId];

  // Look ads up by object identity, not by `==`. `Ad extends Equatable`, so two
  // distinct instances with identical configuration compare equal — an
  // equality-based lookup would collide them (a second load() would no-op, and
  // dispose() could remove the wrong ad's native view).
  int? adIdFor(Ad ad) => _loadedAds.keys.firstWhereOrNull(
        (key) => identical(_loadedAds[key], ad),
      );

  final Set<int> _mountedWidgetAdIds = <int>{};

  bool isWidgetAdIdMounted(int adId) => _mountedWidgetAdIds.contains(adId);

  void mountWidgetAdId(int adId) => _mountedWidgetAdIds.add(adId);

  void unmountWidgetAdId(int adId) => _mountedWidgetAdIds.remove(adId);

  /// Reload callbacks registered by mounted smart-refresh [AdWidget]s. Each one
  /// reloads its banner if it is currently on screen — see
  /// [notifyScreenResumedReload].
  final Set<void Function()> _screenResumeReloaders = <void Function()>{};

  void addScreenResumeReloader(void Function() reload) =>
      _screenResumeReloaders.add(reload);

  void removeScreenResumeReloader(void Function() reload) =>
      _screenResumeReloaders.remove(reload);

  /// Ask every mounted smart-refresh banner to reload if it is currently on
  /// screen. Invoked by [AudienzzSdkFlutter.onScreenResumed] after the page
  /// impression fires, so a returning route/tab shows a fresh creative —
  /// the Flutter analogue of the native screen-change reload.
  void notifyScreenResumedReload() {
    for (final reload in _screenResumeReloaders.toList()) {
      reload();
    }
  }

  final methodChannel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );

  Future<InitializationStatus> initialize({
    required String companyId,
    required bool isAutomaticPpidEnabled,
    String? prebidServerUrl,
  }) async {
    try {
      final initializationStatus =
          await methodChannel.invokeMethod<InitializationStatus>(
        'initialize',
        {
          'companyId': companyId,
          'isAutomaticPpidEnabled': isAutomaticPpidEnabled,
          if (prebidServerUrl != null) 'prebidServerUrl': prebidServerUrl,
        },
      );

      if (initializationStatus != null) {
        return initializationStatus;
      } else {
        throw const SdkInitializationFailedException();
      }
    } on PlatformException {
      throw const SdkInitializationFailedException();
    }
  }

  void _onAdEvent(Ad ad, String eventName, Map<dynamic, dynamic>? arguments) {
    return switch (eventName) {
      'onAdLoaded' => _invokeOnAdLoaded(ad, eventName),
      'onAdFailedToLoad' => _invokeOnAdFailedToLoad(ad, eventName, arguments),
      'onAdClicked' => _invokeOnAdClicked(ad, eventName),
      'onAdOpened' => _invokeOnAdOpened(ad, eventName),
      'onAdClosed' => _invokeOnAdClosed(ad, eventName),
      'onAdImpression' => _invokeOnAdImpression(ad, eventName),
      'onUserEarnedReward' =>
        _invokeOnUserEarnedReward(ad, eventName, arguments),
      _ => log('Invalid ad event name: $eventName'),
    };
  }

  void _invokeOnAdLoaded(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdLoaded.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdLoaded.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdLoaded.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdClicked(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdClicked?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdClicked?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdClicked?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdOpened(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdOpened?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdOpened?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdOpened?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdClosed(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdClosed?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdClosed?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdClosed?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdImpression(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdImpression?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdImpression?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdImpression?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdFailedToLoad(
    Ad ad,
    String eventName,
    Map<dynamic, dynamic>? arguments,
  ) {
    if (ad is BannerAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else if (ad is RewardedAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else if (ad is InterstitialAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnUserEarnedReward(
    Ad ad,
    String eventName,
    Map<dynamic, dynamic>? arguments,
  ) {
    final rewardItem = arguments?['rewardItem'] as RewardItem?;

    if (rewardItem == null) {
      // Throwing here would surface as an unhandled async error inside the
      // method-channel handler — the app gets neither the reward nor a
      // catchable error. Log and drop instead.
      log('$eventName received without a reward item; ignoring');
      return;
    }

    if (ad is RewardedAd) {
      ad.onUserEarnedRewardCallback.call(ad, rewardItem);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  Future<void> loadBannerAd(BannerAd ad) async {
    if (adIdFor(ad) != null) {
      return;
    }

    if (ad.sizes.isEmpty) {
      throw const AdSizeRequiredException();
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    try {
      await methodChannel.invokeMethod<void>(
        'loadBannerAd',
        {
          'adId': adId,
          'adUnitId': ad.adUnitId,
          'auConfigId': ad.auConfigId,
          'adSizes': ad.sizes.toList(),
          'isAdaptiveSize': ad.isAdaptiveSize,
          'isLazyLoad': ad.isLazyLoad,
          'smartRefresh': ad.smartRefresh,
          'prefetchMargin': ad.prefetchMargin,
          if (ad.refreshTimeInterval != null)
            'refreshTimeInterval': ad.refreshTimeInterval,
          'adFormat': ad.adFormat,
          'apiParameters': ad.apiParameters.toList(),
          'protocols': ad.protocols.toList(),
          'placement': ad.placement,
          'playbackMethods': ad.playbackMethods.toList(),
          'videoBitrate': ad.videoBitrate,
          'videoDuration': ad.videoDuration,
          if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
          if (ad.gpId != null) 'gpId': ad.gpId,
          if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
        },
      );
    } on PlatformException catch (e) {
      _handleLoadChannelFailure(adId, ad, e);
    }
  }

  Future<void> loadRewardedAd(RewardedAd ad) async {
    if (adIdFor(ad) != null) {
      return;
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    try {
      await methodChannel.invokeMethod<void>(
        'loadRewardedAd',
        {
          'adId': adId,
          'adUnitId': ad.adUnitId,
          'auConfigId': ad.auConfigId,
          'apiParameters': ad.apiParameters.toList(),
          'protocols': ad.protocols.toList(),
          'placement': ad.placement,
          'playbackMethods': ad.playbackMethods.toList(),
          'videoBitrate': ad.videoBitrate,
          'videoDuration': ad.videoDuration,
          if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
          if (ad.gpId != null) 'gpId': ad.gpId,
          if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
        },
      );
    } on PlatformException catch (e) {
      _handleLoadChannelFailure(adId, ad, e);
    }
  }

  Future<void> loadInterstitialAd(InterstitialAd ad) async {
    if (adIdFor(ad) != null) {
      return;
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    try {
      await methodChannel.invokeMethod<void>(
        'loadInterstitialAd',
        {
          'adId': adId,
          'adUnitId': ad.adUnitId,
          'auConfigId': ad.auConfigId,
          'adFormat': ad.adFormat,
          'apiParameters': ad.apiParameters.toList(),
          'protocols': ad.protocols.toList(),
          'placement': ad.placement,
          'playbackMethods': ad.playbackMethods.toList(),
          'videoBitrate': ad.videoBitrate,
          'videoDuration': ad.videoDuration,
          'minSizePercentage': ad.minSizePercentage,
          if (ad.sizes.isNotEmpty) 'adSizes': ad.sizes.toList(),
          if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
          if (ad.gpId != null) 'gpId': ad.gpId,
          if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
        },
      );
    } on PlatformException catch (e) {
      _handleLoadChannelFailure(adId, ad, e);
    }
  }

  /// Undo a failed native load: drop the registry entry (so a retry actually
  /// re-loads instead of early-returning "already registered") and surface the
  /// failure through the ad's own `onAdFailedToLoad` callback.
  void _handleLoadChannelFailure(int adId, Ad ad, PlatformException e) {
    _loadedAds.remove(adId);
    final error = AdError(
      code: int.tryParse(e.code) ?? -1,
      message: e.message ?? 'Failed to load ad',
    );
    if (ad is BannerAd) {
      ad.onAdFailedToLoad(ad, error);
    } else if (ad is RewardedAd) {
      ad.onAdFailedToLoad(ad, error);
    } else if (ad is InterstitialAd) {
      ad.onAdFailedToLoad(ad, error);
    }
  }

  Future<void> showAdWithoutView(AdWithoutView ad) async {
    final adId = adIdFor(ad);

    // A real throw, not an assert: asserts are stripped in release builds, so
    // an unloaded ad would otherwise send {'adId': null} to the native side.
    if (adId == null) {
      throw StateError(
        'Ad has not been loaded or has already been disposed.',
      );
    }

    return methodChannel.invokeMethod<void>(
      'showAdWithoutView',
      {'adId': adId},
    );
  }

  Future<AdSize?> getPlatformAdSize(BannerAd ad) async {
    final adId = adIdFor(ad);

    if (adId == null) {
      throw StateError(
        'Ad has not been loaded or has already been disposed.',
      );
    }

    return methodChannel.invokeMethod<AdSize?>(
      'getPlatformAdSize',
      {'adId': adId},
    );
  }

  Future<void> disposeAd(Ad ad) {
    final adId = adIdFor(ad);
    final disposedAd = _loadedAds.remove(adId);

    if (disposedAd == null) {
      return Future<void>.value();
    }

    return methodChannel.invokeMethod<void>(
      'disposeAd',
      {'adId': adId},
    );
  }

  Future<void> pauseBannerAutoRefresh(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'pauseBannerAutoRefresh',
      {'adId': adId},
    );
  }

  Future<void> resumeBannerAutoRefresh(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'resumeBannerAutoRefresh',
      {'adId': adId},
    );
  }

  /// Force a fresh auction now for [ad], regardless of the refresh timer —
  /// calls the native `AUBannerView.reloadAd()` / `AudienzzAdViewHandler.reloadAd()`.
  Future<void> reloadBanner(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'reloadBanner',
      {'adId': adId},
    );
  }

  /// Pauses auto-refresh for every currently loaded banner ad.
  Future<void> pauseAllBannerAutoRefresh() async {
    for (final entry in _loadedAds.entries) {
      if (entry.value is BannerAd) {
        await methodChannel.invokeMethod<void>(
          'pauseBannerAutoRefresh',
          {'adId': entry.key},
        );
      }
    }
  }

  /// Resumes auto-refresh for every currently loaded banner ad.
  Future<void> resumeAllBannerAutoRefresh() async {
    for (final entry in _loadedAds.entries) {
      if (entry.value is BannerAd) {
        await methodChannel.invokeMethod<void>(
          'resumeBannerAutoRefresh',
          {'adId': entry.key},
        );
      }
    }
  }
}
