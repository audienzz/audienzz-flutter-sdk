import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// What repeated prefetching costs on the API publishers are required to use.
///
/// One ad is held at a time, an ad older than an hour stops counting as inventory, and prefetching
/// again while one is held or in flight buys nothing.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  late List<MethodCall> calls;
  late List<InterstitialAd> ads;
  late InterstitialAd ad;
  late InterstitialPresentationController controller;
  var now = DateTime(2026);

  InterstitialAd makeAd() {
    final value = InterstitialAd(
      adUnitId: '/prefetch',
      auConfigId: 'prefetch',
      adFormat: AdFormat.banner,
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    ads.add(value);
    return value;
  }

  Future<void> event(InterstitialAd ad, String name) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': adInstanceManager.adIdFor(ad),
        'eventName': name,
        'adError': null,
        'errorDomain': 'com.google.admob',
      })),
      (_) {},
    );
  }

  int loadCalls() =>
      calls.where((c) => c.method == 'loadInterstitialAd').length;

  setUp(() {
    calls = [];
    ads = [];
    now = DateTime(2026);
    adInstanceManager.interstitialClock = () => now;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    ad = makeAd();
    controller = InterstitialPresentationController(ad: ad);
  });

  tearDown(() async {
    for (final a in ads) {
      await event(a, 'onAdClosed');
      await a.dispose();
    }
    await controller.dispose();
    adInstanceManager.interstitialClock = DateTime.now;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('four prefetches in a row buy one ad', () async {
    final pending = [
      controller.prefetch(),
      controller.prefetch(),
      controller.prefetch(),
      controller.prefetch(),
    ];
    expect(loadCalls(), 1, reason: 'only the first may reach the ad server');

    await event(ad, 'onAdLoaded');
    await Future.wait(pending);

    expect(controller.isReady, true);
    expect(loadCalls(), 1);
  });

  test('prefetching again does not replace held inventory', () async {
    final first = controller.prefetch();
    await event(ad, 'onAdLoaded');
    await first;
    expect(controller.isReady, true);

    await controller.prefetch();
    await controller.prefetch();

    expect(loadCalls(), 1, reason: 'a cached ad is not replaced by another prefetch');
    expect(controller.isReady, true);
  });

  test('an expired ad is replaced exactly once', () async {
    final first = controller.prefetch();
    await event(ad, 'onAdLoaded');
    await first;
    expect(controller.isReady, true);

    now = now.add(const Duration(hours: 1, seconds: 1));
    expect(controller.isReady, false,
        reason: 'an ad older than an hour is not inventory');

    // Left in flight deliberately: what matters is how many requests were issued, not how they
    // end. Disposal in tearDown cancels them, so their errors are absorbed here.
    for (final pending in [
      controller.prefetch(),
      controller.prefetch(),
      controller.prefetch(),
    ]) {
      unawaited(pending.catchError((Object _) {}));
    }

    expect(loadCalls(), 2, reason: 'expiry allows one replacement, not one per call');
  });
}
