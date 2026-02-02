import 'package:audienzz_sdk_flutter/src/entities/remote_config/android_ortb.dart';

class AndroidConfig {
  const AndroidConfig({
    required this.ortb,
  });

  factory AndroidConfig.fromJson(Map<String, dynamic> json) {
    return AndroidConfig(
      ortb: AndroidOrtb.fromJson(json['ortb'] as Map<String, dynamic>),
    );
  }

  final AndroidOrtb ortb;

  Map<String, dynamic> toJson() => {
        'ortb': ortb.toJson(),
      };
}
