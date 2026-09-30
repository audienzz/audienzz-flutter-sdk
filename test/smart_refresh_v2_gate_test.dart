import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/refresh/smart_refresh_policy.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The public API documents a directional v2 gate: top fully on screen, at
/// most half below the viewport. Flutter forwarded the override to native and
/// then judged its own banners with the v1 threshold anyway, so on Flutter the
/// switch changed nothing observable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  bool? lastVisible() {
    final verdicts =
        calls.where((c) => c.method == 'setBannerViewportVisible');
    return verdicts.isEmpty
        ? null
        : (verdicts.last.arguments as Map)['visible'] as bool;
  }

  RemotePublisherConfiguration publisher({bool? smartRefreshV2}) =>
      RemotePublisherConfiguration.fromJson({
        'id': 1,
        'prebidServer': {
          'url': 'https://example.invalid/openrtb2/prebid',
          'accountId': '3927',
          'statusUrl': 'https://example.invalid/status',
        },
        'ortb': <String, dynamic>{},
        if (smartRefreshV2 != null) 'smartRefreshV2': smartRefreshV2,
      });

  setUp(() {
    calls = [];
    SmartRefreshPolicy.instance.resetForTesting();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
      return null;
    });
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'v2',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {
          'adUnitPath': '/1234/test',
          'adSizes': ['320x50'],
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['320x50'],
        },
      })
    ]);
    adInstanceManager.currentPage = 'A';
  });

  tearDown(() {
    SmartRefreshPolicy.instance.resetForTesting();
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    AudienzzRemoteConfig.instance.setPublisherConfigForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  group('configuration precedence', () {
    test('nothing configured keeps v1', () {
      expect(SmartRefreshPolicy.instance.isV2Enabled, isFalse);
    });

    test('the backend value applies when there is no override', () {
      AudienzzRemoteConfig.instance
          .setPublisherConfigForTesting(publisher(smartRefreshV2: true));
      expect(SmartRefreshPolicy.instance.isV2Enabled, isTrue);
    });

    test('an explicit override beats the backend in both directions', () {
      AudienzzRemoteConfig.instance
          .setPublisherConfigForTesting(publisher(smartRefreshV2: false));
      SmartRefreshPolicy.instance.setOverride(true);
      expect(SmartRefreshPolicy.instance.isV2Enabled, isTrue);

      AudienzzRemoteConfig.instance
          .setPublisherConfigForTesting(publisher(smartRefreshV2: true));
      SmartRefreshPolicy.instance.setOverride(false);
      expect(SmartRefreshPolicy.instance.isV2Enabled, isFalse);
    });

    test('clearing the override defers to the backend again', () {
      AudienzzRemoteConfig.instance
          .setPublisherConfigForTesting(publisher(smartRefreshV2: true));
      SmartRefreshPolicy.instance.setOverride(false);
      expect(SmartRefreshPolicy.instance.isV2Enabled, isFalse);
      SmartRefreshPolicy.instance.setOverride(null);
      expect(SmartRefreshPolicy.instance.isV2Enabled, isTrue);
    });
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('$platform geometry', () {
      late RemoteBannerAd ad;

      Widget page({double dy = 0}) => MaterialApp(
            home: Scaffold(
              body: Center(
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: SizedBox(
                    width: 320,
                    height: 50,
                    child: AdWidget(ad: ad),
                  ),
                ),
              ),
            ),
          );

      /// Positions the ad so its top edge lands on [top] and returns the
      /// verdict that reached native.
      Future<bool?> verdictWithTopAt(WidgetTester tester, double top) async {
        await tester.pumpWidget(page());
        final resting = tester.getRect(find.byType(AdWidget));
        await tester.pumpWidget(page(dy: top - resting.top));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.getRect(find.byType(AdWidget)).top, closeTo(top, 0.01),
            reason: 'fixture must actually place the ad where it claims');
        return lastVisible();
      }

      Future<void> run(WidgetTester tester, Future<void> Function() body) async {
        debugDefaultTargetPlatformOverride = platform;
        ad = RemoteBannerAd(
          configId: 'v2',
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_, __) {},
        );
        await ad.load();
        try {
          await body();
        } finally {
          await ad.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      }

      testWidgets('v2 accepts exactly half below the viewport', (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(true);
          final screenBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          // 25 of 50 logical pixels below the fold — the boundary itself.
          expect(await verdictWithTopAt(tester, screenBottom - 25), isTrue);
        });
      });

      testWidgets('v2 rejects one pixel more than half below the viewport',
          (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(true);
          final screenBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(await verdictWithTopAt(tester, screenBottom - 24), isFalse);
        });
      });

      testWidgets('v2 accepts a top edge exactly at the viewport top',
          (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(true);
          expect(await verdictWithTopAt(tester, 0), isTrue);
        });
      });

      testWidgets('v2 rejects a clipped top edge', (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(true);
          expect(await verdictWithTopAt(tester, -2), isFalse,
              reason: 'v2 requires the top edge fully on screen');
        });
      });

      testWidgets('v1 still accepts a quarter entering from below',
          (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(false);
          final screenBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(await verdictWithTopAt(tester, screenBottom - 12.5), isTrue,
              reason: 'v1 is the 20% threshold and must be unchanged');
        });
      });

      testWidgets('v1 still rejects below its threshold', (tester) async {
        await run(tester, () async {
          SmartRefreshPolicy.instance.setOverride(false);
          final screenBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(await verdictWithTopAt(tester, screenBottom - 9), isFalse);
        });
      });
    });
  }
}
