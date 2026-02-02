import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

class RemoteInterstitialAdExample extends StatefulWidget {
  const RemoteInterstitialAdExample({
    required this.configId,
    super.key,
  });

  final String configId;

  @override
  State<RemoteInterstitialAdExample> createState() =>
      _RemoteInterstitialAdExampleState();
}

class _RemoteInterstitialAdExampleState
    extends State<RemoteInterstitialAdExample> {
  RemoteInterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    loadAd();
  }

  void loadAd() {
    _interstitialAd = RemoteInterstitialAd(
      configId: widget.configId,
      adFormat: AdFormat.banner,
      onAdLoaded: (ad) {
        setState(() {
          _isAdLoaded = true;
          _error = null;
        });
        print('Remote Interstitial Ad loaded');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _isAdLoaded = false;
          _error = error?.message;
        });
        print('Remote Interstitial Ad failed to load: $error');
        ad.dispose();
      },
      onAdClicked: (ad) => print('Remote Interstitial Ad clicked'),
      onAdOpened: (ad) => print('Remote Interstitial Ad opened'),
      onAdClosed: (ad) {
        print('Remote Interstitial Ad closed');
        ad.dispose();
        setState(() {
          _isAdLoaded = false;
        });
        loadAd();
      },
      onAdImpression: (ad) => print('Remote Interstitial Ad impression'),
    );

    _interstitialAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null) Text('Error: $_error'),
        ElevatedButton(
          onPressed: _isAdLoaded
              ? () {
                  _interstitialAd?.show();
                }
              : null,
          child: Text(_isAdLoaded
              ? 'Show Remote Interstitial Ad'
              : 'Loading Interstitial Ad...'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }
}
