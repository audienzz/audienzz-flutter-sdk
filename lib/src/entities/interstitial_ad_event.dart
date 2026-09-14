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
  /// impression, dismissed, disposeDeferred, or disposed.
  final String name;
  final DateTime timestamp;
  final int? loadAgeMillis;
  final String? responseId;
  final String? reason;
  final AdError? error;
}
