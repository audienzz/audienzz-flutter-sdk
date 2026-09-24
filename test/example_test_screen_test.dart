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
  }

  setUp(() {
    calls = [];
    navigator = GlobalKey<NavigatorState>();
    delayedSize = null;
    AudienzzPageRegistry.instance.resetForTesting();
    adInstanceManager.currentPage = null;
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
    messenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets(
      'banner button destination has Material styling, back navigation and correct page ownership',
      (tester) async {
    await open(tester);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
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
