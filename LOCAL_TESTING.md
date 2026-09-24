# Running this example against the LOCAL native SDKs

The bridge and example use published `com.audienzz:sdk:0.3.0` and
`AudienzziOSSDK ~> 0.4.0` by default. No native checkout is needed for normal builds.
The overrides below are optional and only for developing native changes.

## Android — one Gradle property

Publish the native SDK to your local Maven repository once:

```bash
cd ~/Documents/audienzz-android-sdk
sed -i '' 's/audienzzSdkVersion = "0.3.0"/audienzzSdkVersion = "0.3.0-local"/' Audienzz/build.gradle.kts
./gradlew :Audienzz:publishToMavenLocal
```

After publishing a local build, add this temporary override to `example/android/gradle.properties`
(or pass `-PaudienzzNativeVersion=0.3.0-local` when invoking Gradle):

```properties
audienzzNativeVersion=0.3.0-local
```

That property is what switches `android/build.gradle` over and adds `mavenLocal()`. **Delete the
line to go back to the published pin**, and before releasing — the default in `android/build.gradle`
is `0.3.0`, so nothing about the shipped package depends on it.

Re-publish after every native change; Gradle caches by version, so either re-publish over
`0.3.0-local` or bump the suffix.

## iOS — one environment variable

```bash
export AUDIENZZ_IOS_SDK_PATH=~/Documents/audienzz-ios-sdk
cd audienzz-flutter-sdk/example/ios && pod install
```

To go back:

```bash
unset AUDIENZZ_IOS_SDK_PATH
cd audienzz-flutter-sdk/example/ios && pod install
```

`pod install` prints when it uses the local checkout. The environment variable lets you switch
sources without editing the committed `Podfile`; the generated lockfile records the selected source.

## Run

```bash
flutter run
```

## Collecting a log

Diagnostics are **on** in this example. Every decision the SDK makes about a slot is one
`AUDZ …` line, and every action you take in the app is an `AUDZ app …` line, so a captured log
reads back as a sequence without you having to narrate it.

```bash
adb logcat -c && adb logcat -s AUDZ ReactNative ReactNativeJS flutter > audz.log     # Android
xcrun simctl spawn booted log stream --style compact \
  --predicate 'eventMessage CONTAINS "AUDZ"' > audz.log                              # iOS simulator
```

The line vocabulary is in
`../Audienzz Full Branch Audit 2026-09-20/Capturing Diagnostics.md`.

## Screens to test

Everything the reviews asked about is reachable in at most two taps from the home list.

| Flow | Where |
| --- | --- |
| RemoteBanner in a scrolling page; scroll off and back | **Managed test flows → Article** (two in-content slots; the second is a real scroll away) |
| Background / foreground with a banner on screen | any article — background the app past the refresh interval, then return |
| Page A → ad-free B → A | **Managed test flows → Ad-free destination**, then back |
| Two routes with the same screen name | **Managed test flows → Article 1** and **Article 2** — both are called `article` and must own their banners separately |
| Delayed content | **Managed test flows → Article after 3s** — leave the route before it lands; it must not reclaim the foreground |
| Retained tabs | **Managed test flows → Retained tabs** (both built, only the selected one owns an ad) |
| Host-reported cover | **Article → Report cover** — a painted veil no geometry check can see |
| Durable publisher pause | **Article → Pause refresh** — a scroll or page change must not undo it |
| Interstitial prefetch → show | **Remote config screen → Prefetch**, then **Show at this opportunity** |
| Interstitial prefetchAndShow | same screen → **Show when it arrives** |
| Repeated taps / ineligible opportunity | same screen — every button stays enabled on purpose |
| Disposal during loading | tap **Prefetch** then immediately leave the screen |
| Test screen from an inline button | **Open test screen** below a home banner — normal text, app bar and back button; one PI before its banner request |
| Interstitial return (Android and iOS) | Show an interstitial over a loaded banner, wait past the refresh interval, dismiss — no refresh under the ad, one return PI, then blank/reload on the active page |

For the interstitial flow, also repeat with a publisher-paused banner, a failed presentation,
and a background/foreground round trip while the ad is open. A manual pause must survive dismissal;
a failed show must not report a page return; native foreground recovery must not be followed by a
duplicate return PI. Off-screen banners remain deferred until eligible. These checks require a
device/live test ad to validate actual Google presentation and painting.

### Android interstitial return regression

Native `0.3.0` can latch `APP_BACKGROUND` after a translucent Google `AdActivity` closes: SDK
initialization missed the host's first start, and returning only resumes it. The fix on native
`feature/page-impression-api` also records resumed/paused activities as started. Flutter's return
PI cannot override an incorrect native background verdict.

Until that native patch is released, publish the patched checkout locally with a unique version
(verified with `0.3.1-flutter-review`), then build this example with
`-PaudienzzNativeVersion=0.3.1-flutter-review`. Keep the local override out of committed pins.

Verify this exact sequence on a clean launch:

1. Let a home banner load, then show and dismiss an interstitial.
2. Confirm one return PI and a fresh load for the visible banner.
3. Open the Test Screen from below a banner; its banner must load.
4. Go back; the home banner must blank and then load its replacement.
5. Background for over 30 seconds, then return; no auctions while backgrounded, one recovery PI.

The Flutter bridge unit suite is `./gradlew :audienzz_sdk_flutter:testDebugUnitTest` from
`example/android`. Native regression tests cover both the foreground monitor and actual banner
handler handoffs. The release remains blocked on publishing the native fix and updating the pin.

Device verification on 2026-09-24 (vivo 2004, Android 12; local native `0.3.1-flutter-review`):
interstitial open for 42 seconds with no banner auctions; dismissal produced one PI and blanked
both home slots. Each slot loaded its deferred replacement when scrolled into view. The inline
Test Screen banner loaded and rendered; returning home blanked and rendered a new banner.
Another 43 seconds in the actual background produced no auctions; returning produced one PI and
one successful replacement for the visible slot.
Native unit tests: 251 passed. Flutter Android bridge tests: 23 passed. Removing the foreground
fix fails five regressions, and removing the bridge's return report/cover fails six regression tests.

Native bridge regressions run in the example's `RunnerTests` target, against the normal published
SDK pin (no local native override):

```bash
cd example/ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -parallel-testing-enabled NO -only-testing:RunnerTests CODE_SIGNING_ALLOWED=NO test
```

### What a good run looks like

Leaving an article for the ad-free screen:

```
AUDZ app navigate to=settings
AUDZ page impression id=settings name=settings
AUDZ slot release config=118 reason=otherPage page=settings
```

...and coming back:

```
AUDZ app navigate to=article-1
AUDZ page impression id=article-1 name=article
AUDZ slot recreate config=118 page=article
AUDZ auction start slot=… reason=pageImpression gen=2
AUDZ auction end slot=… result=filled
```

If a slot stays empty, look first at `slot hold reason=…`, then at whether `slot create`'s `page`
matches the `page impression` before it, then at `refresh block … held=`.

## A note on `Podfile.lock`

`example/ios/Podfile.lock` is generated locally and ignored by Git. Running `pod install` with
`AUDIENZZ_IOS_SDK_PATH` set records your checkout in it. To return to the published dependency,
unset the variable and run `pod update AudienzziOSSDK` from `example/ios`.

## Before releasing

1. Delete `audienzzNativeVersion` from `example/android/gradle.properties`.
2. `unset AUDIENZZ_IOS_SDK_PATH` and `pod install`.
3. Build both platforms against the published dependencies. The current required releases are
   Android 0.3.0 and iOS 0.4.0; no local override should be active.
