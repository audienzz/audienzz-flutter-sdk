import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Test screen for the "blank ad while finger on screen" regression.
///
/// **How to use:**
/// 1. Open this screen and IMMEDIATELY start scrolling (keep finger down).
/// 2. **Before fix**: the ad areas stay blank until you lift your finger.
/// 3. **After `doOnAttach` fix**: ads render normally even while actively
///    scrolling.
///
/// Both ads load in [initState] with [isLazyLoad]=false so the network request
/// starts as early as possible.  The [AdWidget] is always in the tree (never
/// conditional) — a spinner overlay is shown until the creative arrives.
/// The list has 97 filler rows below the ads so there is plenty of content to
/// scroll through while the first fetch is in flight.
class ScrollRenderTestExample extends StatefulWidget {
  const ScrollRenderTestExample({super.key});

  @override
  State<ScrollRenderTestExample> createState() =>
      _ScrollRenderTestExampleState();
}

class _ScrollRenderTestExampleState extends State<ScrollRenderTestExample> {
  // Ad 1 — 320×50
  BannerAd? _ad1;
  bool _ad1Loaded = false;
  AdSize? _ad1Size;

  // Ad 2 — 300×250
  BannerAd? _ad2;
  bool _ad2Loaded = false;
  AdSize? _ad2Size;

  @override
  void initState() {
    super.initState();
    _loadAd1();
    _loadAd2();
  }

  @override
  void dispose() {
    _ad1?.dispose();
    _ad2?.dispose();
    super.dispose();
  }

  void _loadAd1() {
    _ad1 = BannerAd(
      adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
      auConfigId: '15624474',
      sizes: const {AdSize(width: 320, height: 50)},
      isLazyLoad: false,
      onAdLoaded: (ad) async {
        final size = await ad.getPlatformAdSize();
        if (mounted) setState(() { _ad1Loaded = true; _ad1Size = size; });
        print('ScrollRenderTest ad1 loaded');
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() { _ad1 = null; });
        print('ScrollRenderTest ad1 failed: $error');
        ad.dispose();
      },
      onAdClicked: (_) {},
      onAdOpened: (_) {},
      onAdClosed: (_) {},
      onAdImpression: (_) {},
    );
    _ad1!.load();
  }

  void _loadAd2() {
    _ad2 = BannerAd(
      adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
      auConfigId: '15624474',
      sizes: const {AdSize(width: 300, height: 250)},
      isLazyLoad: false,
      onAdLoaded: (ad) async {
        final size = await ad.getPlatformAdSize();
        if (mounted) setState(() { _ad2Loaded = true; _ad2Size = size; });
        print('ScrollRenderTest ad2 loaded');
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() { _ad2 = null; });
        print('ScrollRenderTest ad2 failed: $error');
        ad.dispose();
      },
      onAdClicked: (_) {},
      onAdOpened: (_) {},
      onAdClosed: (_) {},
      onAdImpression: (_) {},
    );
    _ad2!.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // 100 items: 0=header, 1=ad1, 2=ad2, 3-99=filler
      itemCount: 100,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        if (index == 1) return _buildAdSlot(_ad1, _ad1Loaded, _ad1Size, '320×50');
        if (index == 2) return _buildAdSlot(_ad2, _ad2Loaded, _ad2Size, '300×250');
        return _buildFillerRow(index - 2);
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFFFF9C4),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scroll-Render Race Condition Test',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Open this screen and IMMEDIATELY start scrolling while keeping '
            'your finger on the screen.\n\n'
            'Before fix → ads stay blank until finger is lifted.\n'
            'After doOnAttach fix → ads render while finger is held.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAdSlot(BannerAd? ad, bool loaded, AdSize? size, String label) {
    if (ad == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text('$label — ad not created',
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final width = size?.width.toDouble() ?? ad.sizes.first.width.toDouble();
    final height = size?.height.toDouble() ?? ad.sizes.first.height.toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  loaded ? Icons.check_circle : Icons.hourglass_top,
                  size: 14,
                  color: loaded ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  loaded ? '$label  ✓ rendered' : '$label  loading…',
                  style: TextStyle(
                    fontSize: 12,
                    color: loaded ? Colors.green[800] : Colors.orange[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                AdWidget(ad: ad),
                if (!loaded) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFillerRow(int n) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Text(
        'Filler row $n — scroll here while ads are loading',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
    );
  }
}
