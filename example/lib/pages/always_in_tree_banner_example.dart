import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Demonstrates the **"always in tree"** [AdWidget] pattern.
///
/// ### Pattern
/// [AdWidget] is placed unconditionally in the widget tree from the very first
/// build — it is never gated on an `onAdLoaded` callback. A [CircularProgressIndicator]
/// overlay is shown until the creative arrives, then fades away.
///
/// This is the **recommended** pattern for apps that want the fastest possible
/// time-to-first-render: the platform view is embedded early, so when the ad
/// content arrives it can draw immediately (no window-attachment race condition).
///
/// ### Contrast with the legacy pattern
/// The **legacy gated pattern** (used in [LegacyBannerAdExample]) only adds
/// [AdWidget] to the tree after `onAdLoaded` fires. That sidesteps the race
/// condition naturally — but delays platform-view embedding and therefore
/// first-render slightly longer.
///
/// ### Relation to the doOnAttach fix
/// On Android, even with the "always in tree" pattern a race can still occur if
/// `fetchDemand` returns *before* Flutter has embedded the platform view into
/// the native hierarchy. The `doOnAttach { invalidate() }` fix in `BannerAd.kt`
/// ensures the creative renders as soon as the view gets a window token,
/// regardless of when `loadAd()` was called relative to view attachment.
class AlwaysInTreeBannerExample extends StatefulWidget {
  const AlwaysInTreeBannerExample({super.key});

  @override
  State<AlwaysInTreeBannerExample> createState() =>
      _AlwaysInTreeBannerExampleState();
}

class _AlwaysInTreeBannerExampleState
    extends State<AlwaysInTreeBannerExample> {
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
    // Both ads start loading immediately — before the first build.
    // AdWidget is always present in the tree, so platform view embedding
    // can begin while the network request is still in flight.
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
        if (mounted) {
          setState(() {
            _ad1Loaded = true;
            _ad1Size = size;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() { _ad1 = null; _ad1Loaded = false; });
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
        if (mounted) {
          setState(() {
            _ad2Loaded = true;
            _ad2Size = size;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() { _ad2 = null; _ad2Loaded = false; });
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PatternInfoCard(),
          const SizedBox(height: 16),
          _AdSlot(
            label: '320 × 50',
            ad: _ad1,
            isLoaded: _ad1Loaded,
            adSize: _ad1Size,
            nominalSize: const AdSize(width: 320, height: 50),
          ),
          const SizedBox(height: 24),
          _AdSlot(
            label: '300 × 250',
            ad: _ad2,
            isLoaded: _ad2Loaded,
            adSize: _ad2Size,
            nominalSize: const AdSize(width: 300, height: 250),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info card
// ---------------------------------------------------------------------------

class _PatternInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"Always in tree" pattern',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'AdWidget is in the widget tree from the very first build. '
            'A spinner is shown until the creative arrives — it is NEVER '
            'hidden and re-added after onAdLoaded.\n\n'
            'This lets the platform view attach early and draw the ad the '
            'moment loadAd() completes, even if the finger is still on screen.',
            style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ad slot
// ---------------------------------------------------------------------------

class _AdSlot extends StatelessWidget {
  const _AdSlot({
    required this.label,
    required this.ad,
    required this.isLoaded,
    required this.adSize,
    required this.nominalSize,
  });

  final String label;
  final BannerAd? ad;
  final bool isLoaded;
  final AdSize? adSize;
  final AdSize nominalSize;

  @override
  Widget build(BuildContext context) {
    final double width =
        adSize?.width.toDouble() ?? nominalSize.width.toDouble();
    final double height =
        adSize?.height.toDouble() ?? nominalSize.height.toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status badge
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoaded
              ? _StatusBadge(
                  key: const ValueKey('loaded'),
                  icon: Icons.check_circle_outline,
                  text: '$label  ✓ creative loaded',
                  iconColor: Colors.green[700]!,
                  textColor: Colors.green[800]!,
                )
              : _StatusBadge(
                  key: const ValueKey('loading'),
                  icon: Icons.hourglass_top_rounded,
                  text: '$label  fetching…',
                  iconColor: Colors.orange[700]!,
                  textColor: Colors.orange[800]!,
                ),
        ),
        const SizedBox(height: 6),
        // Ad container — AdWidget is ALWAYS here, never conditional
        if (ad != null)
          SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // AdWidget unconditionally in tree
                AdWidget(ad: ad!),
                // Spinner overlaid until creative arrives
                if (!isLoaded)
                  Container(
                    color: Colors.grey.shade100,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          )
        else
          SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
