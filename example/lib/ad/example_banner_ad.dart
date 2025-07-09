import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

final class ExampleBannerAd extends StatefulWidget {
  const ExampleBannerAd({
    required this.id,
    required this.adUnitId,
    required this.adConfigId,
    required this.adSize,
    super.key,
  });

  final int id;
  final String adUnitId;
  final String adConfigId;
  final AdSize adSize;

  @override
  State<ExampleBannerAd> createState() => _ExampleBannerAdState();
}

class _ExampleBannerAdState extends State<ExampleBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isLoadingFailed = false;
  AdSize? _bannerAdSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    log("Ad is disposed ${widget.id}");
    super.dispose();
  }

  Future<void> _loadAd() async {
    _bannerAd?.dispose();

    setState(() {
      _bannerAd = null;
      _isLoaded = false;
    });

    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      auConfigId: widget.adConfigId,
      sizes: {widget.adSize},
      onAdLoaded: (ad) async {
        log('Ad is loaded ${widget.id}: ${ad.adUnitId} ');
        final adSize = await ad.getPlatformAdSize();
        setState(
          () {
            _bannerAd = ad;
            _isLoadingFailed = false;
            _isLoaded = true;
            _bannerAdSize = adSize;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isLoadingFailed = true;
          ad.dispose();
        });
      },
    );

    await _bannerAd?.load();
  }

  Widget _getAdWidget() {
    if (_bannerAd != null && _isLoaded && _bannerAdSize != null) {
      return SizedBox(
        width: _bannerAdSize?.width.toDouble(),
        height: _bannerAdSize?.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    if (_isLoadingFailed) {
      return TextButton(
        onPressed: _loadAd,
        child: Text('Retry'),
      );
    }

    return SizedBox(
      width: widget.adSize.width.toDouble(),
      height: widget.adSize.height.toDouble(),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _getAdWidget();
}
