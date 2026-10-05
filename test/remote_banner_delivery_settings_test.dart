import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lazy loading and the prefetch margin of a remote banner are backend-driven
/// only: the ad config's `lazyLoad` and `prefetchDistanceDp`, else the SDK
/// defaults. There is no publisher argument for either.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RemoteAdConfiguration config(
      {bool? lazyLoad, int? prefetchDistanceDp, int? refreshTimeSeconds}) {
    return RemoteAdConfiguration.fromJson({
      'id': 'remote-banner',
      'config': {
        'adType': 'banner',
        if (refreshTimeSeconds != null)
          'refreshTimeSeconds': refreshTimeSeconds,
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

  void seed(
      {bool? lazyLoad, int? prefetchDistanceDp, int? refreshTimeSeconds}) {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
      [
        config(
            lazyLoad: lazyLoad,
            prefetchDistanceDp: prefetchDistanceDp,
            refreshTimeSeconds: refreshTimeSeconds)
      ],
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
        isTrue,
        reason: 'lazy by default, like every other platform',
      );
      expect(ad.prefetchMargin, 200);
      expect(
        ad.refreshTimeInterval,
        0,
        reason: 'no refreshTimeSeconds means no periodic refresh',
      );
    });

    test('the ad config overrides the sdk defaults', () {
      seed(lazyLoad: true, prefetchDistanceDp: 600);
      final ad = build();
      expect(ad.isLazyLoad, isTrue);
      expect(ad.prefetchMargin, 600);
    });

    test('backend seconds reach the bridge in milliseconds, including zero',
        () {
      for (final seconds in [5, 10, 17, 600, 0]) {
        seed(refreshTimeSeconds: seconds);
        expect(build().refreshTimeInterval, seconds * 1000);
      }
    });

    test('null refresh seconds disables periodic refresh', () {
      final json = config().toJson();
      (json['config'] as Map<String, dynamic>)['refreshTimeSeconds'] = null;
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
        [RemoteAdConfiguration.fromJson(json)],
      );
      expect(build().refreshTimeInterval, 0);
    });

    test('native receives an explicit 0, not an omitted interval', () async {
      // An omitted key would let a plugin apply a default interval of its own.
      // Both natives treat an explicit 0 as "no periodic refresh".
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = MethodChannel(
        Constants.methodChannelName,
        StandardMethodCodec(AdMessageCodec()),
      );
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      Map<String, dynamic> withNullSeconds() {
        final json = config().toJson();
        (json['config'] as Map<String, dynamic>)['refreshTimeSeconds'] = null;
        return json;
      }

      for (final json in [config().toJson(), withNullSeconds()]) {
        calls.clear();
        AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
          [RemoteAdConfiguration.fromJson(json)],
        );
        final ad = build();
        await ad.load();
        final args = calls
            .singleWhere((c) => c.method == 'loadBannerAd')
            .arguments as Map;
        expect(args.containsKey('refreshTimeInterval'), isTrue);
        expect(args['refreshTimeInterval'], 0);
        await ad.dispose();
      }
    });

    test('resizeToPrebidCreative is off unless the ad config turns it on',
        () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channel = MethodChannel(
        Constants.methodChannelName,
        StandardMethodCodec(AdMessageCodec()),
      );
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      Future<Map<dynamic, dynamic>> loadArgs({bool? flag}) async {
        final json = config().toJson();
        if (flag != null) {
          (json['config'] as Map<String, dynamic>)['resizeToPrebidCreative'] =
              flag;
        }
        // Round-trip as the config cache does, so the field survives it.
        final cached = RemoteAdConfiguration.fromJson(
          RemoteAdConfiguration.fromJson(json).toJson(),
        );
        AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([cached]);
        calls.clear();
        final ad = build();
        await ad.load();
        await ad.dispose();
        return calls.singleWhere((c) => c.method == 'loadBannerAd').arguments
            as Map;
      }

      expect(build().resizeToPrebidCreative, isFalse);
      expect((await loadArgs()).containsKey('resizeToPrebidCreative'), isFalse);
      final offArgs = await loadArgs(flag: false);
      expect(offArgs.containsKey('resizeToPrebidCreative'), isFalse);
      expect((await loadArgs(flag: true))['resizeToPrebidCreative'], isTrue);
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
