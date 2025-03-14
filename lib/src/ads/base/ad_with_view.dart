import 'package:audienzz_sdk_flutter/src/ads/base/ad.dart';

/// Base class for ads that require view to be shown as widget
abstract class AdWithView extends Ad {
  const AdWithView({
    required super.adUnitId,
    required super.auConfigId,
  });

  /// Function to load this ad object
  Future<void> load();
}
