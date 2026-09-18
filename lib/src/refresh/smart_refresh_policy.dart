import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Which viewport gate smart refresh uses, resolved once for Dart, the
/// platform bridges and the native SDKs so all three agree.
///
/// The public switch used to forward the override to native and stop there.
/// Flutter's own gate stayed on the v1 threshold, Android never enables the
/// native gate at all, and the iOS bridge polls with its own v1 rule — so
/// turning v2 on changed nothing a Flutter publisher could observe.
///
/// Precedence matches the native SDKs: explicit override, then the backend
/// publisher config, then v1.
class SmartRefreshPolicy {
  SmartRefreshPolicy._();

  static final SmartRefreshPolicy instance = SmartRefreshPolicy._();

  bool? _override;

  /// Set by `AudienzzSdkFlutter.setSmartRefreshV2Enabled`. `null` defers to
  /// the backend value.
  void setOverride(bool? enabled) => _override = enabled;

  /// The resolved gate for this session.
  bool get isV2Enabled =>
      _override ??
      AudienzzRemoteConfig.instance.publisherConfig?.smartRefreshV2 ??
      false;

  @visibleForTesting
  void resetForTesting() => _override = null;
}
