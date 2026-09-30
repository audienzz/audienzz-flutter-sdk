import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late BannerAd ad;
  late List<MethodCall> calls;

  setUp(() async {
    calls = [];
    messenger
      ..setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
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
    adInstanceManager.currentPage = 'A';
    ad = BannerAd(
      sizes: const {AdSize(width: 320, height: 50)},
      adUnitId: '/unit',
      auConfigId: 'config',
      smartRefresh: true,
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    await ad.load();
  });

  tearDown(() async {
    await ad.dispose();
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('widget visibility and disposal never issue a publisher resume',
      (tester) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                SizedBox(width: 320, height: 50, child: AdWidget(ad: ad)),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await ad.pauseAutoRefresh();
    calls.clear();
    scroll.jumpTo(800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      calls
          .where((c) => c.method == 'setBannerViewportVisible')
          .map((c) => (c.arguments as Map)['visible']),
      containsAllInOrder([false, true]),
    );
    expect(calls.where((c) => c.method == 'resumeBannerAutoRefresh'), isEmpty);
    expect(calls.where((c) => c.method == 'pauseBannerAutoRefresh'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    expect(calls.last.method, 'setBannerViewportVisible');
    expect((calls.last.arguments as Map)['visible'], false);
    scroll.dispose();
  });

  test('public resume clears publisher pause through its own channel operation',
      () async {
    await ad.pauseAutoRefresh();
    await adInstanceManager.setBannerViewportVisible(ad, visible: false);
    await adInstanceManager.setBannerViewportVisible(ad, visible: true);
    await ad.resumeAutoRefresh();
    expect(calls.skip(1).map((c) => c.method), [
      'pauseBannerAutoRefresh',
      'setBannerViewportVisible',
      'setBannerViewportVisible',
      'resumeBannerAutoRefresh',
    ]);
  });
}
