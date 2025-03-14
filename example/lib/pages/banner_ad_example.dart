import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/constants/constants.dart';
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

  BannerAd? _widthMultisizedBanner;
  bool _isWidthMultisizedBannerLoaded = false;
  bool _isWidthMultisizedBannerLoadFailed = false;
  AdSize? _widthMultisizedBannerAdSize;

  BannerAd? _heightMultisizedBanner;
  bool _isHeightMultisizedBannerLoaded = false;
  bool _isHeightMultisizedBannerLoadFailed = false;
  AdSize? _heightMultisizedBannerAdSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBannerAds();
  }

  @override
  void dispose() {
    _banner320x50?.dispose();
    _banner300x250?.dispose();
    _widthMultisizedBanner?.dispose();
    _heightMultisizedBanner?.dispose();
    super.dispose();
  }

  Future<void> _load320x50BannerAd() async {
    _banner320x50?.dispose();

    setState(() {
      _banner320x50 = null;
      _isBanner320x50Loaded = false;
    });

    _banner320x50 = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2934735716',
      auConfigId: '33994718',
      size: const AdSize(height: 50, width: 320),
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        setState(
          () {
            _banner320x50 = ad;
            _isBanner320x50LoadFailed = false;
            _isBanner320x50Loaded = true;
            _banner320x50AdSize = ad.size;
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
      appContent: Constants.exampleAppContent,
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
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      auConfigId: '33994718',
      size: const AdSize(height: 250, width: 300),
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        setState(
          () {
            _banner300x250 = ad;
            _isBanner300x250LoadFailed = false;
            _isBanner300x250Loaded = true;
            _banner300x250AdSize = ad.size;
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

  Future<void> _loadWidthMultisizedBannerAd() async {
    _widthMultisizedBanner?.dispose();

    setState(() {
      _widthMultisizedBanner = null;
      _isWidthMultisizedBannerLoaded = false;
    });

    final width = MediaQuery.sizeOf(context).width;
    final padding = MediaQuery.paddingOf(context);
    final safeWidth = width - padding.left - padding.right;

    _widthMultisizedBanner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2435281174',
      auConfigId: '33994718',
      size: AdSize(height: 50, width: safeWidth.toInt()),
      isAdaptiveSize: true,
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        log('Ad size: ${ad.size.width} : ${ad.size.height}');
        setState(
          () {
            _widthMultisizedBanner = ad;
            _isWidthMultisizedBannerLoadFailed = false;
            _isWidthMultisizedBannerLoaded = true;
            _widthMultisizedBannerAdSize = ad.size;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isWidthMultisizedBannerLoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _widthMultisizedBanner?.load();
  }

  Future<void> _loadHeightMultisizedBannerAd() async {
    _heightMultisizedBanner?.dispose();

    setState(() {
      _heightMultisizedBanner = null;
      _isHeightMultisizedBannerLoaded = false;
    });

    final height = MediaQuery.sizeOf(context).height;
    final padding = MediaQuery.paddingOf(context);
    final safeHeight = height - padding.top - padding.bottom;

    _heightMultisizedBanner = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2435281174',
      auConfigId: '33994718',
      size: AdSize(height: safeHeight.toInt(), width: 320),
      isAdaptiveSize: true,
      onAdLoaded: (ad) async {
        log('Ad is loaded: ${ad.adUnitId}');
        log('Ad size: ${ad.size.width} : ${ad.size.height}');
        setState(
          () {
            _heightMultisizedBanner = ad;
            _isHeightMultisizedBannerLoadFailed = false;
            _isHeightMultisizedBannerLoaded = true;
            _heightMultisizedBannerAdSize = ad.size;
          },
        );
      },
      onAdFailedToLoad: (ad, error) {
        log('Banner failed to load: ${error?.message}');
        setState(() {
          _isHeightMultisizedBannerLoadFailed = true;
          ad.dispose();
        });
      },
      onAdClicked: (ad) => log('Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Ad impression: ${ad.adUnitId}'),
    );

    await _heightMultisizedBanner?.load();
  }

  Future<void> _loadBannerAds() async {
    _load320x50BannerAd();
    _load300x250BannerAd();
    _loadWidthMultisizedBannerAd();
    _loadHeightMultisizedBannerAd();
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

  Widget _getBannerMultisizeWidthWidget() {
    if (_widthMultisizedBanner != null &&
        _isWidthMultisizedBannerLoaded &&
        _widthMultisizedBannerAdSize != null) {
      return SizedBox(
        width: _widthMultisizedBannerAdSize?.width.toDouble(),
        height: _widthMultisizedBannerAdSize?.height.toDouble(),
        child: AdWidget(ad: _widthMultisizedBanner!),
      );
    }

    if (_isWidthMultisizedBannerLoadFailed) {
      return TextButton(
        onPressed: _loadWidthMultisizedBannerAd,
        child: Text('Retry'),
      );
    }

    return const SizedBox(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _getBannerMultisizeHeightWidget() {
    if (_heightMultisizedBanner != null &&
        _isHeightMultisizedBannerLoaded &&
        _heightMultisizedBannerAdSize != null) {
      return SizedBox(
        width: _heightMultisizedBannerAdSize?.width.toDouble(),
        height: _heightMultisizedBannerAdSize?.height.toDouble(),
        child: AdWidget(ad: _heightMultisizedBanner!),
      );
    }

    if (_isHeightMultisizedBannerLoadFailed) {
      return TextButton(
        onPressed: _loadHeightMultisizedBannerAd,
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
          _getBannerMultisizeWidthWidget(),
          const SizedBox(height: 40),
          _getBannerMultisizeHeightWidget(),
          const SizedBox(height: 40),
          _getBanner300x250Widget(),
          const SizedBox(height: 40),
          _getBanner320x50AdWidget(),
        ],
      ),
    );
  }
}
