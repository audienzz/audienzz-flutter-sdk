import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:equatable/equatable.dart';

/// Base class for all ads
abstract class Ad extends Equatable {
  const Ad({
    required this.adUnitId,
    required this.auConfigId,
  });

  /// An ID identifies your ad in the system.
  /// You should have a valid, active placement ID to monetize your app.
  final String adUnitId;

  /// An ID of the Stored Impression on the server.
  final String auConfigId;

  /// Function to free the resources used for ad
  Future<void> dispose() => adInstanceManager.disposeAd(this);

  @override
  List<Object?> get props => [adUnitId, auConfigId];
}
