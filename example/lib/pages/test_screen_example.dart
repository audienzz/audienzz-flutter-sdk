import 'dart:async';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Minimal second screen for testing per-screen analytics / screen tracking, mirroring the
/// native example's "ad screen" (RemoteConfigAdScreenViewController / RemoteConfigAdActivity).
///
/// Owns its Scaffold for every entry point. The page wrapper and navigator observer share one
/// identity, and the banner waits for that page to be active before loading.
class TestScreenExample extends StatelessWidget {
  const TestScreenExample({super.key});

  static Route<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Test Screen'),
        builder: (_) => const TestScreenExample(),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Test Screen')),
        body: const AudienzzPage(
          name: 'Test Screen',
          child: _TestScreenContent(),
        ),
      );
}

class _TestScreenContent extends StatefulWidget {
  const _TestScreenContent();

  @override
  State<_TestScreenContent> createState() => _TestScreenContentState();
}

class _TestScreenContentState extends State<_TestScreenContent> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _failed = false;
  AdSize? _adSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final page = AudienzzPageScope.maybeOf(context);
    if (page?.isActive == true && _banner == null && !_failed) {
      _loadBanner();
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _loadBanner() {
    final page = AudienzzPageScope.maybeOf(context);
    if (page?.isActive != true) return;
    _banner?.dispose();
    setState(() {
      _banner = null;
      _loaded = false;
      _failed = false;
      _adSize = null;
    });

    _banner = BannerAd(
      pageKey: page!.page.id,
      adUnitId: '/96628199/de_audienzz.ch_v2/multi-size',
      auConfigId: 'wuobgeuc',
      sizes: const {
        AdSize(height: 250, width: 300),
        AdSize(height: 50, width: 320),
      },
      onAdLoaded: (ad) async {
        if (!mounted || !identical(ad, _banner)) return;
        log('[TestScreen] banner loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        if (!mounted || !identical(ad, _banner)) return;
        setState(() {
          _banner = ad;
          _loaded = true;
          _failed = false;
          _adSize = adSize;
        });
      },
      onAdFailedToLoad: (ad, error) {
        if (!mounted || !identical(ad, _banner)) return;
        log('[TestScreen] banner failed: ${error?.message}');
        setState(() {
          _failed = true;
          _banner = null;
        });
        unawaited(ad.dispose());
      },
      onAdImpression: (ad) => log('[TestScreen] banner impression'),
    );

    unawaited(_banner!.load());
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
    final width =
        _adSize?.width.toDouble() ?? _banner!.sizes.first.width.toDouble();
    final height =
        _adSize?.height.toDouble() ?? _banner!.sizes.first.height.toDouble();
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
          'One banner on its own screen — for screen-tracking / analytics logs.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        Center(child: _bannerWidget()),
      ],
    );
  }
}
