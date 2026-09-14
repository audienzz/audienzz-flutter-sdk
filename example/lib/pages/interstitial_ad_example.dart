import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// One preload per intended opportunity. Keep the owner until dismissal/failure;
/// do not recreate inventory for orientation, rebuilds, or dependency changes.
class InterstitialAdExample extends StatefulWidget {
  const InterstitialAdExample({super.key, this.configId});
  final String? configId;

  @override
  State<InterstitialAdExample> createState() => _InterstitialAdExampleState();
}

class _InterstitialAdExampleState extends State<InterstitialAdExample> {
  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;
  String? _error;

  void _terminal(InterstitialAd ad, [AdError? error]) {
    if (!mounted || !identical(ad, _ad)) return;
    setState(() {
      _ad = null;
      _showing = false;
      _error = error?.message;
    });
  }

  Future<void> _load() async {
    if (_loading || _showing || _ad?.isReady == true) return;
    // Reserve the load before awaiting disposal, so rapid taps cannot create two preloads.
    setState(() {
      _loading = true;
      _error = null;
    });
    await _ad?.dispose();
    if (!mounted) return;
    final InterstitialAd ad;
    if (widget.configId != null) {
      ad = RemoteInterstitialAd(
          configId: widget.configId!,
          adFormat: AdFormat.bannerAndVideo,
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_, __) {},
          onAdClosed: _terminal,
          onAdFailedToShow: _terminal,
          onLifecycleEvent: (_, event) =>
              debugPrint('Interstitial ${event.loadId}: ${event.name}'));
    } else {
      ad = InterstitialAd(
          adFormat: AdFormat.bannerAndVideo,
          adUnitId: '/21775744923/example/interstitial',
          auConfigId: '34400101',
          onAdLoaded: (_) {},
          onAdFailedToLoad: (_, __) {},
          onAdClosed: _terminal,
          onAdFailedToShow: _terminal,
          onLifecycleEvent: (_, event) =>
              debugPrint('Interstitial ${event.loadId}: ${event.name}'));
    }
    _ad = ad;
    try {
      await ad
          .load(); // Resolves on Google readiness, not method-channel acknowledgement.
    } catch (error) {
      if (mounted && identical(_ad, ad)) {
        setState(() {
          _ad = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  Future<void> _show() async {
    final ad = _ad;
    if (ad == null || !ad.isReady || _showing) return;
    setState(() {
      _showing = true;
    });
    try {
      await ad.show();
      // Native owns presentation until its terminal event. Never dispose/reload here.
    } catch (error) {
      if (mounted)
        setState(() {
          _showing = false;
          _error = error.toString();
        });
    }
  }

  @override
  void dispose() {
    _ad?.dispose(); // During presentation this defers cleanup until its terminal event.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
          child: Column(children: [
        if (_error != null) Text(_error!),
        ElevatedButton(
            onPressed:
                _loading || _showing || _ad?.isReady == true ? null : _load,
            child: Text(_loading ? 'Loading…' : 'Load interstitial')),
        ElevatedButton(
            onPressed: _ad?.isReady == true && !_showing ? _show : null,
            child: const Text('Show at this transition')),
      ]));
}
