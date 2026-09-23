import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lazy loading and the prefetch margin of a remote banner are backend-driven
/// only: the ad config's `lazyLoad` and `prefetchDistanceDp`, else the SDK
/// defaults. There is no publisher argument for either.
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

  RemoteBannerAd build() {
    return RemoteBannerAd(
      configId: 'remote-banner',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
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
        reason: 'Flutter keeps eager loading: its lazy path needs a mounted, '
            'sized AdWidget, which an integration that mounts only after '
            'onAdLoaded does not have. Deliberately unlike the native SDKs.',
      );
      expect(ad.prefetchMargin, 200);
    });

    test('the ad config overrides the sdk defaults', () {
      seed(lazyLoad: true, prefetchDistanceDp: 600);
      final ad = build();
      expect(ad.isLazyLoad, isTrue);
      expect(ad.prefetchMargin, 600);
    });

    test('a backend eager choice wins over nothing', () {
      seed(lazyLoad: false);
      expect(build().isLazyLoad, isFalse);
    });

    test('a prefetch distance of 0 is honoured, not treated as unset', () {
      seed(lazyLoad: true, prefetchDistanceDp: 0);
      expect(build().prefetchMargin, 0);
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
