import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';

final class PpidManager {
  const PpidManager._();

  /// Supply your own PPID (e.g. a hashed e-mail address). It takes precedence
  /// over the SDK-generated one; pass `null` to clear and fall back to it.
  static Future<void> setPublisherPpid(String? ppid) async {
    return adInstanceManager.methodChannel
        .invokeMethod<void>('setPublisherPpid', {'ppid': ppid});
  }

  /// The PPID currently being sent: yours if set via [setPublisherPpid],
  /// otherwise the SDK-generated UUID. `null` only when consent is missing.
  ///
  /// A PPID is always sent with ad requests — the SDK generates one (persisted
  /// locally, rotated every 12 months) whenever you haven't supplied your own.
  /// There is no enable/disable switch.
  static Future<String?> getPpid() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getPpid',
    );
  }
}
