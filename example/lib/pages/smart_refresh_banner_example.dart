import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Demonstrates a manual [BannerAd] with [smartRefresh] = true and
/// [isLazyLoad] = false.
///
/// No visibility handling lives here: once an ad is created with
/// smartRefresh: true, the SDK's [AdWidget] pauses/resumes auto-refresh itself
/// based on scroll visibility, route occlusion and app lifecycle.
class SmartRefreshBannerExample extends StatelessWidget {
  const SmartRefreshBannerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _SingleSmartRefreshBanner(
          adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
          auConfigId: '15624474',
          sizes: {AdSize(width: 320, height: 50)},
          label: '320×50',
          refreshTimeInterval: 30000,
        ),
        SizedBox(height: 24),
        _SingleSmartRefreshBanner(
          adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
          auConfigId: '15624474',
          sizes: {AdSize(width: 300, height: 250)},
          label: '300×250',
          refreshTimeInterval: 30000,
        ),
      ],
    );
  }
}

class _SingleSmartRefreshBanner extends StatefulWidget {
  const _SingleSmartRefreshBanner({
    required this.adUnitId,
    required this.auConfigId,
    required this.sizes,
    required this.label,
    required this.refreshTimeInterval,
  });

  final String adUnitId;
  final String auConfigId;
  final Set<AdSize> sizes;
  final String label;

  /// Refresh interval in milliseconds passed to [BannerAd.refreshTimeInterval].
  final int refreshTimeInterval;

  @override
  State<_SingleSmartRefreshBanner> createState() =>
      _SingleSmartRefreshBannerState();
}

class _SingleSmartRefreshBannerState extends State<_SingleSmartRefreshBanner> {
  BannerAd? _ad;
  bool _isLoaded = false;
  String? _error;
  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      auConfigId: widget.auConfigId,
      sizes: widget.sizes,
      // Smart refresh is the feature under test; lazy load is off so the
      // demand fetch fires immediately (no prefetch-margin wait). The SDK's
      // AdWidget handles pause/resume — no visibility code needed here.
      smartRefresh: true,
      isLazyLoad: false,
      refreshTimeInterval: widget.refreshTimeInterval,
      onAdLoaded: (ad) async {
        final adSize = await ad.getPlatformAdSize();
        setState(() {
          _isLoaded = true;
          _error = null;
          _adSize = adSize;
        });
        print('SmartRefreshBannerExample [${widget.label}] ad loaded');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _ad = null;
          _isLoaded = false;
          _error = error?.message ?? 'Ad failed to load';
        });
        print('SmartRefreshBannerExample [${widget.label}] failed: $error');
        ad.dispose();
      },
      onAdClicked: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] clicked'),
      onAdOpened: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] opened'),
      onAdClosed: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] closed'),
      onAdImpression: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] impression'),
    );
    _ad!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error [${widget.label}]: $_error'));
    }

    if (_ad == null || widget.sizes.isEmpty) {
      return SizedBox(
        height: widget.sizes.firstOrNull?.height.toDouble() ?? 50,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final width =
        _adSize?.width.toDouble() ?? widget.sizes.first.width.toDouble();
    final height =
        _adSize?.height.toDouble() ?? widget.sizes.first.height.toDouble();

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            AdWidget(ad: _ad!),
            if (!_isLoaded) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
