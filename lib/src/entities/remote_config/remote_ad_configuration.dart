import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_config_data.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_gam_config.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_prebid_config.dart';

class RemoteAdConfiguration {
  const RemoteAdConfiguration({
    required this.id,
    required this.config,
    required this.gamConfig,
    required this.prebidConfig,
  });

  factory RemoteAdConfiguration.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int ? idRaw.toString() : idRaw as String;

    return RemoteAdConfiguration(
      id: id,
      config: RemoteAdConfigData.fromJson(
        json['config'] as Map<String, dynamic>,
      ),
      gamConfig: RemoteGamConfig.fromJson(
        json['gamConfig'] as Map<String, dynamic>,
      ),
      prebidConfig: RemotePrebidConfig.fromJson(
        json['prebidConfig'] as Map<String, dynamic>,
      ),
    );
  }

  final String id;
  final RemoteAdConfigData config;
  final RemoteGamConfig gamConfig;
  final RemotePrebidConfig prebidConfig;

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'gamConfig': gamConfig.toJson(),
        'prebidConfig': prebidConfig.toJson(),
      };
}
