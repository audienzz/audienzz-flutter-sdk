import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ---------------------------------------------------------------------------
// RemoteBannerAdLoader
// ---------------------------------------------------------------------------

/// Manages the lifecycle of a [RemoteBannerAd] and kicks off loading
/// immediately on construction so the Prebid + GAM round-trip can begin
/// *before* the widget tree is fully built.
///
/// Typical usage — pre-load during SDK initialisation, then hand the loader
/// to [RemoteBannerAdExample]:
///
/// ```dart
/// // In initializeSdk(), after all global SDK config is set:
/// _loader = RemoteBannerAdLoader(configId: '118');
///
/// // In build():
/// RemoteBannerAdExample(configId: '118', loader: _loader)
/// ```
///
/// When no loader is passed to [RemoteBannerAdExample], the widget creates and
/// owns one internally — identical behaviour to the pre-refactor version.
class RemoteBannerAdLoader extends ChangeNotifier {
  RemoteBannerAdLoader({required this.configId}) {
    _createAndLoad();
  }

  final String configId;

  RemoteBannerAd? _ad;
  bool isLoaded = false;
  AdSize? adSize;
  String? errorMessage;

  RemoteBannerAd? get ad => _ad;

  void _createAndLoad() {
    _ad = RemoteBannerAd(
      configId: configId,
      onAdLoaded: (ad) async {
        adSize = await ad.getPlatformAdSize();
        isLoaded = true;
        notifyListeners();
        print('RemoteBannerAdLoader [$configId] loaded');
      },
      onAdFailedToLoad: (ad, error) {
        errorMessage = error?.message ?? 'Ad failed to load';
        _ad = null; // null BEFORE notifying so build() sees consistent state
        notifyListeners();
        ad.dispose();
        print('RemoteBannerAdLoader [$configId] failed: $error');
      },
      onAdClicked: (_) {},
      onAdOpened: (_) {},
      onAdClosed: (_) {},
      onAdImpression: (_) => print('Remote Banner Ad [$configId] impression'),
    );
    _ad!.load();
    print('RemoteBannerAdLoader [$configId] load() called');
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// RemoteBannerAdExample
// ---------------------------------------------------------------------------

class RemoteBannerAdExample extends StatefulWidget {
  const RemoteBannerAdExample({
    required this.configId,
    this.loader,
    super.key,
  });

  final String configId;

  /// Optional pre-created loader. When provided this widget observes it but
  /// does NOT dispose it — the caller owns the loader's lifecycle.
  /// When null, a [RemoteBannerAdLoader] is created internally and disposed
  /// with this widget (same behaviour as before this refactor).
  final RemoteBannerAdLoader? loader;

  @override
  State<RemoteBannerAdExample> createState() => _RemoteBannerAdExampleState();
}

class _RemoteBannerAdExampleState extends State<RemoteBannerAdExample> {
  late RemoteBannerAdLoader _loader;

  /// True when this state created the loader and must dispose it.
  bool _ownsLoader = false;

  // Key on the ad SizedBox so _checkSmartRefreshVisibility can locate its
  // RenderBox for accurate visibility measurement.
  final GlobalKey _adKey = GlobalKey();

  // 500 ms polling timer — same cadence as the iOS FBannerAd.swift timer.
  // Fires regardless of which scrollable ancestor the widget lives in, so no
  // ScrollController plumbing is needed.
  Timer? _refreshCheckTimer;

  // Shadow state: avoids redundant pause/resume calls to the platform.
  // Initialised to true so the first tick only pauses if actually off-screen.
  bool _smartRefreshVisible = true;

  // Screen size cached in build() and read by the 500 ms timer.
  // MediaQuery.sizeOf called from a timer (not from build) still registers an
  // InheritedWidget dependency on the element, causing unexpected rebuilds
  // whenever MediaQuery changes (keyboard, rotation). Caching in build()
  // keeps the dependency correctly scoped and the timer reads a plain field.
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.loader != null) {
      _loader = widget.loader!;
      _ownsLoader = false;
    } else {
      _loader = RemoteBannerAdLoader(configId: widget.configId);
      _ownsLoader = true;
    }
    _loader.addListener(_onLoaderChanged);
    // If the loader was pre-created and the ad already loaded before this
    // widget mounted, start the smart-refresh timer immediately.
    if (_loader.isLoaded && (_loader.ad?.smartRefresh ?? false)) {
      _startRefreshCheckTimer();
    }
  }

  @override
  void dispose() {
    _refreshCheckTimer?.cancel();
    _loader.removeListener(_onLoaderChanged);
    if (_ownsLoader) _loader.dispose();
    super.dispose();
  }

  // Called whenever the loader notifies (ad loaded, failed, size resolved).
  void _onLoaderChanged() {
    if (!mounted) return;
    setState(() {});
    if (_loader.isLoaded && (_loader.ad?.smartRefresh ?? false)) {
      _startRefreshCheckTimer();
    }
  }

  void _startRefreshCheckTimer() {
    _refreshCheckTimer?.cancel();
    _refreshCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) _checkSmartRefreshVisibility();
      },
    );
  }

  void _checkSmartRefreshVisibility() {
    final ad = _loader.ad;
    if (ad == null || !_loader.isLoaded || !ad.smartRefresh) return;

    final renderBox = _adKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (size.height == 0) return;

    // localToGlobal uses Flutter's own layout coordinate system, which is
    // accurate regardless of how the platform view is embedded natively.
    // This is what makes it work on Android where Flutter does not physically
    // move the embedded AdManagerAdView when a ListView scrolls.
    final position = renderBox.localToGlobal(Offset.zero);
    final screenRect = Offset.zero & _screenSize; // use cached value, not MediaQuery.sizeOf
    final widgetRect = position & size;
    final intersection = screenRect.intersect(widgetRect);
    final visibleHeight = intersection.height.clamp(0.0, size.height);
    final fraction = visibleHeight / size.height;

    if (fraction < 0.2 && _smartRefreshVisible) {
      setState(() => _smartRefreshVisible = false);
      print(
        'SmartRefresh [${widget.configId}] → PAUSING '
        '(fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})',
      );
      ad.pauseAutoRefresh();
    } else if (fraction >= 0.2 && !_smartRefreshVisible) {
      setState(() => _smartRefreshVisible = true);
      print(
        'SmartRefresh [${widget.configId}] → RESUMING '
        '(fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})',
      );
      ad.resumeAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep screen size up to date so _checkSmartRefreshVisibility can read it
    // without calling MediaQuery.sizeOf from a timer (which would register a
    // stale InheritedWidget dependency outside of build).
    _screenSize = MediaQuery.sizeOf(context);

    final errorMessage = _loader.errorMessage;
    if (errorMessage != null) {
      return Center(child: Text('Error: $errorMessage'));
    }

    // AdWidget must be in the tree from the very first build so the native
    // platform view is attached to the iOS/Android view hierarchy immediately.
    // With isLazyLoad = true the demand fetch is only triggered once the
    // native view enters the viewport — but that can only happen if the view
    // is already embedded in the hierarchy. Gating AdWidget behind isLoaded
    // creates a deadlock: the view never attaches, the fetch never fires, and
    // onAdLoaded never arrives.
    //
    // If the ad or its sizes aren't available yet (e.g. remote config hasn't
    // loaded or the ad failed) fall back to a 50 dp placeholder.
    final ad = _loader.ad;
    if (ad == null || ad.sizes.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isLoaded = _loader.isLoaded;
    final adSize = _loader.adSize;
    final width = adSize?.width.toDouble() ?? ad.sizes.first.width.toDouble();
    final height = adSize?.height.toDouble() ?? ad.sizes.first.height.toDouble();

    // Colour indicator: green = auto-refresh active (≥20% visible), red = paused.
    // Shown only once the ad is loaded and smartRefresh is enabled.
    final showIndicator = isLoaded && ad.smartRefresh;
    final indicatorColor = _smartRefreshVisible
        ? const Color(0xFFB9F6CA) // light green
        : const Color(0xFFFFCDD2); // light red
    final labelColor = _smartRefreshVisible
        ? const Color(0xFF1B5E20) // dark green text
        : const Color(0xFFB71C1C); // dark red text
    final labelText = _smartRefreshVisible
        ? '● Auto-refresh active'
        : '● Auto-refresh paused';

    // Avoid AnimatedContainer here. AnimatedContainer schedules a 300 ms
    // implicit animation on every SmartRefresh state flip, which rebuilds the
    // entire subtree (Column → SizedBox → Stack → AdWidget) on every
    // animation frame (~18 rebuilds per transition). A plain conditional
    // ColoredBox collapses that to a single rebuild per state change with no
    // ongoing animation overhead during scroll.
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIndicator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              labelText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
        SizedBox(
          key: _adKey,
          width: width,
          height: height,
          // Stack the AdWidget behind a spinner so the native view is always
          // attached (enabling lazy-load visibility detection) while a
          // loading indicator is shown until the first creative arrives.
          child: Stack(
            children: [
              AdWidget(ad: ad),
              if (!isLoaded)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );

    // RepaintBoundary isolates this widget as its own compositor layer.
    // Without it, markNeedsPaint() walks up to the SingleChildScrollView's
    // layer and re-rasterizes everything (lorem ipsum glyphs, dividers, etc.)
    // every time the SmartRefresh indicator color changes. With it, only this
    // widget's layer is re-rasterized — the parent column is untouched.
    if (!showIndicator) return RepaintBoundary(child: column);
    return RepaintBoundary(child: ColoredBox(color: indicatorColor, child: column));
  }
}
