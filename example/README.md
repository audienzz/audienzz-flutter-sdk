# Audienzz SDK Flutter — Example App

Demonstrates the main features of the `audienzz_sdk_flutter` plugin.

## Screens

### Regular example tab
Shows remote-config banner ads (`configId` 118 and 192) inside a `SingleChildScrollView` alongside a remote interstitial ad. Demonstrates:
- Remote banner loading and display
- **Smart Refresh visual indicator**: the background turns **green** while ≥ 20 % of the ad is visible (auto-refresh active) and **red** when < 20 % is visible (auto-refresh paused). The color transitions smoothly as you scroll.

### List example tab
Shows five sticky banner ads interleaved with article paragraphs in a `ListView`, using `AudienzzStickyAdWrapper` so each ad stays pinned within its reserved area while scrolling past it. Same green/red smart-refresh indicator applies to every ad in the list.

## Running

```bash
cd example
flutter run
```

The app initialises the SDK with remote configuration (publisher ID `81`) and targets the Audienzz test environment. All ad requests include `TEST=1` targeting so only test creatives are served.
