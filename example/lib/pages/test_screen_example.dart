import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Minimal second screen for testing per-screen analytics / screen tracking, mirroring the
/// native example's "ad screen" (RemoteConfigAdScreenViewController / RemoteConfigAdActivity).
///
/// It is opened from the "Test Screen" navigation tile in main.dart, which reports the route via
/// `pageImpression('Test Screen')` on entry and `pageImpression('home')` on return — so
/// navigating Home -> Test Screen -> Home produces a fresh `pageImpression` per visit and this
/// banner's auction events are attributed to `screen_name: Test Screen`. Uses the same 300x250
/// unit (wuobgeuc) as the native example so logs line up across platforms.
class TestScreenExample extends StatefulWidget {
  const TestScreenExample({super.key});

  @override
  State<TestScreenExample> createState() => _TestScreenExampleState();
}

class _TestScreenExampleState extends State<TestScreenExample> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _failed = false;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanner();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    _banner?.dispose();
    setState(() {
      _banner = null;
      _loaded = false;
      _failed = false;
    });

    _banner = BannerAd(
      adUnitId: '/96628199/de_audienzz.ch_v2/multi-size',
      auConfigId: 'wuobgeuc',
      sizes: const {
        AdSize(height: 250, width: 300),
        AdSize(height: 50, width: 320),
      },
      onAdLoaded: (ad) async {
        log('[TestScreen] banner loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        setState(() {
          _banner = ad;
          _loaded = true;
          _failed = false;
          _adSize = adSize;
        });
      },
      onAdFailedToLoad: (ad, error) {
        log('[TestScreen] banner failed: ${error?.message}');
        setState(() {
          _failed = true;
          ad.dispose();
        });
      },
      onAdImpression: (ad) => log('[TestScreen] banner impression'),
    );

    await _banner?.load();
  }

  Widget _bannerWidget() {
    if (_failed) {
      return TextButton(onPressed: _loadBanner, child: const Text('Retry'));
    }
    if (_banner == null || _banner!.sizes.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final width = _adSize?.width.toDouble() ?? _banner!.sizes.first.width.toDouble();
    final height = _adSize?.height.toDouble() ?? _banner!.sizes.first.height.toDouble();
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          AdWidget(ad: _banner!),
          if (!_loaded) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        const Text(
          'Test Screen',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'One banner on its own screen — for screen-tracking / analytics logs.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Center(child: _bannerWidget()),
      ],
    );
  }
}
