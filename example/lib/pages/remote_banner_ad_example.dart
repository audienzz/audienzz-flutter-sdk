import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

class RemoteBannerAdExample extends StatefulWidget {
  const RemoteBannerAdExample({
    required this.configId,
    super.key,
  });

  final String configId;

  @override
  State<RemoteBannerAdExample> createState() => _RemoteBannerAdExampleState();
}

class _RemoteBannerAdExampleState extends State<RemoteBannerAdExample> {
  RemoteBannerAd? _bannerAd;
  bool _isAdLoaded = false;
  String? _error;

  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    loadAd();
  }

  void loadAd() {
    _bannerAd = RemoteBannerAd(
      configId: widget.configId,
      onAdLoaded: (ad) async {
        final adSize = await ad.getPlatformAdSize();
        setState(() {
          _isAdLoaded = true;
          _error = null;
          _adSize = adSize;
        });
        print('Remote Banner Ad loaded');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _isAdLoaded = false;
          _error = error?.message;
        });
        print('Remote Banner Ad failed to load: $error');
        ad.dispose();
      },
      onAdClicked: (ad) => print('Remote Banner Ad clicked'),
      onAdOpened: (ad) => print('Remote Banner Ad opened'),
      onAdClosed: (ad) => print('Remote Banner Ad closed'),
      onAdImpression: (ad) => print('Remote Banner Ad impression'),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    if (_isAdLoaded && _bannerAd != null) {
      final width = _adSize?.width.toDouble() ??
          _bannerAd!.sizes.first.width.toDouble();
      final height = _adSize?.height.toDouble() ??
          _bannerAd!.sizes.first.height.toDouble();

      return SizedBox(
        width: width,
        height: height,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox(
      height: 50,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
