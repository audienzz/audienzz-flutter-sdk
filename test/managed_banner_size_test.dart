import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AudienzzBanner` sizing for FIXED (non-adaptive) multi-size placements.
///
/// 0.3.0 adopted the delivered size only for adaptive configs, so a fixed
/// placement stayed at `placeholderHeight` forever: a taller creative was cut
/// off and a shorter one left a gap. These tests drive the real widget through
/// the method channel and assert the slot's laid-out height.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  /// What the next `getPlatformAdSize` query answers. A function so a test can
  /// hand out a pending future or throw.
  late FutureOr<AdSize?> Function() platformSize;

  int lookups() => calls.where((c) => c.method == 'getPlatformAdSize').length;
  int loadCount() => calls.where((c) => c.method == 'loadBannerAd').length;

  setUp(() {
    calls = [];
    platformSize = () => null;
    messenger
      ..setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getPlatformAdSize') {
          return platformSize();
        }
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          return 0;
        }
        if (call.method == 'resize') {
          return {'width': 320.0, 'height': 50.0};
        }
        return null;
      });
    // A fixed multi-size placement, like production configs 46/50.
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'multi',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {
          'adUnitPath': '/96628199/multi-size',
          'adSizes': ['300x250', '320x50', '300x600'],
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['300x250', '320x50', '300x600'],
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

  Widget app(Widget child) => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  Object? adId() =>
      (calls.lastWhere((c) => c.method == 'loadBannerAd').arguments
          as Map)['adId'];

  Future<void> nativeEvent(String name, {int? width, int? height}) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('onAdEvent', {
            'adId': adId(),
            'eventName': name,
            if (width != null) 'width': width,
            if (height != null) 'height': height,
          }),
        ),
        (_) {},
      );

  double slotHeight(WidgetTester tester) =>
      tester.getSize(find.byType(AudienzzBanner)).height;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a shorter fixed creative shrinks the slot instead of leaving a gap',
      (tester) async {
    final sizes = <String>[];
    final order = <String>[];
    final controller = AudienzzBannerController();
    await tester.pumpWidget(
      app(
        AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'top',
            controller: controller,
            onAdSizeChanged: (_, size) {
              sizes.add('${size.width}x${size.height}');
              order.add('size');
            },
            onAdLoaded: (_) => order.add('loaded'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 250, reason: 'reservation before delivery');
    expect(controller.adSize, isNull);

    platformSize = () => const AdSize(width: 320, height: 50);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();

    expect(lookups(), 1, reason: 'fixed banners must read the delivered size');
    expect(slotHeight(tester), 50);
    expect(sizes, ['320x50']);
    expect(controller.adSize?.width, 320);
    expect(controller.adSize?.height, 50);
    expect(
      order,
      ['size', 'loaded'],
      reason: 'the size is readable when onAdLoaded fires',
    );
    await unmount(tester);
  });

  testWidgets('a taller fixed creative grows the slot instead of being cut off',
      (tester) async {
    await tester.pumpWidget(
      app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'middle',
            placeholderHeight: 50,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 50);

    platformSize = () => const AdSize(width: 300, height: 600);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 600);
    await unmount(tester);
  });

  testWidgets(
      'a refresh that serves a different size resizes and notifies once',
      (tester) async {
    final sizes = <String>[];
    final controller = AudienzzBannerController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    await tester.pumpWidget(
      app(
        AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'top',
            controller: controller,
            onAdSizeChanged: (_, size) =>
                sizes.add('${size.width}x${size.height}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    platformSize = () => const AdSize(width: 320, height: 50);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 50);

    // Same size again: a refresh with an identical creative size is no change.
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    expect(sizes, ['320x50']);

    platformSize = () => const AdSize(width: 300, height: 250);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();

    expect(lookups(), 3, reason: 'every delivery reads the size');
    expect(slotHeight(tester), 250);
    expect(sizes, ['320x50', '300x250']);
    expect(notifications, 2);
    expect(controller.adSize?.height, 250);
    expect(loadCount(), 1, reason: 'resizing never requests another ad');
    await unmount(tester);
  });

  testWidgets(
      'sizeToCreative: false keeps the reservation but still reports the size',
      (tester) async {
    final sizes = <String>[];
    final controller = AudienzzBannerController();
    await tester.pumpWidget(
      app(
        AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'wrapped',
            placeholderHeight: 160,
            sizeToCreative: false,
            controller: controller,
            onAdSizeChanged: (_, size) =>
                sizes.add('${size.width}x${size.height}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    platformSize = () => const AdSize(width: 320, height: 50);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();

    expect(slotHeight(tester), 160);
    expect(sizes, ['320x50']);
    expect(controller.adSize?.height, 50);
    await unmount(tester);
  });

  testWidgets(
      'a slow size reply for an earlier delivery cannot override a later one',
      (tester) async {
    await tester.pumpWidget(
      app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'multi', slotKey: 'top'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = Completer<AdSize?>();
    platformSize = () => first.future;
    await nativeEvent('onAdLoaded');
    await tester.pump();

    platformSize = () => const AdSize(width: 300, height: 600);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 600);

    first.complete(const AdSize(width: 320, height: 50));
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 600, reason: 'stale reply ignored');
    await unmount(tester);
  });

  testWidgets(
      'a failed size lookup keeps the reservation and still reports the load',
      (tester) async {
    var loaded = 0;
    platformSize = () => throw PlatformException(code: 'unavailable');
    await tester.pumpWidget(
      app(
        AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'top',
            onAdLoaded: (_) => loaded++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();

    expect(slotHeight(tester), 250);
    expect(loaded, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('an iOS size push resizes a fixed slot too', (tester) async {
    final sizes = <String>[];
    await tester.pumpWidget(
      app(
        AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'multi',
            slotKey: 'top',
            onAdSizeChanged: (_, size) =>
                sizes.add('${size.width}x${size.height}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    platformSize = () => const AdSize(width: 300, height: 250);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    await nativeEvent('onAdSizeChanged', width: 320, height: 50);
    await tester.pumpAndSettle();

    expect(slotHeight(tester), 50);
    expect(sizes, ['300x250', '320x50']);
    await unmount(tester);
  });

  testWidgets('a retired slot forgets its size and ignores a late reply',
      (tester) async {
    final sizes = <String>[];
    final controller = AudienzzBannerController();
    Widget page({required bool active}) => app(
          AudienzzPage(
            name: 'article',
            active: active,
            child: AudienzzBanner(
              adConfigId: 'multi',
              slotKey: 'top',
              controller: controller,
              onAdSizeChanged: (_, size) =>
                  sizes.add('${size.width}x${size.height}'),
            ),
          ),
        );
    await tester.pumpWidget(page(active: true));
    await tester.pumpAndSettle();

    platformSize = () => const AdSize(width: 320, height: 50);
    await nativeEvent('onAdLoaded');
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 50);

    final late = Completer<AdSize?>();
    platformSize = () => late.future;
    await nativeEvent('onAdLoaded');
    await tester.pump();

    await tester.pumpWidget(page(active: false));
    await tester.pumpAndSettle();
    expect(controller.adSize, isNull);
    expect(slotHeight(tester), 250, reason: 'back to the reservation');

    late.complete(const AdSize(width: 300, height: 600));
    await tester.pumpAndSettle();
    expect(slotHeight(tester), 250);
    expect(sizes, ['320x50']);
    await unmount(tester);
  });
}
