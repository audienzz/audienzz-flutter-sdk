import 'dart:async';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

class RewardedAdExample extends StatefulWidget {
  const RewardedAdExample({super.key});

  @override
  State<RewardedAdExample> createState() => _RewardAdExampleState();
}

class _RewardAdExampleState extends State<RewardedAdExample> {
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoadFailed = false;
  bool _isRewardedAdLoaded = false;

  Orientation? _currentOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentOrientation = MediaQuery.orientationOf(context);
    unawaited(_loadRewardedAd());
  }

  Future<void> _loadRewardedAd() async {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdLoaded = false;
    _rewardedAd = RewardedAd(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      auConfigId: '34400101',
      onAdClicked: (ad) => log('Rewarded Ad clicked: ${ad.adUnitId}'),
      onAdOpened: (ad) => log('Rewarded Ad opened: ${ad.adUnitId}'),
      onAdClosed: (ad) => log('Rewarded Ad closed: ${ad.adUnitId}'),
      onAdImpression: (ad) => log('Rewarded Ad impression: ${ad.adUnitId}'),
      onAdLoaded: (ad) {
        log('Rewarded ad ${ad.adUnitId} loaded.');
        setState(() {
          _rewardedAd = ad;
          _isRewardedAdLoadFailed = false;
          _isRewardedAdLoaded = true;
        });
      },
      onAdFailedToLoad: (ad, error) {
        log('RewardedAd failed to load: ${error?.message}');
        setState(() {
          _rewardedAd?.dispose();
          _rewardedAd = null;
          _isRewardedAdLoadFailed = true;
        });
      },
      onUserEarnedRewardCallback: (_, reward) {
        log('Earned reward: ${reward.type} : ${reward.amount}');
      },
    );

    await _rewardedAd?.load();
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) {
      log('Warning: attempt to show rewarded before loaded.');
      return;
    }
    _rewardedAd?.show();
    _rewardedAd = null;
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (_, orientation) {
        if (_currentOrientation != orientation) {
          _currentOrientation = orientation;
          _loadRewardedAd();
        }

        return Center(
          child: _isRewardedAdLoadFailed
              ? TextButton(
                  onPressed: _loadRewardedAd,
                  child: Text('Retry'),
                )
              : TextButton(
                  onPressed: _isRewardedAdLoaded ? _showRewardedAd : null,
                  child: _isRewardedAdLoaded
                      ? const Text('Show rewarded ad')
                      : const CircularProgressIndicator(),
                ),
        );
      },
    );
  }
}
