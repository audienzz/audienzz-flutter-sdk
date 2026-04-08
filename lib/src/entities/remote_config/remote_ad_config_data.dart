class RemoteAdConfigData {
  const RemoteAdConfigData({
    required this.adType,
    this.refreshTimeSeconds,
    this.prefetchDistanceDp,
  });

  factory RemoteAdConfigData.fromJson(Map<String, dynamic> json) {
    return RemoteAdConfigData(
      adType: json['adType'] as String,
      // decodeIfPresent equivalent: returns null for both absent keys and JSON null,
      // so callers apply a default via the null-coalescing operator.
      refreshTimeSeconds: json['refreshTimeSeconds'] as int?,
      prefetchDistanceDp: json['prefetchDistanceDp'] as int?,
    );
  }

  final String adType;

  /// Seconds between auto-refresh cycles. `null` when absent or null in the remote payload.
  final int? refreshTimeSeconds;

  /// Prefetch margin in logical pixels (dp). `null` when absent or null in the remote payload.
  /// Maps to `prefetchMarginDp` on Android and `prefetchMarginPoints` on iOS.
  final int? prefetchDistanceDp;

  Map<String, dynamic> toJson() => {
        'adType': adType,
        if (refreshTimeSeconds != null) 'refreshTimeSeconds': refreshTimeSeconds,
        if (prefetchDistanceDp != null) 'prefetchDistanceDp': prefetchDistanceDp,
      };
}
