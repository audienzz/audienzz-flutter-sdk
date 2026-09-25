// Exercises the shipped example screens, not a reconstruction of them: the
// ordering these cases are about is a property of the actual composition.
// ignore_for_file: lines_longer_than_80_chars, avoid_relative_lib_imports
// ignore_for_file: cascade_invocations, require_trailing_commas
// ignore_for_file: always_put_control_body_on_new_line
import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/pages/managed_banner_example.dart';
import '../example/lib/pages/remote_banner_ad_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  List<Map<dynamic, dynamic>> pageReports() => calls
      .where((c) => c.method == 'pageImpression')
      .map((c) => c.arguments as Map)
      .toList();

  List<String?> loadedPageKeys() => calls
      .where((c) => c.method == 'loadBannerAd')
      .map((c) => (c.arguments as Map)['pageKey'] as String?)
      .toList();

  setUp(() {
    calls = [];
    AudienzzPageRegistry.instance.resetForTesting();
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
        'id': '46',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {
          'adUnitPath': '/1234/test',
          'adSizes': ['320x50'],
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['320x50'],
        },
      }),
    ]);
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('remote adaptive example keeps the available width before and after a creative', (tester) async {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': '46', 'config': {'adType': 'banner'},
        'gamConfig': {'adUnitPath': '/test', 'adSizes': ['300x250'],
          'adaptiveBannerConfig': {'enabled': true, 'widthStrategy': 'FULL_WIDTH'}},
        'prebidConfig': {'placementId': 'test', 'adSizes': ['300x250']},
      }),
    ]);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getPlatformAdSize') return AdSize(width: 320, height: 140);
      return null;
    });
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AudienzzNavigatorObserver()],
      home: const Scaffold(body: Center(child: SizedBox(width: 400,
        child: RemoteBannerAdExample(configId: '46')))),
    ));
    // The spinner is intentionally present until a creative arrives.
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getSize(find.byType(AdWidget)).width, 400);
    final id = (calls.singleWhere((call) => call.method == 'loadBannerAd').arguments as Map)['adId'];
    await messenger.handlePlatformMessage(channel.name,
      channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': id, 'eventName': 'onAdLoaded',
      })), (_) {});
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AdWidget)), const Size(400, 140));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the recommended example reports its page before either slot loads',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AudienzzNavigatorObserver()],
      home: const ManagedBannerExample(configId: '46'),
    ));
    await tester.pumpAndSettle();

    expect(pageReports(), hasLength(1), reason: 'one visit, one report');
    final reportIndex = calls.indexWhere((c) => c.method == 'pageImpression');
    final firstLoad = calls.indexWhere((c) => c.method == 'loadBannerAd');
    expect(firstLoad, isNonNegative, reason: 'control: a slot really did load');
    expect(reportIndex, lessThan(firstLoad));

    // Both slots belong to the one page, and are told apart by slot key alone.
    final pageId = pageReports().single['pageId'];
    expect(loadedPageKeys(), everyElement(equals(pageId)));
  });

  testWidgets('A -> ad-free B -> A releases and recreates without page code',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [AudienzzNavigatorObserver()],
      home: const ManagedBannerExample(configId: '46'),
    ));
    await tester.pumpAndSettle();
    final firstVisit = pageReports().single['pageId'];
    final loadsOnA = loadedPageKeys().length;
    expect(loadsOnA, greaterThan(0), reason: 'control: A really loaded');

    // The ad-free destination carries no ad code at all; reporting it is what
    // ends A's visit.
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'ad-free'),
      builder: (_) => const AdFreeExample(),
    )));
    await tester.pumpAndSettle();
    expect(pageReports(), hasLength(2));
    expect(pageReports().last['pageId'], isNot(firstVisit));
    expect(loadedPageKeys(), hasLength(loadsOnA),
        reason: 'an ad-free destination must not buy an auction');

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    // Returning is a new visit of the same route instance, and its slots are
    // recreated under it.
    expect(pageReports(), hasLength(3));
    expect(pageReports().last['pageId'], firstVisit);
    expect(loadedPageKeys().length, greaterThan(loadsOnA));
    expect(loadedPageKeys().last, firstVisit);
  });
}
