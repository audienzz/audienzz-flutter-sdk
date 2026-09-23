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
    final pending = controller.prefetch();
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

  test('prefetch alone never presents, and prefetchAndShow reuses it', () async {
    await ready();
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty,
        reason: 'a prefetch must not present');

    expect(await controller.prefetchAndShow(), true);
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
    // Inventory already in hand: no second request was spent on it.
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
  });

  test('prefetchAndShow presents once when the load completes', () async {
    final pending = controller.prefetchAndShow();
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty,
        reason: 'nothing to present until the ad arrives');
    await event(ad, 'onAdLoaded');
    expect(await pending, true);
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
  });

  test('concurrent prefetchAndShow calls share one load and one presentation',
      () async {
    final first = controller.prefetchAndShow();
    final second = controller.prefetchAndShow();
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1,
        reason: 'repeated calls must join the request in flight');
    await event(ad, 'onAdLoaded');
    final results = await Future.wait([first, second]);
    expect(results.where((submitted) => submitted).length, 1,
        reason: 'one presentation, not one per caller');
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
  });

  test('prefetchAndShow is cancelled by a backgrounded app, not queued',
      () async {
    final pending = controller.prefetchAndShow();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await event(ad, 'onAdLoaded');
    expect(await pending, false);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    // Returning to the foreground must not replay it; the ad is kept for an
    // opportunity the publisher chooses.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(controller.isReady, true);
  });

  test('a missed opportunity never displays when a slow prefetch completes',
      () async {
    final first = controller.prefetch();
    final second = controller.prefetch();
    expect(await controller.show(eligible: true), false);
    await event(ad, 'onAdLoaded');
    await Future.wait([first, second]);
    await controller.prefetch();
    expect(controller.isReady, true);
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(await controller.show(eligible: true), true);
    expect(await controller.show(eligible: true), false);
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
  });

  test('a frequency cap skips the opportunity and retains the ad', () async {
    await ready();
    expect(await controller.show(eligible: false), false);
    expect(controller.isReady, true);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
  });

  test('background has no pending show to replay on foreground', () async {
    await ready();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(await controller.show(eligible: true), false);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    expect(controller.isReady, true);
    expect(await controller.show(eligible: true), true);
  });

  test('another interstitial presentation preserves this ready ad', () async {
    await ready();
    final otherAd = makeAd();
    final other = InterstitialPresentationController(ad: otherAd);
    final pending = other.prefetch();
    await event(otherAd, 'onAdLoaded');
    await pending;
    expect(await other.show(eligible: true), true);
    expect(await controller.show(eligible: true), false);
    expect(controller.isReady, true);
    await event(otherAd, 'onAdClosed');
    expect(await controller.show(eligible: true), true);
    await other.dispose();
  });

  test('disposing a presenting controller retains callbacks until terminal',
      () async {
    await ready();
    expect(await controller.show(eligible: true), true);
    final id = adInstanceManager.adIdFor(ad);
    await controller.dispose();
    expect(adInstanceManager.adIdFor(ad), id);
    expect(await controller.show(eligible: true), false);
    await expectLater(controller.prefetch(), throwsStateError);
    await event(ad, 'onAdClosed');
    expect(adInstanceManager.adIdFor(ad), isNull);
  });

  test('disposed preload cannot resurrect an earlier show opportunity',
      () async {
    final pending = expectLater(controller.prefetch(), throwsStateError);
    expect(await controller.show(eligible: true), false);
    await controller.dispose();
    await pending;
    expect(controller.isReady, false);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
  });

  test('Google load code domain and message survive the event bridge',
      () async {
    final pending = expectLater(
        controller.prefetch(),
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
