import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `gamConfig.includeFluid` adds GAM's fluid size next to the slot's fixed
/// sizes (e.g. fluid GAM native styles); Prebid keeps its fixed sizes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> json({Object? includeFluid, bool set = false}) => {
        'id': 'remote-banner',
        'config': {'adType': 'banner'},
        'gamConfig': {
          'adUnitPath': '/1234/unit',
          'adSizes': ['300x250', '320x50'],
          if (set) 'includeFluid': includeFluid,
        },
        'prebidConfig': {
          'placementId': 'placement',
          'adSizes': ['300x250'],
        },
      };

  RemoteAdConfiguration parse({Object? includeFluid, bool set = false}) =>
      RemoteAdConfiguration.fromJson(
        json(includeFluid: includeFluid, set: set),
      );

  RemoteBannerAd build() => RemoteBannerAd(
        configId: 'remote-banner',
        onAdLoaded: (_) {},
        onAdFailedToLoad: (_, __) {},
      );

  tearDown(
    () => AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null),
  );

  group('parsing', () {
    test('absent is off', () {
      expect(parse().gamConfig.includeFluid, isFalse);
    });

    test('true is on', () {
      expect(
        parse(includeFluid: true, set: true).gamConfig.includeFluid,
        isTrue,
      );
    });

    test('malformed values are off and the config still parses', () {
      for (final raw in <Object?>[
        false,
        'true',
        1,
        null,
        <String, dynamic>{},
      ]) {
        final config = parse(includeFluid: raw, set: true);
        expect(config.gamConfig.includeFluid, isFalse, reason: '$raw');
        expect(config.gamConfig.adUnitPath, '/1234/unit', reason: '$raw');
      }
    });

    test('the cached copy keeps the flag', () {
      final cached = RemoteAdConfiguration.fromJson(
        parse(includeFluid: true, set: true).toJson(),
      );
      expect(cached.gamConfig.includeFluid, isTrue);
    });
  });

  group('banner', () {
    test('follows the ad config', () {
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([parse()]);
      expect(build().includeFluid, isFalse);
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
        [parse(includeFluid: true, set: true)],
      );
      expect(build().includeFluid, isTrue);
    });

    test('Prebid keeps its fixed sizes', () {
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
        [parse(includeFluid: true, set: true)],
      );
      final ad = build();
      expect(ad.prebidSizes!.map((s) => '${s.width}x${s.height}'), ['300x250']);
      expect(ad.sizes.length, 2, reason: 'GAM keeps its fixed sizes too');
    });

    test('reaches the plugins only when on', () async {
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

      Future<Map<dynamic, dynamic>> loadArgs(
        RemoteAdConfiguration config,
      ) async {
        AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([config]);
        calls.clear();
        final ad = build();
        await ad.load();
        await ad.dispose();
        return calls.singleWhere((c) => c.method == 'loadBannerAd').arguments
            as Map;
      }

      expect(
        (await loadArgs(parse())).containsKey('includeFluid'),
        isFalse,
        reason: 'absent unless on, so an older plugin is unchanged',
      );
      expect(
        (await loadArgs(parse(includeFluid: true, set: true)))['includeFluid'],
        isTrue,
      );
    });
  });
}
