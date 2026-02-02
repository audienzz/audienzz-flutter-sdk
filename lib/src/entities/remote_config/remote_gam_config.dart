import 'package:audienzz_sdk_flutter/src/entities/remote_config/adaptive_banner_config.dart';

class RemoteGamConfig {
  const RemoteGamConfig({
    required this.adUnitPath,
    required this.adSizes,
    this.adaptiveBannerConfig,
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
    );
  }

  final String adUnitPath;
  final List<String> adSizes;
  final AdaptiveBannerConfig? adaptiveBannerConfig;

  Map<String, dynamic> toJson() => {
        'adUnitPath': adUnitPath,
        'adSizes': adSizes,
        if (adaptiveBannerConfig != null)
          'adaptiveBannerConfig': adaptiveBannerConfig!.toJson(),
      };
}
