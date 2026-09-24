import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_interstitial_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sizes a remote interstitial hands its plugin are Prebid's banner
/// format, and nothing else: both plugins put them on
/// `bannerParameters.adSizes`, and a GAM interstitial takes no sizes.
///
/// They were read from `gamConfig.adSizes`. That was right by coincidence —
/// the two lists match in every config today — so these tests make the lists
/// DIFFER, which is the only way to tell which one is being read.
void main() {
  RemoteAdConfiguration config({
    required List<String> gamSizes,
    required List<String> prebidSizes,
  }) {
    return RemoteAdConfiguration.fromJson({
      'id': 'remote-interstitial',
      'config': {'adType': 'interstitial'},
      'gamConfig': {'adUnitPath': '/1234/interstitial', 'adSizes': gamSizes},
      'prebidConfig': {'placementId': 'placement', 'adSizes': prebidSizes},
    });
  }

  // AdSize has no value equality, so compare on `WxH`.
  List<String> sizesOf(RemoteInterstitialAd ad) =>
      ad.sizes.map((s) => '${s.width}x${s.height}').toList();

  RemoteInterstitialAd build() => RemoteInterstitialAd(
        configId: 'remote-interstitial',
        onAdLoaded: (_) {},
        onAdFailedToLoad: (_, __) {},
      );

  tearDown(() => AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null));

  test('requests the PREBID sizes, not the GAM slot sizes', () {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      config(gamSizes: ['300x250'], prebidSizes: ['320x480']),
    ]);

    expect(sizesOf(build()), ['320x480']);
  });

  test('orders them largest first, matching the native interstitials', () {
    // Prebid treats the first banner.format as primary, and both natives sort
    // by area descending.
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      config(gamSizes: [], prebidSizes: ['320x460', '320x480', '300x250']),
    ]);

    expect(sizesOf(build()), ['320x480', '320x460', '300x250']);
  });
}
