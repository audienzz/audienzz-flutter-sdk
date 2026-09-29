# Clickstream analytics contract

The cross-platform contract is maintained in
[audienzz-android-sdk/docs/analytics-contract.md](https://github.com/audienzz/audienzz-android-sdk/blob/main/docs/analytics-contract.md).

Android `0.3.1` / iOS `0.4.1` additions: top-level `publisher_id`, `environment`, `os_version`;
company/website mapping moves to the collector; plain-decimal CPM with source-specific currency; unknown IDs
omitted; iOS impressions guarded per creative. Stock Prebid iOS cannot expose exact bid economics,
so those fields remain absent. Attribute values remain JSON strings.

The required native versions are Android `0.3.1` and iOS `0.4.1`, selected by this bridge.
Rebuild and reinstall the app after upgrading; Dart/JS reloads do not apply native analytics fixes.
See the contract for page-impression ownership, immediate durable delivery, legacy payload handling
and outstanding client/backend checks.

Ad events retain the `page_impression_id` and screen name captured at request start. A new page
impression (including returning to a screen) creates a new ID; refreshes keep the current visit ID.
An interstitial prefetched on A and shown on B keeps A's ID throughout. Report the page before
loading ads; a request made before the first page report has no page ID. No manual ID propagation
is needed in Dart/JS. These guarantees are included in the required native releases.
