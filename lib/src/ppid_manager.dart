import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/failed_to_get_automatic_ppid_exception.dart';

final class PpidManager {
  const PpidManager._();

  /// Check if automatic PPID is enabled
  static Future<bool> isAutomaticPpidEnabled() async {
    final isAutomaticPpidEnabled =
        await adInstanceManager.methodChannel.invokeMethod<bool>(
      'isAutomaticPpidEnabled',
    );

    if (isAutomaticPpidEnabled != null) {
      return isAutomaticPpidEnabled;
    } else {
      throw const FailedToGetAutomaticPpidException();
    }
  }

  /// Used to enable or disable automatic PPID usage
  static Future<void> setAutomaticPpidEnabled({
    required bool isAutomaticPpidEnabled,
  }) async {
    return adInstanceManager.methodChannel
        .invokeMethod<void>('setAutomaticPpidEnabled', {
      'isAutomaticPpidEnabled': isAutomaticPpidEnabled,
    });
  }

  /// Used to obtain PPID if automaticPpid is enabled
  static Future<String?> getPpid() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getPpid',
    );
  }

  /// Sets a publisher-provided PPID value (e.g. a hashed user account ID).
  /// When set, this value is sent on every ad request instead of the auto-generated UUID.
  /// Pass null to clear and fall back to UUID generation.
  static Future<void> setPpid(String? ppid) async {
    return adInstanceManager.methodChannel.invokeMethod<void>(
      'setPpid',
      {'ppid': ppid},
    );
  }
}
