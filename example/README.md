# Audienzz Flutter example

For publisher integration, start with the [five-step guide](../README.md#quick-integration-remote-config--pageimpression).
This app also contains lower-level and legacy examples for regression testing.

## Run

This branch uses **local native SDKs**. First follow [LOCAL_TESTING.md](../LOCAL_TESTING.md) to
publish Android locally and install the iOS development pod, then run from the repository root:

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
SDK interstitial dismissal recover banners without a new analytics page when using the current
local native SDKs. Do not add another `pageImpression` call to those callbacks.
