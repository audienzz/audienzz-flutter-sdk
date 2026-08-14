Audienzz SDK Flutter
========

## Overview

A mobile advertising SDK that combines header bidding capabilities from Prebid Mobile with Google's advertising ecosystem through a unified interface.
The implementation includes lazy loading functionality to optimize application performance by deferring ad initialization until needed.

## Underlying Technologies

### Prebid Mobile SDK

Prebid Mobile is an open-source framework that enables header bidding within mobile applications.
It conducts real-time auctions where multiple demand sources compete for ad inventory placement.

Functionality:

- Real-time auction management between demand partners
- Communication with Prebid Server for bid processing
- Support for banner, native, and video ad formats
- Ad rendering from winning auction results

### Google Ads SDK (Google Mobile Ads SDK)

The Google Mobile Ads SDK provides access to Google's advertising networks including AdMob and Google
Ad Manager. It handles ad serving and mediation across multiple ad networks.

Functionality:

- Banner, interstitial, native, and rewarded video ad formats
- Network mediation through Google's platform
- Performance analytics and reporting
- Privacy compliance features

## Minimum Supported Versions

The Audienzz Flutter SDK requires a minimum iOS version of **13.0** or higher and a minimum android version of **API 24 (Android 7.0, Nougat)** or higher.

Installation
-------

In your terminal run command:
```
flutter pub add audienzz_sdk_flutter
```

OR add directly to pubspec.yaml
```yaml
    audienzz_sdk_flutter: latest
```

and run command:
```
flutter pub get
```

Setup Android
-------

Add your AdMob app ID, to your app's `AndroidManifest.xml` file.
To do so, add a <meta-data> tag with android:name="com.google.android.gms.ads.APPLICATION_ID".
You can find your app ID in the AdMob web interface.
For android:value, insert your own AdMob app ID, surrounded by quotation marks.

```xml
<manifest>
  <application>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>
  </application>
</manifest>
```

Setup IOS
-------

Update your app's `Info.plist` file with your AdMob app ID:

```
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

Consent
-------
The SDK does **not** gate itself on user consent — that's the app's responsibility.
Run your CMP (consent) flow and forward the result **before** you initialize the SDK
or load any ads:

1. Show your CMP and obtain the user's choice.
2. Forward the signals via `AudienzzTargeting` — `setSubjectToGDPR(...)`,
   `setGdprConsentString(...)`, `setPurposeConsents(...)`.
3. **Then** call `initialize(...)` / `initializeRemote(...)` and load ads.

Initializing or loading ads before consent will request ads without the consent
signals.

Initialize SDK
-------
First of all, SDK needs to be initialized. It's done asynchronously, so after callback
is triggered with `InitializationStatus.success`, SDK is ready to be used.

```dart
 final status = await AudienzzSdkFlutter.instance.initialize(companyId: 'CompanyID', isAutomaticPpidEnabled: false);

 if (status == InitializationStatus.success) {
   // SDK is ready to be used
 }
```
CompanyId is provided by Audienzz, usually - it is id of the company in ad console.
Automatic PPID (Publisher Provided Identifier for Google Ad Manager) usage could be specified at initialization or though PpidManager class.

The Audienzz SDK Flutter allows you to display three types Ads - `BannerAd`, `InterstitialAd` and `RewardedAd`.

Lazy Loading
-------
Lazy loading defers the ad request until the `BannerAd` widget is actually visible on screen, saving resources for ads that may never be seen.

Enable by setting `isLazyLoad: true` (the default):

```dart
final banner = BannerAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  sizes: {const AdSize(width: 320, height: 50)},
  isLazyLoad: true,       // ad loads only when the widget scrolls into view
  prefetchMargin: 200,    // start fetching 200 logical pixels before the view appears (default)
  onAdLoaded: (_) {},
  onAdFailedToLoad: (_, __) {},
)..load();
```

> **Note:** `prefetchMargin` has no practical effect inside `ListView` / `GridView` because those widgets create items just before they appear on screen. Use `isLazyLoad: false` there instead and let the list handle its own item prefetch.

Smart Refresh
-------
Smart Refresh makes banner auto-refresh viewport-aware: auto-refresh is **paused** while less than 20 % of the ad height is visible on screen, and **resumes** intelligently when the ad scrolls back into view.

#### Visibility detection

The SDK polls the ad's position every 500 ms using Flutter's `RenderBox.localToGlobal()` — Flutter's own layout coordinate system, not the native platform's. This means the 20 % rule is enforced correctly on both platforms regardless of how the ad is embedded:

- **iOS** — UIKit already moves its views during scroll, but the polling approach keeps parity with the Android implementation and avoids UIScrollView ancestor look-ups.
- **Android** — Flutter does not physically move the embedded `AdManagerAdView` when a `ListView` or `SingleChildScrollView` scrolls (it applies compositor-level clipping instead). Native visibility APIs (`getGlobalVisibleRect`, `getLocationOnScreen`) therefore always report the view's original position. The Flutter coordinate-space polling works around this limitation entirely. No `ScrollController` needs to be wired up by the caller.

#### Stale-aware resume

When the ad scrolls back into view the SDK checks how long it was off-screen:

| State | Action |
|---|---|
| **Stale** — hidden ≥ refresh interval | Fetches new demand immediately, then resumes normal auto-refresh. |
| **Fresh** — hidden < refresh interval | Waits the remaining interval, then fetches and resumes auto-refresh. |

This means the refresh cycle is never reset to zero when the ad returns — it continues from where it left off.

#### Usage

Enable by setting `smartRefresh: true` alongside a `refreshTimeInterval`:

```dart
final banner = BannerAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  sizes: {const AdSize(width: 320, height: 50)},
  refreshTimeInterval: 30000, // 30-second refresh cycle
  isLazyLoad: true,
  smartRefresh: true,
  onAdLoaded: (_) {},
  onAdFailedToLoad: (_, __) {},
)..load();
```

> **Note:** `smartRefresh` has no effect without `refreshTimeInterval` set.
>
> **`RemoteBannerAd`** always has `smartRefresh` enabled — it is unconditionally set to `true` from remote configuration and cannot be disabled per-instance.

#### Manual pause / resume

The visibility layer auto-pauses refresh for scroll position, `Navigator` routes and app backgrounding. It **cannot** detect a same-route cover — an `OverlayEntry`, a modal barrier, a custom widget stacked on top — because Flutter exposes no occlusion signal for platform views. When you show such an overlay, pause refresh yourself and resume it when the overlay is dismissed. Both APIs take effect on Android and iOS.

Pause / resume a **specific** banner via its `BannerAd` instance:

```dart
banner.pauseAutoRefresh();  // e.g. an overlay now covers this ad
banner.resumeAutoRefresh(); // overlay dismissed
```

Pause / resume **every** loaded banner at once via the SDK singleton — handy for a full-screen overlay that covers all ads:

```dart
await AudienzzSdkFlutter.instance.pauseAllAutoRefresh();
await AudienzzSdkFlutter.instance.resumeAllAutoRefresh();
```

Resume is stale-aware: it keeps the existing refresh cycle rather than restarting the interval from zero.

> **Note:** These methods act on banner auto-refresh only, and require the banner to have been loaded with a `refreshTimeInterval`. They work whether or not `smartRefresh` is enabled.

Examples
========
You can find examples of practical implementation here:

[Examples](example/lib/pages)

Quick Start
===========

Minimal initialization and first ad load.

```dart
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await AudienzzSdkFlutter.instance
      .initialize(companyId: 'YOUR_COMPANY_ID');
  runApp(MyApp(initialized: status == InitializationStatus.success));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.initialized});
  final bool initialized;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      adUnitId: 'YOUR_AD_UNIT_ID',
      auConfigId: 'YOUR_AU_CONFIG_ID',
      sizes: {const AdSize(width: 320, height: 50)},
      onAdLoaded: (_) => debugPrint('Banner loaded'),
      onAdFailedToLoad: (_, error) => debugPrint('Banner load failed: ${error?.message}'),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Audienzz Quick Start')),
        body: widget.initialized && _banner != null
            ? Center(child: AdWidget(ad: _banner!))
            : const Center(child: Text('SDK not initialized')),
      ),
    );
  }
}
```

Interstitial minimal usage
--------------------------
```dart
final interstitial = InterstitialAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  adFormat: AdFormat.bannerAndVideo,
  onAdLoaded: (_) => debugPrint('Interstitial loaded'),
  onAdFailedToLoad: (_, error) => debugPrint('Interstitial fail: ${error?.message}'),
  onAdClosed: (ad) async {
    await ad.dispose();
  },
);
await interstitial.load();
await interstitial.show();
```

Rewarded minimal usage
----------------------
```dart
final rewarded = RewardedAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  onAdLoaded: (_) => debugPrint('Rewarded loaded'),
  onAdFailedToLoad: (_, error) => debugPrint('Rewarded fail: ${error?.message}'),
  onUserEarnedRewardCallback: (_, reward) {
    debugPrint('User rewarded: ${reward.amount} ${reward.type}');
  },
  onAdClosed: (ad) async {
    await ad.dispose();
  },
);
await rewarded.load();
await rewarded.show();
```

Remote Configuration Integration
=================================

The SDK supports a simplified integration using remote configuration. This allows you to manage ad units (GAM IDs, Prebid Config IDs, sizes, etc.) from the backend, requiring only a simple configuration ID in your app.

## Initialize SDK with Remote Configuration

Before using remote configuration ads, ensure the SDK is properly initialized:

```dart
final status = await AudienzzSdkFlutter.instance.initializeRemote(
  publisherId: 'YOUR_PUBLISHER_ID', // Will be provided for you
  remoteUrl: 'https://api.adnz.co/api/ws-sdk-config/public/v1/', // Audienzz remote config URL
  isAutomaticPpidEnabled: false
);

if (status == InitializationStatus.success) {
  // SDK is ready to use with remote config
}
```

## Banner Ad (Remote Config)

Use `RemoteBannerAd` to load a banner defined by a remote configuration ID.

```dart
// 1. Create the remote banner ad with the configuration ID
final remoteBanner = RemoteBannerAd(
  configId: 'YOUR_CONFIG_ID',
  onAdLoaded: (ad) {
    debugPrint('Remote banner loaded successfully');
  },
  onAdFailedToLoad: (ad, error) {
    debugPrint('Remote banner failed to load: ${error?.message}');
  },
  onAdClicked: (ad) {
    debugPrint('Remote banner clicked');
  },
  onAdClosed: (ad) {
    debugPrint('Remote banner closed');
  },
);

// 2. Load the ad
await remoteBanner.load();

#### Fixed Size Banner
The SDK will use the sizes defined in the remote configuration. To ensure the banner is displayed correctly, you should place the `AdWidget` inside a container (like a `SizedBox`) that matches the intended ad size:

```dart
Center(
  child: SizedBox(
    width: 320,
    height: 50,
    child: AdWidget(ad: remoteBanner),
  ),
)
```

#### Adaptive Banner
If adaptive banners are enabled in the backend for your configuration ID, the SDK will automatically calculate the optimal height. You should ensure the `AdWidget` has enough horizontal space to calculate the adaptive size correctly:

```dart
Center(
  child: AdWidget(ad: remoteBanner),
)
```

// 3. Display the ad using AdWidget
@override
Widget build(BuildContext context) {
  return Center(
    child: AdWidget(ad: remoteBanner),
  );
}

// 4. Dispose when done
@override
void dispose() {
  remoteBanner.dispose();
  super.dispose();
}
```

## Interstitial Ad (Remote Config)

Use `RemoteInterstitialAd` to load an interstitial defined by a remote configuration ID.

```dart
// 1. Create the remote interstitial ad with the configuration ID
final remoteInterstitial = RemoteInterstitialAd(
  configId: 'YOUR_CONFIG_ID',
  onAdLoaded: (ad) {
    debugPrint('Remote interstitial loaded successfully');
  },
  onAdFailedToLoad: (ad, error) {
    debugPrint('Remote interstitial failed to load: ${error?.message}');
  },
  onAdClosed: (ad) async {
    debugPrint('Remote interstitial closed');
    await ad.dispose();
  },
);

// 2. Load the ad
await remoteInterstitial.load();

// 3. Show the ad when ready
await remoteInterstitial.show();
```

Targeting basics
================

Set per-user data (keywords, location, privacy) and global targeting.

User keywords
-------------
```dart
await AudienzzTargeting.addUserKeywords(['sports', 'travel']);
await AudienzzTargeting.addUserKeyword('gaming');
final all = await AudienzzTargeting.getKeywordSet();
await AudienzzTargeting.removeUserKeyword('travel');
await AudienzzTargeting.clearUserKeywords();
```

User location
-------------
```dart
await AudienzzTargeting.setUserLatLng(47.3769, 8.5417); // Zurich
final loc = await AudienzzTargeting.getUserLatLng();
```

GDPR / COPPA
------------
```dart
await AudienzzTargeting.setSubjectToGDPR(isSubject: true);
await AudienzzTargeting.setGdprConsentString('COabcd...');
await AudienzzTargeting.setPurposeConsents('111000');
await AudienzzTargeting.setSubjectToCOPPA(isSubject: false);
```

External User IDs (EIDs)
------------------------
```dart
await AudienzzTargeting.setExternalUserIds([
  ExternalUserId(
    source: 'adserver.org',
    uniqueIds: [UniqueId(id: 'user-123', atype: 1)],
  ),
]);
final eids = await AudienzzTargeting.getExternalUserIds();
```

Global targeting and ext data
-----------------------------
```dart
// Global key -> single value
await AudienzzTargeting.addSingleGlobalTargeting('section', 'home');

// Global key -> multiple values
await AudienzzTargeting.addGlobalTargeting('interests', {'tech', 'finance'});

// Remove / Clear
await AudienzzTargeting.removeGlobalTargeting('section');
await AudienzzTargeting.clearGlobalTargeting();

// Ext data
await AudienzzTargeting.addExtData('category', 'news');
await AudienzzTargeting.updateExtData('tags', ['flutter', 'ads']);
await AudienzzTargeting.removeExtData('category');
await AudienzzTargeting.clearExtData();
```

Global OpenRTB config
---------------------
```dart
await AudienzzTargeting.setGlobalOrtbConfig({
  'regs': {
    'coppa': 0,
  },
  'user': {
    'yob': 1990,
  },
});
final ortb = await AudienzzTargeting.getGlobalOrtbConfig();
```

Passing placement identifiers on ads
------------------------------------
```dart
final banner = BannerAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  sizes: {const AdSize(width: 320, height: 50)},
  pbAdSlot: '/1234/home/top_banner',
  gpId: 'gpid-abc-123',
  impOrtbConfig: '{"ext":{"example":"value"}}', // custom ORTB at imp-level
  onAdLoaded: (_) {},
  onAdFailedToLoad: (_, __) {},
)..load();
```

PpidManager 
------------------------------------
| Method                    | Parameters                        | Description                                                                                                                              |
|---------------------------|-----------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `isAutomaticPpidEnabled`  |                                   | Used to get current status of automatic PPID usage (if true - PPID is generated and used with all requests, if false - PPID is not used) |
| `setAutomaticPpidEnabled` | `isAutomaticPpidEnabled: Boolean` | Used to enable or disable automatic PPID usage                                                                                           |
| `getPpid`                 |                                   | Used to obtain current PPID if automaticPpid is enabled                                                                                  |

API Reference
=============

## SDK Initialization

| Method                                   | Parameters                                                         | Description                                                                                                                                    |
|------------------------------------------|--------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `AudienzzSdkFlutter.instance.initialize` | `{required String companyId, bool isAutomaticPpidEnabled = false}` | Initializes the SDK. Automatic Ppid could be enabled or disabled. Returns `InitializationStatus`. Must be called before using any ad features. |

## Ad Base Classes

### Ad
| Property/Method | Type           | Description                                |
|-----------------|----------------|--------------------------------------------|
| `adUnitId`      | `String`       | Unique identifier for your ad placement.   |
| `auConfigId`    | `String`       | ID of the stored impression on the server. |
| `dispose()`     | `Future<void>` | Frees resources used for the ad.           |

### AdWithView (extends Ad)
| Property/Method | Type           | Description                                           |
|-----------------|----------------|-------------------------------------------------------|
| `load()`        | `Future<void>` | Loads the ad. Used for ads that are shown as widgets. |

### AdWithoutView (extends Ad)
| Property/Method          | Type | Description                                     |
|--------------------------|------|-------------------------------------------------|
| *(inherits all from Ad)* |      | Used for ads that do not require a widget view. |

## BannerAd (extends AdWithView)
| Property/Method       | Type                                         | Description                                                             |
|-----------------------|----------------------------------------------|-------------------------------------------------------------------------|
| `sizes`               | `Set<AdSize>`                                | Required. Ad sizes for the bid request. At least one required.          |
| `isAdaptiveSize`      | `bool`                                       | If true, ad size is adaptive. Default: false.                           |
| `refreshTimeInterval` | `int?`                                       | Refresh time in milliseconds. Optional.                                 |
| `isLazyLoad`          | `bool`                                       | If true, defers ad loading until the view is visible. Requires `smartRefresh: true` (coerced off otherwise). Default: `false`. |
| `prefetchMargin`      | `int`                                        | Logical pixels before the view enters the viewport at which the demand fetch begins. Maps to `prefetchMarginPoints` on iOS and `prefetchMarginDp` on Android. Has no practical effect inside `ListView`/`GridView`. Default: `200`. |
| `smartRefresh`        | `bool`                                       | If true, pauses auto-refresh when < 20 % of the ad height is visible and resumes — with stale-aware timing — when it returns. Requires `refreshTimeInterval`. Default: `false`. |
| `adFormat`            | `AdFormat`                                   | Desired ad format (banner, video, or both). Default: `AdFormat.banner`. |
| `apiParameters`       | `Set<ApiParameter>`                          | API frameworks for bid response. Default: `{mraid3, omid1}`.            |
| `protocols`           | `Set<Protocol>`                              | Supported video protocols. Optional.                                    |
| `placement`           | `Placement`                                  | Placement type. Default: `Placement.inBanner`.                          |
| `playbackMethods`     | `Set<PlaybackMethod>`                        | Video playback methods. Default: `{autoPlaySoundOn}`.                   |
| `videoBitrate`        | `VideoBitrate`                               | Video bitrate range. Default: `min: 300, max: 1500`.                    |
| `videoDuration`       | `VideoDuration`                              | Video duration range. Default: `min: 1, max: 30`.                       |
| `pbAdSlot`            | `String?`                                    | PB Ad Slot identifier. Optional.                                        |
| `gpId`                | `String?`                                    | Global Placement ID. Optional.                                          |
| `impOrtbConfig`       | `String?`                                    | Custom ORTB object for impression. Optional.                            |
| `onAdLoaded`          | `void Function(BannerAd ad)`                 | Callback when ad is loaded.                                             |
| `onAdFailedToLoad`    | `void Function(BannerAd ad, AdError? error)` | Callback when ad fails to load.                                         |
| `onAdOpened`          | `void Function(BannerAd ad)?`                | Callback when ad overlay opens.                                         |
| `onAdClosed`          | `void Function(BannerAd ad)?`                | Callback when user returns to app.                                      |
| `onAdClicked`         | `void Function(BannerAd ad)?`                | Callback when ad is clicked.                                            |
| `onAdImpression`      | `void Function(BannerAd ad)?`                | Callback when ad is visible for 1s.                                     |
| `getPlatformAdSize()` | `Future<AdSize?>`                            | Gets the ad size assigned on the platform.                              |
| `load()`              | `Future<void>`                               | Loads the ad.                                                           |
| `pauseAutoRefresh()`  | `Future<void>`                               | Pauses auto-refresh for this banner (e.g. when an overlay covers it). Requires `refreshTimeInterval`. |
| `resumeAutoRefresh()` | `Future<void>`                               | Resumes auto-refresh for this banner, with stale-aware timing.          |

## InterstitialAd (extends AdWithoutView)
| Property/Method     | Type                                               | Description                                                   |
|---------------------|----------------------------------------------------|---------------------------------------------------------------|
| `adFormat`          | `AdFormat`                                         | Required. Desired ad format.                                  |
| `minSizePercentage` | `MinSizePercentage`                                | Minimum ad size in percent. Default: `width: 80, height: 60`. |
| `sizes`             | `Set<AdSize>`                                      | Ad sizes for the bid request. Optional.                       |
| `apiParameters`     | `Set<ApiParameter>`                                | API frameworks for bid response. Default: `{mraid3, omid1}`.  |
| `protocols`         | `Set<Protocol>`                                    | Supported video protocols. Optional.                          |
| `placement`         | `Placement`                                        | Placement type. Default: `Placement.inBanner`.                |
| `playbackMethods`   | `Set<PlaybackMethod>`                              | Video playback methods. Default: `{enterSoundOff}`.           |
| `videoBitrate`      | `VideoBitrate`                                     | Video bitrate range. Default: `min: 300, max: 1500`.          |
| `videoDuration`     | `VideoDuration`                                    | Video duration range. Default: `min: 1, max: 30`.             |
| `pbAdSlot`          | `String?`                                          | PB Ad Slot identifier. Optional.                              |
| `gpId`              | `String?`                                          | Global Placement ID. Optional.                                |
| `impOrtbConfig`     | `String?`                                          | Custom ORTB object for impression. Optional.                  |
| `onAdLoaded`        | `void Function(InterstitialAd ad)`                 | Callback when ad is loaded.                                   |
| `onAdFailedToLoad`  | `void Function(InterstitialAd ad, AdError? error)` | Callback when ad fails to load.                               |
| `onAdOpened`        | `void Function(InterstitialAd ad)?`                | Callback when ad overlay opens.                               |
| `onAdClosed`        | `void Function(InterstitialAd ad)?`                | Callback when user returns to app.                            |
| `onAdClicked`       | `void Function(InterstitialAd ad)?`                | Callback when ad is clicked.                                  |
| `onAdImpression`    | `void Function(InterstitialAd ad)?`                | Callback when ad is visible for 1s.                           |
| `load()`            | `Future<void>`                                     | Loads the ad.                                                 |
| `show()`            | `Future<void>`                                     | Shows the ad (must be loaded first).                          |

## RewardedAd (extends AdWithoutView)
| Property/Method              | Type                                              | Description                                                  |
|------------------------------|---------------------------------------------------|--------------------------------------------------------------|
| `apiParameters`              | `Set<ApiParameter>`                               | API frameworks for bid response. Default: `{mraid3, omid1}`. |
| `protocols`                  | `Set<Protocol>`                                   | Supported video protocols. Optional.                         |
| `placement`                  | `Placement`                                       | Placement type. Default: `Placement.inBanner`.               |
| `playbackMethods`            | `Set<PlaybackMethod>`                             | Video playback methods. Default: `{enterSoundOff}`.          |
| `videoBitrate`               | `VideoBitrate`                                    | Video bitrate range. Default: `min: 300, max: 1500`.         |
| `videoDuration`              | `VideoDuration`                                   | Video duration range. Default: `min: 1, max: 30`.            |
| `pbAdSlot`                   | `String?`                                         | PB Ad Slot identifier. Optional.                             |
| `gpId`                       | `String?`                                         | Global Placement ID. Optional.                               |
| `impOrtbConfig`              | `String?`                                         | Custom ORTB object for impression. Optional.                 |
| `onAdLoaded`                 | `void Function(RewardedAd ad)`                    | Callback when ad is loaded.                                  |
| `onAdFailedToLoad`           | `void Function(RewardedAd ad, AdError? error)`    | Callback when ad fails to load.                              |
| `onAdOpened`                 | `void Function(RewardedAd ad)?`                   | Callback when ad overlay opens.                              |
| `onAdClosed`                 | `void Function(RewardedAd ad)?`                   | Callback when user returns to app.                           |
| `onAdClicked`                | `void Function(RewardedAd ad)?`                   | Callback when ad is clicked.                                 |
| `onAdImpression`             | `void Function(RewardedAd ad)?`                   | Callback when ad is visible for 1s.                          |
| `onUserEarnedRewardCallback` | `void Function(RewardedAd ad, RewardItem reward)` | Callback when user earns a reward.                           |
| `load()`                     | `Future<void>`                                    | Loads the ad.                                                |
| `show()`                     | `Future<void>`                                    | Shows the ad (must be loaded first).                         |

## AdWidget
| Property/Method | Type         | Description                                            |
|-----------------|--------------|--------------------------------------------------------|
| `ad`            | `AdWithView` | The ad instance to display. Must be loaded before use. |

## AudienzzStickyAdWrapper
Wraps any `AdWidget` and keeps the ad "sticky" inside a reserved area. This is useful when creatives vary in size (e.g., 320x50 up to 300x600) and you want a stable layout with improved viewability.

**Key ideas**
- The wrapper always reserves `maxHeight` in the layout, preventing layout jumps.
- The ad sticks to the top of the viewport while the wrapper is visible.
- When the wrapper scrolls off-screen, the ad naturally scrolls away.
- If `scrollController` is not provided, the wrapper listens to scroll notifications.

**Example**
```dart
final _scrollController = ScrollController();

ListView(
  controller: _scrollController,
  children: [
    AudienzzStickyAdWrapper(
      scrollController: _scrollController,
      stickyTopOffset: 0, // or MediaQuery.padding.top + kToolbarHeight
      maxHeight: 450,
      child: AdWidget(ad: bannerAd),
    ),
  ],
)
```

| Property | Type | Description |
|---|---|---|
| `child` | `Widget` | Ad widget to display (e.g., `AdWidget`). |
| `scrollController` | `ScrollController?` | Optional. If provided, drives sticky updates. |
| `stickyTopOffset` | `double?` | Top offset for sticky position. Defaults to `MediaQuery.padding.top`. |
| `maxHeight` | `double` | Reserved height for the wrapper. Default `600`. |
| `enabled` | `bool` | Enable/disable sticky behavior. Default `true`. |
| `debugLog` | `bool` | Logs internal calculations for debugging. Default `false`. |

## Data Classes & Enums

### AdFormat
| Value            | Description                      |
|------------------|----------------------------------|
| `banner`         | Banner ad format.                |
| `video`          | Video ad format.                 |
| `bannerAndVideo` | Multi-format (banner and video). |

### AdSize
| Property | Type  | Description        |
|----------|-------|--------------------|
| `height` | `int` | Desired ad height. |
| `width`  | `int` | Desired ad width.  |

### ApiParameter
| Value    | Description              |
|----------|--------------------------|
| `vpaid1` | VPAID 1.0 API framework. |
| `vpaid2` | VPAID 2.0 API framework. |
| `mraid1` | MRAID 1.0 API framework. |
| `ormma`  | ORMMA API framework.     |
| `mraid2` | MRAID 2.0 API framework. |
| `mraid3` | MRAID 3.0 API framework. |
| `omid1`  | OMID 1.0 API framework.  |

### Placement
| Value          | Description                 |
|----------------|-----------------------------|
| `inStream`     | In-stream video placement.  |
| `inBanner`     | In-banner video placement.  |
| `inArticle`    | In-article video placement. |
| `inFeed`       | In-feed video placement.    |
| `interstitial` | Interstitial placement.     |
| `slider`       | Slider placement.           |
| `floating`     | Floating placement.         |

### PlaybackMethod
| Value              | Description               |
|--------------------|---------------------------|
| `autoPlaySoundOn`  | Auto-play with sound on.  |
| `autoPlaySoundOff` | Auto-play with sound off. |
| `clickToPlay`      | Click to play.            |
| `mouseOver`        | Play on mouse over.       |
| `enterSoundOn`     | Enter with sound on.      |
| `enterSoundOff`    | Enter with sound off.     |

### Protocol
| Value             | Description                 |
|-------------------|-----------------------------|
| `vast1_0`         | VAST 1.0 protocol.          |
| `vast2_0`         | VAST 2.0 protocol.          |
| `vast3_0`         | VAST 3.0 protocol.          |
| `vast1_0wrapper`  | VAST 1.0 wrapper protocol.  |
| `vast2_0wrapper`  | VAST 2.0 wrapper protocol.  |
| `vast3_0wrapper`  | VAST 3.0 wrapper protocol.  |
| `vast4_0`         | VAST 4.0 protocol.          |
| `vast4_0wrapper`  | VAST 4.0 wrapper protocol.  |
| `daast1_0`        | DAAST 1.0 protocol.         |
| `daast1_0wrapper` | DAAST 1.0 wrapper protocol. |

### VideoBitrate
| Property | Type  | Description                    |
|----------|-------|--------------------------------|
| `min`    | `int` | Minimum video bitrate in kbps. |
| `max`    | `int` | Maximum video bitrate in kbps. |

### VideoDuration
| Property | Type  | Description                        |
|----------|-------|------------------------------------|
| `min`    | `int` | Minimum video duration in seconds. |
| `max`    | `int` | Maximum video duration in seconds. |

### MinSizePercentage
| Property | Type  | Description                |
|----------|-------|----------------------------|
| `width`  | `int` | Minimum width in percent.  |
| `height` | `int` | Minimum height in percent. |

### AdError
| Property  | Type     | Description                |
|-----------|----------|----------------------------|
| `code`    | `int`    | Error code.                |
| `message` | `String` | Descriptive error message. |

### RewardItem
| Property | Type     | Description           |
|----------|----------|-----------------------|
| `amount` | `num`    | Amount of the reward. |
| `type`   | `String` | Type of the reward.   |

### InitializationStatus
| Value     | Description                   |
|-----------|-------------------------------|
| `success` | SDK initialized successfully. |
| `fail`    | SDK initialization failed.    |

## Exceptions
| Exception                           | Description                                            |
|-------------------------------------|--------------------------------------------------------|
| `SdkInitializationFailedException`  | Thrown if SDK initialization fails.                    |
| `AdMessageCodecReadingException`    | Thrown if there is an error reading ad message codec.  |
| `AdSizeRequiredException`           | Thrown if ad size is required but missing.             |
| `RewardItemMissingException`        | Thrown if a reward item is missing in a rewarded ad.   |
| `FailedToGetAutomaticPpidException` | Thrown if automatic PPID status could not be obtained. |

License
========

    Copyright 2025 Audienzz AG.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
       http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
