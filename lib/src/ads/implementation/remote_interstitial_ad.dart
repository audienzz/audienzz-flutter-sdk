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
    required super.adFormat,
    super.minSizePercentage,
    super.apiParameters,
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
  }) : super(
          adUnitId: _getAdUnitId(configId),
          auConfigId: _getAuConfigId(configId),
          sizes: _getSizes(configId),
        );

  final String configId;

  static RemoteAdConfiguration? _getConfig(String configId) {
    return AudienzzRemoteConfig.instance.remoteConfigFor(configId);
  }

  static Set<AdSize> _getSizes(String configId) {
    return AdSizeMapper.map(_getConfig(configId)?.gamConfig.adSizes ?? []);
  }

  static String _getAdUnitId(String configId) {
    return _getConfig(configId)?.gamConfig.adUnitPath ?? '';
  }

  static String _getAuConfigId(String configId) {
    return _getConfig(configId)?.prebidConfig.placementId ?? '';
  }

  @override
  Future<void> load() async {
    if (_getConfig(configId) == null) {
      log('Config with id $configId not found');
      onAdFailedToLoad(
        this,
        AdError(code: -1, message: 'Config with id $configId not found'),
      );
      return;
    }
    return super.load();
  }
}
