import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';

abstract final class Constants {
  const Constants._();

  static const exampleAppContent = AppContent(
    id: '123',
    episode: 1,
    title: 'Example Title',
    series: 'Example Series',
    season: 'Example Season',
    artist: 'Example Artist',
    genre: 'Example Genre',
    album: 'Example Album',
    isrc: '123456',
    url: 'https://example.com',
    categories: ['Category1', 'Category2'],
    productionQuality: 5,
    context: 1,
    contentRating: 'PG',
    userRating: '4.5',
    qaMediaRating: 3,
    keywordsString: 'example,keywords',
    liveStream: 0,
    sourceRelationship: 1,
    length: 120,
    language: 'English',
    embeddable: 0,
    dataObjects: [
      DataObject(
        id: '456',
        name: 'Data Object',
        segments: [
          DataObjectSegment(
            id: 'segment1',
            name: 'Segment 1',
            value: 'Value 1',
          ),
          DataObjectSegment(
            id: 'segment2',
            name: 'Segment 2',
            value: 'Value 2',
          ),
        ],
      ),
    ],
    producerObject: ProducerObject(
      id: '789',
      name: 'Producer Object',
      domain: 'example.com',
      categories: ['Category3', 'Category4'],
    ),
  );
}
