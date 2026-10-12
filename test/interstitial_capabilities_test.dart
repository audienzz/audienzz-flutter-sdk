import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An interstitial's formats and API frameworks are backend-controlled.
///
/// A remote interstitial forwards its ad config's `prebidConfig.format` /
/// `prebidConfig.apis` with each ACCEPTED load, and the native SDK validates
/// them exactly as its own remote interstitial does. Without a valid format
/// (a hand-built interstitial, or an ad config that has none) Dart sends
/// `banner`: video is opt-in per placement. These tests pin what crosses the
/// channel, and when.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  late List<MethodCall> calls;
  final ads = <InterstitialAd>[];

  void seed(Map<String, dynamic> prebidConfig) {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'int',
        'config': {'adType': 'interstitial'},
        'gamConfig': {'adUnitPath': '/1/int', 'adSizes': ['320x480']},
        'prebidConfig': {
          'placementId': 'p',
          'adSizes': ['320x480'],
          ...prebidConfig,
        },
      }),
    ]);
  }

  RemoteInterstitialAd remote() {
    final ad = RemoteInterstitialAd(
      configId: 'int',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    ads.add(ad);
    return ad;
  }

  Future<void> event(InterstitialAd ad, String name) async {
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onAdEvent', {
        'adId': adInstanceManager.adIdFor(ad),
        'eventName': name,
        'adError': null,
        'errorDomain': 'com.google.admob',
      }),),
      (_) {},
    );
  }

  /// Starts a load and lets its channel call go out. A load settles only when
  /// Google delivers, so it is not awaited here.
  Future<void> start(InterstitialAd ad) async {
    unawaited(ad.load());
    await Future<void>.delayed(Duration.zero);
  }

  List<Map<Object?, Object?>> loads() => calls
      .where((c) => c.method == 'loadInterstitialAd')
      .map((c) => c.arguments as Map<Object?, Object?>)
      .toList();

  setUp(() {
    calls = [];
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    for (final ad in ads) {
      await event(ad, 'onAdClosed');
      await ad.dispose();
    }
    ads.clear();
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('a hand-built interstitial requests banner only', () async {
    final handBuilt = InterstitialAd(
      adUnitId: '/1/int',
      auConfigId: 'p',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    ads.add(handBuilt);
    await start(handBuilt);

    final payload = loads().single;
    expect(payload.containsKey('adFormat'), isFalse);
    expect(payload.containsKey('apiParameters'), isFalse);
    expect(payload['backendFormat'], 'banner',
        reason: 'no ad config: banner, not the native banner + video',);
    expect(payload.containsKey('backendApis'), isFalse);
  });

  test('video defaults describe an interstitial, as native does', () async {
    // They were empty protocols and an in-banner placement, forwarded as-is:
    // a video interstitial was described to bidders as a banner slot.
    final ad = InterstitialAd(
      adUnitId: '/1/int',
      auConfigId: 'p',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    ads.add(ad);
    await start(ad);

    final payload = loads().single;
    expect(payload['protocols'], [Protocol.vast2_0]);
    expect(payload['placement'], Placement.interstitial);
    expect(payload['playbackMethods'], [PlaybackMethod.autoPlaySoundOff]);
  });

  test('a remote interstitial forwards its ad config values', () async {
    seed({'format': 'banner', 'apis': [7, 3]});
    await start(remote());

    final payload = loads().single;
    expect(payload['backendFormat'], 'banner');
    expect(payload['backendApis'], [7, 3]);
    expect(payload.containsKey('adFormat'), isFalse);
  });

  test('an unconfigured remote interstitial requests banner only', () async {
    seed({});
    await start(remote());

    final payload = loads().single;
    expect(payload['backendFormat'], 'banner');
    expect(payload.containsKey('backendApis'), isFalse);
  });

  test('video is requested only when the ad config asks for it', () async {
    for (final format in ['video', 'bannerAndVideo']) {
      seed({'format': format});
      final ad = remote();
      await start(ad);
      expect(loads().last['backendFormat'], format);
      await event(ad, 'onAdClosed');
    }
  });

  test('an unknown format falls back to banner, not banner + video',
      () async {
    seed({'format': 'BannerAndVideo'});
    await start(remote());

    expect(
      loads().single['backendFormat'],
      'banner',
      reason: 'formats are case-sensitive; native would add video',
    );
  });

  test('malformed values are dropped without failing the config', () async {
    seed({'format': 5, 'apis': '3,5'});
    await start(remote());

    final payload = loads().single;
    expect(payload['adUnitId'], '/1/int', reason: 'the placement still loads');
    expect(payload['backendFormat'], 'banner');
    expect(payload.containsKey('backendApis'), isFalse);
  });

  test('only integral numbers are forwarded', () async {
    seed({'apis': [3, '5', true, 6.5, 7.0, null]});
    await start(remote());

    expect(loads().single['backendApis'], [3, 7]);
  });

  test('the values survive the local cache', () {
    seed({'format': 'video', 'apis': [7]});
    final cached = RemoteAdConfiguration.fromJson(
        AudienzzRemoteConfig.instance.remoteConfigFor('int')!.toJson(),);
    expect(cached.prebidConfig.format, 'video');
    expect(cached.prebidConfig.apis, [7]);
  });

  test('a config change neither discards ready inventory nor requests',
      () async {
    seed({'format': 'banner'});
    final ad = remote();
    final first = ad.load();
    final coalesced = ad.load();
    await event(ad, 'onAdLoaded');
    await Future.wait([first, coalesced]);
    expect(ad.isReady, isTrue);
    expect(loads(), hasLength(1), reason: 'coalesced loads send nothing new');

    seed({'format': 'video'});
    await ad.load();

    expect(ad.isReady, isTrue, reason: 'the ready ad is kept');
    expect(
      loads(),
      hasLength(1),
      reason: 'no request because the config changed',
    );
  });

  test('the next accepted load reads the config at that moment', () async {
    seed({'format': 'banner'});
    final ad = remote();
    final first = ad.load();
    await event(ad, 'onAdLoaded');
    await first;
    await ad.show();
    await event(ad, 'onAdOpened');

    seed({'format': 'video', 'apis': [7]});
    await start(ad);
    expect(
      loads(),
      hasLength(1),
      reason: 'nothing is requested over a presentation',
    );
    expect(calls.where((c) => c.method == 'disposeAd'), isEmpty,
        reason: 'the ad on screen is not torn down',);

    await event(ad, 'onAdClosed');
    await start(ad);

    expect(loads(), hasLength(2));
    expect(loads().last['backendFormat'], 'video');
    expect(loads().last['backendApis'], [7]);
  });
}
