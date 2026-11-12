import 'package:audienzz_sdk_flutter/src/entities/remote_config/adaptive_banner_config.dart';

class RemoteGamConfig {
  const RemoteGamConfig({
    required this.adUnitPath,
    required this.adSizes,
    this.adaptiveBannerConfig,
    this.includeFluid = false,
  });

  factory RemoteGamConfig.fromJson(Map<String, dynamic> json) {
    return RemoteGamConfig(
      adUnitPath: json['adUnitPath'] as String,
      adSizes: (json['adSizes'] as List).cast<String>(),
      adaptiveBannerConfig: json['adaptiveBannerConfig'] != null
          ? AdaptiveBannerConfig.fromJson(
              json['adaptiveBannerConfig'] as Map<String, dynamic>,
            )
          : null,
      // Read leniently, like the native SDKs: only a JSON `true` turns it on,
      // and a malformed value never costs the publisher the ad config.
      includeFluid: json['includeFluid'] == true,
    );
  }

  final String adUnitPath;
  final List<String> adSizes;
  final AdaptiveBannerConfig? adaptiveBannerConfig;

  /// Also ask GAM for the fluid size, next to [adSizes]: full slot width,
  /// height set by the creative (e.g. a fluid GAM native style). Prebid is
  /// unaffected and keeps bidding on `prebidConfig.adSizes`.
  final bool includeFluid;

  Map<String, dynamic> toJson() => {
        'adUnitPath': adUnitPath,
        'adSizes': adSizes,
        if (adaptiveBannerConfig != null)
          'adaptiveBannerConfig': adaptiveBannerConfig!.toJson(),
        if (includeFluid) 'includeFluid': true,
      };
}
