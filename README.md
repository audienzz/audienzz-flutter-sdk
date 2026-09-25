Audienzz SDK Flutter
========

> **Native dependencies:** Android `com.audienzz:sdk:0.3.0` (Maven Central) and
> iOS `AudienzziOSSDK ~> 0.4.0` (CocoaPods). These releases provide the page ownership,
> refresh and interstitial APIs used by this bridge. The examples use published dependencies
> by default. Optional local development overrides are described in [LOCAL_TESTING.md](LOCAL_TESTING.md).

> **Unreleased fixes on this branch:** adaptive iOS loading and banner-only slot numbering
> need the matching native fixes. Flutter also needs the new native interstitial context API.
> Until native releases and bridge pins are updated, use the local native overrides in
> [LOCAL_TESTING.md](LOCAL_TESTING.md#pending-native-fixes-in-this-branch).

## Quick integration (remote config + `pageImpression`)

The recommended path: Audienzz supplies your publisher and placement IDs, the backend configures
delivery, and managed widgets own each banner's lifecycle. Five steps.

### 1. Install

```sh
flutter pub add audienzz_sdk_flutter
```

Use the package release that requires **Android 0.3.0 / iOS 0.4.0** (this branch). Older Flutter
releases do not include the managed APIs below. Minimum deployment targets: **Android API 24**
and **iOS 15.0**. Set your app's iOS deployment target accordingly.

Add your GAM/AdMob app ID to `AndroidManifest.xml` as `com.google.android.gms.ads.APPLICATION_ID`
and to `Info.plist` as `GADApplicationIdentifier` — see [Android setup](#setup-android) and
[iOS setup](#setup-ios). In GAM, leave each banner ad unit's **refresh rate unset**; Audienzz owns refresh.

### 2. Initialize once, at app startup

Run your CMP and forward its result through `AudienzzTargeting` **before** initializing or creating
ads — see [Consent](#consent). Initialize from your app's startup flow, so every entry route uses it.

```dart
import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

Future<InitializationStatus> initializeAds() async {
  WidgetsFlutterBinding.ensureInitialized();
  return AudienzzSdkFlutter.instance.initializeRemote(
    publisherId: 'YOUR_PUBLISHER_ID',
    remoteUrl: 'https://api.adnz.co/api/ws-sdk-config/public/v1/',
  );
}
```

Await this once after consent. Check the returned status: `success` means ready, `fallbackPolling`
means configuration recovery is still pending, and `fail` means initialization failed. Keep app
content available on failure; create remote interstitials only after configuration is available.

On iOS, if your app requests tracking permission, add `NSUserTrackingUsageDescription` and
resolve ATT while the app is active, **before ad initialization**. Prompt only for `notDetermined`;
a denied/restricted decision must still let your app initialize. IDFA remains unavailable without
authorization. The example includes this flow; the SDK never prompts automatically for publishers.
See [Apple's ATT request requirements](https://developer.apple.com/documentation/apptrackingtransparency/attrackingmanager/requesttrackingauthorization(completionhandler:)).

### 3. Report every screen — including screens without ads

> **Required:** every screen that becomes active must produce a `pageImpression` (PI), even if it
> contains no ads. This includes the initial screen, navigation to an ad-free settings/profile
> screen, tab changes, and returning to a previous screen. Report the screen independently of
> whether an ad loads. Reporting the destination releases the previous screen's banners so they
> cannot keep refreshing behind it.

Keep one observer for your `Navigator` and wrap each ad-bearing route in `AudienzzPage` (step 4):

```dart
final adNavigationObserver = AudienzzNavigatorObserver();

// In your app widget:
MaterialApp(
  navigatorObservers: [adNavigationObserver],
  home: const ArticlePage(),
);
```

The observer reports push, pop, replace and remove, including **ad-free destinations**. Reporting
the destination releases the previous page's banners. The page wrapper binds banners to the correct
route instance, even when two routes have the same name. **The observer and managed page already
report PI: do not add a second manual `pageImpression` call for the same transition.**

For tabs inside one route, wrap each tab in its own `AudienzzPage` and set `active` to whether it is
selected. For nested or custom navigation, follow the [managed integration](#the-managed-integration-recommended).

### 4. Place a banner

```dart
class ArticlePage extends StatelessWidget {
  const ArticlePage({super.key});

  @override
  Widget build(BuildContext context) => AudienzzPage(
        name: 'article',
        child: Scaffold(
          body: ListView(children: const [
            Text('Article content'),
            AudienzzBanner(
              adConfigId: 'YOUR_BANNER_CONFIG_ID',
              slotKey: 'article-middle',
              placeholderHeight: 250,
            ),
          ]),
        ),
      );
}
```

Keep `slotKey` stable and unique within the page. Reserve the expected height **before** the ad
loads; `AudienzzBanner` mounts the placeholder, loads and disposes for you. Remote banners default
to lazy loading; the backend controls `lazyLoad`, prefetch distance and refresh settings.

### 5. Show an interstitial

Keep one controller per placement, created after remote initialization, outside transient routes:

```dart
final interstitial = InterstitialPresentationController(
  ad: RemoteInterstitialAd(
    configId: 'YOUR_INTERSTITIAL_CONFIG_ID',
    onAdLoaded: (_) {},
    onAdFailedToLoad: (_, error) => debugPrint('Interstitial load failed: $error'),
    onAdFailedToShow: (_, error) => debugPrint('Interstitial show failed: $error'),
  ),
);
```

Choose the flow that matches the display opportunity; these are separate actions:

```dart
await interstitial.prefetch();                 // Cache one ad; never presents.
await interstitial.show(eligible: canShowAd);   // Show now if ready; otherwise skip.

// Alternative: explicitly request presentation as soon as the ad is ready.
await interstitial.prefetchAndShow(eligible: canShowAd);
```

`canShowAd` is your current frequency-cap and screen-policy decision. Handle these futures with
`try` / `catch`; load and presentation errors can throw. Repeated prefetches share an outstanding
load and retain ready inventory. Keep the controller alive through dismissal and call `dispose()`
when its owning scope ends. See [interstitial lifecycle](#interstitial-lifecycle-and-migration).

The bridge holds banner refresh while an SDK interstitial is presented. Dismissal reports the
current page again and replaces its banners, unless navigation or foreground recovery already
reported that page visit. Android waits for the host activity to resume if dismissal arrives first.
Do not add a manual PI in `onAdClosed`. Failed presentation does not create a page impression, and
dismissal never clears a publisher's manual refresh pause.

**Android release dependency:** the native foreground-tracking fix for a translucent Google ad
activity is required for this flow. It is on the native `feature/page-impression-api` branch and is
not in the current `0.3.0` pin. Release that native patch and update the pin before shipping these
Android changes; see [local verification](LOCAL_TESTING.md#android-interstitial-return-regression).

### What the SDK handles

Managed banners own loading, page transitions, viewport refresh gating and disposal. Native code
pauses refresh in the background and handles foreground recovery. **Do not add refresh timers or
reload on rebuild, navigation or app resume.** Smart Refresh v2 is selected by backend configuration;
without it, the classic viewport gate applies.

For custom covers, attach an `AudienzzBannerController` to the banner, call
`controller.reportCover(covered: true)`, and clear it when the cover disappears. For a whole retained page, set `AudienzzPage.active` to `false`. See [test flows and local setup](LOCAL_TESTING.md) before shipping.

---

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

The Audienzz Flutter SDK requires a minimum iOS version of **15.0** or higher and a minimum android version of **API 24 (Android 7.0, Nougat)** or higher.

Installation
-------

In your terminal run command:
```
flutter pub add audienzz_sdk_flutter
```

This selects a published package version and adds it to `pubspec.yaml`. Use the release matching
the native dependencies listed above; retain the generated version constraint.

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
 final status = await AudienzzSdkFlutter.instance.initialize(companyId: 'CompanyID');

 if (status == InitializationStatus.success) {
   // SDK is ready to be used
 }
```
CompanyId is provided by Audienzz, usually - it is id of the company in ad console.
PPID is managed by the native SDK and the backend `ppidEnabled` setting. Use `PpidManager` to supply your own identifier; initialization has no PPID toggle.

The Audienzz SDK Flutter allows you to display three types Ads - `BannerAd`, `InterstitialAd` and `RewardedAd`.

Lazy Loading
-------
Lazy loading defers the ad request until the `BannerAd` widget is actually visible on screen, saving resources for ads that may never be seen.

For the lower-level `BannerAd`, opt in with `isLazyLoad: true` and `smartRefresh: true`; `isLazyLoad` defaults to `false` on that class. Remote banners use the backend setting, which defaults to `true`:

```dart
final banner = BannerAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  sizes: {const AdSize(width: 320, height: 50)},
  isLazyLoad: true,       // request when the widget approaches the viewport
  smartRefresh: true,     // required for Flutter viewport reporting
  prefetchMargin: 200,    // start fetching 200 logical pixels before the view appears (default)
  onAdLoaded: (_) {},
  onAdFailedToLoad: (_, __) {},
)..load();
```

A lazy slot must be mounted and sized before its viewport can be measured. In `ListView` / `GridView`, the list's cache extent can limit how far ahead a slot exists; prefetch cannot start before it is built.

Smart Refresh
-------
Smart Refresh gates periodic banner requests on viewport eligibility. The classic gate requires at least 20% of the ad height to be visible. Smart Refresh v2 requires the top edge to be visible and at most half the height to extend below the viewport. The backend `smartRefreshV2` flag selects v2; an explicit `setSmartRefreshV2Enabled(...)` call overrides it.

#### Visibility detection

The SDK polls the ad's position every 500 ms using Flutter's `RenderBox.localToGlobal()` — Flutter's own layout coordinate system, not the native platform's. It applies the selected v1/v2 rule on both platforms:

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

The visibility layer handles viewport position, ancestor clipping and supported hit-test-visible covers. Arbitrary painted or pointer-transparent overlays cannot be inferred reliably. Report them with `banner.reportObscured(true)` and clear with `false`; for a managed banner, attach an `AudienzzBannerController` and use `reportCover(covered: ...)`. Publisher pause/resume below is a separate, durable policy control on both platforms.

Pause / resume a **specific** banner via its `BannerAd` instance:

```dart
banner.pauseAutoRefresh();  // publisher policy pauses refresh
banner.resumeAutoRefresh(); // publisher policy allows refresh again
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

Lower-level APIs
================

For new remote integrations, use the [five-step quick integration](#quick-integration-remote-config--pageimpression)
above. The following examples show individual lower-level APIs after initialization. For a manual
banner integration, report its page before constructing it, mount a sized `AdWidget` immediately,
and dispose the ad with its owner. See [manual screen reporting](#reporting-screens-without-the-managed-widgets).

Interstitial minimal usage
--------------------------
```dart
final interstitial = InterstitialAd(
  adUnitId: 'YOUR_AD_UNIT_ID',
  auConfigId: 'YOUR_AU_CONFIG_ID',
  onAdLoaded: (_) => debugPrint('Interstitial loaded'),
  onAdFailedToLoad: (_, error) => debugPrint('Interstitial fail: ${error?.message}'),
  onAdClosed: (_) => debugPrint('Interstitial dismissed'),
  onAdFailedToShow: (_, error) => debugPrint('Presentation failed: $error'),
  onLifecycleEvent: (_, event) => debugPrint('${event.loadId}: ${event.name}'),
);
// Retain this controller outside transient route widgets; one per logical placement.
final controller = InterstitialPresentationController(ad: interstitial);

Future<void> prepareNextOpportunity() async {
  try { await controller.prefetch(); }
  catch (error) { debugPrint('Prefetch failed: $error'); }
}

Future<void> onEligibleTransition(bool publisherAllowsAd) async {
  try {
    final submitted = await controller.show(eligible: publisherAllowsAd);
    // false means skipped. No late load completion will show this opportunity.
  } catch (error) { debugPrint('Presentation failed: $error'); }
}

// Or, when you want the ad shown as soon as it arrives — asked for by name:
Future<bool> showWhenReady() => controller.prefetchAndShow();
```

### Migrating from `preload` / `showAtOpportunity`

| Before | Now |
| --- | --- |
| `controller.preload()` | `controller.prefetch()` |
| `controller.showAtOpportunity(eligible: x)` | `controller.show(eligible: x)` |
| load, then show from the load callback | `controller.prefetchAndShow()` |

The verb now decides whether anything is presented: `prefetch` never presents, `show` presents only
what is already in hand and reports a skip otherwise, and `prefetchAndShow` is the one call that
presents something you did not explicitly time. `eligible` defaults to `true` on `show`.

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
```

#### When the auction starts

Both delivery settings of a `RemoteBannerAd` come from the ad config only — `lazyLoad` and `prefetchDistanceDp` (default `200` dp/pt) — so a placement is tuned in the backend, behaves the same on every platform, and changes without an app release. There are no arguments for them. When the ad config says nothing, both `RemoteBannerAd` and `AudienzzBanner` wait for the viewport (`lazyLoad` defaults to `true`), as on every other platform.

> **Mount the `AdWidget` before the ad loads.** Lazy loading needs a mounted platform view with
> non-zero dimensions. Waiting for `onAdLoaded` before mounting it prevents loading from starting.
> Reserve the expected dimensions from the first build, or use `AudienzzBanner`, which does this
> for you. To request immediately regardless of position, set `lazyLoad: false` in the backend.

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

```dart
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

final controller = InterstitialPresentationController(ad: remoteInterstitial);
// Prefetch ahead of a likely opportunity; catch load failures.
Future<void> prepare() async {
  try { await controller.prefetch(); }
  catch (error) { debugPrint('Prefetch failed: $error'); }
}
// Called separately at the actual transition, after checking publisher frequency caps.
Future<bool> showAtTransition(bool publisherAllowsAd) =>
    controller.show(eligible: publisherAllowsAd);
// Handle errors from showAtTransition and dispose the controller when no longer needed.
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
| `setPublisherPpid`        | `String? ppid`                    | Supply your own PPID (e.g. a hashed e-mail). Takes precedence over the SDK-generated one; pass `null` to clear and fall back to it.       |
| `getPpid`                 |                                   | The PPID currently being sent: yours if set, otherwise the SDK-generated UUID. `null` when the backend disables PPID (`ppidEnabled: false`). |

PPID is enabled by default. The native SDK generates a persisted identifier, rotated every
12 months, unless you supply your own. The publisher configuration controls whether either
identifier is sent; there is no initialization argument for this:

| Publisher config field | Effect when `false` | Absent |
|---|---|---|
| `ppidEnabled` | No PPID is sent at all, including one you supplied | Enabled |

API Reference
=============

## SDK Initialization

| Method                                   | Parameters                                                         | Description                                                                                                                                    |
|------------------------------------------|--------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `AudienzzSdkFlutter.instance.initialize` | `{required String companyId}` | Initializes the SDK. PPID is managed automatically and attached when enabled by the backend publisher configuration. Returns `InitializationStatus`. Must be called before using any ad features. |
| `AudienzzSdkFlutter.instance.pageImpression` | `{BuildContext? context, String? name}` | Report every screen/dialog, including ad-free destinations — fires a `pageImpression`. See [Screen tracking](#screen-tracking-analytics). |
| `AudienzzSdkFlutter.instance.setSmartRefreshV2Enabled` | `bool enabled` | Force smart-refresh v2 (directional viewport gate) on/off, overriding backend config. Call **before** creating banners. |
| `AudienzzSdkFlutter.instance.setBlankOnScreenReload` | `bool enabled` | Blank a native banner's slot during a screen-resume reload (default `false`). Call **before** creating banners. |
| `AudienzzSdkFlutter.instance.setAppVolume` | `double volume` | Set the global ad audio volume for all ad types (`0.0`–`1.0`, `0.0` = muted). The SDK defaults to muted. |

## Screen tracking (analytics)

The SDK ties ad events to the screen the user is on: reporting an ad-bearing screen fires a
`pageImpression` and starts a fresh page-impression id that groups every ad event on that visit.

### GAM prerequisite

When the SDK owns refresh, the **GAM ad unit's own refresh rate must be unset**. Two refresh owners
cannot be reconciled from the app: Google's server-configured refresh runs independently of the
SDK's scheduler, and no publisher lifecycle code can compensate for it. Check this per ad unit
before enabling smart refresh.

### The managed integration (recommended)

Wire navigation once, place a banner, and write nothing else. No `load()`, no `Timer`, no reload
after a page impression or an app resume, no `dispose()`.

```dart
MaterialApp(
  // One adapter. Covers push, pop, replace and remove, and reports ad-free
  // destinations too — that is what releases the previous page's banners.
  navigatorObservers: [AudienzzNavigatorObserver()],
  home: const ArticlePage(),
);

class ArticlePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AudienzzPage(
        name: 'article',
        child: ListView(children: const [
          ArticleBody(),
          // Reserves its height immediately and loads as it nears the viewport.
          AudienzzBanner(adConfigId: '46', slotKey: 'in-content-1'),
        ]),
      );
}
```

`AudienzzPage` and `AudienzzNavigatorObserver` give **each route instance its own page identity**,
so two article routes both named `article` own their banners separately with nothing to configure.
They resolve the *same* handle for the same route, and only one activation is reported per
navigation.

The legacy `pageImpression(name:)` keeps **name identity**, so reporting a screen again still
matches the banners already on it and refreshes them. Compatibility lives at that boundary; it does
not weaken the managed contract.

`AudienzzBanner` identifies a slot by `(page, slotKey)` — an `adConfigId` is not unique, the same
placement can appear twice on one page — and binds explicitly to the page it is built inside, not to
whichever page was activated most recently.

`AudienzzPage(id: …)` is available when a host wants to choose the identity itself — a custom
router that already has a stable per-instance key. It is not needed for the default setup.

For a tab or an `IndexedStack`, pass whether this tab is selected, so a pre-built tab does not claim
the active page and does not buy an ad the reader may never see:

```dart
AudienzzPage(name: 'feed', active: _selectedIndex == 0, child: …)
```

**Custom router?** There is one contract: mint a handle per route instance and activate it when that
route becomes visible.

```dart
final page = createAudienzzPage('article');            // id == 'article'
await AudienzzSdkFlutter.instance.activatePage(page);  // when it becomes visible

// Or, when two routes share a name and must own their banners separately:
await AudienzzSdkFlutter.instance
    .activatePage(const AudienzzPageHandle(id: 'article-42', name: 'article'));
```

Activate the destination on every transition, including to screens with no ads. Activating a page is
what deactivates the previous one; nothing else needs to be called.

### Reporting screens without the managed widgets

If you place `RemoteBannerAd` yourself, you own the ordering: **report the page, then create its
ads.** An ad created before its page is reported carries no page, and the next page impression
sweeps it as belonging elsewhere.

```dart
await AudienzzSdkFlutter.instance.pageImpression(name: 'home');
// …create this screen's ads now, not before.
```

Report from the navigation action — the router callback, the tab listener, the route observer.
Do **not** report from `build`, `didChangeDependencies`, a layout callback or a parent `initState`
that runs after its children: rendering, layout, theme changes and rebuilds are not navigation
events, and a report that lands after a child has been constructed binds that child to the previous
page permanently.

Notes:
- `pageImpression(name:)` uses the name as the page identity. Two routes that share a name are the
  same page to the coordinator; use `activatePage` with a handle when that matters.
- A page impression is the whole transition. Native releases every banner that is not on the
  incoming page and re-auctions the ones that are, and the Flutter widget remounts its platform view
  when the native epoch changes. **Do not also reload manually** — that gives one transition two
  owners and two auctions, the second discarding the creative the first just fetched.

Two optional session-wide toggles tune smart-refresh (call **before** creating banners):

```dart
// Use the v2 directional viewport gate (top fully on screen, at most half off the
// bottom) instead of the legacy 20%-visible gate. Overrides backend config.
await AudienzzSdkFlutter.instance.setSmartRefreshV2Enabled(true);

// Blank a native banner's slot during a screen-resume reload (default false).
await AudienzzSdkFlutter.instance.setBlankOnScreenReload(true);
```

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

An interstitial's formats and API frameworks are not arguments: they are backend-controlled (`prebidConfig.format` / `prebidConfig.apis`). A `RemoteInterstitialAd` uses its ad config's values; a hand-built `InterstitialAd` requests banner + video with MRAID 1/2/3 + OMID 1. See [docs/interstitial-capabilities.md](docs/interstitial-capabilities.md).

| Property/Method     | Type                                               | Description                                                   |
|---------------------|----------------------------------------------------|---------------------------------------------------------------|
| `minSizePercentage` | `MinSizePercentage`                                | Minimum ad size in percent. Default: `width: 80, height: 60`. |
| `sizes`             | `Set<AdSize>`                                      | Ad sizes for the bid request. Optional.                       |
| `protocols`         | `Set<Protocol>`                                    | Supported video protocols. Default: `{vast2_0}`.              |
| `placement`         | `Placement`                                        | Placement type. Default: `Placement.interstitial`.            |
| `playbackMethods`   | `Set<PlaybackMethod>`                              | Video playback methods. Default: `{autoPlaySoundOff}`.        |
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


## Publisher pause and smart-refresh visibility

`BannerAd.pauseAutoRefresh()` is a durable publisher pause. Only `BannerAd.resumeAutoRefresh()` clears it. Scrolling, returning to the app and `pageImpression` do not implicitly resume a publisher-paused banner.

`AdWidget` sends its visibility/overlay/unmount state through a separate internal channel operation (`setBannerViewportVisible`). Publishers should let `AdWidget` manage visibility and use the public pause API only for their own pause policy. Both native plugin implementations preserve these independent reasons.

Original banner refresh is owned by the native Audienzz SDK and completes at the Google load result. Configure the GAM ad unit with its own refresh rate unset. The required native releases are Android 0.3.0 and iOS 0.4.0; both are published and selected by this bridge.


## Interstitial lifecycle and migration

Flutter's lower-level `InterstitialAd` and `RemoteInterstitialAd` retain an explicit `load()` /
`show()` contract on both platforms. The recommended `InterstitialPresentationController` exposes
`prefetch()` / `show()` / `prefetchAndShow()`, matching the native remote interstitial flow.
Loading or prefetching alone never presents an ad.

- `load()` preserves callback-based failure handling: load failures go to `onAdFailedToLoad`,
  and the returned future settles without an error. Check `isReady` before calling `show()`.
  For an awaited flow, use `await ad.load(throwOnFailure: true)` inside `try`/`catch`; this
  throws on failure, cancellation during loading, busy state, or a 120-second timeout.
  `InterstitialPresentationController.prefetch()` always uses this strict mode.
- Concurrent loads share one request; loading an already-ready ad does not replace it. After a
  terminal failure or dismissal the same Dart object may load again with a new ID.
- `isReady` excludes expired and presenting inventory. Ads expire after one hour; call `load()`
  explicitly to replace expired inventory. There is no periodic interstitial refresh.
- `show()` completes when native accepts the call, not when the ad closes. Use `onAdClosed` for
  completed dismissal and `onAdFailedToShow` for presentation failure (code/message/domain).
  Presentation failures no longer masquerade as load failures or successful closures.
- Cleanup occurs automatically on dismissal/failure. `dispose()` during presentation defers
  cleanup so callbacks survive; disposal during loading cancels the readiness future.
- Do not reload interstitials on rebuild, rotation, `pageImpression`, or banner smart refresh.
  Preload at most the intended next opportunity and apply publisher frequency rules before
  requesting when possible. An old show request is never replayed later on foreground/navigation.
- `onLifecycleEvent` supplies a per-load ID, event name, Google response ID when available,
  loaded-ad age, and errors/disposal reasons. Forward it with app/SDK version, route, foreground
  state, and publisher eligibility decisions to your analytics. Track loadRequested, loaded,
  showAttempted, presented, impression, dismissed/showFailed, and disposed separately.

These changes improve correctness; a higher render rate alone does not demonstrate more revenue.
Compare impressions and revenue per session alongside unused prefetches and presentation failures.


### Recommended interstitial presentation controller

`InterstitialPresentationController` works with original and remote interstitials. Retain one
controller per logical placement outside transient page widgets, and use it exclusively to prefetch,
show and dispose its ad. `prefetch()` shares an outstanding load and keeps ready inventory; it never
presents. `show(eligible: ...)` immediately skips if the publisher disallows the opportunity,
the ad is unavailable/expired, Flutter is inactive, or another interstitial in this engine is
presenting. A skipped opportunity is never queued, including across foreground or page changes —
that is what `prefetchAndShow()` is for, and it has to be asked for by name. The ready ad remains
available for a later explicit opportunity; no extra request is issued.

A true result means the native show command was accepted. Use `onAdOpened`, `onAdImpression`,
`onAdFailedToShow` and `onAdClosed` for the actual outcome. Presentation errors still throw.
The controller does not infer your frequency cap or own other SDKs' fullscreen ads: compute
`eligible` at the transition, including your own modal/ad policy. Prefetching has no implicit
publisher eligibility decision. Check that policy before requesting too, when possible.

There is no scheduled show, arbitrary wait period, or dependency on banner smart refresh.
`dispose()` during presentation preserves callbacks until dismissal/failure. Repeated prefetch
calls after dismissal may prepare the next opportunity; never request it just to raise render rate.
`opportunitySkipped` lifecycle events include a reason when a load is registered. Google iOS
interstitial load failures now preserve their original error code and domain; Android load events
also carry their error domain.

### Automatic request counters

Original and remote banners include `au_page_seq`, `au_slot` and `hb_refresh_count` in GAM
custom targeting. Interstitials include only `au_page_seq` and `hb_refresh_count`; they never
consume a banner position. See [the request targeting contract](docs/ad-request-targeting.md)
for page resets, automatic slot ordering and request-count semantics. No new publisher parameter is required.
