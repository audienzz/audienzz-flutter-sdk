import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_without_view.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/api_parameter.dart';
import 'package:audienzz_sdk_flutter/src/entities/reward_item.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/placement.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/playback_method.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/protocol.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_bitrate.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_duration.dart';

/// Class for work with rewarded ads
final class RewardedAd extends AdWithoutView {
  const RewardedAd({
    required super.adUnitId,
    required super.auConfigId,
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
    required this.onUserEarnedRewardCallback,
    this.apiParameters = const {ApiParameter.mraid3, ApiParameter.omid1},
    this.protocols = const {},
    this.placement = Placement.inBanner,
    this.playbackMethods = const {PlaybackMethod.enterSoundOff},
    this.videoBitrate = const VideoBitrate(min: 300, max: 1500),
    this.videoDuration = const VideoDuration(min: 1, max: 30),
    this.pbAdSlot,
    this.gpId,
    this.impOrtbConfig,
    this.onAdOpened,
    this.onAdClosed,
    this.onAdClicked,
    this.onAdImpression,
  });

  /// The property is dedicated to adding values for API Frameworks to a bid
  /// response according to the OpenRTB 2.5 spec.
  final Set<ApiParameter> apiParameters;

  /// Array or enum of OpenRTB 2.5 supported Protocols.
  final Set<Protocol> protocols;

  /// Placement type for the ad
  final Placement placement;

  ///Array of OpenRTB 2.5 playback methods. Only one method is typically used
  ///in practice. It is strongly advised to use only the
  ///[PlaybackMethod.autoPlaySoundOn]`
  final Set<PlaybackMethod> playbackMethods;

  /// The property representing the OpenRTB 2.5 bit rate in Kbps.
  final VideoBitrate videoBitrate;

  /// A property representing the OpenRTB 2.5 video ad duration in seconds.
  final VideoDuration videoDuration;

  /// PB Ad Slot is an identifier tied to the placement
  /// the ad will be delivered in.
  /// The use case for PB Ad Slot is to pass to exchange an ID they can use to
  /// tie to reporting systems or use for data science driven model building
  /// to match with impressions sourced from alternate integrations.
  /// A common ID to pass is the ad server slot name.
  final String? pbAdSlot;

  /// The Global Placement ID (GPID) is a key that uniquely identifies
  /// a specific instance of an adUnit.
  final String? gpId;

  /// Custom ortb object to be added on impression level
  final String? impOrtbConfig;

  /// A callback triggered when an ad is received.
  final void Function(RewardedAd ad) onAdLoaded;

  /// A callback triggered when an ad request failed.
  final void Function(RewardedAd ad, AdError? error) onAdFailedToLoad;

  /// A callback triggered when an ad opens an overlay that covers the screen.
  final void Function(RewardedAd ad)? onAdOpened;

  /// A callback triggered when the user is about to return to the app.
  final void Function(RewardedAd ad)? onAdClosed;

  /// A callback triggered when a click is recorded for an ad.
  final void Function(RewardedAd ad)? onAdClicked;

  /// A callback triggered when the ad has been on
  /// the screen for a minimum of 1 sec duration
  final void Function(RewardedAd ad)? onAdImpression;

  /// A callback that would be called when the
  /// ad conditions are met and user earned a reward
  final void Function(RewardedAd ad, RewardItem reward)
      onUserEarnedRewardCallback;

  /// Function to load this ad object
  Future<void> load() => adInstanceManager.loadRewardedAd(this);

  /// Function to show this ad, requires ad to be loaded before invoking
  /// In case of invoking before the ad is loaded error will be thrown
  Future<void> show() => adInstanceManager.showAdWithoutView(this);

  @override
  List<Object?> get props => [
        adUnitId,
        auConfigId,
        onAdLoaded,
        onAdFailedToLoad,
        onUserEarnedRewardCallback,
        onAdClicked,
        onAdImpression,
        onAdClosed,
        onAdOpened,
        apiParameters,
        protocols,
        placement,
        playbackMethods,
        videoBitrate,
        videoDuration,
        pbAdSlot,
        gpId,
        impOrtbConfig,
      ];
}
