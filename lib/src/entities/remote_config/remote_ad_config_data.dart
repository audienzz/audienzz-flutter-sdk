class RemoteAdConfigData {
  const RemoteAdConfigData({
    required this.adType,
    this.refreshTimeSeconds,
    this.prefetchDistanceDp,
    this.lazyLoad,
    this.resizeToPrebidCreative,
    this.stickyMaxHeight,
    this.stickyTopOffset,
    this.preloadDistancePages,
    this.refreshOnBack = false,
  });

  factory RemoteAdConfigData.fromJson(Map<String, dynamic> json) {
    return RemoteAdConfigData(
      adType: json['adType'] as String,
      // decodeIfPresent equivalent: returns null for both absent keys and JSON null,
      // so callers apply a default via the null-coalescing operator.
      refreshTimeSeconds: json['refreshTimeSeconds'] as int?,
      prefetchDistanceDp: json['prefetchDistanceDp'] as int?,
      lazyLoad: json['lazyLoad'] as bool?,
      resizeToPrebidCreative: json['resizeToPrebidCreative'] as bool?,
      stickyMaxHeight: json['stickyMaxHeight'] as int?,
      stickyTopOffset: json['stickyTopOffset'] as int?,
      // Lenient: anything but a non-negative whole number is treated as absent
      // and never fails the ad config, so a malformed value only costs the
      // backend override, not the placement.
      preloadDistancePages: _nonNegativeInt(json['preloadDistancePages']),
      // Only a JSON boolean `true` turns it on.
      refreshOnBack: json['refreshOnBack'] == true,
    );
  }

  final String adType;

  /// Seconds between auto-refresh cycles. `null` when absent or null in the remote payload.
  final int? refreshTimeSeconds;

  /// Prefetch margin in logical pixels (dp). `null` when absent or null in the remote payload.
  /// Maps to `prefetchMarginDp` on Android and `prefetchMarginPoints` on iOS.
  final int? prefetchDistanceDp;

  /// Whether the banner defers its auction until it approaches the viewport.
  /// `null` when absent or null in the remote payload; the SDK default applies.
  final bool? lazyLoad;

  /// Whether a banner whose Prebid creative rendered is sized to the winning
  /// Prebid bid (`hb_size`) instead of the GAM creative it was rendered in,
  /// e.g. a 300x250 Prebid ad that GAM placed in a 300x600 creative, or a
  /// 300x600 one placed in a 300x250 creative. A creative GAM served itself
  /// keeps GAM's size. `null` (absent) means on; `false` opts the placement
  /// out.
  final bool? resizeToPrebidCreative;

  /// Reserved height (dp/pt) for [AudienzzStickyAdWrapper].
  /// `null` falls back to the SDK default (600).
  final int? stickyMaxHeight;

  /// Y offset (dp/pt) from the scroll viewport top where the sticky ad pins.
  /// `null` falls back to 0 (or the scroll view's safe-area padding on iOS).
  final int? stickyTopOffset;

  /// How many pages (ePaper tiles) before the reader reaches it an
  /// `AudienzzGalleryAd` slot requests its ad. `null` when absent, negative or
  /// not a whole number; `AudienzzGalleryAds` then uses its local default (2).
  final int? preloadDistancePages;

  /// Gallery ads: reload the slot's ad when the reader comes back to the
  /// gallery (an article closed, the app back from the background), like every
  /// other banner. `false` (the default, and anything but a JSON `true`) keeps
  /// the ad across leaving and returning.
  final bool refreshOnBack;

  /// Same bounds as the native SDKs (a 32-bit Int): a larger number, or a
  /// non-finite one (`1e309` decodes to infinity), is treated as absent.
  static const _maxInt32 = 2147483647;

  static int? _nonNegativeInt(Object? value) {
    if (value is int) {
      return value >= 0 && value <= _maxInt32 ? value : null;
    }
    if (value is double &&
        value.isFinite &&
        value >= 0 &&
        value <= _maxInt32 &&
        value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'adType': adType,
        if (refreshTimeSeconds != null) 'refreshTimeSeconds': refreshTimeSeconds,
        if (prefetchDistanceDp != null) 'prefetchDistanceDp': prefetchDistanceDp,
        if (lazyLoad != null) 'lazyLoad': lazyLoad,
        if (resizeToPrebidCreative != null)
          'resizeToPrebidCreative': resizeToPrebidCreative,
        if (stickyMaxHeight != null) 'stickyMaxHeight': stickyMaxHeight,
        if (stickyTopOffset != null) 'stickyTopOffset': stickyTopOffset,
        if (preloadDistancePages != null)
          'preloadDistancePages': preloadDistancePages,
        if (refreshOnBack) 'refreshOnBack': true,
      };
}
