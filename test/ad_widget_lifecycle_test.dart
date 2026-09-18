import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle cases the visibility poll alone does not cover.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  /// Every verdict delivered for [adId], in order.
  List<bool> verdictsFor(int adId) => calls
      .where((c) => c.method == 'setBannerViewportVisible')
      .map((c) => c.arguments as Map)
      .where((a) => a['adId'] == adId)
      .map((a) => a['visible'] as bool)
      .toList();

  setUp(() {
    calls = [];
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
        'id': 'lifecycle',
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
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<RemoteBannerAd> makeAd() async {
    final ad = RemoteBannerAd(
      configId: 'lifecycle',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    await ad.load();
    return ad;
  }

  // The tree shape is identical for every offset, so moving the ad updates the
  // existing State instead of remounting it — which is what makes the
  // "transitions only" assertion meaningful.
  Widget page(AdWithView ad, {double dy = 0}) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Transform.translate(
              offset: Offset(0, dy),
              child:
                  SizedBox(width: 320, height: 50, child: AdWidget(ad: ad)),
            ),
          ),
        ),
      );

  testWidgets('replacing the ad inside one AdWidget state pauses the outgoing '
      'ad and resumes the incoming one', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final first = await makeAd();
      final second = await makeAd();
      final firstId = adInstanceManager.adIdFor(first)!;
      final secondId = adInstanceManager.adIdFor(second)!;
      expect(firstId == secondId, isFalse);

      await tester.pumpWidget(page(first));
      await tester.pump(const Duration(seconds: 1));
      expect(verdictsFor(firstId).last, isTrue,
          reason: 'control: the first ad must be reported visible');

      // Same widget position, same State object, different ad.
      await tester.pumpWidget(page(second));
      await tester.pump(const Duration(seconds: 1));

      expect(verdictsFor(firstId).last, isFalse,
          reason: 'the replaced ad must not keep refreshing unseen');
      expect(verdictsFor(secondId), isNotEmpty,
          reason: 'the incoming ad must be synchronized, not assumed resumed');
      expect(verdictsFor(secondId).last, isTrue);

      await first.dispose();
      await second.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a hidden banner reports exactly one pause, not one per poll',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final ad = await makeAd();
      final adId = adInstanceManager.adIdFor(ad)!;
      await tester.pumpWidget(page(ad));
      await tester.pump(const Duration(seconds: 1));
      expect(verdictsFor(adId).last, isTrue, reason: 'control');

      await tester.pumpWidget(page(ad, dy: 5000));
      await tester.pump(const Duration(seconds: 3));

      final falses = verdictsFor(adId).where((v) => !v).length;
      expect(falses, 1,
          reason: 'transitions only — six poll ticks must not send six pauses');

      await ad.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the app going to background pauses without a geometry change',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final ad = await makeAd();
      final adId = adInstanceManager.adIdFor(ad)!;
      await tester.pumpWidget(page(ad));
      await tester.pump(const Duration(seconds: 1));
      expect(verdictsFor(adId).last, isTrue, reason: 'control');

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      expect(verdictsFor(adId).last, isFalse);

      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(verdictsFor(adId).last, isTrue);

      await ad.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
