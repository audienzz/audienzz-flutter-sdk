import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  late List<MethodCall> calls;
  late List<InterstitialAd> ads;
  late InterstitialAd ad;
  late InterstitialPresentationController controller;
  late List<AdError?> loadErrors;

  InterstitialAd makeAd() {
    final value = InterstitialAd(
      adUnitId: '/opportunity',
      auConfigId: 'opportunity',
      adFormat: AdFormat.banner,
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, error) => loadErrors.add(error),
    );
    ads.add(value);
    return value;
  }

  Future<void> event(InterstitialAd ad, String name, {AdError? error}) async {
    await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
          'adId': adInstanceManager.adIdFor(ad),
          'eventName': name,
          'adError': error,
          'errorDomain': 'com.google.admob',
        }),),
        (_) {},);
  }

  Future<void> ready() async {
    final pending = controller.preload();
    await event(ad, 'onAdLoaded');
    await pending;
  }

  setUp(() {
    calls = [];
    ads = [];
    loadErrors = [];
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    ad = makeAd();
    controller = InterstitialPresentationController(ad: ad);
  });
  tearDown(() async {
    for (final ad in ads) {
      await event(ad, 'onAdClosed');
      await ad.dispose();
    }
    await controller.dispose();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('a missed opportunity never displays when a slow preload completes',
      () async {
    final first = controller.preload();
    final second = controller.preload();
    expect(await controller.showAtOpportunity(eligible: true), false);
    await event(ad, 'onAdLoaded');
    await Future.wait([first, second]);
    await controller.preload();
    expect(controller.isReady, true);
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(await controller.showAtOpportunity(eligible: true), true);
    expect(await controller.showAtOpportunity(eligible: true), false);
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
  });

  test('a frequency cap skips the opportunity and retains the ad', () async {
    await ready();
    expect(await controller.showAtOpportunity(eligible: false), false);
    expect(controller.isReady, true);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
  });

  test('background has no pending show to replay on foreground', () async {
    await ready();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(await controller.showAtOpportunity(eligible: true), false);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(controller.isReady, true);
    expect(await controller.showAtOpportunity(eligible: true), true);
  });

  test('another interstitial presentation preserves this ready ad', () async {
    await ready();
    final otherAd = makeAd();
    final other = InterstitialPresentationController(ad: otherAd);
    final pending = other.preload();
    await event(otherAd, 'onAdLoaded');
    await pending;
    expect(await other.showAtOpportunity(eligible: true), true);
    expect(await controller.showAtOpportunity(eligible: true), false);
    expect(controller.isReady, true);
    await event(otherAd, 'onAdClosed');
    expect(await controller.showAtOpportunity(eligible: true), true);
    await other.dispose();
  });

  test('disposing a presenting controller retains callbacks until terminal',
      () async {
    await ready();
    expect(await controller.showAtOpportunity(eligible: true), true);
    final id = adInstanceManager.adIdFor(ad);
    await controller.dispose();
    expect(adInstanceManager.adIdFor(ad), id);
    expect(await controller.showAtOpportunity(eligible: true), false);
    await expectLater(controller.preload(), throwsStateError);
    await event(ad, 'onAdClosed');
    expect(adInstanceManager.adIdFor(ad), isNull);
  });

  test('disposed preload cannot resurrect an earlier show opportunity',
      () async {
    final pending = expectLater(controller.preload(), throwsStateError);
    expect(await controller.showAtOpportunity(eligible: true), false);
    await controller.dispose();
    await pending;
    expect(controller.isReady, false);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
  });

  test('Google load code domain and message survive the event bridge',
      () async {
    final pending = expectLater(
        controller.preload(),
        throwsA(isA<AdError>()
            .having((e) => e.code, 'code', 7)
            .having((e) => e.domain, 'domain', 'com.google.admob')
            .having((e) => e.message, 'message', 'original Google error'),),);
    await event(ad, 'onAdFailedToLoad',
        error: const AdError(code: 7, message: 'original Google error'),);
    await pending;
    expect(loadErrors.single?.code, 7);
    expect(loadErrors.single?.domain, 'com.google.admob');
  });
}
