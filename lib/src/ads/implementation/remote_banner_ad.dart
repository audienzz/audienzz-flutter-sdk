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
    // Lazy loading and the prefetch margin are deliberately not arguments:
    // they come from the ad config's `lazyLoad` and `prefetchDistanceDp`
    // alone, so a placement behaves the same in every app and on every
    // platform.
    super.pageKey,
    super.startPublisherPaused,
  }) : super(
          // GAM gets the GAM slot's sizes and Prebid gets Prebid's, the split
          // the native remote banners make. Feeding Prebid the GAM list asked
          // bidders for sizes the publisher kept out of header bidding.
          sizes: _getSizes(configId),
          prebidSizes: _getPrebidSizes(configId),
          // No Prebid sizes means the placement is sold through GAM alone.
          headerBidding: _getPrebidSizes(configId) != null,
          adUnitId: _getAdUnitId(configId),
          auConfigId: _getAuConfigId(configId),
          refreshTimeInterval: _getRefreshTime(configId),
          isAdaptiveSize: _getIsAdaptive(configId),
          adaptiveBannerConfig:
              _getConfig(configId)?.gamConfig.adaptiveBannerConfig,
          // Ad config -> SDK default, for both delivery settings.
          isLazyLoad: _getLazyLoad(configId),
          prefetchMargin: _getPrefetchMargin(configId),
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

  /// `prebidConfig.adSizes`, largest first — the order the native remote
  /// banners use, and the one that decides Prebid's primary size.
  ///
  /// `null` when the config lists none. The banner then serves GAM-only
  /// (`headerBidding: false`), as the native remote banners do; the plugins
  /// still build their Prebid ad unit from [sizes], which is never sent.
  static Set<AdSize>? _getPrebidSizes(String configId) {
    final adSizes = _getConfig(configId)?.prebidConfig.adSizes ?? [];
    final sizes = AdSizeMapper.map(adSizes).toList()
      ..sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return sizes.isEmpty ? null : sizes.toSet();
  }

  static String _getAdUnitId(String configId) {
    return _getConfig(configId)?.gamConfig.adUnitPath ?? '';
  }

  static String _getAuConfigId(String configId) {
    return _getConfig(configId)?.prebidConfig.placementId ?? '';
  }

  static const _defaultRefreshSeconds = 30;
  static const _defaultPrefetchMargin = 200;

  /// Lazy when the ad config says nothing, like every other platform.
  ///
  /// Flutter's lazy path needs the platform view to exist and be sized before
  /// a viewport verdict can be produced, so an integration must mount its
  /// `AdWidget` (or a sized placeholder around it) before `load()` completes.
  /// One that mounts it only after `onAdLoaded` never loads: no widget, no
  /// viewport, no load, no callback. See the lazy-loading note in the README.
  static const _defaultLazyLoad = true;

  static bool _getLazyLoad(String configId) {
    return _getConfig(configId)?.config.lazyLoad ?? _defaultLazyLoad;
  }

  static int _getRefreshTime(String configId) {
    // Fall back to 30 s when refreshTimeSeconds is absent or null in the remote payload.
    final seconds =
        _getConfig(configId)?.config.refreshTimeSeconds ?? _defaultRefreshSeconds;
    return seconds * 1000;
  }

  static int _getPrefetchMargin(String configId) {
    // Fall back to 200 logical pixels when prefetchDistanceDp is absent or null.
    // Maps to prefetchMarginDp on Android and prefetchMarginPoints on iOS.
    return _getConfig(configId)?.config.prefetchDistanceDp ?? _defaultPrefetchMargin;
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
    // Config-derived fields (adUnitId, sizes, …) are resolved once at
    // construction. If this ad was built before remote config was available,
    // they were baked empty even though the config exists now — that would be
    // a silent no-fill. Surface it instead of loading an unusable request.
    if (adUnitId.isEmpty || sizes.isEmpty) {
      log('RemoteBannerAd "$configId" was constructed before remote config '
          'was available; its ad unit/sizes are empty.');
      onAdFailedToLoad(
        this,
        AdError(
          code: -1,
          message: 'RemoteBannerAd "$configId" was constructed before remote '
              'config was available. Construct it after awaiting '
              'initializeRemote().',
        ),
      );
      return;
    }
    return super.load();
  }
}
