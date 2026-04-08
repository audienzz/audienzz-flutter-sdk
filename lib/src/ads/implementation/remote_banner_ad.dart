import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:audienzz_sdk_flutter/src/utils/ad_size_mapper.dart';

final class RemoteBannerAd extends BannerAd {
  RemoteBannerAd({
    required this.configId,
    required super.onAdLoaded,
    required super.onAdFailedToLoad,
    super.adFormat,
    super.apiParameters,
    super.protocols,
    super.placement,
    super.playbackMethods,
    super.videoBitrate,
    super.videoDuration,
    super.pbAdSlot,
    super.gpId,
    super.impOrtbConfig,
    super.onAdClicked,
    super.onAdClosed,
    super.onAdOpened,
    super.onAdImpression,
  }) : super(
          sizes: _getSizes(configId),
          adUnitId: _getAdUnitId(configId),
          auConfigId: _getAuConfigId(configId),
          refreshTimeInterval: _getRefreshTime(configId),
          isAdaptiveSize: _getIsAdaptive(configId),
          // Always enable smart refresh for remote-config banners: pause auto-refresh
          // when the ad scrolls off-screen, resume (or force-refresh if stale) on return.
          smartRefresh: true,
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

  static const _defaultRefreshSeconds = 30;

  static int _getRefreshTime(String configId) {
    // Fall back to 30 s when refreshTimeSeconds is absent or null in the remote payload.
    final seconds =
        _getConfig(configId)?.config.refreshTimeSeconds ?? _defaultRefreshSeconds;
    return seconds * 1000;
  }

  static bool _getIsAdaptive(String configId) {
    return _getConfig(configId)?.gamConfig.adaptiveBannerConfig?.enabled ??
        false;
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
