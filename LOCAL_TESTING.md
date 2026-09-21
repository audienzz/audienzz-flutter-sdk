# Running this example against the LOCAL native SDKs

This bridge calls native APIs that are **not in any published release** — `pageImpression`,
per-view `setScreen`, the interstitial `prefetch`/`show`/`prefetchAndShow` contract and the
analytics corrections. The published pins (`com.audienzz:sdk:0.2.2`, `AudienzziOSSDK 0.3.2`) do
not provide them, so the example **cannot run against them**. Both overrides below are opt-in and
leave the distributable manifests naming real releases.

## Android — one Gradle property

Publish the native SDK to your local Maven repository once:

```bash
cd ~/Documents/audienzz-android-sdk
sed -i '' 's/audienzzSdkVersion = "0.2.2"/audienzzSdkVersion = "0.2.3-local"/' Audienzz/build.gradle.kts
./gradlew :Audienzz:publishToMavenLocal
```

`example/android/gradle.properties` already carries:

```properties
audienzzNativeVersion=0.2.3-local
```

That property is what switches `android/build.gradle` over and adds `mavenLocal()`. **Delete the
line to go back to the published pin** — the default in `android/build.gradle` is still `0.2.2`,
so nothing about the shipped package changes.

Re-publish after every native change; Gradle caches by version, so either re-publish over
`0.2.3-local` or bump the suffix.

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

`pod install` prints which one it chose. It is an env var rather than an edit so the committed
`Podfile` and `Podfile.lock` keep naming a real tag — an absolute path checked into a lock file
only resolves on one machine, which is how one got into this repo before.

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

Running `pod install` with `AUDIENZZ_IOS_SDK_PATH` set rewrites `example/ios/Podfile.lock` to point
at your checkout, so the file will show as modified while you are testing. **Do not commit it** —
an absolute path in a tracked lock only resolves on one machine. `git checkout -- example/ios/Podfile.lock`
puts it back; the installed Pods are unaffected.

## Before releasing

1. Delete `audienzzNativeVersion` from `example/android/gradle.properties`.
2. `unset AUDIENZZ_IOS_SDK_PATH` and `pod install`.
3. Release the native SDKs, then re-pin this package to those versions and rebuild.
