import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which page an ad belongs to is fixed when it is created and travels to native as `pageKey`.
/// A Flutter banner lives in the single FlutterActivity / FlutterViewController, so native cannot
/// work this out from the view hierarchy — if the stamp is wrong, page-scoped release and reload
/// target the wrong banners for the rest of that ad's life.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final codec = StandardMethodCodec(AdMessageCodec());
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  BannerAd makeBanner() => BannerAd(
        sizes: const {AdSize(width: 320, height: 50)},
        adUnitId: '/unit',
        auConfigId: 'config',
        onAdLoaded: (_) {},
        onAdFailedToLoad: (_, __) {},
      );

  setUp(() {
    calls = [];
    adInstanceManager.currentPage = null;
    adInstanceManager.lastReportedPage = null;
    adInstanceManager.pageEpoch.value = 0;
    messenger.setMockMethodCallHandler(
      MethodChannel(Constants.methodChannelName, codec),
      (call) async {
        calls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      MethodChannel(Constants.methodChannelName, codec),
      null,
    );
  });

  test('an ad created after a page impression carries that page', () async {
    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    // The stamp is the page INSTANCE id, not the display name: two routes can
    // share a name and must still own their banners separately.
    final articleId = adInstanceManager.currentPage;
    expect(articleId, isNot('Article'));

    final ad = makeBanner();
    await ad.load();

    expect(adInstanceManager.pageFor(ad), articleId);
    final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
    expect((load.arguments as Map)['pageKey'], articleId);
  });

  test('two visits to the same screen name are different pages', () async {
    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    final first = makeBanner();
    await first.load();

    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    final second = makeBanner();
    await second.load();

    expect(
      adInstanceManager.pageFor(first),
      isNot(adInstanceManager.pageFor(second)),
      reason: 'a repeated screen name must not merge two article routes',
    );
  });

  test('an ad keeps its page when a later screen is reported', () async {
    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    final articleId = adInstanceManager.currentPage;
    final ad = makeBanner();
    await ad.load();

    await AudienzzSdkFlutter.instance.pageImpression(name: 'Home');

    expect(
      adInstanceManager.pageFor(ad),
      articleId,
      reason: 'ownership is fixed at creation, not reassigned by later screens',
    );
  });

  test('two ads created on different pages are stamped separately', () async {
    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    final articleId = adInstanceManager.currentPage;
    final article = makeBanner();
    await article.load();

    await AudienzzSdkFlutter.instance.pageImpression(name: 'Home');
    final homeId = adInstanceManager.currentPage;
    final home = makeBanner();
    await home.load();

    expect(articleId, isNot(homeId));
    expect(adInstanceManager.pageFor(article), articleId);
    expect(adInstanceManager.pageFor(home), homeId);
  });

  test('an ad created before any page impression carries no page', () async {
    // Native attach-time adoption cannot repair a bridge ad — with no page key its host resolves
    // to the single host controller, which can never equal a route key — so this is an integration
    // error the SDK reports rather than a state it can recover from.
    final ad = makeBanner();
    await ad.load();

    expect(adInstanceManager.pageFor(ad), isNull);
    final load = calls.firstWhere((c) => c.method == 'loadBannerAd');
    expect((load.arguments as Map).containsKey('pageKey'), isFalse);
  });

  test('disposing an ad forgets its page', () async {
    await AudienzzSdkFlutter.instance.pageImpression(name: 'Article');
    final ad = makeBanner();
    await ad.load();

    await ad.dispose();

    expect(adInstanceManager.pageFor(ad), isNull);
  });
}
