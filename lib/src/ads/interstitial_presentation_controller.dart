import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:flutter/widgets.dart';

/// Retains one interstitial for a publisher-approved display opportunity.
/// Keep one controller per logical placement outside transient route widgets.
/// The supplied ad belongs to this controller; use its callbacks for outcomes.
/// It works with both InterstitialAd and RemoteInterstitialAd.
final class InterstitialPresentationController {
  InterstitialPresentationController({required InterstitialAd ad}) : _ad = ad;

  final InterstitialAd _ad;
  bool _disposed = false;

  bool get isReady => !_disposed && _ad.isReady;

  /// Concurrent calls share the load; a ready ad is retained.
  /// Throws on load failure, cancellation, or timeout; handle the returned future.
  /// This never presents, including after a skipped show opportunity.
  Future<void> preload() {
    if (_disposed) {
      return Future.error(StateError('Controller is disposed.'));
    }
    return _ad.load(throwOnFailure: true);
  }

  /// At the transition, pass the current frequency-cap/placement decision.
  /// False means skipped, with no queued show or retry. A late preload
  /// remains ready for a later opportunity. True means the native
  /// show command was accepted, not that an impression was recorded. Show
  /// errors are thrown and also delivered to onAdFailedToShow.
  Future<bool> showAtOpportunity({required bool eligible}) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final String? reason;
    if (!eligible) {
      reason = 'ineligible';
    } else if (!isReady) {
      reason = 'notReady';
    } else if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      reason = 'inactive';
    } else if (adInstanceManager.hasPresentingInterstitial) {
      reason = 'anotherInterstitialPresenting';
    } else {
      reason = null;
    }
    if (reason != null) {
      adInstanceManager.recordInterstitialOpportunitySkipped(_ad, reason);
      return false;
    }
    // Eligibility and submission run without awaiting readiness.
    await _ad.show();
    return true;
  }

  /// Disposing during presentation leaves native ownership until the terminal
  /// callback, but this controller cannot request further loads or shows.
  Future<void> dispose() {
    if (_disposed) {
      return Future.value();
    }
    _disposed = true;
    return _ad.dispose();
  }
}
