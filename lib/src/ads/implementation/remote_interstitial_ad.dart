import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:audienzz_sdk_flutter/src/utils/ad_size_mapper.dart';

final class RemoteInterstitialAd extends InterstitialAd {
  RemoteInterstitialAd({
    required this.configId,
    required super.onAdLoaded,
    required super.onAdFailedToLoad,
    super.minSizePercentage,
    super.protocols,
    super.placement,
    super.playbackMethods,
    super.videoBitrate,
    super.videoDuration,
    super.pbAdSlot,
    super.gpId,
    super.impOrtbConfig,
    super.onAdOpened,
    super.onAdClosed,
    super.onAdClicked,
    super.onAdImpression,
    super.onAdFailedToShow,
    super.onLifecycleEvent,
  }) : super(
          adUnitId: _getAdUnitId(configId),
          auConfigId: _getAuConfigId(configId),
          sizes: _getSizes(configId),
        );

  final String configId;

  static RemoteAdConfiguration? _getConfig(String configId) {
    return AudienzzRemoteConfig.instance.remoteConfigFor(configId);
  }

  /// The Prebid banner format for this interstitial: `prebidConfig.adSizes`,
  /// largest first — the field and order the native remote interstitials use.
  ///
  /// These sizes go ONLY to Prebid: both plugins put them on
  /// `bannerParameters.adSizes` (iOS also into the #1135 `banner.format`
  /// merge), and a GAM interstitial takes no sizes. They were read from
  /// `gamConfig.adSizes`, the GAM slot's list. The two match in every config
  /// today, so the request was right by coincidence; a publisher whose Prebid
  /// and GAM sizes differ got the wrong Prebid format on Flutter only.
  static Set<AdSize> _getSizes(String configId) {
    final adSizes = _getConfig(configId)?.prebidConfig.adSizes ?? [];
    final sizes = AdSizeMapper.map(adSizes).toList()
      ..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return sizes.toSet();
  }

  static String _getAdUnitId(String configId) {
    return _getConfig(configId)?.gamConfig.adUnitPath ?? '';
  }

  static String _getAuConfigId(String configId) {
    return _getConfig(configId)?.prebidConfig.placementId ?? '';
  }

  @override
  Future<void> load({bool throwOnFailure = false}) async {
    if (_getConfig(configId) == null) {
      log('Config with id $configId not found');
      final error =
          AdError(code: -1, message: 'Config with id $configId not found');
      onAdFailedToLoad(this, error);
      if (throwOnFailure) throw error;
      return;
    }
    return super.load(throwOnFailure: throwOnFailure);
  }
}
