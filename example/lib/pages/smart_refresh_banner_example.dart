import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Demonstrates manual [BannerAd] with [smartRefresh] = true and
/// [isLazyLoad] = false.
///
/// Each [_SingleSmartRefreshBanner] mirrors the polling approach used by
/// [RemoteBannerAdExample]: a 500 ms [Timer] checks [RenderBox.localToGlobal]
/// visibility and calls [BannerAd.pauseAutoRefresh] / [resumeAutoRefresh].
class SmartRefreshBannerExample extends StatelessWidget {
  const SmartRefreshBannerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _SingleSmartRefreshBanner(
          adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
          auConfigId: '15624474',
          sizes: {AdSize(width: 320, height: 50)},
          label: '320×50',
          refreshTimeInterval: 30000,
        ),
        SizedBox(height: 24),
        _SingleSmartRefreshBanner(
          adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
          auConfigId: '15624474',
          sizes: {AdSize(width: 300, height: 250)},
          label: '300×250',
          refreshTimeInterval: 30000,
        ),
      ],
    );
  }
}

class _SingleSmartRefreshBanner extends StatefulWidget {
  const _SingleSmartRefreshBanner({
    required this.adUnitId,
    required this.auConfigId,
    required this.sizes,
    required this.label,
    required this.refreshTimeInterval,
  });

  final String adUnitId;
  final String auConfigId;
  final Set<AdSize> sizes;
  final String label;

  /// Refresh interval in milliseconds passed to [BannerAd.refreshTimeInterval].
  final int refreshTimeInterval;

  @override
  State<_SingleSmartRefreshBanner> createState() =>
      _SingleSmartRefreshBannerState();
}

class _SingleSmartRefreshBannerState extends State<_SingleSmartRefreshBanner> {
  BannerAd? _ad;
  bool _isLoaded = false;
  String? _error;
  AdSize? _adSize;

  /// Key on the SizedBox that holds the [AdWidget] so we can call
  /// [RenderBox.localToGlobal] to measure visibility accurately.
  final GlobalKey _adKey = GlobalKey();

  /// 500 ms polling timer — same cadence as [RemoteBannerAdExample].
  Timer? _refreshCheckTimer;

  /// Shadow state to avoid redundant pause/resume calls.
  bool _smartRefreshVisible = true;

  // Screen size cached in build() — see RemoteBannerAdExample for rationale.
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _refreshCheckTimer?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: widget.adUnitId,
      auConfigId: widget.auConfigId,
      sizes: widget.sizes,
      // Smart refresh is the feature under test; lazy load is off so the
      // demand fetch fires immediately (no prefetch-margin wait).
      smartRefresh: true,
      isLazyLoad: false,
      refreshTimeInterval: widget.refreshTimeInterval,
      onAdLoaded: (ad) async {
        final adSize = await ad.getPlatformAdSize();
        setState(() {
          _isLoaded = true;
          _error = null;
          _adSize = adSize;
        });
        _startRefreshCheckTimer();
        print('SmartRefreshBannerExample [${widget.label}] ad loaded');
      },
      onAdFailedToLoad: (ad, error) {
        setState(() {
          _ad = null;
          _isLoaded = false;
          _error = error?.message ?? 'Ad failed to load';
        });
        print('SmartRefreshBannerExample [${widget.label}] failed: $error');
        ad.dispose();
      },
      onAdClicked: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] clicked'),
      onAdOpened: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] opened'),
      onAdClosed: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] closed'),
      onAdImpression: (ad) =>
          print('SmartRefreshBannerExample [${widget.label}] impression'),
    );
    _ad!.load();
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
    final ad = _ad;
    if (ad == null || !_isLoaded) return;

    final renderBox = _adKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    if (size.height == 0) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenRect = Offset.zero & _screenSize;
    final widgetRect = position & size;
    final intersection = screenRect.intersect(widgetRect);
    final visibleHeight = intersection.height.clamp(0.0, size.height);
    final fraction = visibleHeight / size.height;

    if (fraction < 0.2 && _smartRefreshVisible) {
      setState(() => _smartRefreshVisible = false);
      print(
        'SmartRefresh [${widget.label}] → PAUSING '
        '(fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})',
      );
      ad.pauseAutoRefresh();
    } else if (fraction >= 0.2 && !_smartRefreshVisible) {
      setState(() => _smartRefreshVisible = true);
      print(
        'SmartRefresh [${widget.label}] → RESUMING '
        '(fraction=${fraction.toStringAsFixed(2)}, posY=${position.dy.toStringAsFixed(0)})',
      );
      ad.resumeAutoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.sizeOf(context);

    if (_error != null) {
      return Center(child: Text('Error [${widget.label}]: $_error'));
    }

    if (_ad == null || widget.sizes.isEmpty) {
      return SizedBox(
        height: widget.sizes.firstOrNull?.height.toDouble() ?? 50,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final width =
        _adSize?.width.toDouble() ?? widget.sizes.first.width.toDouble();
    final height =
        _adSize?.height.toDouble() ?? widget.sizes.first.height.toDouble();

    // Colour indicator: green = auto-refresh active (≥20% visible), red = paused.
    final indicatorColor = _isLoaded
        ? (_smartRefreshVisible
            ? const Color(0xFFB9F6CA) // light green
            : const Color(0xFFFFCDD2)) // light red
        : null;
    final labelColor = _smartRefreshVisible
        ? const Color(0xFF1B5E20) // dark green
        : const Color(0xFFB71C1C); // dark red
    final statusText = _smartRefreshVisible
        ? '● Auto-refresh active'
        : '● Auto-refresh paused';

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${widget.label}  $statusText',
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
          child: Stack(
            children: [
              AdWidget(ad: _ad!),
              if (!_isLoaded)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );

    // Avoid AnimatedContainer — same reason as RemoteBannerAdExample:
    // a 300 ms animation triggers ~18 widget-tree rebuilds per SmartRefresh
    // state flip, adding unnecessary work to scroll frames.
    if (!_isLoaded || indicatorColor == null) return RepaintBoundary(child: column);
    return RepaintBoundary(child: ColoredBox(color: indicatorColor, child: column));
  }
}
