import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:flutter/widgets.dart';

/// Retains one interstitial for a publisher-approved display opportunity.
///
/// Three verbs, and the verb decides whether anything is presented:
///
///  * [prefetch] obtains and retains one ad. It never presents.
///  * [show] presents ready inventory at this opportunity, or reports that it was skipped. It
///    never schedules a presentation for later — the reader will not be interrupted somewhere
///    else, out of context.
///  * [prefetchAndShow] presents when the load completes, or presents inventory already in hand.
///    This is the only entry point that presents something the publisher did not explicitly time.
///
/// Keep one controller per logical placement outside transient route widgets.
/// The supplied ad belongs to this controller; use its callbacks for outcomes.
/// It works with both InterstitialAd and RemoteInterstitialAd.
///
/// **Migration.** `preload()` is [prefetch]; `showAtOpportunity(eligible:)` is [show].
final class InterstitialPresentationController {
  InterstitialPresentationController({required InterstitialAd ad}) : _ad = ad;

  final InterstitialAd _ad;
  bool _disposed = false;

  bool get isReady => !_disposed && _ad.isReady;

  /// Obtain and retain one ad, without displaying it.
  ///
  /// Concurrent calls share the load; a ready ad is retained rather than replaced.
  /// Throws on load failure, cancellation, or timeout; handle the returned future.
  /// This never presents, including after a skipped show opportunity.
  Future<void> prefetch() {
    if (_disposed) {
      return Future.error(StateError('Controller is disposed.'));
    }
    return _ad.load(throwOnFailure: true);
  }

  /// Present ready inventory at this opportunity.
  ///
  /// Pass the current frequency-cap/placement decision as [eligible] (default `true`).
  /// False means skipped, with no queued show or retry — a prefetch that lands afterwards stays
  /// ready for a later opportunity. True means the native show command was accepted, not that an
  /// impression was recorded. Show errors are thrown and also delivered to onAdFailedToShow.
  Future<bool> show({bool eligible = true}) async {
    final reason = _skipReason(eligible: eligible);
    if (reason != null) {
      adInstanceManager.recordInterstitialOpportunitySkipped(_ad, reason);
      return false;
    }
    // Eligibility and submission run without awaiting readiness.
    await _ad.show();
    return true;
  }

  /// Present as soon as the load completes, or present inventory already in hand.
  ///
  /// The same guards as [show] apply at the moment of presentation: a backgrounded app, an ad that
  /// never arrived, or another interstitial already on screen all cancel it and report the skip.
  /// Repeated calls share the one load rather than starting a second.
  ///
  /// Returns whether a presentation was submitted. A load failure is rethrown, as in [prefetch].
  Future<bool> prefetchAndShow({bool eligible = true}) async {
    if (_disposed) {
      return Future.error(StateError('Controller is disposed.'));
    }
    if (!isReady) {
      await _ad.load(throwOnFailure: true);
    }
    return show(eligible: eligible);
  }

  String? _skipReason({required bool eligible}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!eligible) {
      return 'ineligible';
    }
    if (!isReady) {
      return 'notReady';
    }
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return 'inactive';
    }
    if (adInstanceManager.hasPresentingInterstitial) {
      return 'anotherInterstitialPresenting';
    }
    return null;
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
