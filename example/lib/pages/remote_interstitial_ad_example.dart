import 'package:audienzz_sdk_flutter_example/pages/interstitial_ad_example.dart';
import 'package:flutter/material.dart';

class RemoteInterstitialAdExample extends StatelessWidget {
  const RemoteInterstitialAdExample({required this.configId, super.key});
  final String configId;

  @override
  Widget build(BuildContext context) =>
      InterstitialAdExample(configId: configId);
}
