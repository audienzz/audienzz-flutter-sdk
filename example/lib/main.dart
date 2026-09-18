import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
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
import 'package:audienzz_sdk_flutter_example/pages/article_in_content_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/overlay_detection_test.dart';
import 'package:audienzz_sdk_flutter_example/pages/scroll_render_test_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/test_screen_example.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late final Future<void> init;
  bool useRemoteConfiguration = true;


  // Reports pushed/returned routes automatically (see AudienzzNavigatorObserver).
  // The SDK's observer. It covers push, pop, replace and remove, reports
  // ad-free destinations (that is what releases the previous page's banners)
  // and agrees with AudienzzPage about page identity.
  final _navObserver = AudienzzNavigatorObserver();

  // Tab = screen. Each tab is reported as its own screen so switching tabs fires
  // a fresh page impression, and the incoming tab's ads reload immediately —
  // the Flutter analogue of the native screen-change reload.
  late final TabController _tabController;
  int _lastTab = 0;
  static const List<String> _tabKeys = [
    'Regular example',
    'List example',
    'Legacy (v0.0.10)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _initializeSdk();
  }

  void _initializeSdk() {
    init = initializeSdk();
  }

  /// Fires once per tab change: report the now-active tab as a screen (fresh page
  /// impression) and reload that tab's banner ads. A Flutter banner is a platform
  /// view that can't be re-auctioned in place, so we RECREATE the ad here — which
  /// blanks the slot (placeholder) during the reload and shows a fresh creative,
  /// matching the native screen-change reload. This is the recommended pattern for
  /// screens whose ads stay mounted (tabs); stack routes that unmount reload for
  /// free on remount.
  void _onTabChanged() {
    final i = _tabController.index;
    if (i == _lastTab) return;
    _lastTab = i;
    // Tabs live inside ONE Navigator route, so the RouteObserver can't see them —
    // report them explicitly by key. (Pushed pages are reported automatically.)
    AudienzzSdkFlutter.instance.pageImpression(name: _tabKeys[i]);
    // No manual reload. The page impression above is the whole transition:
    // native releases every banner that is not on the incoming page and
    // re-auctions the ones that are, and the widget remounts its platform view
    // when the native epoch changes. Reloading here as well gave one tab switch
    // two owners and two auctions, the second discarding the creative the first
    // had just fetched.
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Request App Tracking Transparency BEFORE initializing the ad SDK, so GMA
  /// has the consent/tracking state when it starts serving (consent-before-init).
  Future<void> _requestTrackingAuthorization() async {
    if (!Platform.isIOS) return;
    // ATT can only be presented once the app is active.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    log('ATT status: ${await AppTrackingTransparency.trackingAuthorizationStatus}');
  }

  Future<void> initializeSdk() async {
    await _requestTrackingAuthorization();

    // Report each ad-bearing route explicitly via pageImpression (see the ListTile onTap + the
    // 'home' report below).
    // Opt into smart-refresh v2 (directional viewport gate) instead of the legacy 20% gate,
    // and blank the slot during a screen-resume reload — parity with the native iOS/Android SDKs.
    // Both override backend config for the session; call before creating banners.
    await AudienzzSdkFlutter.instance.setSmartRefreshV2Enabled(true);
    await AudienzzSdkFlutter.instance.setBlankOnScreenReload(true);

    final InitializationStatus status;
    if (useRemoteConfiguration) {
      status = await AudienzzSdkFlutter.instance.initializeRemote(
        publisherId: '35',
        remoteUrl: 'https://api.adnz.co/api/ws-sdk-config/public/v1',
      );
    } else {
      status = await AudienzzSdkFlutter.instance.initialize(
        companyId: 'Company Id',
      );
    }

    log(status.toString());

    // The initial route is reported automatically by AudienzzNavigatorObserver
    // once the MaterialApp builds — no explicit pageImpression here.

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

    // Deliberately NOT creating the banner loaders here.
    //
    // RemoteBannerAdLoader loads in its constructor, and this runs before the
    // MaterialApp exists — so before AudienzzNavigatorObserver has reported the
    // initial route. An ad created before its page is reported carries no page,
    // and the next page impression sweeps it as belonging to somewhere else.
    // The ~100–400 ms this used to save is not worth a slot that can be
    // released the moment the reader navigates.
    //
    // They are created in _AdsHomeState.initState instead, which runs after the
    // Navigator has reported the route this page lives on.
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: init,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            // The observer auto-reports every named route pushed/returned below.
            navigatorObservers: [_navObserver],
            home: Scaffold(
              appBar: AppBar(
                title: TabBar(
                  controller: _tabController,
                  tabs: [
                    for (final key in _tabKeys) Tab(text: key),
                  ],
                ),
                actions: const [],
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  // No externally created loaders. Each RemoteBannerAdExample
                  // owns exactly one, created in its own initState — which runs
                  // after the Navigator has reported this route, so the ordering
                  // contract holds with a single owner per slot. Supplying a
                  // second owner after the first frame made one slot spend two
                  // requests and display only one of them.
                  AdsPages(useRemoteConfiguration: useRemoteConfiguration),
                  ListWithAdsExample(),
                  LegacyBannerAdExample(),
                ],
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
      onTap: () {
        // Name the route; AudienzzNavigatorObserver reports the screen on push and
        // reports the revealed screen again on return — no pageImpression call here.
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(name: title),
            builder: (ctx) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: pageBuilder(ctx),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

final class AdsPages extends StatelessWidget {
  const AdsPages({
    required this.useRemoteConfiguration,
    super.key,
  });

  final bool useRemoteConfiguration;

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
                child: Text('Remote Banner Ad (46)'),
              ),
              RemoteBannerAdExample(configId: '46'),

              loremIpsum(),

              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Banner Ad (48)'),
              ),
              RemoteBannerAdExample(configId: '48'),

              loremIpsum(),

              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Interstitial Ad (47)'),
              ),
              RemoteInterstitialAdExample(configId: '47'),

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
                title: 'Test Screen',
                subtitle: 'One banner on its own screen — for screen-tracking logs',
                pageBuilder: (_) => const TestScreenExample(),
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
              _NavigationTile(
                title: 'Article (in-content ads)',
                subtitle: '5 in-content banners in a long article — client layout',
                pageBuilder: (_) => const ArticleInContentExample(),
              ),
              _NavigationTile(
                title: 'Overlay Detection / Global Pause',
                subtitle: 'OverlayEntry cover + pauseAllAutoRefresh()',
                pageBuilder: (_) => const OverlayDetectionTestScreen(),
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
