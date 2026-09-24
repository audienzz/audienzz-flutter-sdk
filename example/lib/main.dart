import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/pages/banner_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/interstitial_ad_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/list_with_ads_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/managed_banner_example.dart';
import 'package:audienzz_sdk_flutter_example/pages/managed_flows_example.dart';
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

  /// Rebuild so each tab's [AudienzzPage] sees its new `active` value.
  ///
  /// Reporting the tab from here as well would be a second reporter for one
  /// transition. Tabs live inside ONE Navigator route, so the observer cannot
  /// tell them apart — that is exactly what the per-tab [AudienzzPage] wrappers
  /// below are for. Mixing the two (observer route instances for pushed pages,
  /// a name-only `pageImpression` for tabs) meant a banner created for the
  /// initial route was never reassigned to the tab key reported on return.
  void _onTabChanged() {
    final i = _tabController.index;
    if (i == _lastTab) return;
    AudienzzDiagnostics.logAppAction('selectTab', {'tab': _tabKeys[i]});
    setState(() => _lastTab = i);
  }

  Widget _tabBody(int index) {
    switch (index) {
      case 0:
        return AdsPages(useRemoteConfiguration: useRemoteConfiguration);
      case 1:
        return const ListWithAdsExample();
      default:
        return const LegacyBannerAdExample();
    }
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
    // One greppable AUDZ line per slot decision, on the Dart side and in both native SDKs.
    // Capture with `flutter logs` and grep AUDZ. On by default HERE because this app exists to
    // be tested and have its log read back; in a real app it is off unless you ask for it.
    await AudienzzSdkFlutter.instance.setDiagnosticsEnabled(true);
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
                  // One page per tab, and only the selected one is active. Two
                  // retained tabs are two screens: without this they would share
                  // the enclosing route's identity, so switching tabs left every
                  // banner belonging to a screen nobody was looking at.
                  for (var i = 0; i < _tabKeys.length; i++)
                    AudienzzPage(
                      name: _tabKeys[i],
                      active: _tabController.index == i,
                      child: _tabBody(i),
                    ),
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
    this.bare = false,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder pageBuilder;

  /// The destination brings its own Scaffold; do not wrap it in another one.
  final bool bare;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        AudienzzDiagnostics.logAppAction('navigate', {'to': title});
        // Name the route; AudienzzNavigatorObserver reports the screen on push and
        // reports the revealed screen again on return — no pageImpression call here.
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(name: title),
            builder: (ctx) => bare
                ? pageBuilder(ctx)
                : Scaffold(
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

    // One under every ad slot, matching the native examples: the screen-navigation test is about
    // what happens to THAT banner when you leave and come back, so the button has to be reachable
    // while the slot it concerns is on screen. Which one you tapped is printed, because four
    // identical buttons would otherwise make a captured log ambiguous.
    Widget openTestScreen(BuildContext context, String from) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ElevatedButton(
            onPressed: () {
              debugPrint('[Example] opening test screen ($from)');
              Navigator.of(context).push(TestScreenExample.route());
            },
            child: Text('Open test screen ($from)'),
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
              openTestScreen(context, 'from banner 46'),

              loremIpsum(),

              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Remote Banner Ad (48)'),
              ),
              RemoteBannerAdExample(configId: '48'),
              openTestScreen(context, 'from banner 48'),

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
                title: 'Managed Banner (recommended)',
                subtitle: 'AudienzzPage + AudienzzBanner — no loader, no reload, no disposal',
                pageBuilder: (_) => const ManagedBannerExample(configId: '46'),
                bare: true,
              ),
              _NavigationTile(
                title: 'Managed test flows',
                subtitle: 'A→B→A, repeated articles, delayed content, retained tabs, cover',
                pageBuilder: (_) => const ManagedFlowsExample(configId: '46'),
                bare: true,
              ),
              _NavigationTile(
                title: 'Ad-free destination',
                subtitle: 'Page A → ad-free B → A: leaving releases, returning recreates',
                pageBuilder: (_) => const AdFreeExample(),
                bare: true,
              ),
              _NavigationTile(
                title: 'Test Screen',
                subtitle: 'One banner on its own screen — for screen-tracking logs',
                pageBuilder: (_) => const TestScreenExample(),
                bare: true,
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
