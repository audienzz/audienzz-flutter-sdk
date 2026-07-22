import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Manual test bench for SmartRefresh visibility handling.
///
/// The SDK auto-pauses auto-refresh on scroll visibility, Navigator routes,
/// and app backgrounding — but it CANNOT auto-detect a same-route cover
/// (an [OverlayEntry] / custom stacked widget), because Flutter exposes no
/// occlusion signal. For those, publishers call
/// [AudienzzSdkFlutter.pauseAllAutoRefresh] / [resumeAllAutoRefresh].
///
/// Watch the console for `AudienzzSmartRefresh → PAUSE/RESUME` while using the
/// buttons:
///  - "Toggle overlay"  → NO auto-pause (undetectable cover)
///  - "Push route"      → auto-pause (routeCurrent=false), resume on back
///  - "pauseAll/resumeAll" → explicit global pause/resume for the overlay case
class OverlayDetectionTestScreen extends StatefulWidget {
  const OverlayDetectionTestScreen({super.key});

  @override
  State<OverlayDetectionTestScreen> createState() =>
      _OverlayDetectionTestScreenState();
}

class _OverlayDetectionTestScreenState
    extends State<OverlayDetectionTestScreen> {
  BannerAd? _ad;
  AdSize? _size;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
      auConfigId: '15624474',
      sizes: const {AdSize(width: 300, height: 250)},
      smartRefresh: true,
      isLazyLoad: false,
      refreshTimeInterval: 30000,
      onAdLoaded: (ad) async {
        final s = await ad.getPlatformAdSize();
        if (mounted) setState(() => _size = s);
        debugPrint('OverlayTest: ad loaded');
      },
      // Keep the AdWidget mounted on failure so the visibility manager keeps
      // running even on a no-fill (useful when testing without live demand).
      onAdFailedToLoad: (ad, e) =>
          debugPrint('OverlayTest: ad failed (${e?.message})'),
      onAdImpression: (_) => debugPrint('OverlayTest: impression'),
    );
    _ad!.load();
  }

  @override
  void dispose() {
    _entry?.remove();
    _ad?.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_entry != null) {
      debugPrint('=== OverlayEntry removed ===');
      _entry!.remove();
      setState(() => _entry = null);
      return;
    }
    debugPrint('=== OverlayEntry shown (opaque, same route — NOT auto-paused) ===');
    final entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: ColoredBox(
          color: Colors.indigo,
          child: Center(
            child: TextButton(
              onPressed: _toggleOverlay,
              child: const Text(
                'OVERLAY\n(tap to dismiss)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    setState(() => _entry = entry);
  }

  void _pushRoute() {
    debugPrint('=== route pushed (control — auto-pauses) ===');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Route on top')),
          body: const Center(child: Text('Go back — ad should resume')),
        ),
      ),
    );
  }

  Future<void> _pauseAll() async {
    debugPrint('=== pauseAllAutoRefresh() ===');
    await AudienzzSdkFlutter.instance.pauseAllAutoRefresh();
  }

  Future<void> _resumeAll() async {
    debugPrint('=== resumeAllAutoRefresh() ===');
    await AudienzzSdkFlutter.instance.resumeAllAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay detection / global pause')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'SmartRefresh auto-pauses on scroll, Navigator routes and app '
            'backgrounding. It CANNOT detect an OverlayEntry cover — use '
            'pauseAllAutoRefresh() there. Watch the console for '
            '"AudienzzSmartRefresh → PAUSE/RESUME".',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (ad != null)
            Center(
              child: SizedBox(
                width: _size?.width.toDouble() ?? 300,
                height: _size?.height.toDouble() ?? 250,
                child: AdWidget(ad: ad),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _toggleOverlay,
            child: Text(_entry == null
                ? 'Show overlay (undetected cover)'
                : 'Hide overlay'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pushRoute,
            child: const Text('Push route (auto-pauses)'),
          ),
          const Divider(height: 32),
          const Text(
            'Explicit global control (for overlays the SDK can’t detect):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pauseAll,
                  child: const Text('pauseAllAutoRefresh()'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _resumeAll,
                  child: const Text('resumeAllAutoRefresh()'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
