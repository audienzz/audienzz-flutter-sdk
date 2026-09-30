// Tests the same destination and route factory used by the buttons below the banners.
// ignore_for_file: avoid_relative_lib_imports, lines_longer_than_80_chars
import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/pages/test_screen_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = StandardMethodCodec(AdMessageCodec());
  final channel = MethodChannel(Constants.methodChannelName, codec);
  late List<MethodCall> calls;
  late GlobalKey<NavigatorState> navigator;
  Completer<AdSize?>? delayedSize;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [AudienzzNavigatorObserver()],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    await tester.pump();
    calls.clear();
    unawaited(navigator.currentState!.push(TestScreenExample.route()));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    // Let visibility polling see the route's completed transition layout.
    await tester.pump(const Duration(milliseconds: 500));
  }

  setUp(() {
    calls = [];
    navigator = GlobalKey<NavigatorState>();
    delayedSize = null;
    AudienzzPageRegistry.instance.resetForTesting();
    adInstanceManager.currentPage = null;
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': '46',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 7},
        'gamConfig': {
          'adUnitPath': '/fixture/remote-banner',
          'adSizes': ['300x250'],
        },
        'prebidConfig': {
          'placementId': 'remote-placement',
          'adSizes': ['300x250'],
        },
      }),
    ]);
    messenger
      ..setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getPlatformAdSize') {
          return delayedSize?.future ?? const AdSize(width: 300, height: 250);
        }
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          return 0;
        }
        if (call.method == 'resize') {
          return {'width': 300.0, 'height': 250.0};
        }
        return null;
      });
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform test destination forwards backend refresh and mounts its lazy banner',
      (tester) async {
        await open(tester);

        final load = calls.singleWhere((c) => c.method == 'loadBannerAd');
        final args = load.arguments as Map;
        expect(args['adUnitId'], '/fixture/remote-banner');
        expect(args['auConfigId'], 'remote-placement');
        expect(args['refreshTimeInterval'], 7000);
        expect(args['smartRefresh'], isTrue);
        expect(args['isLazyLoad'], isTrue);
        expect(args['prefetchMargin'], 200);
        // No onAdLoaded has been delivered. A lazy ad must already be mounted
        // so native prefetch can evaluate its position and start the first request.
        expect(find.byType(AdWidget), findsOneWidget);
        await messenger.handlePlatformMessage(
          Constants.methodChannelName,
          codec.encodeMethodCall(
            MethodCall('onAdEvent', {
              'adId': args['adId'],
              'eventName': 'onAdLoaded',
            }),
          ),
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        // Once the loading indicator is removed, the visible creative must
        // allow the native eligible-time clock to run.
        final visible = calls
            .where((c) => c.method == 'setBannerViewportVisible')
            .map((c) => c.arguments as Map)
            .where((a) => a['adId'] == args['adId'])
            .toList();
        expect(visible, isNotEmpty);
        expect(visible.last['visible'], isTrue);

        await tester.pumpWidget(const SizedBox());
        expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
      'banner button destination has Material styling, back navigation and correct page ownership',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    tester.view.viewPadding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
    await open(tester);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.getTopLeft(find.byType(BackButton)).dy, greaterThanOrEqualTo(32));
    final description = find.text(
      'One banner on its own screen — for screen-tracking / analytics logs.',
    );
    final text = tester.widget<RichText>(
      find.descendant(of: description, matching: find.byType(RichText)),
    );
    expect(text.text.style!.fontSize, lessThan(30));
    expect(text.text.style!.decoration, isNot(TextDecoration.underline));

    final reports = calls.where((c) => c.method == 'pageImpression').toList();
    final loads = calls.where((c) => c.method == 'loadBannerAd').toList();
    expect(reports, hasLength(1));
    expect(loads, hasLength(1));
    expect((reports.single.arguments as Map)['name'], 'Test Screen');
    expect(
      (loads.single.arguments as Map)['pageKey'],
      (reports.single.arguments as Map)['pageId'],
    );
    expect(
      calls.indexOf(reports.single),
      lessThan(calls.indexOf(loads.single)),
    );

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a size callback arriving after leaving the screen cannot update disposed state',
      (tester) async {
    await open(tester);
    final load = calls.singleWhere((c) => c.method == 'loadBannerAd');
    final id = (load.arguments as Map)['adId'];
    delayedSize = Completer<AdSize?>();
    await messenger.handlePlatformMessage(
      Constants.methodChannelName,
      codec.encodeMethodCall(
        MethodCall('onAdEvent', {'adId': id, 'eventName': 'onAdLoaded'}),
      ),
      (_) {},
    );
    await tester.pump();
    expect(calls.where((c) => c.method == 'getPlatformAdSize'), hasLength(1));

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(TestScreenExample), findsNothing);
    delayedSize!.complete(const AdSize(width: 300, height: 250));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
