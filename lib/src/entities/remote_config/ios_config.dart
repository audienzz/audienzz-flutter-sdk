import 'package:audienzz_sdk_flutter/src/entities/remote_config/ios_ortb.dart';

class IosConfig {
  const IosConfig({
    required this.ortb,
  });

  factory IosConfig.fromJson(Map<String, dynamic> json) {
    return IosConfig(
      ortb: IosOrtb.fromJson(json['ortb'] as Map<String, dynamic>),
    );
  }

  final IosOrtb ortb;

  Map<String, dynamic> toJson() => {
        'ortb': ortb.toJson(),
      };
}
