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
    this.ppidEnabled,
    this.automaticPpidEnabled,
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
      ppidEnabled: json['ppidEnabled'] as bool?,
      automaticPpidEnabled: json['automaticPpidEnabled'] as bool?,
    );
  }

  final int id;
  final PrebidServer prebidServer;
  final Ortb ortb;
  final AndroidConfig? android;
  final IosConfig? ios;

  /// Master backend switch for Publisher Provided Identifiers. `false` suppresses every PPID,
  /// including one the app supplied through [PpidManager.setPublisherPpid] — it is a per-publisher
  /// privacy switch, not a preference. Absent/null → enabled.
  final bool? ppidEnabled;

  /// Backend switch for the SDK-generated PPID only. `false` stops the SDK minting and rotating
  /// its own UUID; a PPID the app supplied is still sent. Absent/null → enabled.
  final bool? automaticPpidEnabled;

  Map<String, dynamic> toJson() => {
        'id': id,
        'prebidServer': prebidServer.toJson(),
        'ortb': ortb.toJson(),
        if (android != null) 'android': android!.toJson(),
        if (ios != null) 'ios': ios!.toJson(),
        if (ppidEnabled != null) 'ppidEnabled': ppidEnabled,
        if (automaticPpidEnabled != null)
          'automaticPpidEnabled': automaticPpidEnabled,
      };
}
