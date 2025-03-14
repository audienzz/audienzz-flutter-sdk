import 'package:audienzz_sdk_flutter/src/entities/app_content/data_object.dart';
import 'package:audienzz_sdk_flutter/src/entities/app_content/producer_object.dart';

/// Describes an [OpenRTB](https://www.iab.com/wp-content/uploads/2016/03/OpenRTB-API-Specification-Version-2-5-FINAL.pdf)
/// appContent object
final class AppContent {
  const AppContent({
    this.id,
    this.episode,
    this.title,
    this.series,
    this.season,
    this.artist,
    this.genre,
    this.album,
    this.isrc,
    this.url,
    this.categories,
    this.productionQuality,
    this.context,
    this.contentRating,
    this.userRating,
    this.qaMediaRating,
    this.keywordsString,
    this.liveStream,
    this.sourceRelationship,
    this.length,
    this.language,
    this.embeddable,
    this.dataObjects,
    this.producerObject,
  });

  /// ID uniquely identifying the content
  final String? id;

  /// Episode number
  final int? episode;

  /// Content title
  final String? title;

  /// Content series
  final String? series;

  /// Content season
  final String? season;

  /// Artist credited with the content
  final String? artist;

  /// Genre that best describes the content
  final String? genre;

  /// Album to which the content belongs; typically for audio
  final String? album;

  /// International Standard Recording Code conforming to ISO- 3901
  final String? isrc;

  /// URL of the content, for buy-side contextualization or review
  final String? url;

  /// Array of IAB content categories that describe the content producer
  final List<String>? categories;

  /// Production quality.
  final int? productionQuality;

  /// Type of content (game, video, text, etc.)
  final int? context;

  /// Content rating
  final String? contentRating;

  /// User rating of the content
  final String? userRating;

  /// Media rating per IQG guidelines
  final int? qaMediaRating;

  /// Comma separated list of keywords describing the content
  final String? keywordsString;

  /// 0 = not live, 1 = content is live
  final int? liveStream;

  /// 0 = indirect, 1 = direct
  final int? sourceRelationship;

  /// Length of content in seconds; appropriate for video or audio
  final int? length;

  /// Content language using ISO-639-1-alpha-2
  final String? language;

  /// Indicator of whether or not the content is embeddable (e.g.,
  /// an embeddable video player), where 0 = no, 1 = yes
  final int? embeddable;

  /// The data and segment objects together allow additional data
  /// about the related object (e.g. user, content) to be specified
  final List<DataObject>? dataObjects;

  /// This object defines the producer of the content
  /// in which the ad will be shown
  final ProducerObject? producerObject;
}
