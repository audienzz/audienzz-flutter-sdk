import 'dart:async';
import 'dart:developer';
import 'dart:math' show Random;

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

class InterstitialAdExample extends StatefulWidget {
  const InterstitialAdExample({super.key});

  @override
  State<InterstitialAdExample> createState() => _InterstitialAdExampleState();
}

class _InterstitialAdExampleState extends State<InterstitialAdExample> {
  InterstitialAd? _interstitialBannerAd;
  bool _isInterstitialBannerAdLoaded = false;
  bool _isInterstitialBannerAdLoadFailed = false;

  InterstitialAd? _interstitialVideoAd;
  bool _isInterstitialVideoAdLoaded = false;
  bool _isInterstitialVideoAdLoadFailed = false;

  InterstitialAd? _interstitialMultiformatAd;
  bool _isInterstitialMultiformatAdLoaded = false;
  bool _isInterstitialMultiformatAdLoadFailed = false;

  Orientation? _currentOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentOrientation = MediaQuery.orientationOf(context);
    unawaited(_loadAds());
  }

  Future<void> _loadInterstitialBannerAd() async {
    _interstitialBannerAd?.dispose();
    _isInterstitialBannerAdLoaded = false;
    _interstitialBannerAd = InterstitialAd(
      adFormat: AdFormat.banner,
      adUnitId: 'ca-app-pub-3940256099942544/4411468910',
      auConfigId: '34400101',
      sizes: {AdSize(height: 50, width: 320)},
      onAdLoaded: (ad) {
        log('Banner ${ad.adUnitId} loaded.');
        setState(() {
          _interstitialBannerAd = ad;
          _isInterstitialBannerAdLoadFailed = false;
          _isInterstitialBannerAdLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        log('InterstitialAd failed to load: ${error?.message}');
        setState(() {
          _interstitialBannerAd?.dispose();
          _interstitialBannerAd = null;
          _isInterstitialBannerAdLoadFailed = true;
          _isInterstitialBannerAdLoaded = false;
        });
      },
      onAdClicked: (ad) => log('Interstitial Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Interstitial Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Interstitial Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Interstitial Ad impression: ${ad.adUnitId}'),
    );

    await _interstitialBannerAd?.load();
  }

  Future<void> _loadInterstitialVideoAd() async {
    _interstitialVideoAd?.dispose();
    _isInterstitialVideoAdLoaded = false;
    _interstitialVideoAd = InterstitialAd(
      adFormat: AdFormat.video,
      adUnitId: 'ca-app-pub-3940256099942544/5135589807',
      auConfigId: '34400101',
      sizes: {AdSize(height: 50, width: 320)},
      onAdLoaded: (ad) {
        log('Video ${ad.adUnitId} loaded.');
        setState(() {
          _interstitialVideoAd = ad;
          _isInterstitialVideoAdLoadFailed = false;
          _isInterstitialVideoAdLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        log('InterstitialAd failed to load: ${error?.message}');
        setState(() {
          _interstitialVideoAd?.dispose();
          _interstitialVideoAd = null;
          _isInterstitialVideoAdLoadFailed = true;
          _isInterstitialVideoAdLoaded = false;
        });
      },
      onAdClicked: (ad) => log('Interstitial Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Interstitial Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Interstitial Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Interstitial Ad impression: ${ad.adUnitId}'),
    );

    await _interstitialVideoAd?.load();
  }

  Future<void> _loadInterstitialMultiformatAd() async {
    _interstitialMultiformatAd?.dispose();
    _isInterstitialMultiformatAdLoaded = false;
    _interstitialMultiformatAd = InterstitialAd(
      adFormat: AdFormat.bannerAndVideo,
      sizes: const {
        AdSize(height: 50, width: 319),
        AdSize(height: 250, width: 300)
      },
      adUnitId: Random().nextInt(2) == 0
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/5135589807',
      auConfigId: '34400101',
      onAdLoaded: (ad) {
        log('Multiformat ${ad.adUnitId} loaded.');
        setState(() {
          _interstitialMultiformatAd = ad;
          _isInterstitialMultiformatAdLoadFailed = false;
          _isInterstitialMultiformatAdLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        log('InterstitialAd failed to load: ${error?.message}');
        setState(() {
          _interstitialMultiformatAd?.dispose();
          _interstitialMultiformatAd = null;
          _isInterstitialMultiformatAdLoadFailed = true;
          _isInterstitialMultiformatAdLoaded = false;
        });
      },
      onAdClicked: (ad) => log('Interstitial Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Interstitial Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Interstitial Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Interstitial Ad impression: ${ad.adUnitId}'),
    );

    await _interstitialMultiformatAd?.load();
  }

  Future<void> _loadAds() async {
    await _loadInterstitialBannerAd();
    await _loadInterstitialVideoAd();
    await _loadInterstitialMultiformatAd();
  }

  void _showInterstitialBannerAd() {
    if (_interstitialBannerAd == null) {
      log('Warning: attempt to show interstitial banner ${_interstitialBannerAd?.adUnitId} before loaded.');
      return;
    }
    _interstitialBannerAd?.show();
    _interstitialBannerAd?.dispose();
    _loadInterstitialBannerAd();
  }

  void _showInterstitialVideoAd() {
    if (_interstitialVideoAd == null) {
      log('Warning: attempt to show interstitial video ${_interstitialVideoAd?.adUnitId}  before loaded.');
      return;
    }
    _interstitialVideoAd?.show();
    _interstitialVideoAd?.dispose();
    _loadInterstitialVideoAd();
  }

  void _showInterstitialMultiformatAd() {
    if (_interstitialMultiformatAd == null) {
      log('Warning: attempt to show interstitial multiformat ${_interstitialMultiformatAd?.adUnitId} before loaded.');
      return;
    }
    _interstitialMultiformatAd?.show();
    _interstitialMultiformatAd?.dispose();
    _loadInterstitialMultiformatAd();
  }

  @override
  void dispose() {
    _interstitialBannerAd?.dispose();
    _interstitialVideoAd?.dispose();
    _interstitialMultiformatAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (_, orientation) {
        if (_currentOrientation != orientation) {
          _currentOrientation = orientation;
          _loadAds();
        }

        return Center(
          child: Column(
            children: [
              if (_isInterstitialBannerAdLoadFailed)
                TextButton(
                  onPressed: _loadInterstitialBannerAd,
                  child: Text('Retry'),
                )
              else
                TextButton(
                  onPressed: _isInterstitialBannerAdLoaded
                      ? _showInterstitialBannerAd
                      : null,
                  child: _isInterstitialBannerAdLoaded
                      ? const Text('Show interstitial banner ad')
                      : const CircularProgressIndicator(),
                ),
              if (_isInterstitialVideoAdLoadFailed)
                TextButton(
                  onPressed: _loadInterstitialVideoAd,
                  child: Text('Retry'),
                )
              else
                TextButton(
                  onPressed: _isInterstitialVideoAdLoaded
                      ? _showInterstitialVideoAd
                      : null,
                  child: _isInterstitialVideoAdLoaded
                      ? const Text('Show interstitial video ad')
                      : const CircularProgressIndicator(),
                ),
              if (_isInterstitialMultiformatAdLoadFailed)
                TextButton(
                  onPressed: _loadInterstitialMultiformatAd,
                  child: Text('Retry'),
                )
              else
                TextButton(
                  onPressed: _isInterstitialMultiformatAdLoaded
                      ? _showInterstitialMultiformatAd
                      : null,
                  child: _isInterstitialMultiformatAdLoaded
                      ? const Text('Show interstitial multiformat ad')
                      : const CircularProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }
}
