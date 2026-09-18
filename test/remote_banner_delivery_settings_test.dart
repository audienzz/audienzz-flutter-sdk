import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lazy loading and the prefetch margin are delivery decisions a publisher has
/// to be able to make.
///
/// [RemoteBannerAd] derived both from the ad config alone, so a publisher whose
/// slot auctioned at the wrong moment had no lever without a backend change.
void main() {
  RemoteAdConfiguration config({bool? lazyLoad, int? prefetchDistanceDp}) {
    return RemoteAdConfiguration.fromJson({
      'id': 'remote-banner',
      'config': {
        'adType': 'banner',
        'refreshTimeSeconds': 30,
        if (lazyLoad != null) 'lazyLoad': lazyLoad,
        if (prefetchDistanceDp != null)
          'prefetchDistanceDp': prefetchDistanceDp,
      },
      'gamConfig': {
        'adUnitPath': '/1234/unit',
        'adSizes': ['320x50'],
      },
      'prebidConfig': {
        'placementId': 'placement',
        'adSizes': ['320x50'],
      },
    });
  }

  void seed({bool? lazyLoad, int? prefetchDistanceDp}) {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
      [config(lazyLoad: lazyLoad, prefetchDistanceDp: prefetchDistanceDp)],
    );
  }

  RemoteBannerAd build({bool? isLazyLoad, int? prefetchMargin}) {
    return RemoteBannerAd(
      configId: 'remote-banner',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
      isLazyLoad: isLazyLoad,
      prefetchMargin: prefetchMargin,
    );
  }

  tearDown(
    () => AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null),
  );

  group('resolution precedence', () {
    test('an ad config that says nothing gets the sdk defaults', () {
      seed();
      final ad = build();
      expect(
        ad.isLazyLoad,
        isFalse,
        reason: 'remote banners auction at load() unless asked otherwise',
      );
      expect(ad.prefetchMargin, 200);
    });

    test('the ad config overrides the sdk defaults', () {
      seed(lazyLoad: true, prefetchDistanceDp: 600);
      final ad = build();
      expect(ad.isLazyLoad, isTrue);
      expect(ad.prefetchMargin, 600);
    });

    test('the publisher overrides the ad config', () {
      seed(lazyLoad: true, prefetchDistanceDp: 600);
      final ad = build(isLazyLoad: false, prefetchMargin: 900);
      expect(ad.isLazyLoad, isFalse);
      expect(ad.prefetchMargin, 900);
    });

    test('omitting the publisher argument falls back to the ad config', () {
      seed(lazyLoad: true, prefetchDistanceDp: 600);
      final ad = build(prefetchMargin: 900);
      expect(ad.isLazyLoad, isTrue, reason: 'only the margin was overridden');
      expect(ad.prefetchMargin, 900);
    });

    test('a prefetch margin of 0 is honoured, not treated as unset', () {
      seed(prefetchDistanceDp: 600);
      expect(build(prefetchMargin: 0).prefetchMargin, 0);
    });
  });

  group('decoding', () {
    test('lazyLoad decodes from the remote payload', () {
      expect(config(lazyLoad: true).config.lazyLoad, isTrue);
      expect(config(lazyLoad: false).config.lazyLoad, isFalse);
      expect(config().config.lazyLoad, isNull);
    });

    test('lazyLoad survives a cache round trip', () {
      final json = config(lazyLoad: true, prefetchDistanceDp: 600).toJson();
      final restored = RemoteAdConfiguration.fromJson(json);
      expect(restored.config.lazyLoad, isTrue);
      expect(restored.config.prefetchDistanceDp, 600);
    });
  });
}
