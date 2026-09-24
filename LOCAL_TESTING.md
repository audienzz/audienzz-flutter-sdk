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
| iOS interstitial return | Show an interstitial over a loaded banner, wait past the refresh interval, dismiss — no refresh under the ad, one return PI, then blank/reload on the active page |

For the iOS interstitial flow, also repeat with a publisher-paused banner, a failed presentation,
and a background/foreground round trip while the ad is open. A manual pause must survive dismissal;
a failed show must not report a page return; native foreground recovery must not be followed by a
duplicate return PI. Off-screen banners remain deferred until eligible. These checks require a
device/live test ad to validate actual Google presentation and painting.

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
