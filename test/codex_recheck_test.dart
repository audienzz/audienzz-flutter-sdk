// Independent review probes, adopted verbatim as regression tests.
// Kept in the reviewer's own formatting so the assertions stay auditable;
// repo lint rules are waived rather than reformatting them.
// ignore_for_file: directives_ordering, unawaited_futures, lines_longer_than_80_chars,
// ignore_for_file: always_put_control_body_on_new_line, require_trailing_commas
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The managed integration, exercised through the real widgets.
///
/// Requests are counted at the method channel. `loadBannerAd` is what creates
/// and registers the native handler; with lazy loading it does **not** by itself
/// prove that a Prebid auction or a Google handoff happened — that needs the
/// platform view to attach and the viewport check to pass, which these widget
/// tests do not exercise. What this file establishes is ownership and count of
/// *requests to the native layer*: zero here means nothing was even asked for.
/// The native auction counts live in the Android and iOS handler suites.
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


  testWidgets('RECHECK missing config recovers on rebuild when config arrives', (tester) async {
    final config = RemoteAdConfiguration.fromJson({'id':'managed','config':{'adType':'banner','refreshTimeSeconds':30},'gamConfig':{'adUnitPath':'/1234/test','adSizes':['320x50']},'prebidConfig':{'placementId':'test','adSizes':['320x50']}});
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([]);
    Widget page() => app(AudienzzPage(name:'A',child:AudienzzBanner(adConfigId:'managed',slotKey:'a')));
    await tester.pumpWidget(page()); await tester.pumpAndSettle();
    expect(tester.takeException(),isNull); expect(loadCount(),0);
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([config]);
    await tester.pumpWidget(page()); await tester.pumpAndSettle();
    expect(loadCount(),1);
  });

  testWidgets('RECHECK changing an active page id activates the successor', (tester) async {
    Widget page(String id) => app(AudienzzPage(name:'Article',id:id,child:const AudienzzBanner(adConfigId:'managed',slotKey:'a')));
    await tester.pumpWidget(page('A')); await tester.pumpAndSettle();
    expect(loadCount(),1);
    await tester.pumpWidget(page('B')); await tester.pumpAndSettle();
    expect(pageReports().map((p)=>p['pageId']).toList(),['A','B']);
    expect(loadedPageKeys(),['A','B']);
  });

  testWidgets('RECHECK active false blocks an existing Flutter banner without a successor page', (tester) async {
    Widget page(bool active) => app(AudienzzPage(name:'Article',active:active,child:const AudienzzBanner(adConfigId:'managed',slotKey:'a')));
    await tester.pumpWidget(page(true)); await tester.pump(const Duration(seconds:1));
    final verdicts = () => calls.where((c)=>c.method=='setBannerViewportVisible').map((c)=>(c.arguments as Map)['visible']).toList();
    expect(verdicts().last,true);
    await tester.pumpWidget(page(false)); await tester.pump(const Duration(seconds:2));
    expect(verdicts().last,false);
  });

  testWidgets('RECHECK cover reported before activation is retained', (tester) async {
    final controller=AudienzzBannerController();
    Widget page(bool active) => app(AudienzzPage(name:'Article',active:active,child:AudienzzBanner(adConfigId:'managed',slotKey:'a',controller:controller)));
    await tester.pumpWidget(page(false)); await tester.pumpAndSettle();
    await controller.reportCover(covered:true);
    await controller.stopAutoRefresh();
    await tester.pumpWidget(page(true)); await tester.pump(const Duration(seconds:1));
    final ad=tester.widget<AdWidget>(find.byType(AdWidget)).ad;
    expect(adInstanceManager.isBannerObscured(ad as BannerAd),isTrue);
    // The stop now travels IN the creation payload rather than as a separate
    // command, so that an eager banner cannot start a request before it lands —
    // see 'retained publisher stop is installed before native eager load'.
    // Either mechanism satisfies what this case is about: the stop survived.
    final installedAtCreate = calls
        .where((c)=>c.method=='loadBannerAd')
        .any((c)=>(c.arguments as Map)['publisherPaused']==true);
    expect(installedAtCreate || calls.any((c)=>c.method=='pauseBannerAutoRefresh'),isTrue);
  });

  testWidgets('RECHECK controller replacement can clear an existing cover', (tester) async {
    final first=AudienzzBannerController(), second=AudienzzBannerController();
    Widget page(AudienzzBannerController ctrl) => app(AudienzzPage(name:'Article',child:AudienzzBanner(adConfigId:'managed',slotKey:'a',controller:ctrl)));
    await tester.pumpWidget(page(first)); await tester.pumpAndSettle();
    await first.reportCover(covered:true);
    final ad=tester.widget<AdWidget>(find.byType(AdWidget)).ad as BannerAd;
    expect(adInstanceManager.isBannerObscured(ad),true);
    await tester.pumpWidget(page(second)); await tester.pumpAndSettle();
    await second.reportCover(covered:false);
    expect(adInstanceManager.isBannerObscured(ad),false);
  });

  testWidgets('RECHECK wrapper and navigator report one activation', (tester) async {
    await tester.pumpWidget(MaterialApp(navigatorObservers:[AudienzzNavigatorObserver()],home:const Scaffold(body:AudienzzPage(name:'/',child:AudienzzBanner(adConfigId:'managed',slotKey:'a')))));
    await tester.pumpAndSettle();
    expect(pageReports(),hasLength(1));
  });

  testWidgets('RECHECK renaming the analytics label is not a new visit', (tester) async {
    Widget page(String name) => app(AudienzzPage(name:name,child:const AudienzzBanner(adConfigId:'managed',slotKey:'a')));
    await tester.pumpWidget(page('article')); await tester.pumpAndSettle();
    expect(pageReports(),hasLength(1));
    expect(loadCount(),1);
    final id=pageReports().single['pageId'];

    // Same screen, same route, a different label for analytics.
    await tester.pumpWidget(page('article/detail')); await tester.pumpAndSettle();
    expect(pageReports(),hasLength(1),reason:'a label is not a navigation');
    expect(loadCount(),1,reason:'and it must not re-auction the slot');
    expect(loadedPageKeys(),[id]);
  });

  testWidgets('RECHECK managed article routes have distinct ownership by default', (tester) async {
    final nav=GlobalKey<NavigatorState>();
    const body=Scaffold(body:AudienzzPage(name:'article',child:AudienzzBanner(adConfigId:'managed',slotKey:'a')));
    await tester.pumpWidget(MaterialApp(navigatorKey:nav,navigatorObservers:[AudienzzNavigatorObserver()],home:body));
    await tester.pumpAndSettle();
    nav.currentState!.push(MaterialPageRoute<void>(settings:const RouteSettings(name:'article'),builder:(_)=>body));
    await tester.pumpAndSettle();
    expect(loadedPageKeys(),hasLength(2));
    expect(loadedPageKeys().toSet(),hasLength(2));
  });
}
