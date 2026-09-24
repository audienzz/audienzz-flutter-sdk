import 'dart:async';
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_registry.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/pages/remote_banner_ad_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(Constants.methodChannelName, StandardMethodCodec(AdMessageCodec()));
  late List<MethodCall> calls;
  List<MethodCall> reports() => calls.where((c) => c.method == 'pageImpression').toList();
  List<MethodCall> loads() => calls.where((c) => c.method == 'loadBannerAd').toList();
  setUp(() {
    calls = [];
    AudienzzPageRegistry.instance.resetForTesting();
    messenger.setMockMethodCallHandler(channel, (call) async { calls.add(call); return null; });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
      return null;
    });
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'audit', 'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {'adUnitPath': '/audit/banner', 'adSizes': ['320x50']},
        'prebidConfig': {'placementId': 'audit', 'adSizes': ['320x50']},
      })
    ]);
  });
  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('late content on retained route must not reclaim the foreground page', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final loaded = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav, navigatorObservers: [AudienzzNavigatorObserver()],
      home: Scaffold(body: ValueListenableBuilder<bool>(
        valueListenable: loaded,
        builder: (_, ready, __) => ready
          ? const AudienzzPage(name: 'a', child: AudienzzBanner(adConfigId: 'audit', slotKey: 'one'))
          : const Text('Loading a'),
      )),
    ));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'b'), builder: (_) => const Scaffold(body: Text('Visible b')))));
    await tester.pumpAndSettle();
    expect((reports().last.arguments as Map)['name'], 'b');
    final before = reports().length;
    loaded.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Visible b'), findsOneWidget);
    expect(reports().length, before, reason: 'hidden route is not a new visit');
    expect(loads(), isEmpty);
    await tester.pumpWidget(const SizedBox());
    loaded.dispose();
  });

  testWidgets('late managed wrapper must keep the initial route identity', (tester) async {
    final loaded = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AudienzzNavigatorObserver()],
      home: Scaffold(body: ValueListenableBuilder<bool>(
        valueListenable: loaded,
        builder: (_, ready, __) => ready
          ? const AudienzzPage(name: 'article', child: AudienzzBanner(adConfigId: 'audit', slotKey: 'one'))
          : const Text('Loading article'),
      )),
    ));
    await tester.pumpAndSettle();
    expect(reports(), hasLength(1));
    final firstId = (reports().single.arguments as Map)['pageId'];
    loaded.value = true;
    await tester.pumpAndSettle();
    expect(loads(), hasLength(1));
    expect((loads().single.arguments as Map)['pageKey'], firstId);
    expect(reports(), hasLength(1));
    await tester.pumpWidget(const SizedBox());
    loaded.dispose();
  });

  testWidgets('actual low-level example reports its route before loading', (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AudienzzNavigatorObserver()],
      home: const Scaffold(body: RemoteBannerAdExample(configId: 'audit')),
    ));
    // The example deliberately shows a spinning progress indicator until a real ad loads.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(reports(), hasLength(1));
    expect(loads(), hasLength(1));
    final reportIndex = calls.indexWhere((c) => c.method == 'pageImpression');
    final loadIndex = calls.indexWhere((c) => c.method == 'loadBannerAd');
    expect(reportIndex, lessThan(loadIndex));
    expect((loads().single.arguments as Map)['pageKey'], (reports().single.arguments as Map)['pageId']);
    await tester.pumpWidget(const SizedBox());
  });
}
