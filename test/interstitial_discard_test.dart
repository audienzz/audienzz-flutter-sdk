import 'dart:async';
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inventory that loads and is then released without ever being seen is the
/// load-to-impression gap. `loaded` with no matching `impression` was silent,
/// and expiry in particular was only evaluated lazily, so an ad could age out
/// with nothing recorded anywhere.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  late List<InterstitialAdEvent> events;
  late List<InterstitialAd> ads;
  var now = DateTime(2026);

  InterstitialAd makeAd() {
    final value = InterstitialAd(
      adUnitId: '/discard',
      auConfigId: 'discard',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
      onLifecycleEvent: (_, e) => events.add(e),
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

  List<InterstitialAdEvent> discards() =>
      events.where((e) => e.name == 'discardedWithoutImpression').toList();

  setUp(() {
    events = [];
    ads = [];
    now = DateTime(2026);
    adInstanceManager.interstitialClock = () => now;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() async {
    for (final a in ads) {
      await a.dispose();
    }
    adInstanceManager.interstitialClock = DateTime.now;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('expiry reports the discard exactly once', () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    expect(discards(), isEmpty, reason: 'control: held inventory is not a discard');

    now = now.add(const Duration(hours: 1, minutes: 1));
    // Re-loading is what observes the expiry; the new load stays pending.
    unawaited(ad.load().catchError((_) {}));

    expect(discards().length, 1);
    expect(discards().single.reason, 'expired');
    expect(discards().single.loadAgeMillis, greaterThan(3600 * 1000));
  });

  test('disposal of held inventory reports a discard', () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    await ad.dispose();

    expect(discards().length, 1);
    expect(discards().single.reason, 'disposed');
  });

  test('a presentation failure reports a discard', () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    await ad.show();
    await event(ad, 'onAdFailedToShow');

    expect(discards().length, 1);
    expect(discards().single.reason, 'presentationFailed');
  });

  test('presented and dismissed with no impression reports a discard',
      () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    await ad.show();
    await event(ad, 'onAdOpened');
    await event(ad, 'onAdClosed');

    expect(discards().length, 1);
    expect(discards().single.reason, 'dismissedWithoutImpression');
  });

  test('inventory that recorded an impression is never a discard', () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    await ad.show();
    await event(ad, 'onAdOpened');
    await event(ad, 'onAdImpression');
    await event(ad, 'onAdClosed');

    expect(events.map((e) => e.name), contains('impression'));
    expect(discards(), isEmpty);
  });

  test('a load failure is not an unused successful load', () async {
    final ad = makeAd();
    unawaited(ad.load().catchError((_) {}));
    await event(ad, 'onAdFailedToLoad');

    expect(events.map((e) => e.name), contains('loadFailed'));
    expect(discards(), isEmpty,
        reason: 'there was never any inventory to waste');
  });

  test('every discard carries the load id and an age', () async {
    final ad = makeAd();
    final loading = ad.load();
    await event(ad, 'onAdLoaded');
    await loading;
    now = now.add(const Duration(minutes: 5));
    await ad.dispose();

    final discard = discards().single;
    final loaded = events.firstWhere((e) => e.name == 'loaded');
    expect(discard.loadId, loaded.loadId,
        reason: 'the discard must be correlatable with its load');
    expect(discard.loadAgeMillis, 5 * 60 * 1000);
  });
}
