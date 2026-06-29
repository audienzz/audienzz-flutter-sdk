import 'dart:async';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/pages/banner_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/interstitial_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/list_with_ads_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/ppid_usage_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/remote_banner_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/remote_interstitial_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/legacy_banner_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/rewarded_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/smart_refresh_banner_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/always_in_tree_banner_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/scroll_render_test_example.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<void> init;
  bool useRemoteConfiguration = true;

  RemoteBannerAdLoader? _loader118;
  RemoteBannerAdLoader? _loader192;

  @override
  void initState() {
    super.initState();
    _initializeSdk();
  }

  void _initializeSdk() {
    init = initializeSdk();
  }

  @override
  void dispose() {
    _loader118?.dispose();
    _loader192?.dispose();
    super.dispose();
  }

  Future<void> initializeSdk() async {
    final InitializationStatus status;
    if (useRemoteConfiguration) {
      status = await AudienzzSdkFlutter.instance.initializeRemote(
        publisherId: '81',
        isAutomaticPpidEnabled: true,
        remoteUrl: 'https://api.adnz.co/api/ws-sdk-config/public/v1',
      );
    } else {
      status = await AudienzzSdkFlutter.instance.initialize(
        companyId: 'Company Id',
        isAutomaticPpidEnabled: true,
      );
    }

    log(status.toString());

    await AudienzzSdkFlutter.instance.setSchainObject("""
                        { "source": 
                            { "schain": {
                                "ver": "1.0",
                                "complete": 1,
                                "nodes": [
                                    {
                                        "asi": "netpoint-media.de",
                                        "sid": "np-7255",
                                        "hp": 1
                                    }
                                  ]
                                }
                            } 
                        }
                    """);

    await AudienzzTargeting.addSingleGlobalTargeting("TEST", "1");

    // Start loading AFTER all global SDK config is set (schain + targeting must
    // be in place before fetchDemand constructs the OpenRTB request).
    // Starting here — before FutureBuilder resolves — saves the FutureBuilder
    // rebuild → widget mount → initState → loadAd() round-trip (~100–400 ms).
    if (useRemoteConfiguration) {
      _loader118 = RemoteBannerAdLoader(configId: '118');
      _loader192 = RemoteBannerAdLoader(configId: '192');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: init,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            home: DefaultTabController(
              length: 3,
              child: Scaffold(
                appBar: AppBar(
                  title: TabBar(
                    tabs: [
                      Tab(text: "Regular example"),
                      Tab(text: "List example"),
                      Tab(text: "Legacy (v0.0.10)"),
                    ],
                  ),
                  actions: const [],
                ),
                body: TabBarView(
                  children: [
                    AdsPages(
                      useRemoteConfiguration: useRemoteConfiguration,
                      loader118: _loader118,
                      loader192: _loader192,
                    ),
                    ListWithAdsExample(),
                    LegacyBannerAdExample(),
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

// ---------------------------------------------------------------------------
// Navigation helper
// ---------------------------------------------------------------------------

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.title,
    required this.subtitle,
    required this.pageBuilder,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder pageBuilder;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: pageBuilder(ctx),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

final class AdsPages extends StatelessWidget {
  const AdsPages({
    required this.useRemoteConfiguration,
    this.loader118,
    this.loader192,
    super.key,
  });

  final bool useRemoteConfiguration;
  final RemoteBannerAdLoader? loader118;
  final RemoteBannerAdLoader? loader192;

  @override
  Widget build(BuildContext context) {
    if (useRemoteConfiguration) {
      return _buildRemoteExamples(context);
    }
    return _buildRegularExamples(context);
  }

  Widget _buildRemoteExamples(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;

    Widget loremIpsum() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. '
            'Cras at ultricies ante. Ut nulla nunc, feugiat sed turpis ut, '
            'eleifend sodales ligula. Duis viverra congue magna, ac egestas '
            'risus facilisis ac. Aenean eget velit vitae libero malesuada '
            'luctus. Aliquam elementum dignissim viverra. Morbi a lacus dolor. '
            'Quisque sapien lorem, scelerisque vitae neque non, rutrum finibus '
            'turpis. Nunc maximus venenatis sollicitudin.'
            ' Phasellus id consectetur arcu, eget tincidunt turpis. '
            'Integer ac tincidunt erat. Aliquam pulvinar ligula massa, '
            'sit amet feugiat mi sodales a. Vestibulum posuere tempus quam, '
            'et convallis turpis interdum ut. In feugiat convallis felis, '
            'nec vulputate ipsum tempor et. Nam et dictum massa. '
            'Quisque at risus ullamcorper, volutpat lectus ac, luctus ex.'
            ' Nulla dignissim, ex at vehicula vestibulum, ante tellus '
            'lobortis eros, eget posuere odio lacus ut felis.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey),
      ),
    );

    return Padding(
      padding: viewPadding,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Banner Ad (Adaptive - 118)'),
              ),
              RemoteBannerAdExample(configId: '118', loader: loader118),

              loremIpsum(),

              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Banner Ad (Fixed - 192)'),
              ),
              RemoteBannerAdExample(configId: '192', loader: loader192),

              loremIpsum(),

              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Interstitial Ad (267)'),
              ),
              RemoteInterstitialAdExample(configId: '267'),

              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'Test Screens',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              _NavigationTile(
                title: 'Always-in-tree Banner Pattern',
                subtitle: 'AdWidget never gated behind onAdLoaded',
                pageBuilder: (_) => const AlwaysInTreeBannerExample(),
              ),
              _NavigationTile(
                title: 'Smart Refresh Banner',
                subtitle: 'Manual BannerAd with smartRefresh=true',
                pageBuilder: (_) => const SmartRefreshBannerExample(),
              ),
              _NavigationTile(
                title: 'Scroll-Render Race Condition Test',
                subtitle: 'Scroll while loading — tests doOnAttach fix',
                pageBuilder: (_) => const ScrollRenderTestExample(),
              ),

              const Divider(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildRegularExamples(BuildContext context) {
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
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('PPID usage'),
              ),
              PpidUsageExample(),
              Divider(),
            ],
          ),
        ),
      ),
    );
  }
}
