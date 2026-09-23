class RemotePrebidConfig {
  const RemotePrebidConfig({
    required this.placementId,
    required this.adSizes,
    this.format,
    this.apis,
  });

  /// Both interstitial fields are read leniently: a malformed value becomes
  /// "not configured", so the native SDK applies its default, rather than
  /// throwing and dropping the placement's whole config.
  factory RemotePrebidConfig.fromJson(Map<String, dynamic> json) {
    final format = json['format'];
    final apis = json['apis'];
    return RemotePrebidConfig(
      placementId: json['placementId'] as String,
      adSizes: (json['adSizes'] as List).cast<String>(),
      format: format is String ? format : null,
      apis: apis is List
          ? [
              for (final api in apis)
                if (api is num &&
                    api == api.truncate() &&
                    api.abs() <= 0x7fffffff)
                  api.toInt(),
            ]
          : null,
    );
  }

  final String placementId;
  final List<String> adSizes;

  /// Interstitials: the media formats the bid request asks for — `banner`,
  /// `video` or `bannerAndVideo`. The raw backend value; the native SDK
  /// validates it. `null` when absent or not a string.
  final String? format;

  /// Interstitials: the OpenRTB API framework ids the impression advertises.
  /// Only integral numbers are kept; `null` when absent or not a list. The
  /// native SDK validates them like [format].
  final List<int>? apis;

  Map<String, dynamic> toJson() => {
        'placementId': placementId,
        'adSizes': adSizes,
        if (format != null) 'format': format,
        if (apis != null) 'apis': apis,
      };
}
