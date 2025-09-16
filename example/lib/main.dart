import 'dart:async';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/pages/banner_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/interstitial_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/list_with_ads_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/rewarded_ad_example.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<void> init;

  @override
  void initState() {
    super.initState();
    init = initializeSdk();
  }

  Future<void> initializeSdk() async {
    final status = await AudienzzSdkFlutter.instance.initialize(
      companyId: 'Company Id',
    );

    log(status.toString());

    await AudienzzSdkFlutter.instance.setSchainObject("""{
    "source": {
    "schain": [
    {
    "asi": "audienzz.com",
    "sid": "812net",
    "hp": 1
    }
    ]
    }
    }""");

    await AudienzzTargeting.addSingleGlobalTargeting("TEST", "1");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: init,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  title: TabBar(
                    tabs: [
                      Tab(text: "Regular example"),
                      Tab(text: "List example"),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    AdsPages(),
                    ListWithAdsExample(),
                  ],
                ),
              ),
            ),
          );
        } else {
          return const MaterialApp(
            home: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}

final class AdsPages extends StatelessWidget {
  const AdsPages({super.key});

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;

    return Padding(
      padding: viewPadding,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Divider(),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Banner ads'),
              ),
              BannerAdExample(),
              Divider(),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Rewarded ad'),
              ),
              RewardedAdExample(),
              Divider(),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Interstitial ads'),
              ),
              InterstitialAdExample(),
              Divider(),
            ],
          ),
        ),
      ),
    );
  }
}
