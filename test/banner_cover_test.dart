import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the widget reports when something is painted over the banner.
///
/// The previous check treated "one of the ad's ancestors took the hit" as proof the ad was
/// visible. Every cover inside the same Stack, Scaffold or scrollable shares those ancestors, so
/// they all read as visible — while a cover that takes no pointers at all was never in the hit
/// path to begin with.
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
        if (call.method == 'create') return 0;
        if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
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

  /// The last visibility verdict pushed to native, or null if none was pushed.
  bool? lastVisible() {
    final c = calls.where((c) => c.method == 'setBannerViewportVisible');
    if (c.isEmpty) return null;
    return (c.last.arguments as Map)['visible'] as bool;
  }

  Widget page({Widget? cover}) => MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: SizedBox(width: 320, height: 50, child: AdWidget(ad: ad)),
              ),
              if (cover != null) Positioned.fill(child: cover),
            ],
          ),
        ),
      );

  testWidgets('an interactive same-route overlay pauses the banner',
      (tester) async {
    // Shares every ancestor with the ad, which used to be read as proof of visibility.
    await tester.pumpWidget(page(
      cover: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isFalse, reason: 'a cover that takes pointers must pause refresh');
  });

  testWidgets('a dialog pauses the banner', (tester) async {
    await tester.pumpWidget(page());
    await tester.pump(const Duration(seconds: 2));
    final context = tester.element(find.byType(Scaffold));
    unawaitedShowDialog(context);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isFalse, reason: 'a modal barrier covers the banner');
  });

  testWidgets('an uncovered banner is never paused', (tester) async {
    await tester.pumpWidget(page());
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isNot(isFalse),
        reason: 'control — a plainly visible banner must keep refreshing');
  });

  testWidgets('uncovering the banner resumes it', (tester) async {
    await tester.pumpWidget(page(
      cover: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isFalse);

    await tester.pumpWidget(page());
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isTrue, reason: 'removing the cover must resume refresh');
  });

  testWidgets('an opaque cover that shares the ad\'s ancestors pauses it',
      (tester) async {
    // A ColoredBox is hit-testable and opaque, but every ancestor it shares with the ad is in the
    // hit path too — which the previous check accepted as proof the ad was visible.
    await tester.pumpWidget(page(cover: const ColoredBox(color: Color(0xFF000000))));
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isFalse,
        reason: 'sharing an ancestor with the cover is not proof of visibility');
  });

  testWidgets('a cover that passes pointers through needs the explicit signal',
      (tester) async {
    // This is the documented limitation. An IgnorePointer veil, a CustomPaint overlay or a
    // decoration paints over the ad and never enters the hit path, so no hit-test-based check can
    // see it. reportObscured is how a publisher says so.
    await tester.pumpWidget(page(
      cover: const IgnorePointer(child: ColoredBox(color: Color(0xFF000000))),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isNot(isFalse),
        reason: 'documented limitation: a pointer-transparent cover is invisible to hit testing');

    ad.reportObscured(true);
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isFalse, reason: 'the explicit signal must pause refresh');

    ad.reportObscured(false);
    await tester.pump(const Duration(seconds: 2));
    expect(lastVisible(), isTrue, reason: 'clearing it must resume refresh');
  });

}

void unawaitedShowDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const AlertDialog(content: Text('hello')),
  );
}
