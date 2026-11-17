# Audienzz Flutter example

For publisher integration, start with the [five-step guide](../README.md#quick-integration-remote-config--pageimpression).
This app also contains lower-level and legacy examples for regression testing.

## Run

The example defaults to published **Android 0.3.6 / iOS 0.4.6**; no sibling checkout is needed.
Optional local native testing is documented in [LOCAL_TESTING.md](../LOCAL_TESTING.md).
Run from the repository root:

```sh
flutter pub get
cd example
flutter pub get
flutter run
```

The app uses production publisher **35**, remote banners **46 / 48**, and interstitial **47**.
It adds `TEST=1` targeting; ad-ops configuration determines which creatives match that targeting.
The startup flow requests iOS ATT when needed and handles initialization failures/retry before
enabling ads. Publisher apps must integrate their own CMP; ATT does not replace consent setup.

## Run on an iOS device

The project ships without a signing team, so it builds on the simulator as is. For a device:

1. `cd example/ios && pod install`, then open `Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities** and choose your team.
3. If Xcode reports the bundle id (`com.audienzz.audienzzSdkFlutter`) as unavailable, change it to
   one your team owns. `Info.plist` reads it from `PRODUCT_BUNDLE_IDENTIFIER`.
4. Run `flutter run` in `example` with the device connected.

Keep your team and bundle id out of commits that you send back to this repository.

## Screens

- **Regular example:** fixed and adaptive RemoteBanners, scrolling content, and the separate
  Prefetch / Show / Prefetch and show interstitial actions.
- **List example:** sticky banners among article content.
- **Managed Banner / Managed test flows:** the recommended page/banner API, retained tabs,
  repeated articles, delayed content and covers.
- **Test Screen / Ad-free destination:** navigation and return behavior, including leaving a
  page with ads for one without ads.
- **Other regression screens:** always-in-tree banners, smart refresh, scroll/render timing,
  in-content ads, overlay/global pause and legacy integration.

The visibility indicators describe eligibility, not proof that an auction or impression occurred.
Use `AUDZ` logs to verify actual requests and events. Flutter iOS forwards enabled native diagnostics
to the Flutter terminal/IDE console. See [logging and device checks](../LOCAL_TESTING.md).

The example reports real navigation once through its page/navigation integration. App return and
SDK interstitial dismissal recover banners without a new analytics page when using the published
native SDKs. Do not add another `pageImpression` call to those callbacks.
