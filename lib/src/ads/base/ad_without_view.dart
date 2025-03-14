import 'package:audienzz_sdk_flutter/src/ads/base/ad.dart';

/// Base class for the ads that do not require view to be shown as widget
abstract class AdWithoutView extends Ad {
  const AdWithoutView({
    required super.adUnitId,
    required super.auConfigId,
  });
}
