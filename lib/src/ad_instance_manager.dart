import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ads/base/ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_without_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/rewarded_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/reward_item_missing_exception.dart';
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
        assert(call.method == 'onAdEvent', 'Unsupported ad event');

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

  int? adIdFor(Ad ad) => _loadedAds.keys.firstWhereOrNull(
        (key) => _loadedAds[key] == ad,
      );

  final Set<int> _mountedWidgetAdIds = <int>{};

  bool isWidgetAdIdMounted(int adId) => _mountedWidgetAdIds.contains(adId);

  void mountWidgetAdId(int adId) => _mountedWidgetAdIds.add(adId);

  void unmountWidgetAdId(int adId) => _mountedWidgetAdIds.remove(adId);

  final methodChannel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );

  Future<InitializationStatus> initialize({
    required String companyId,
  }) async {
    try {
      final initializationStatus =
          await methodChannel.invokeMethod<InitializationStatus>(
        'initialize',
        {'companyId': companyId},
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
      throw const RewardItemMissingException();
    }

    if (ad is RewardedAd) {
      ad.onUserEarnedRewardCallback.call(ad, rewardItem);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  Future<void> loadBannerAd(BannerAd ad) {
    if (adIdFor(ad) != null) {
      return Future<void>.value();
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    return methodChannel.invokeMethod<void>(
      'loadBannerAd',
      {
        'adId': adId,
        'adUnitId': ad.adUnitId,
        'auConfigId': ad.auConfigId,
        'adSize': ad.size,
        'isAdaptiveSize': ad.isAdaptiveSize,
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
        if (ad.keyword != null) 'keyword': ad.keyword,
        if (ad.keywords.isNotEmpty) 'keywords': ad.keywords,
        if (ad.appContent != null) 'appContent': ad.appContent,
      },
    );
  }

  Future<void> loadRewardedAd(RewardedAd ad) {
    if (adIdFor(ad) != null) {
      return Future<void>.value();
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    return methodChannel.invokeMethod<void>(
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
        if (ad.keyword != null) 'keyword': ad.keyword,
        if (ad.keywords.isNotEmpty) 'keywords': ad.keywords,
        if (ad.appContent != null) 'appContent': ad.appContent,
      },
    );
  }

  Future<void> loadInterstitialAd(InterstitialAd ad) {
    if (adIdFor(ad) != null) {
      return Future<void>.value();
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    return methodChannel.invokeMethod<void>(
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
        if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
        if (ad.gpId != null) 'gpId': ad.gpId,
        if (ad.keyword != null) 'keyword': ad.keyword,
        if (ad.keywords.isNotEmpty) 'keywords': ad.keywords,
        if (ad.appContent != null) 'appContent': ad.appContent,
      },
    );
  }

  Future<void> showAdWithoutView(AdWithoutView ad) async {
    final adId = adIdFor(ad);

    assert(
      adId != null,
      '$Ad has not been loaded or has already been disposed.',
    );

    return methodChannel.invokeMethod<void>(
      'showAdWithoutView',
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
}
