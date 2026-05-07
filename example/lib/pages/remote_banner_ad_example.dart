import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class RemoteBannerAdExample extends StatefulWidget {
  const RemoteBannerAdExample({
    required this.configId,
    super.key,
  });

  final String configId;

  @override
  State<RemoteBannerAdExample> createState() => _RemoteBannerAdExampleState();
}

class _RemoteBannerAdExampleState extends State<RemoteBannerAdExample> {
  RemoteBannerAd? _bannerAd;
  bool _isAdLoaded = false;
  String? _error;
  AdSize? _adSize;

  // Key on the loaded-ad SizedBox so we can locate its RenderBox.
  final GlobalKey _adKey = GlobalKey();

  // 500 ms polling timer — same cadence as the iOS FBannerAd.swift polling
  // timer. Fires _checkSmartRefreshVisibility() regardless of which scrollable
  // ancestor the widget lives in, so no ScrollController plumbing is needed.
  Timer? _refreshCheckTimer;

  // Shadow state: avoids redundant pause/resume calls to the platform.
  // Initialised to true so the first tick only pauses if actually off-screen.
  bool _smartRefreshVisible = true;

  @override
  void initState() {
    super.initState();
    loadAd();
  }

  @override
  void dispose() {
    _refreshCheckTimer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
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
    final ad = _bannerAd;
    if (ad == null || !_isAdLoaded || !ad.smartRefresh) return;

    final renderBox = _adKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (size.height == 0) return;

    // localToGlobal uses Flutter's own layout coordinate system, which is
    // accurate regardless of how the platform view is embedded natively.
    // This is what makes it work on Android where Flutter does not physically
    // move the embedded AdManagerAdView when a ListView scrolls.
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.sizeOf(context);
    final screenRect = Offset.zero & screenSize;
    final widgetRect = position & size;
    final intersection = screenRect.intersect(widgetRect);
    final visibleHeight = intersection.height.clamp(0.0, size.height);
    final fraction = visibleHeight / size.height;

    if (fraction < 0.2 && _smartRefreshVisible) {
      setState(() => _smartRefreshVisible = false);
      print('SmartRefresh [${widget.configId}] → PAUSING (fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})');
      ad.pauseAutoRefresh();
    } else if (fraction >= 0.2 && !_smartRefreshVisible) {
      setState(() => _smartRefreshVisible = true);
      print('SmartRefresh [${widget.configId}] → RESUMING (fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})');
      ad.resumeAutoRefresh();
    }
  }

  void loadAd() {
    _bannerAd = RemoteBannerAd(
      configId: widget.configId,
      onAdLoaded: (ad) async {
        final adSize = await ad.getPlatformAdSize();
        setState(() {
          _isAdLoaded = true;
          _error = null;
          _adSize = adSize;
        });
        // Start the polling timer once the ad is loaded. The first tick fires
        // after 500 ms so any ads that loaded while off-screen get paused
        // quickly without needing a manual post-frame callback.
        if (ad.smartRefresh) _startRefreshCheckTimer();
        print('Remote Banner Ad loaded');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _isAdLoaded = false;
          _error = error?.message;
        });
        print('Remote Banner Ad failed to load: $error');
        ad.dispose();
      },
      onAdClicked: (ad) => print('Remote Banner Ad clicked'),
      onAdOpened: (ad) => print('Remote Banner Ad opened'),
      onAdClosed: (ad) => print('Remote Banner Ad closed'),
      onAdImpression: (ad) => print('Remote Banner Ad impression'),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    // AdWidget must be in the tree from the very first build so the native
    // platform view is attached to the iOS/Android view hierarchy immediately.
    // With isLazyLoad = true the demand fetch is only triggered once the
    // native view enters the viewport — but that can only happen if the view
    // is already embedded in the hierarchy.  Gating AdWidget behind
    // _isAdLoaded creates a deadlock: the view never attaches, the fetch never
    // fires, and onAdLoaded never arrives.
    //
    // If the banner ad or its sizes aren't available yet (e.g. remote config
    // hasn't loaded) fall back to a plain spinner.
    if (_bannerAd == null || _bannerAd!.sizes.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final width = _adSize?.width.toDouble() ??
        _bannerAd!.sizes.first.width.toDouble();
    final height = _adSize?.height.toDouble() ??
        _bannerAd!.sizes.first.height.toDouble();

    // Colour: green = auto-refresh active (≥20% visible), red = paused (<20%).
    // Shown only once the ad is loaded and smartRefresh is enabled.
    final showIndicator = _isAdLoaded && (_bannerAd?.smartRefresh ?? false);
    final indicatorColor = _smartRefreshVisible
        ? const Color(0xFFB9F6CA) // light green
        : const Color(0xFFFFCDD2); // light red
    final labelColor = _smartRefreshVisible
        ? const Color(0xFF1B5E20) // dark green text
        : const Color(0xFFB71C1C); // dark red text
    final labelText = _smartRefreshVisible
        ? '● Auto-refresh active'
        : '● Auto-refresh paused';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: showIndicator ? indicatorColor : null,
      child: Column(
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
            // loading indicator is shown until the first ad arrives.
            child: Stack(
              children: [
                AdWidget(ad: _bannerAd!),
                if (!_isAdLoaded)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
