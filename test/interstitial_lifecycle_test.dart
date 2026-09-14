import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  late InterstitialAd ad;
  late List<MethodCall> calls;
  late List<InterstitialAdEvent> events;
  late int closed;
  late int loaded;
  late int loadFailures;
  late List<AdError> showFailures;
  late DateTime now;
  Object? channelError;

  Future<void> event(String name, {int? id, AdError? error}) async {
    await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
          'adId': id ?? adInstanceManager.adIdFor(ad),
          'eventName': name,
          'adError': error,
          'errorDomain': 'google.test',
          'responseId': 'response-123'
        })),
        (_) {});
  }

  Future<void> makeReady() async {
    final ready = ad.load();
    await event('onAdLoaded');
    await ready;
  }

  setUp(() {
    calls = [];
    events = [];
    closed = 0;
    loaded = 0;
    loadFailures = 0;
    showFailures = [];
    channelError = null;
    now = DateTime.utc(2026);
    adInstanceManager.interstitialClock = () => now;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (channelError != null && call.method != 'disposeAd')
        throw channelError!;
      return null;
    });
    ad = InterstitialAd(
        adUnitId: '/probe',
        auConfigId: 'probe',
        adFormat: AdFormat.banner,
        onAdLoaded: (_) => loaded++,
        onAdClosed: (_) => closed++,
        onAdFailedToLoad: (_, __) => loadFailures++,
        onAdFailedToShow: (_, error) => showFailures.add(error),
        onLifecycleEvent: (_, value) => events.add(value));
  });
  tearDown(() async {
    // Complete presentations before cleanup, matching the real terminal event.
    await event('onAdClosed');
    await ad.dispose();
    adInstanceManager.interstitialClock = DateTime.now;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('load waits for Google readiness and concurrent calls share one request',
      () async {
    var complete = false;
    final first = ad.load().then((_) => complete = true);
    final second = ad.load();
    await Future<void>.delayed(Duration.zero);
    expect(complete, false);
    expect(ad.isReady, false);
    await expectLater(ad.show(), throwsStateError);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    await event('onAdLoaded');
    await Future.wait([first, second]);
    expect(ad.isReady, true);
    await ad.load();
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
    expect(loaded, 1);
  });

  test('README await load then show cannot show before loaded', () async {
    final flow = () async {
      await ad.load();
      await ad.show();
    }();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'showAdWithoutView'), isEmpty);
    await event('onAdLoaded');
    await flow;
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
  });

  test('dispose during presentation preserves terminal callbacks and telemetry',
      () async {
    await makeReady();
    final id = adInstanceManager.adIdFor(ad);
    await ad.show();
    await ad.dispose();
    expect(adInstanceManager.adIdFor(ad), id);
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty);
    await event('onAdOpened');
    await event('onAdImpression');
    await event('onAdClosed');
    await event('onAdClosed', id: id);
    expect(closed, 1);
    expect(adInstanceManager.adIdFor(ad), isNull);
    expect(events.map((e) => e.name), [
      'loadRequested',
      'loaded',
      'showAttempted',
      'disposeDeferred',
      'presented',
      'impression',
      'dismissed',
      'disposed'
    ]);
    expect(events.map((e) => e.loadId).toSet(), {id});
    expect(events.last.responseId, 'response-123');
  });

  test(
      'asynchronous load failure permits same-object retry and ignores old events',
      () async {
    final pending = expectLater(ad.load(), throwsA(isA<AdError>()));
    final old = adInstanceManager.adIdFor(ad);
    await event('onAdFailedToLoad',
        error: const AdError(code: 2, message: 'network'));
    await pending;
    expect(loadFailures, 1);
    final retry = ad.load();
    await event('onAdLoaded', id: old);
    expect(loaded, 0);
    await event('onAdLoaded');
    await retry;
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 2);
  });

  test(
      'show failure carries domain and is never reported as load failure or close',
      () async {
    await makeReady();
    final id = adInstanceManager.adIdFor(ad);
    await ad.show();
    await event('onAdFailedToShow',
        error: const AdError(code: 7, message: 'presenter'));
    await event('onAdFailedToShow', id: id);
    expect(showFailures.single.code, 7);
    expect(showFailures.single.domain, 'google.test');
    expect(loadFailures, 0);
    expect(closed, 0);
    expect(adInstanceManager.adIdFor(ad), isNull);
  });

  test(
      'synchronous native show rejection invokes the presentation callback once',
      () async {
    await makeReady();
    channelError =
        PlatformException(code: '-2', message: 'expired', details: 'audienzz');
    await expectLater(ad.show(), throwsA(isA<PlatformException>()));
    expect(showFailures.single.message, 'expired');
    expect(closed, 0);
  });

  test('duplicate shows and loads during presentation never replace the ad',
      () async {
    await makeReady();
    await ad.show();
    await expectLater(ad.show(), throwsStateError);
    await expectLater(ad.load(), throwsStateError);
    expect(calls.where((c) => c.method == 'showAdWithoutView').length, 1);
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
  });

  test('disposal during load settles the future and drops a late load',
      () async {
    final pending = expectLater(ad.load(), throwsStateError);
    final id = adInstanceManager.adIdFor(ad);
    await ad.dispose();
    await pending;
    await event('onAdLoaded', id: id);
    expect(loaded, 0);
  });

  test('expired inventory is replaced only on an explicit load', () async {
    await makeReady();
    now = now.add(const Duration(hours: 1));
    expect(ad.isReady, false);
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 1);
    final ready = ad.load();
    await event('onAdLoaded');
    await ready;
    expect(ad.isReady, true);
    expect(calls.where((c) => c.method == 'loadInterstitialAd').length, 2);
    expect(events.where((e) => e.reason == 'expired').length, 1);
  });

  test('channel load failure settles the readiness future', () async {
    channelError = PlatformException(code: 'invalid', message: 'bad config');
    await expectLater(ad.load(), throwsA(isA<AdError>()));
    expect(loadFailures, 1);
    expect(adInstanceManager.adIdFor(ad), isNull);
  });

  testWidgets('a missing native completion times out instead of hanging',
      (tester) async {
    final pending = expectLater(ad.load(), throwsA(isA<AdError>()));
    await tester.pump(const Duration(seconds: 120));
    await pending;
    expect(loadFailures, 1);
    expect(adInstanceManager.adIdFor(ad), isNull);
  });
}
