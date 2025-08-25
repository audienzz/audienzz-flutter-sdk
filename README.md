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

The Audienzz SDK Flutter allows you to display three types Ads - `BannerAd`, `InterstitialAd` and `RewardedAd`.

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


API Reference
=============

## SDK Initialization

| Method | Parameters | Description |
|--------|------------|-------------|
| `AudienzzSdkFlutter.instance.initialize` | `{required String companyId}` | Initializes the SDK. Returns `InitializationStatus`. Must be called before using any ad features. |

## Ad Base Classes

### Ad
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `adUnitId` | `String` | Unique identifier for your ad placement. |
| `auConfigId` | `String` | ID of the stored impression on the server. |
| `dispose()` | `Future<void>` | Frees resources used for the ad. |

### AdWithView (extends Ad)
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `load()` | `Future<void>` | Loads the ad. Used for ads that are shown as widgets. |

### AdWithoutView (extends Ad)
| Property/Method | Type | Description |
|-----------------|------|-------------|
| *(inherits all from Ad)* | | Used for ads that do not require a widget view. |

## BannerAd (extends AdWithView)
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `sizes` | `Set<AdSize>` | Required. Ad sizes for the bid request. At least one required. |
| `isAdaptiveSize` | `bool` | If true, ad size is adaptive. Default: false. |
| `refreshTimeInterval` | `int?` | Refresh time in milliseconds. Optional. |
| `adFormat` | `AdFormat` | Desired ad format (banner, video, or both). Default: `AdFormat.banner`. |
| `apiParameters` | `Set<ApiParameter>` | API frameworks for bid response. Default: `{mraid3, omid1}`. |
| `protocols` | `Set<Protocol>` | Supported video protocols. Optional. |
| `placement` | `Placement` | Placement type. Default: `Placement.inBanner`. |
| `playbackMethods` | `Set<PlaybackMethod>` | Video playback methods. Default: `{autoPlaySoundOn}`. |
| `videoBitrate` | `VideoBitrate` | Video bitrate range. Default: `min: 300, max: 1500`. |
| `videoDuration` | `VideoDuration` | Video duration range. Default: `min: 1, max: 30`. |
| `pbAdSlot` | `String?` | PB Ad Slot identifier. Optional. |
| `gpId` | `String?` | Global Placement ID. Optional. |
| `impOrtbConfig` | `String?` | Custom ORTB object for impression. Optional. |
| `onAdLoaded` | `void Function(BannerAd ad)` | Callback when ad is loaded. |
| `onAdFailedToLoad` | `void Function(BannerAd ad, AdError? error)` | Callback when ad fails to load. |
| `onAdOpened` | `void Function(BannerAd ad)?` | Callback when ad overlay opens. |
| `onAdClosed` | `void Function(BannerAd ad)?` | Callback when user returns to app. |
| `onAdClicked` | `void Function(BannerAd ad)?` | Callback when ad is clicked. |
| `onAdImpression` | `void Function(BannerAd ad)?` | Callback when ad is visible for 1s. |
| `getPlatformAdSize()` | `Future<AdSize?>` | Gets the ad size assigned on the platform. |
| `load()` | `Future<void>` | Loads the ad. |

## InterstitialAd (extends AdWithoutView)
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `adFormat` | `AdFormat` | Required. Desired ad format. |
| `minSizePercentage` | `MinSizePercentage` | Minimum ad size in percent. Default: `width: 80, height: 60`. |
| `sizes` | `Set<AdSize>` | Ad sizes for the bid request. Optional. |
| `apiParameters` | `Set<ApiParameter>` | API frameworks for bid response. Default: `{mraid3, omid1}`. |
| `protocols` | `Set<Protocol>` | Supported video protocols. Optional. |
| `placement` | `Placement` | Placement type. Default: `Placement.inBanner`. |
| `playbackMethods` | `Set<PlaybackMethod>` | Video playback methods. Default: `{enterSoundOff}`. |
| `videoBitrate` | `VideoBitrate` | Video bitrate range. Default: `min: 300, max: 1500`. |
| `videoDuration` | `VideoDuration` | Video duration range. Default: `min: 1, max: 30`. |
| `pbAdSlot` | `String?` | PB Ad Slot identifier. Optional. |
| `gpId` | `String?` | Global Placement ID. Optional. |
| `impOrtbConfig` | `String?` | Custom ORTB object for impression. Optional. |
| `onAdLoaded` | `void Function(InterstitialAd ad)` | Callback when ad is loaded. |
| `onAdFailedToLoad` | `void Function(InterstitialAd ad, AdError? error)` | Callback when ad fails to load. |
| `onAdOpened` | `void Function(InterstitialAd ad)?` | Callback when ad overlay opens. |
| `onAdClosed` | `void Function(InterstitialAd ad)?` | Callback when user returns to app. |
| `onAdClicked` | `void Function(InterstitialAd ad)?` | Callback when ad is clicked. |
| `onAdImpression` | `void Function(InterstitialAd ad)?` | Callback when ad is visible for 1s. |
| `load()` | `Future<void>` | Loads the ad. |
| `show()` | `Future<void>` | Shows the ad (must be loaded first). |

## RewardedAd (extends AdWithoutView)
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `apiParameters` | `Set<ApiParameter>` | API frameworks for bid response. Default: `{mraid3, omid1}`. |
| `protocols` | `Set<Protocol>` | Supported video protocols. Optional. |
| `placement` | `Placement` | Placement type. Default: `Placement.inBanner`. |
| `playbackMethods` | `Set<PlaybackMethod>` | Video playback methods. Default: `{enterSoundOff}`. |
| `videoBitrate` | `VideoBitrate` | Video bitrate range. Default: `min: 300, max: 1500`. |
| `videoDuration` | `VideoDuration` | Video duration range. Default: `min: 1, max: 30`. |
| `pbAdSlot` | `String?` | PB Ad Slot identifier. Optional. |
| `gpId` | `String?` | Global Placement ID. Optional. |
| `impOrtbConfig` | `String?` | Custom ORTB object for impression. Optional. |
| `onAdLoaded` | `void Function(RewardedAd ad)` | Callback when ad is loaded. |
| `onAdFailedToLoad` | `void Function(RewardedAd ad, AdError? error)` | Callback when ad fails to load. |
| `onAdOpened` | `void Function(RewardedAd ad)?` | Callback when ad overlay opens. |
| `onAdClosed` | `void Function(RewardedAd ad)?` | Callback when user returns to app. |
| `onAdClicked` | `void Function(RewardedAd ad)?` | Callback when ad is clicked. |
| `onAdImpression` | `void Function(RewardedAd ad)?` | Callback when ad is visible for 1s. |
| `onUserEarnedRewardCallback` | `void Function(RewardedAd ad, RewardItem reward)` | Callback when user earns a reward. |
| `load()` | `Future<void>` | Loads the ad. |
| `show()` | `Future<void>` | Shows the ad (must be loaded first). |

## AdWidget
| Property/Method | Type | Description |
|-----------------|------|-------------|
| `ad` | `AdWithView` | The ad instance to display. Must be loaded before use. |

## Data Classes & Enums

### AdFormat
| Value | Description |
|-------|-------------|
| `banner` | Banner ad format. |
| `video` | Video ad format. |
| `bannerAndVideo` | Multi-format (banner and video). |

### AdSize
| Property | Type | Description |
|----------|------|-------------|
| `height` | `int` | Desired ad height. |
| `width` | `int` | Desired ad width. |

### ApiParameter
| Value | Description |
|-------|-------------|
| `vpaid1` | VPAID 1.0 API framework. |
| `vpaid2` | VPAID 2.0 API framework. |
| `mraid1` | MRAID 1.0 API framework. |
| `ormma` | ORMMA API framework. |
| `mraid2` | MRAID 2.0 API framework. |
| `mraid3` | MRAID 3.0 API framework. |
| `omid1` | OMID 1.0 API framework. |

### Placement
| Value | Description |
|-------|-------------|
| `inStream` | In-stream video placement. |
| `inBanner` | In-banner video placement. |
| `inArticle` | In-article video placement. |
| `inFeed` | In-feed video placement. |
| `interstitial` | Interstitial placement. |
| `slider` | Slider placement. |
| `floating` | Floating placement. |

### PlaybackMethod
| Value | Description |
|-------|-------------|
| `autoPlaySoundOn` | Auto-play with sound on. |
| `autoPlaySoundOff` | Auto-play with sound off. |
| `clickToPlay` | Click to play. |
| `mouseOver` | Play on mouse over. |
| `enterSoundOn` | Enter with sound on. |
| `enterSoundOff` | Enter with sound off. |

### Protocol
| Value | Description |
|-------|-------------|
| `vast1_0` | VAST 1.0 protocol. |
| `vast2_0` | VAST 2.0 protocol. |
| `vast3_0` | VAST 3.0 protocol. |
| `vast1_0wrapper` | VAST 1.0 wrapper protocol. |
| `vast2_0wrapper` | VAST 2.0 wrapper protocol. |
| `vast3_0wrapper` | VAST 3.0 wrapper protocol. |
| `vast4_0` | VAST 4.0 protocol. |
| `vast4_0wrapper` | VAST 4.0 wrapper protocol. |
| `daast1_0` | DAAST 1.0 protocol. |
| `daast1_0wrapper` | DAAST 1.0 wrapper protocol. |

### VideoBitrate
| Property | Type | Description |
|----------|------|-------------|
| `min` | `int` | Minimum video bitrate in kbps. |
| `max` | `int` | Maximum video bitrate in kbps. |

### VideoDuration
| Property | Type | Description |
|----------|------|-------------|
| `min` | `int` | Minimum video duration in seconds. |
| `max` | `int` | Maximum video duration in seconds. |

### MinSizePercentage
| Property | Type | Description |
|----------|------|-------------|
| `width` | `int` | Minimum width in percent. |
| `height` | `int` | Minimum height in percent. |

### AdError
| Property | Type | Description |
|----------|------|-------------|
| `code` | `int` | Error code. |
| `message` | `String` | Descriptive error message. |

### RewardItem
| Property | Type | Description |
|----------|------|-------------|
| `amount` | `num` | Amount of the reward. |
| `type` | `String` | Type of the reward. |

### InitializationStatus
| Value | Description |
|-------|-------------|
| `success` | SDK initialized successfully. |
| `fail` | SDK initialization failed. |

## Exceptions
| Exception | Description |
|-----------|-------------|
| `SdkInitializationFailedException` | Thrown if SDK initialization fails. |
| `AdMessageCodecReadingException` | Thrown if there is an error reading ad message codec. |
| `AdSizeRequiredException` | Thrown if ad size is required but missing. |
| `RewardItemMissingException` | Thrown if a reward item is missing in a rewarded ad. |

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
