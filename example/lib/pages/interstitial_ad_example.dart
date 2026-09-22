import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// The three interstitial verbs, side by side.
///
///  * **Prefetch** obtains and retains one ad. Nothing is presented.
///  * **Show at this transition** presents what is in hand, at a moment you chose. If nothing is
///    ready it reports a skip and stops — it does not present later, when the reader has moved on.
///  * **Prefetch and show** is the one call that presents something you did not explicitly time.
///
/// Every button is deliberately left enabled so the repeated-tap behaviour is visible: tapping
/// prefetch twice does not buy two requests, and tapping show twice does not present twice.
///
/// Keep the owner until dismissal/failure; do not recreate inventory for orientation, rebuilds, or
/// dependency changes.
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

  /// One line that always says where the ad is.
  ///
  /// The button labels carried this before, which meant the two states that matter most could not
  /// be told apart: an ad sitting ready and an ad never fetched both showed "Prefetch". Matches
  /// the vocabulary the native examples print, so a log reads the same on every platform.
  String _status = 'not loaded';

  void _setStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
    debugPrint('[Interstitial] $status');
  }

  void _terminal(InterstitialAd ad, [AdError? error]) {
    if (!mounted || !identical(ad, _ad)) return;
    setState(() {
      _showing = false;
      _error = error?.message;
    });
    // Inventory is spent on presentation, so the slot really is empty again.
    _setStatus(error == null ? 'closed — not loaded' : 'failed to show: ${error.message}');
  }

  @override
  void initState() {
    super.initState();
    final InterstitialAd ad;
    if (widget.configId != null) {
      ad = RemoteInterstitialAd(
          configId: widget.configId!,
          adFormat: AdFormat.bannerAndVideo,
          // After a plain prefetch this is where it stops: ready, nothing on screen.
          onAdLoaded: (_) => _setStatus('ready to show'),
          onAdFailedToLoad: (_, error) => _setStatus('load failed: ${error?.message ?? 'unknown'}'),
          onAdClosed: _terminal,
          onAdFailedToShow: _terminal,
          onLifecycleEvent: (_, event) {
            if (event.name == 'opportunitySkipped') _setStatus('opportunity skipped');
            debugPrint('Interstitial ${event.loadId}: ${event.name}');
          });
    } else {
      ad = InterstitialAd(
          adFormat: AdFormat.bannerAndVideo,
          adUnitId: '/21775744923/example/interstitial',
          auConfigId: '34400101',
          onAdLoaded: (_) => _setStatus('ready to show'),
          onAdFailedToLoad: (_, error) => _setStatus('load failed: ${error?.message ?? 'unknown'}'),
          onAdClosed: _terminal,
          onAdFailedToShow: _terminal,
          onLifecycleEvent: (_, event) {
            if (event.name == 'opportunitySkipped') _setStatus('opportunity skipped');
            debugPrint('Interstitial ${event.loadId}: ${event.name}');
          });
    }
    _ad = ad;
    _controller = InterstitialPresentationController(ad: ad);
  }

  Future<void> _prefetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _setStatus('loading…');
    try {
      // Deliberately NOT guarded here: repeated taps must be safe at the SDK
      // boundary, and they are — a second call joins the request in flight or
      // reuses ready inventory.
      await _controller.prefetch();
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
    setState(() {
      _showing = true;
    });
    try {
      final submitted = await _controller.show(eligible: true);
      // Reported rather than silently queued: `show` takes an opportunity or skips it.
      _setStatus(submitted ? 'showing' : 'not ready — nothing to show (prefetch first)');
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

  Future<void> _prefetchAndShow() async {
    setState(() {
      _showing = true;
      _error = null;
    });
    _setStatus('loading… (will show when ready)');
    try {
      final submitted = await _controller.prefetchAndShow();
      if (!submitted && mounted) {
        setState(() {
          _showing = false;
        });
      }
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
    // Disposing WHILE a load is in flight is a supported sequence: leave this
    // screen with "Loading…" on it and nothing arrives later to present.
    // During a presentation this defers cleanup until the terminal event.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status,
                style: const TextStyle(fontFamily: 'monospace'),
                textAlign: TextAlign.center)),
        if (_error != null) Text(_error!),
        ElevatedButton(
            onPressed: _prefetch,
            child: Text(_loading ? 'Loading…' : 'Prefetch')),
        ElevatedButton(
            onPressed: _show,
            child: Text(_showing ? 'Presenting…' : 'Show')),
        ElevatedButton(
            onPressed: _prefetchAndShow,
            child: const Text('Prefetch and show')),
        const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tap any button twice: a second prefetch costs no extra request, '
              'and a second show cannot present twice. Leaving this screen '
              'while it says Loading… disposes the owner, and nothing arrives '
              'afterwards to interrupt you.',
              textAlign: TextAlign.center,
            )),
      ]));
}
