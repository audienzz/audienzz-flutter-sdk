import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A remote banner sends GAM the GAM slot's sizes and Prebid the Prebid ones —
/// the split the native remote banners make.
///
/// One list used to feed both, so a publisher who allowed a size in GAM (for
/// direct-sold line items) but kept it out of header bidding had Prebid asked
/// for it anyway, on Flutter only. Each case below is the shape of a live
/// config, asserted on what actually crosses the method channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final codec = StandardMethodCodec(AdMessageCodec());
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(Constants.methodChannelName, codec);
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    adInstanceManager.currentPage = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
  });

  void seed(List<String> gam, List<String> prebid) {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'slot',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {'adUnitPath': '/1234/unit', 'adSizes': gam},
        'prebidConfig': {'placementId': 'placement', 'adSizes': prebid},
      }),
    ]);
  }

  /// What the plugin receives. AdSize has no value equality, so `WxH`.
  Future<Map<Object?, Object?>> loadPayload() async {
    final ad = RemoteBannerAd(
      configId: 'slot',
      onAdLoaded: (_) {},
      onAdFailedToLoad: (_, __) {},
    );
    await ad.load();
    return calls.lastWhere((c) => c.method == 'loadBannerAd').arguments
        as Map<Object?, Object?>;
  }

  List<String>? sizes(Object? raw) => (raw as List<Object?>?)
      ?.cast<AdSize>()
      .map((s) => '${s.width}x${s.height}')
      .toList();

  test('matching lists (prod 46/48/50): Prebid gets exactly the GAM sizes',
      () async {
    // The no-op case: every current production banner looks like this, so its
    // request must be unchanged. Already largest-first, so the order holds too.
    seed(['300x250', '320x50'], ['300x250', '320x50']);

    final payload = await loadPayload();

    expect(sizes(payload['adSizes']), ['300x250', '320x50']);
    expect(sizes(payload['prebidAdSizes']), sizes(payload['adSizes']));
  });

  test('a GAM-only size (dev 192) reaches GAM and never reaches Prebid',
      () async {
    seed(['300x250', '300x600', '320x480'], ['300x250', '320x480']);

    final payload = await loadPayload();

    expect(sizes(payload['adSizes']), contains('300x600'),
        reason: 'direct-sold 300x600 line items must still be able to serve');
    expect(sizes(payload['prebidAdSizes']), isNot(contains('300x600')),
        reason: 'the publisher kept 300x600 out of header bidding');
  });

  test('Prebid sizes go largest first (dev 118), which sets the primary size',
      () async {
    // Native sorts by area; the first entry becomes the ad unit's primary.
    seed(
      ['300x250', '320x50', '320x150', '320x480'],
      ['300x250', '320x50', '320x150', '320x480'],
    );

    final payload = await loadPayload();

    expect(sizes(payload['prebidAdSizes']),
        ['320x480', '300x250', '320x150', '320x50']);
    expect(sizes(payload['adSizes']),
        ['300x250', '320x50', '320x150', '320x480'],
        reason: 'the GAM request is left exactly as it was');
  });

  test('an empty Prebid list (prod 49) is not sent, so the plugin falls back',
      () async {
    // Sending it would crash both plugins, which build the ad unit from the
    // first size. What an empty list SHOULD mean is undecided (Android native
    // refuses to load, iOS native goes GAM-only), so this keeps today's
    // behaviour: the plugin uses adSizes for Prebid, as before.
    seed(['300x250'], []);

    final payload = await loadPayload();

    expect(payload.containsKey('prebidAdSizes'), isFalse);
    expect(sizes(payload['adSizes']), ['300x250']);
  });
}
