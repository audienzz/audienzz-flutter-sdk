import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';

/// A Google interstitial lifecycle event, correlated by one ID per load attempt.
/// Connect this callback to publisher analytics to distinguish unused preloads from show failures.
final class InterstitialAdEvent {
  const InterstitialAdEvent(
      {required this.loadId,
      required this.name,
      required this.timestamp,
      this.loadAgeMillis,
      this.responseId,
      this.reason,
      this.error});
  final int loadId;

  /// loadRequested, loaded, loadFailed, showAttempted, presented, showFailed,
  /// impression, dismissed, disposeDeferred, disposed, or
  /// `discardedWithoutImpression`.
  ///
  /// `discardedWithoutImpression` fires at most once per load, when inventory
  /// that loaded successfully is released before it records an impression.
  /// [reason] then distinguishes `expired`, `disposed`, `replaced`,
  /// `presentationFailed` and `dismissedWithoutImpression`. It never fires for
  /// a load that failed, or for inventory that was shown and counted.
  ///
  /// It is a diagnostic, not a billing record: it does not replace Ad Manager's
  /// responses-served or AdX render-rate reporting, which are measured
  /// server-side across demand sources the SDK cannot see. A process killed
  /// while inventory is held emits nothing, so these counts are a lower bound.
  final String name;
  final DateTime timestamp;
  final int? loadAgeMillis;
  final String? responseId;
  final String? reason;
  final AdError? error;
}
