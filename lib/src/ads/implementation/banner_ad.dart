import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_with_view.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_format.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/api_parameter.dart';
import 'package:audienzz_sdk_flutter/src/entities/app_content/app_content.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/placement.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/playback_method.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/protocol.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_bitrate.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_duration.dart';

/// Class for work with banner ads
final class BannerAd extends AdWithView {
  const BannerAd({
    required this.size,
    required super.adUnitId,
    required super.auConfigId,
    required this.onAdLoaded,
    required this.onAdFailedToLoad,
    this.adFormat = AdFormat.banner,
    this.apiParameters = const {ApiParameter.mraid3, ApiParameter.omid1},
    this.protocols = const {},
    this.placement = Placement.inBanner,
    this.playbackMethods = const {PlaybackMethod.autoPlaySoundOn},
    this.videoBitrate = const VideoBitrate(min: 300, max: 1500),
    this.videoDuration = const VideoDuration(min: 1, max: 30),
    this.pbAdSlot,
    this.gpId,
    this.keyword,
    this.keywords = const [],
    this.appContent,
    this.onAdClicked,
    this.onAdClosed,
    this.onAdOpened,
    this.onAdImpression,
    this.isAdaptiveSize = false,
    this.refreshTimeInterval,
  });

  /// Specify width and height of the ad unit, will be used in a bid request
  final AdSize size;

  /// Specify if the ad size should be adaptive, by default - false
  final bool isAdaptiveSize;

  /// Specify refresh time in milliseconds for the ad
  final int? refreshTimeInterval;

  /// Ad desired format, [AdFormat.banner], [AdFormat.video]
  /// or [AdFormat.bannerAndVideo] (used by multiformat banner ads)
  final AdFormat adFormat;

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

  /// This the context keyword for adUnit context targeting.
  /// Inserts the given element in the set if it is not already present.
  final String? keyword;

  /// This the context keyword set for adUnit context targeting.
  /// Adds the elements of the given set to the set.
  final List<String> keywords;

  /// Describes an [OpenRTB](https://www.iab.com/wp-content/uploads/2016/03/OpenRTB-API-Specification-Version-2-5-FINAL.pdf)
  /// appContent object
  final AppContent? appContent;

  /// A callback triggered when an ad is received.
  final void Function(BannerAd ad) onAdLoaded;

  /// A callback triggered when an ad request failed.
  final void Function(BannerAd ad, AdError? error) onAdFailedToLoad;

  /// A callback triggered when an ad opens an overlay that covers the screen.
  final void Function(BannerAd ad)? onAdOpened;

  /// A callback triggered when the user is about to return to the app.
  final void Function(BannerAd ad)? onAdClosed;

  /// A callback triggered when a click is recorded for an ad.
  final void Function(BannerAd ad)? onAdClicked;

  /// A callback triggered when the ad has been on
  /// the screen for a minimum of 1 sec duration
  final void Function(BannerAd ad)? onAdImpression;

  /// Function to load this ad object
  @override
  Future<void> load() => adInstanceManager.loadBannerAd(this);

  @override
  List<Object?> get props => [
        adUnitId,
        auConfigId,
        size,
        onAdLoaded,
        onAdFailedToLoad,
        onAdImpression,
        onAdOpened,
        onAdClosed,
        onAdClicked,
        isAdaptiveSize,
        refreshTimeInterval,
        adFormat,
        apiParameters,
        protocols,
        placement,
        playbackMethods,
        videoBitrate,
        videoDuration,
        pbAdSlot,
        gpId,
        keyword,
        keywords,
        appContent,
      ];
}
