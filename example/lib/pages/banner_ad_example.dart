import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

class BannerAdExample extends StatefulWidget {
  const BannerAdExample({super.key});

  @override
  State<BannerAdExample> createState() => _BannerAdExampleState();
}

class _BannerAdExampleState extends State<BannerAdExample> {
  BannerAd? _banner320x50;
  bool _isBanner320x50Loaded = false;
  bool _isBanner320x50LoadFailed = false;
  AdSize? _banner320x50AdSize;

  BannerAd? _banner300x250;
  bool _isBanner300x250Loaded = false;
  bool _isBanner300x250LoadFailed = false;
  AdSize? _banner300x250AdSize;

  BannerAd? _widthAdaptiveBanner;
  bool _isWidthAdaptiveBannerLoaded = false;
  bool _isWidthAdaptiveBannerLoadFailed = false;
  AdSize? _widthAdaptiveBannerAdSize;

  BannerAd? _heightAdaptiveBanner;
  bool _isHeightAdaptiveBannerLoaded = false;
  bool _isHeightAdaptiveBannerLoadFailed = false;
  AdSize? _heightAdaptiveBannerAdSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBannerAds();
  }

  @override
  void dispose() {
    _banner320x50?.dispose();
    _banner300x250?.dispose();
    _widthAdaptiveBanner?.dispose();
    _heightAdaptiveBanner?.dispose();
    super.dispose();
  }

  Future<void> _load320x50BannerAd() async {
    _banner320x50?.dispose();

    setState(() {
      _banner320x50 = null;
      _isBanner320x50Loaded = false;
    });

    _banner320x50 = BannerAd(
      adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
      auConfigId: '15624474',
      sizes: {
        AdSize(height: 50, width: 320),
        AdSize(height: 250, width: 300),
        AdSize(height: 160, width: 320),
        AdSize(height: 416, width: 320)
      },
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        setState(
          () {
            _banner320x50 = ad;
            _isBanner320x50LoadFailed = false;
            _isBanner320x50Loaded = true;
            _banner320x50AdSize = adSize;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isBanner320x50LoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _banner320x50?.load();
  }

  Future<void> _load300x250BannerAd() async {
    _banner300x250?.dispose();

    setState(() {
      _banner300x250 = null;
      _isBanner300x250Loaded = false;
    });

    _banner300x250 = BannerAd(
      adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
      auConfigId: '15624474',
      sizes: const {
        AdSize(height: 250, width: 300),
        AdSize(height: 50, width: 320)
      },
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        setState(
          () {
            _banner300x250 = ad;
            _isBanner300x250LoadFailed = false;
            _isBanner300x250Loaded = true;
            _banner300x250AdSize = adSize;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isBanner300x250LoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _banner300x250?.load();
  }

  Future<void> _loadWidthAdaptiveBannerAd() async {
    _widthAdaptiveBanner?.dispose();

    setState(() {
      _widthAdaptiveBanner = null;
      _isWidthAdaptiveBannerLoaded = false;
    });

    final width = MediaQuery.sizeOf(context).width;
    final padding = MediaQuery.paddingOf(context);
    final safeWidth = width - padding.left - padding.right;

    _widthAdaptiveBanner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2435281174',
      auConfigId: '33994718',
      sizes: {AdSize(height: 50, width: safeWidth.toInt())},
      isAdaptiveSize: true,
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        log('Ad size: ${adSize?.width} : ${adSize?.height}');
        setState(
          () {
            _widthAdaptiveBanner = ad;
            _isWidthAdaptiveBannerLoadFailed = false;
            _isWidthAdaptiveBannerLoaded = true;
            _widthAdaptiveBannerAdSize = adSize;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isWidthAdaptiveBannerLoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _widthAdaptiveBanner?.load();
  }

  Future<void> _loadHeightAdaptiveBannerAd() async {
    _heightAdaptiveBanner?.dispose();

    setState(() {
      _heightAdaptiveBanner = null;
      _isHeightAdaptiveBannerLoaded = false;
    });

    final height = MediaQuery.sizeOf(context).height;
    final padding = MediaQuery.paddingOf(context);
    final safeHeight = height - padding.top - padding.bottom;

    _heightAdaptiveBanner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2435281174',
      auConfigId: '33994718',
      sizes: {AdSize(height: safeHeight.toInt(), width: 320)},
      isAdaptiveSize: true,
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        final adSize = await ad.getPlatformAdSize();
        log('Ad size: ${adSize?.width} : ${adSize?.height}');
        setState(
          () {
            _heightAdaptiveBanner = ad;
            _isHeightAdaptiveBannerLoadFailed = false;
            _isHeightAdaptiveBannerLoaded = true;
            _heightAdaptiveBannerAdSize = adSize;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isHeightAdaptiveBannerLoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _heightAdaptiveBanner?.load();
  }

  Future<void> _loadBannerAds() async {
    _load320x50BannerAd();
    _load300x250BannerAd();
    _loadWidthAdaptiveBannerAd();
    _loadHeightAdaptiveBannerAd();
  }

  Widget _getBanner320x50AdWidget() {
    if (_banner320x50 != null &&
        _isBanner320x50Loaded &&
        _banner320x50AdSize != null) {
      return SizedBox(
        width: _banner320x50AdSize?.width.toDouble(),
        height: _banner320x50AdSize?.height.toDouble(),
        child: AdWidget(ad: _banner320x50!),
      );
    }

    if (_isBanner320x50LoadFailed) {
      return TextButton(
        onPressed: _load320x50BannerAd,
        child: Text('Retry'),
      );
    }

    return const SizedBox(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _getBanner300x250Widget() {
    if (_banner300x250 != null &&
        _isBanner300x250Loaded &&
        _banner300x250AdSize != null) {
      return SizedBox(
        width: _banner300x250AdSize?.width.toDouble(),
        height: _banner300x250AdSize?.height.toDouble(),
        child: AdWidget(ad: _banner300x250!),
      );
    }

    if (_isBanner300x250LoadFailed) {
      return TextButton(
        onPressed: _load300x250BannerAd,
        child: Text('Retry'),
      );
    }

    return const SizedBox(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _getBannerAdaptiveWidthWidget() {
    if (_widthAdaptiveBanner != null &&
        _isWidthAdaptiveBannerLoaded &&
        _widthAdaptiveBannerAdSize != null) {
      return SizedBox(
        width: _widthAdaptiveBannerAdSize?.width.toDouble(),
        height: _widthAdaptiveBannerAdSize?.height.toDouble(),
        child: AdWidget(ad: _widthAdaptiveBanner!),
      );
    }

    if (_isWidthAdaptiveBannerLoadFailed) {
      return TextButton(
        onPressed: _loadWidthAdaptiveBannerAd,
        child: Text('Retry'),
      );
    }

    return const SizedBox(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _getBannerAdaptiveHeightWidget() {
    if (_heightAdaptiveBanner != null &&
        _isHeightAdaptiveBannerLoaded &&
        _heightAdaptiveBannerAdSize != null) {
      return SizedBox(
        width: _heightAdaptiveBannerAdSize?.width.toDouble(),
        height: _heightAdaptiveBannerAdSize?.height.toDouble(),
        child: AdWidget(ad: _heightAdaptiveBanner!),
      );
    }

    if (_isHeightAdaptiveBannerLoadFailed) {
      return TextButton(
        onPressed: _loadHeightAdaptiveBannerAd,
        child: Text('Retry'),
      );
    }

    return const SizedBox(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _getBannerAdaptiveWidthWidget(),
          const SizedBox(height: 40),
          _getBannerAdaptiveHeightWidget(),
          const SizedBox(height: 40),
          _getBanner300x250Widget(),
          const SizedBox(height: 40),
          _getBanner320x50AdWidget(),
        ],
      ),
    );
  }
}
