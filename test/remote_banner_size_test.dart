import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Delivered-size handling shared by every banner, including a low-level
/// `RemoteBannerAd` mounted in an `AdWidget` without `AudienzzBanner`.
///
/// Both plugins push `onAdSizeChanged` before `onAdLoaded` on every delivery
/// that changes the size (Android did not before 0.3.1). These tests drive
/// those channel events and assert the public surface: `adSize`,
/// `adSizeListenable`, `AdWidget`'s laid-out height and the AUDZ lines.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;
  late int platformViewsCreated;
  AdSize? lookupReply;

  setUp(() {
    calls = [];
    platformViewsCreated = 0;
    lookupReply = null;
    messenger
      ..setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getPlatformAdSize') {
          return lookupReply;
        }
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          platformViewsCreated++;
          return 0;
        }
        if (call.method == 'resize') {
          final args = call.arguments as Map;
          return {'width': args['width'], 'height': args['height']};
        }
        return null;
      });
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': '46',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 7},
        'gamConfig': {
          'adUnitPath': '/96628199/multi-size',
          'adSizes': ['300x250', '300x600', '320x50'],
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['300x250', '300x600', '320x50'],
        },
      }),
    ]);
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<RemoteBannerAd> loadedAd({
    void Function(BannerAd ad, AdSize size)? onSize,
  }) async {
    final ad = RemoteBannerAd(
      configId: '46',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
      onAdSizeChanged: onSize,
    );
    await ad.load();
    return ad;
  }

  Future<void> event(
    RemoteBannerAd ad,
    String name, {
    int? width,
    int? height,
  }) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onAdEvent', {
          'adId': adInstanceManager.adIdFor(ad),
          'eventName': name,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        }),
      ),
      (_) {},
    );
  }

  /// A delivery as both plugins now report it: size first, then the load.
  Future<void> deliver(RemoteBannerAd ad, int width, int height) async {
    await event(ad, 'onAdSizeChanged', width: width, height: height);
    await event(ad, 'onAdLoaded');
  }

  test('a pushed size is readable as adSize and notifies listeners', () async {
    final pushed = <String>[];
    final ad = await loadedAd(
      onSize: (_, size) => pushed.add('${size.width}x${size.height}'),
    );
    final seen = <int?>[];
    ad.adSizeListenable.addListener(
      () => seen.add(ad.adSizeListenable.value?.height),
    );
    expect(ad.adSize, isNull);

    await deliver(ad, 320, 50);
    expect(ad.adSize?.width, 320);
    expect(ad.adSize?.height, 50);

    await deliver(ad, 300, 600);
    expect(seen, [50, 600]);
    expect(pushed, ['320x50', '300x600']);
    await ad.dispose();
  });

  test('a lookup reply is recorded when no push arrived', () async {
    final ad = await loadedAd();
    lookupReply = const AdSize(width: 300, height: 250);
    final reply = await ad.getPlatformAdSize();
    expect(reply?.height, 250);
    expect(ad.adSize?.height, 250);
    await ad.dispose();
  });

  test('diagnostics log the size change and every delivery', () async {
    final lines = <String>[];
    final oldEnabled = AudienzzDiagnostics.isEnabled;
    final oldSink = AudienzzDiagnostics.sink;
    AudienzzDiagnostics.isEnabled = true;
    AudienzzDiagnostics.sink = lines.add;
    addTearDown(() {
      AudienzzDiagnostics.isEnabled = oldEnabled;
      AudienzzDiagnostics.sink = oldSink;
    });
    final ad = await loadedAd();
    final id = adInstanceManager.adIdFor(ad);

    await deliver(ad, 300, 250);
    await event(ad, 'onAdLoaded'); // refresh, same size: no new push
    await deliver(ad, 320, 50);

    const unit = '/96628199/multi-size';
    expect(
      lines.where((l) => l.startsWith('AUDZ banner ')),
      [
        'AUDZ banner size adId=$id unit=$unit size=300x250 source=push',
        'AUDZ banner loaded adId=$id unit=$unit size=300x250',
        'AUDZ banner loaded adId=$id unit=$unit size=300x250',
        'AUDZ banner size adId=$id unit=$unit size=320x50 source=push',
        'AUDZ banner loaded adId=$id unit=$unit size=320x50',
      ],
    );
    await ad.dispose();
  });

  group('AdWidget', () {
    Widget scrollable(Widget child) => MaterialApp(
          home: Scaffold(
            body: ListView(children: [child]),
          ),
        );

    testWidgets(
        'sizes itself to the creative when the parent leaves height open',
        (tester) async {
      final ad = await loadedAd();
      await tester.pumpWidget(scrollable(AdWidget(ad: ad)));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(AdWidget)).height,
        250,
        reason: 'first configured size reserved before delivery',
      );

      await deliver(ad, 320, 50);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdWidget)).height, 50);

      await deliver(ad, 300, 600);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdWidget)).height, 600);
      expect(
        platformViewsCreated,
        1,
        reason: 'resizing must not recreate the platform view',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await ad.dispose();
    });

    testWidgets('a fixed-height parent keeps control', (tester) async {
      final ad = await loadedAd();
      await tester.pumpWidget(
        scrollable(SizedBox(height: 100, child: AdWidget(ad: ad))),
      );
      await tester.pumpAndSettle();

      await deliver(ad, 300, 600);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdWidget)).height, 100);
      expect(ad.adSize?.height, 600, reason: 'size still reported');
      expect(platformViewsCreated, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await ad.dispose();
    });

    testWidgets('a loosely bounded parent keeps today\'s behaviour (fill)',
        (tester) async {
      // Bounded but not tight, e.g. a banner aligned inside a fixed area: the
      // ad keeps filling the space it is given, exactly as before 0.3.1.
      final ad = await loadedAd();
      await tester.pumpWidget(
        scrollable(
          SizedBox(
            height: 300,
            child: Align(
              alignment: Alignment.topCenter,
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await deliver(ad, 320, 50);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AdWidget)).height, 300);

      await tester.pumpWidget(const SizedBox.shrink());
      await ad.dispose();
    });
  });
}
