class RemoteAdConfigData {
  const RemoteAdConfigData({
    required this.adType,
    this.refreshTimeSeconds,
    this.prefetchDistanceDp,
    this.stickyMaxHeight,
    this.stickyTopOffset,
  });

  factory RemoteAdConfigData.fromJson(Map<String, dynamic> json) {
    return RemoteAdConfigData(
      adType: json['adType'] as String,
      // decodeIfPresent equivalent: returns null for both absent keys and JSON null,
      // so callers apply a default via the null-coalescing operator.
      refreshTimeSeconds: json['refreshTimeSeconds'] as int?,
      prefetchDistanceDp: json['prefetchDistanceDp'] as int?,
      stickyMaxHeight: json['stickyMaxHeight'] as int?,
      stickyTopOffset: json['stickyTopOffset'] as int?,
    );
  }

  final String adType;

  /// Seconds between auto-refresh cycles. `null` when absent or null in the remote payload.
  final int? refreshTimeSeconds;

  /// Prefetch margin in logical pixels (dp). `null` when absent or null in the remote payload.
  /// Maps to `prefetchMarginDp` on Android and `prefetchMarginPoints` on iOS.
  final int? prefetchDistanceDp;

  /// Reserved height (dp/pt) for [AudienzzStickyAdWrapper].
  /// `null` falls back to the SDK default (600).
  final int? stickyMaxHeight;

  /// Y offset (dp/pt) from the scroll viewport top where the sticky ad pins.
  /// `null` falls back to 0 (or the scroll view's safe-area padding on iOS).
  final int? stickyTopOffset;

  Map<String, dynamic> toJson() => {
        'adType': adType,
        if (refreshTimeSeconds != null) 'refreshTimeSeconds': refreshTimeSeconds,
        if (prefetchDistanceDp != null) 'prefetchDistanceDp': prefetchDistanceDp,
        if (stickyMaxHeight != null) 'stickyMaxHeight': stickyMaxHeight,
        if (stickyTopOffset != null) 'stickyTopOffset': stickyTopOffset,
      };
}
