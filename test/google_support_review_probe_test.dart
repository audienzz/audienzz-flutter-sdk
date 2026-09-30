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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(Constants.methodChannelName, StandardMethodCodec(AdMessageCodec()));
  late RemoteBannerAd ad;
  late List<MethodCall> calls;
  bool? lastVisible() {
    final verdicts = calls.where((c) => c.method == 'setBannerViewportVisible');
    return verdicts.isEmpty ? null : (verdicts.last.arguments as Map)['visible'] as bool;
  }
  setUp(() async {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
      return null;
    });
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'review', 'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {'adUnitPath': '/1234/test', 'adSizes': ['320x50']},
        'prebidConfig': {'placementId': 'test', 'adSizes': ['320x50']},
      })
    ]);
    adInstanceManager.currentPage = 'A';
    await AudienzzSdkFlutter.instance.setSmartRefreshV2Enabled(true);
    ad = RemoteBannerAd(configId: 'review', onAdLoaded: (_) {}, onAdFailedToLoad: (_, __) {});
    await ad.load();
  });
  tearDown(() async {
    await ad.dispose();
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });
  Widget page({double x = 0, double y = 0, double height = 50, bool offstage = false}) => MaterialApp(
    home: Scaffold(body: Center(child: Offstage(offstage: offstage, child: Transform.translate(
      offset: Offset(x, y), child: SizedBox(width: 320, height: height, child: AdWidget(ad: ad)),
    )))),
  );
  Future<void> establishVisible(WidgetTester tester) async {
    await tester.pumpWidget(page());
    ad.reportObscured(true);
    await tester.pump(const Duration(seconds: 1));
    expect(lastVisible(), isFalse, reason: 'control: a real false verdict must reach native');
    ad.reportObscured(false);
    await tester.pump(const Duration(seconds: 1));
    expect(lastVisible(), isTrue, reason: 'control: a real true verdict must reach native');
  }
  // The probe set debugDefaultTargetPlatformOverride inside each test body and
  // cleared it only in tearDown. Flutter verifies that foundation debug vars are
  // unset immediately after the body returns, BEFORE tearDown runs, so every
  // test aborted on that invariant regardless of its own assertions. Scoping the
  // override to the body fixes the harness without altering a single assertion.
  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform v2 must reject a banner with only 25 percent entering from below', (tester) async {
      await onPlatform(platform, () async {
      await establishVisible(tester);
      expect(calls.where((c) => c.method == 'setSmartRefreshV2Enabled').single.arguments, {'enabled': true});
      final rect = tester.getRect(find.byType(AdWidget));
      final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final dy = screenBottom - rect.height * 0.25 - rect.top;
      await tester.pumpWidget(page(y: dy));
      await tester.pump(const Duration(seconds: 2));
      final moved = tester.getRect(find.byType(AdWidget));
      expect((screenBottom - moved.top) / moved.height, closeTo(0.25, 0.001));
      expect(lastVisible(), isFalse, reason: 'public v2 contract requires at least half entering from below');
      });
    });
    testWidgets('$platform horizontally absent banner must pause', (tester) async {
      await onPlatform(platform, () async {
      await establishVisible(tester);
      await tester.pumpWidget(page(x: 1500));
      await tester.pump(const Duration(seconds: 2));
      expect(lastVisible(), isFalse, reason: 'zero intersection width is not visible');
      });
    });
    testWidgets('$platform collapsed banner must pause', (tester) async {
      await onPlatform(platform, () async {
      await establishVisible(tester);
      await tester.pumpWidget(page(height: 0));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getSize(find.byType(AdWidget)).height, 0);
      expect(lastVisible(), isFalse, reason: 'a zero-height banner cannot render');
      });
    });
    testWidgets('$platform offstage banner must pause', (tester) async {
      await onPlatform(platform, () async {
      await establishVisible(tester);
      await tester.pumpWidget(page(offstage: true));
      await tester.pump(const Duration(seconds: 2));
      expect(lastVisible(), isFalse, reason: 'offstage child remains mounted but is not painted');
      });
    });
    testWidgets('$platform same loaded ad remounted visibly must resume', (tester) async {
      await onPlatform(platform, () async {
      await establishVisible(tester);
      await tester.pumpWidget(const SizedBox());
      expect(lastVisible(), isFalse, reason: 'unmount sends the native pause');
      await tester.pumpWidget(page());
      await tester.pump(const Duration(seconds: 2));
      expect(lastVisible(), isTrue, reason: 'the new widget must clear the previous widget pause');
      });
    });
  }
}
