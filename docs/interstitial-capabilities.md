# Interstitial formats and API frameworks

What an interstitial's bid request advertises — the media formats it asks for, and the OpenRTB
API frameworks its renderer supports — is **backend-controlled**, and identical on iOS, Android,
React Native and Flutter. Apps cannot set either.

## Backend schema

Both fields live in the ad config's `prebidConfig`, because they only shape the Prebid
impression. The placement's type stays in `config.adType` and is unrelated: `adType` says *what
kind of placement* this is (`"interstitial"`); `format` says *which media* its auction asks for.

```json
{
  "id": 47,
  "config": { "adType": "interstitial" },
  "gamConfig": { "adUnitPath": "/96628199/de_audienzz.ch_v2/multi-size", "adSizes": ["320x480"] },
  "prebidConfig": {
    "placementId": "wuobgeuc",
    "adSizes": ["320x480"],
    "format": "bannerAndVideo",
    "apis": [3, 5, 6, 7]
  }
}
```

| Field | Type | Values | When absent or invalid |
|---|---|---|---|
| `prebidConfig.format` | string | `banner`, `video`, `bannerAndVideo` (case-sensitive) | `bannerAndVideo` |
| `prebidConfig.apis` | array of integers | OpenRTB 2.x API framework ids; supported: `3` MRAID 1, `5` MRAID 2, `6` MRAID 3, `7` OMID 1 | `[3, 5, 6, 7]` |

Both fields are optional. A placement with neither behaves exactly as if it had the defaults.

## Validation

Every SDK applies the same rules; the same test table pins them on each platform.

- **`format`** must be exactly one of the three values. Anything else — a different case
  (`"BANNER"`), an unsupported format (`"native"`), a number, a list, `null` — means
  `bannerAndVideo`.
- **`apis`** keeps, in backend order and without duplicates, only the supported ids. Unsupported
  frameworks are never advertised: VPAID 1/2 (`1`, `2`) and ORMMA (`4`) are dropped, as are
  unknown ids, strings, booleans and fractional numbers (`7.0` counts as `7`). If nothing usable
  is left — missing, not an array, empty, or only unsupported values — it is `[3, 5, 6, 7]`. An
  interstitial is never sent without an `api` list.
- The list applies to `banner.api` and, when video is requested, `video.api`.
- A video request always carries playable video parameters: MP4, VAST 2.0, muted autoplay,
  interstitial placement, unless a hand-built interstitial supplied its own (its `api` is still
  replaced).

**Malformed configuration never blocks a load.** A wrong type in either field is read as "not
configured"; the rest of the ad config — and every other placement in the payload — is unaffected,
and the interstitial loads with the defaults.

## When the values are read

Once per **accepted** load, at the moment it starts. A prefetch that is coalesced onto a load in
flight, or answered by an ad that is already ready, reads nothing. So a configuration change:

- does not discard a ready ad, and a later prefetch keeps reusing it;
- does not interrupt an ad on screen;
- never causes a request by itself;
- applies to the next load that is actually started.

## What apps can no longer set — BREAKING

| Platform | Removed | Now |
|---|---|---|
| iOS | `AUInterstitialView(configId:adFormats:)`, `(configId:adFormats:isLazyLoad:)`, `(configId:adFormats:isLazyLoad:minWidthPerc:minHeightPerc:)` | `AUInterstitialView(configId:)`, `(configId:isLazyLoad:)`, `(configId:isLazyLoad:minWidthPerc:minHeightPerc:)` |
| Android | `AudienzzInterstitialAdUnit(configId, adUnitFormats)` and `(configId, adUnitFormats, adSizes)` | `AudienzzInterstitialAdUnit(configId)`, `(configId, minWidthPerc, minHeightPerc)` |
| React Native | `OriginalInterstitial` props `adFormats`, `apiParameters` | — |
| Flutter | `InterstitialAd` / `RemoteInterstitialAd` arguments `adFormat`, `apiParameters` | — |

On every platform, an interstitial's `api` in `bannerParameters` / `videoParameters`, and the
`banner.api`, `video.api` and disallowed `banner` / `video` objects of an `impOrtbConfig`, are
ignored. Their other settings are kept: sizes, minimum size percentages, video duration, bitrate,
protocols, playback methods and the rest of an `impOrtbConfig`.

A **hand-built** interstitial has no ad config, so it always requests `bannerAndVideo` with
`[3, 5, 6, 7]`. To choose a format per placement, use the remote-config interstitial and set it in
the backend.

Banners, rewarded ads and the Rendering API are unchanged.

## Operating notes

- A placement whose video demand cannot be rendered should be set to `"format": "banner"` in the
  backend. Every interstitial now requests video by default; previously some requested banner
  only (Android's remote interstitial, and apps that chose banner).
- Bridges: Flutter's remote interstitials read the ad config in Dart and hand the raw values to the
  native SDK through a bridge-only entry point (`@_spi(AudienzzBridge)` on iOS,
  `@AudienzzBridgeApi` on Android); the native SDK validates them. React Native's remote
  interstitial uses the native remote interstitial directly.
