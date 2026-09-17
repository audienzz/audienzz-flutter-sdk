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
  late final InterstitialAd _ad;
  late final InterstitialPresentationController _controller;
  bool _loading = false;
  bool _showing = false;
  String? _error;

  void _terminal(InterstitialAd ad, [AdError? error]) {
    if (!mounted || !identical(ad, _ad)) return;
    setState(() {
      _showing = false;
      _error = error?.message;
    });
  }

  @override
  void initState() {
    super.initState();
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
    _controller = InterstitialPresentationController(ad: ad);
  }

  Future<void> _load() async {
    if (_loading || _showing || _controller.isReady) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _controller.preload();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _show() async {
    if (!_controller.isReady || _showing) return;
    setState(() {
      _showing = true;
    });
    try {
      final submitted = await _controller.showAtOpportunity(eligible: true);
      if (!submitted && mounted) {
        setState(() {
          _showing = false;
        });
      }
      // Native owns presentation until its terminal event. Never dispose/reload here.
    } catch (error) {
      if (mounted) {
        setState(() {
          _showing = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller
        .dispose(); // During presentation this defers cleanup until its terminal event.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
          child: Column(children: [
        if (_error != null) Text(_error!),
        ElevatedButton(
            onPressed:
                _loading || _showing || _controller.isReady ? null : _load,
            child: Text(_loading ? 'Loading…' : 'Load interstitial')),
        ElevatedButton(
            onPressed: _controller.isReady && !_showing ? _show : null,
            child: const Text('Show at this transition')),
      ]));
}
