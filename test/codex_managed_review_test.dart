// Independent review probes, adopted verbatim as regression tests.
// Kept in the reviewer's own formatting so the assertions stay auditable
// against the original; repo lint rules are waived rather than reformatting them.
// ignore_for_file: directives_ordering, unawaited_futures, lines_longer_than_80_chars,
// ignore_for_file: always_put_control_body_on_new_line, require_trailing_commas
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The managed integration, exercised through the real widgets.
///
/// Requests are counted at the method channel — `loadBannerAd` is what starts a
/// native auction — not from Dart callbacks, which cannot establish that
/// nothing was requested.
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

  int loadCount() => calls.where((c) => c.method == 'loadBannerAd').length;

  List<String?> loadedPageKeys() => calls
      .where((c) => c.method == 'loadBannerAd')
      .map((c) => (c.arguments as Map)['pageKey'] as String?)
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
        'id': 'managed',
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
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('page ownership', () {
    testWidgets('the page is reported before the banner is created',
        (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(pageReports(), hasLength(1));
      expect(loadCount(), 1);
      final reportIndex =
          calls.indexWhere((c) => c.method == 'pageImpression');
      final loadIndex = calls.indexWhere((c) => c.method == 'loadBannerAd');
      expect(reportIndex, lessThan(loadIndex),
          reason: 'an ad created before its page is swept as the previous page');
      expect(loadedPageKeys().single, pageReports().single['pageId']);
    });

    testWidgets('two routes with the same screen name own separate pages',
        (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(
        const AudienzzPage(
          key: ValueKey('second'),
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();

      final reports = pageReports();
      expect(reports.map((r) => r['name']), ['article', 'article']);
      expect(reports[0]['pageId'], isNot(reports[1]['pageId']));
    });

    testWidgets('an inactive page reserves the slot and requests nothing',
        (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'tab-b',
          active: false,
          child: AudienzzBanner(
            adConfigId: 'managed',
            slotKey: 'one',
            placeholderHeight: 300,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(pageReports(), isEmpty);
      expect(loadCount(), 0, reason: 'a pre-built tab must not buy an ad');
      expect(tester.getSize(find.byType(AudienzzBanner)).height, 300,
          reason: 'the space is still reserved');
    });

    testWidgets('a pre-built tab requests exactly once when it is selected',
        (tester) async {
      Widget tab({required bool active}) => app(
            AudienzzPage(
              name: 'tab-b',
              active: active,
              child: const AudienzzBanner(
                adConfigId: 'managed',
                slotKey: 'one',
              ),
            ),
          );

      await tester.pumpWidget(tab(active: false));
      await tester.pumpAndSettle();
      expect(loadCount(), 0);

      await tester.pumpWidget(tab(active: true));
      await tester.pumpAndSettle();
      expect(pageReports(), hasLength(1));
      expect(loadCount(), 1);

      // Staying selected across further frames must not buy more.
      await tester.pumpWidget(tab(active: true));
      await tester.pumpAndSettle();
      expect(loadCount(), 1);
    });
  });

  group('slot ownership', () {
    testWidgets('an ordinary rebuild requests nothing', (tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(app(
          AudienzzPage(
            name: 'article',
            child: AudienzzBanner(
              adConfigId: 'managed',
              slotKey: 'one',
              placeholderHeight: 200 + i.toDouble(),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }
      expect(loadCount(), 1, reason: 'only the first build owns a request');
    });

    testWidgets('two slots on one page are separated by slot key alone',
        (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: Column(
            children: [
              AudienzzBanner(
                adConfigId: 'managed',
                slotKey: 'top',
                placeholderHeight: 50,
              ),
              AudienzzBanner(
                adConfigId: 'managed',
                slotKey: 'bottom',
                placeholderHeight: 50,
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(pageReports(), hasLength(1));
      expect(loadCount(), 2,
          reason: 'one configuration id, two genuinely different slots');
    });

    testWidgets('changing the slot key replaces exactly one owner',
        (tester) async {
      Widget page(String slot) => app(
            AudienzzPage(
              name: 'article',
              child: AudienzzBanner(adConfigId: 'managed', slotKey: slot),
            ),
          );
      await tester.pumpWidget(page('one'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page('two'));
      await tester.pumpAndSettle();

      expect(loadCount(), 2);
      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1),
          reason: 'the replaced slot is disposed, not orphaned');
    });

    testWidgets('disposal retires the ad', (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(loadCount(), 1);

      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpAndSettle();

      expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
    });
  });

  group('lazy loading', () {
    testWidgets('managed loading defaults to near-viewport', (tester) async {
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();
      final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
      expect((load.arguments as Map)['isLazyLoad'], isTrue);
    });

    testWidgets('the ad config decides: a backend eager choice wins',
        (tester) async {
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
        RemoteAdConfiguration.fromJson({
          'id': 'managed',
          'config': {
            'adType': 'banner',
            'refreshTimeSeconds': 30,
            'lazyLoad': false,
            'prefetchDistanceDp': 600,
          },
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
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ));
      await tester.pumpAndSettle();
      final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
      expect((load.arguments as Map)['isLazyLoad'], isFalse);
      expect((load.arguments as Map)['prefetchMargin'], 600);
    });

    testWidgets('the slot is laid out with a real size before loading',
        (tester) async {
      // The lazy check needs geometry. An integration that mounts its ad view
      // only after onAdLoaded deadlocks; the reservation is what prevents that.
      await tester.pumpWidget(app(
        const AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'managed',
            slotKey: 'one',
            placeholderHeight: 180,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AudienzzBanner)).height, 180);
      expect(loadCount(), 1);
    });
  });

  testWidgets('REVIEW retained tabs A B A report every activation', (tester) async {
    Widget tabs(int selected) => app(Column(children: [
      AudienzzPage(name: 'A', active: selected == 0, child: const SizedBox(height:50)),
      AudienzzPage(name: 'B', active: selected == 1, child: const SizedBox(height:50)),
    ]));
    await tester.pumpWidget(tabs(0)); await tester.pumpAndSettle();
    await tester.pumpWidget(tabs(1)); await tester.pumpAndSettle();
    await tester.pumpWidget(tabs(0)); await tester.pumpAndSettle();
    expect(pageReports().map((p) => p['name']).toList(), ['A','B','A']);
  });

  testWidgets('REVIEW adapter and page wrapper use same identity on return', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[AudienzzNavigatorObserver()],
      home: const Scaffold(body:AudienzzPage(name:'A',child:AudienzzBanner(adConfigId:'managed',slotKey:'a')))));
    await tester.pumpAndSettle();
    final bannerPage = loadedPageKeys().single;
    key.currentState!.push(MaterialPageRoute<void>(settings:const RouteSettings(name:'B'),builder:(_)=>const Scaffold(body:Text('no ads'))));
    await tester.pumpAndSettle();
    key.currentState!.pop(); await tester.pumpAndSettle();
    expect(pageReports().last['pageId'], bannerPage);
  });

  testWidgets('REVIEW legacy same-name page impression preserves banner ownership', (tester) async {
    await AudienzzSdkFlutter.instance.pageImpression(name:'article');
    final first = adInstanceManager.currentPage;
    await AudienzzSdkFlutter.instance.pageImpression(name:'article');
    expect(adInstanceManager.currentPage, first);
  });

  testWidgets('REVIEW buried route removal must not activate the route below it', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey:key,navigatorObservers:[AudienzzNavigatorObserver()],home: const Scaffold(body:Text('home'))));
    await tester.pumpAndSettle();
    final middle = MaterialPageRoute<void>(settings:const RouteSettings(name:'middle'),builder:(_)=>const Scaffold(body:Text('middle')));
    key.currentState!.push(middle); await tester.pumpAndSettle();
    key.currentState!.push(MaterialPageRoute<void>(settings:const RouteSettings(name:'top'),builder:(_)=>const Scaffold(body:Text('top'))));
    await tester.pumpAndSettle();
    final count = pageReports().length;
    key.currentState!.removeRoute(middle); await tester.pumpAndSettle();
    expect(pageReports(),hasLength(count));
  });

  testWidgets('REVIEW missing configuration reports error without crashing widget', (tester) async {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([]);
    await tester.pumpWidget(app(const AudienzzPage(name:'A',child:AudienzzBanner(adConfigId:'managed',slotKey:'a'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

}
