import 'package:audienzz_sdk_flutter/src/entities/remote_config/android_config.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/ios_config.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/ortb.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/prebid_server.dart';

class RemotePublisherConfiguration {
  const RemotePublisherConfiguration({
    required this.id,
    required this.prebidServer,
    required this.ortb,
    this.android,
    this.ios,
  });

  factory RemotePublisherConfiguration.fromJson(Map<String, dynamic> json) {
    return RemotePublisherConfiguration(
      id: json['id'] as int,
      prebidServer: PrebidServer.fromJson(
        json['prebidServer'] as Map<String, dynamic>,
      ),
      ortb: Ortb.fromJson(json['ortb'] as Map<String, dynamic>),
      android: json['android'] != null
          ? AndroidConfig.fromJson(json['android'] as Map<String, dynamic>)
          : null,
      ios: json['ios'] != null
          ? IosConfig.fromJson(json['ios'] as Map<String, dynamic>)
          : null,
    );
  }

  final int id;
  final PrebidServer prebidServer;
  final Ortb ortb;
  final AndroidConfig? android;
  final IosConfig? ios;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prebidServer': prebidServer.toJson(),
        'ortb': ortb.toJson(),
        if (android != null) 'android': android!.toJson(),
        if (ios != null) 'ios': ios!.toJson(),
      };
}
