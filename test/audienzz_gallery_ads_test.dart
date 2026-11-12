import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AudienzzGalleryAds`: ePaper ad slots preloaded by page distance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  Map<String, dynamic> configJson(
    String id, {
    Object? preloadDistancePages,
    bool includeFluid = false,
  }) =>
      {
        'id': id,
        'config': {
          'adType': 'banner',
          'refreshTimeSeconds': 30,
          if (preloadDistancePages != null)
            'preloadDistancePages': preloadDistancePages,
        },
        'gamConfig': {
          'adUnitPath': '/1234/$id',
          'adSizes': ['300x250', '300x600'],
          if (includeFluid) 'includeFluid': true,
        },
        'prebidConfig': {
          'placementId': 'pb-$id',
          'adSizes': ['300x250'],
        },
      };

  void setConfigs(List<Map<String, dynamic>> configs) =>
      AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(
        configs.map(RemoteAdConfiguration.fromJson).toList(),
      );

  List<Map<dynamic, dynamic>> loads() => calls
      .where((c) => c.method == 'loadBannerAd')
      .map((c) => c.arguments as Map)
      .toList();

  List<String> loadedUnits() =>
      loads().map((a) => a['adUnitId'] as String).toList();

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return {'width': 800.0, 'height': 250.0};
      return null;
    });
    setConfigs([configJson('a'), configJson('b')]);
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  const slots = [
    AudienzzGalleryAdSlot(slotKey: 'ad-1', adConfigId: 'a', pageIndex: 4),
    AudienzzGalleryAdSlot(slotKey: 'ad-2', adConfigId: 'b', pageIndex: 12),
  ];

  Widget epaper(
    PageController controller, {
    List<AudienzzGalleryAdSlot> gallerySlots = slots,
    bool active = true,
    void Function(String)? onAdLoaded,
    void Function(String, AdError?)? onAdFailedToLoad,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: AudienzzPage(
            name: 'epaper',
            active: active,
            child: AudienzzGalleryAds(
              controller: controller,
              slots: gallerySlots,
              onAdLoaded: onAdLoaded,
              onAdFailedToLoad: onAdFailedToLoad,
              child: PageView.builder(
                controller: controller,
                itemCount: 16,
                itemBuilder: (context, index) {
                  for (final slot in gallerySlots) {
                    if (slot.pageIndex == index) {
                      return AudienzzGalleryAd(
                        key: ValueKey(slot.slotKey),
                        slotKey: slot.slotKey,
                      );
                    }
                  }
                  return Center(child: Text('tile $index'));
                },
              ),
            ),
          ),
        ),
      );

  Future<void> goTo(WidgetTester tester, PageController c, int page) async {
    c.jumpToPage(page);
    await tester.pumpAndSettle();
  }

  Future<void> nativeEvent(int adId, String name, {int? height}) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('onAdEvent', {
            'adId': adId,
            'eventName': name,
            if (height != null) 'width': 300,
            if (height != null) 'height': height,
          }),
        ),
        (_) {},
      );

  group('config.preloadDistancePages', () {
    RemoteAdConfigData parse(Object? value) => RemoteAdConfigData.fromJson({
          'adType': 'banner',
          if (value != null) 'preloadDistancePages': value,
        });

    test('read leniently: only a non-negative whole number counts', () {
      expect(parse(null).preloadDistancePages, isNull);
      expect(parse(3).preloadDistancePages, 3);
      expect(parse(0).preloadDistancePages, 0);
      expect(parse(2.0).preloadDistancePages, 2);
      expect(parse(-1).preloadDistancePages, isNull);
      expect(parse(1.5).preloadDistancePages, isNull);
      expect(parse('2').preloadDistancePages, isNull);
      expect(parse(true).preloadDistancePages, isNull);
    });

    test('kept in the cached copy', () {
      final json = parse(5).toJson();
      expect(json['preloadDistancePages'], 5);
      expect(RemoteAdConfigData.fromJson(json).preloadDistancePages, 5);
      expect(parse(null).toJson().containsKey('preloadDistancePages'), false);
    });

    test('backend value wins, local default 2 otherwise', () {
      setConfigs([
        configJson('a'),
        configJson('b', preloadDistancePages: 4),
        configJson('c', preloadDistancePages: 'x'),
      ]);
      expect(AudienzzGalleryAds.defaultPreloadDistancePages, 2);
      expect(AudienzzGalleryAds.preloadDistanceFor('a'), 2);
      expect(AudienzzGalleryAds.preloadDistanceFor('b'), 4);
      expect(AudienzzGalleryAds.preloadDistanceFor('c'), 2);
      expect(AudienzzGalleryAds.preloadDistanceFor('missing'), 2);
    });
  });

  testWidgets('nothing is requested when the ePaper opens far from the slots',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loads(), isEmpty);
    await goTo(tester, controller, 1);
    expect(loads(), isEmpty, reason: 'page 1 is 3 pages from slot 4');
  });

  testWidgets('a slot is requested once the reader is within 2 pages',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();

    await goTo(tester, controller, 2);
    expect(loadedUnits(), ['/1234/a']);
    await goTo(tester, controller, 3);
    await goTo(tester, controller, 4);
    expect(loadedUnits(), ['/1234/a'], reason: 'requested once');

    await goTo(tester, controller, 9);
    expect(loadedUnits(), ['/1234/a']);
    await goTo(tester, controller, 10);
    expect(loadedUnits(), ['/1234/a', '/1234/b']);
  });

  testWidgets('swiping backwards preloads too', (tester) async {
    final controller = PageController(initialPage: 15);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loadedUnits(), isEmpty, reason: '15 is 3 pages after 12');
    await goTo(tester, controller, 14);
    expect(loadedUnits(), ['/1234/b']);
  });

  testWidgets('the backend distance is per placement', (tester) async {
    setConfigs([
      configJson('a', preloadDistancePages: 0),
      configJson('b', preloadDistancePages: 12),
    ]);
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/b'], reason: 'b preloads on open');

    await goTo(tester, controller, 3);
    expect(loadedUnits(), ['/1234/b'], reason: 'a only on its own page');
    await goTo(tester, controller, 4);
    expect(loadedUnits(), ['/1234/b', '/1234/a']);
  });

  testWidgets('a mid-swipe position counts', (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    await goTo(tester, controller, 1);
    final width = tester.getSize(find.byType(PageView)).width;
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(Offset(-width * 0.6, 0));
    await tester.pump();
    expect(loadedUnits(), isEmpty, reason: 'page 1.6 is 2.4 from slot 4');
    await gesture.moveBy(Offset(-width * 0.5, 0));
    await tester.pump();
    expect(loadedUnits(), ['/1234/a'], reason: 'page 2.1 is within 2');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('preloads eagerly with the RemoteBanner request otherwise',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    final gallery = Map<dynamic, dynamic>.of(loads().single);
    calls.clear();

    // The same placement as a managed banner.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudienzzPage(
            name: 'feed',
            child: AudienzzBanner(adConfigId: 'a', slotKey: 'feed-a'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final banner = Map<dynamic, dynamic>.of(loads().single);

    expect(gallery['isLazyLoad'], false);
    expect(banner['isLazyLoad'], true);
    expect(gallery['keepsAdAcrossPages'], true);
    expect(banner.containsKey('keepsAdAcrossPages'), false);
    for (final key in [
      'adId',
      'requestSlot',
      'pageKey',
      'isLazyLoad',
      'keepsAdAcrossPages',
    ]) {
      gallery.remove(key);
      banner.remove(key);
    }
    // Values without value equality (sizes, bitrate): compare as sent.
    final codec = AdMessageCodec();
    expect(gallery.keys.toSet(), banner.keys.toSet());
    for (final key in gallery.keys) {
      expect(
        codec.encodeMessage(gallery[key])!.buffer.asUint8List(),
        codec.encodeMessage(banner[key])!.buffer.asUint8List(),
        reason: '$key',
      );
    }
  });

  testWidgets('a preloaded ad is held hidden until its tile shows it',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    await goTo(tester, controller, 2);
    final adId = loads().single['adId'];
    final verdicts = calls
        .where((c) => c.method == 'setBannerViewportVisible')
        .map((c) => c.arguments as Map)
        .where((a) => a['adId'] == adId)
        .map((a) => a['visible'])
        .toList();
    expect(verdicts, [false]);
    expect(find.byType(AdWidget), findsNothing);

    await goTo(tester, controller, 4);
    expect(find.byType(AdWidget), findsOneWidget);
  });

  testWidgets('the tile takes the creative height, refreshes included',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    final loaded = <String>[];
    await tester.pumpWidget(epaper(controller, onAdLoaded: loaded.add));
    await tester.pumpAndSettle();
    final adId = loads().single['adId'] as int;
    final galleryAd = find.byKey(const ValueKey('ad-1'));
    Size adSlot() => tester.getSize(
          find.descendant(of: galleryAd, matching: find.byType(SizedBox)).first,
        );
    expect(adSlot().height, 250, reason: 'placeholder height');

    await nativeEvent(adId, 'onAdSizeChanged', height: 600);
    await nativeEvent(adId, 'onAdLoaded');
    await tester.pumpAndSettle();
    expect(adSlot().height, 600);
    expect(adSlot().width, tester.getSize(find.byType(PageView)).width);
    expect(loaded, ['ad-1']);

    await nativeEvent(adId, 'onAdSizeChanged', height: 250);
    await tester.pumpAndSettle();
    expect(adSlot().height, 250);
  });

  testWidgets('the ad outlives its tile: swiping away and back requests none',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(find.byType(AdWidget), findsOneWidget);
    await goTo(tester, controller, 8);
    expect(find.byType(AdWidget), findsNothing, reason: 'tile disposed');
    await goTo(tester, controller, 4);
    expect(find.byType(AdWidget), findsOneWidget);
    expect(loadedUnits(), ['/1234/a']);
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty);
  });

  testWidgets('leaving the page and coming back keeps the ads, no reload',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    await goTo(tester, controller, 12);
    expect(loadedUnits(), ['/1234/a', '/1234/b']);
    expect(find.byType(AdWidget), findsOneWidget);

    // An article opened on top: the page is not active.
    await tester.pumpWidget(epaper(controller, active: false));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty);

    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/a', '/1234/b'], reason: 'nothing reloaded');
    expect(calls.where((c) => c.method == 'reloadBanner'), isEmpty);
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty);
    expect(find.byType(AdWidget), findsOneWidget);
  });

  testWidgets('nothing new is requested while the page is away',
      (tester) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller, active: false));
    await tester.pumpAndSettle();
    await goTo(tester, controller, 4);
    expect(loads(), isEmpty);

    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/a'], reason: 'in range once it is back');
  });

  testWidgets('a native page re-report does not rebuild a kept ad view',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    Key? viewKey() => tester.widget(find.byType(PlatformViewLink)).key;
    final before = viewKey();
    final pageKey = loads().single['pageKey'] as String;

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onPageImpression', {'name': pageKey}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(viewKey(), before);
  });

  testWidgets('refresh comes from the ad config, as for a RemoteBanner',
      (tester) async {
    setConfigs([
      configJson('a'),
      {
        ...configJson('b'),
        'config': {'adType': 'banner'},
      },
    ]);
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    await goTo(tester, controller, 12);
    final byUnit = {for (final a in loads()) a['adUnitId']: a};
    expect(byUnit['/1234/a']!['refreshTimeInterval'], 30000);
    expect(byUnit['/1234/a']!['smartRefresh'], true);
    expect(
      byUnit['/1234/b']!['refreshTimeInterval'],
      0,
      reason: 'no refreshTimeSeconds: no periodic refresh',
    );
  });

  testWidgets('a placement without config is retried after a page return',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    const missing = [
      AudienzzGalleryAdSlot(slotKey: 'x', adConfigId: 'late', pageIndex: 4),
    ];
    await tester.pumpWidget(epaper(controller, gallerySlots: missing));
    await tester.pumpAndSettle();
    expect(loads(), isEmpty);

    setConfigs([configJson('late')]);
    await tester.pumpWidget(
      epaper(controller, gallerySlots: missing, active: false),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(epaper(controller, gallerySlots: missing));
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/late']);
  });

  testWidgets('a placement without config fails once, not on every scroll',
      (tester) async {
    final controller = PageController(initialPage: 3);
    addTearDown(controller.dispose);
    final failed = <String>[];
    await tester.pumpWidget(
      epaper(
        controller,
        gallerySlots: const [
          AudienzzGalleryAdSlot(slotKey: 'x', adConfigId: 'none', pageIndex: 4),
        ],
        onAdFailedToLoad: (key, _) => failed.add(key),
      ),
    );
    await tester.pumpAndSettle();
    await goTo(tester, controller, 4);
    await goTo(tester, controller, 5);
    expect(loads(), isEmpty);
    expect(failed, ['x']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a no-fill keeps the ad: its native scheduler owns the slot',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    final failed = <String>[];
    await tester.pumpWidget(
      epaper(controller, onAdFailedToLoad: (key, _) => failed.add(key)),
    );
    await tester.pumpAndSettle();
    final adId = loads().single['adId'] as int;
    await nativeEvent(adId, 'onAdFailedToLoad');
    await tester.pumpAndSettle();
    await goTo(tester, controller, 5);
    expect(failed, ['ad-1']);
    expect(loads(), hasLength(1));
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty);
  });

  testWidgets('changing a slot config replaces its ad; moving it does not',
      (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/a']);

    await tester.pumpWidget(
      epaper(
        controller,
        gallerySlots: const [
          AudienzzGalleryAdSlot(slotKey: 'ad-1', adConfigId: 'a', pageIndex: 5),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/a'], reason: 'moved, same ad');

    await tester.pumpWidget(
      epaper(
        controller,
        gallerySlots: const [
          AudienzzGalleryAdSlot(slotKey: 'ad-1', adConfigId: 'b', pageIndex: 5),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(loadedUnits(), ['/1234/a', '/1234/b']);
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  testWidgets('leaving the ePaper disposes its ads', (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'disposeAd'), hasLength(1));
  });

  testWidgets('without an AudienzzPage nothing is requested', (tester) async {
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AudienzzGalleryAds(
          controller: controller,
          slots: slots,
          child: PageView.builder(
            controller: controller,
            itemCount: 16,
            itemBuilder: (context, index) => index == 4
                ? const AudienzzGalleryAd(slotKey: 'ad-1')
                : Text('tile $index'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads(), isEmpty);
    expect(find.byType(AdWidget), findsNothing);
  });

  testWidgets('a fluid placement keeps requesting fluid', (tester) async {
    setConfigs([configJson('a', includeFluid: true), configJson('b')]);
    final controller = PageController(initialPage: 4);
    addTearDown(controller.dispose);
    await tester.pumpWidget(epaper(controller));
    await tester.pumpAndSettle();
    expect(loads().single['includeFluid'], true);
  });
}
