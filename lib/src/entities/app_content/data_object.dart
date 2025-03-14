import 'package:audienzz_sdk_flutter/src/entities/app_content/data_object_segment.dart';

/// Defines additional data about the related object
/// (e.g. user, content) to be specified
final class DataObject {
  const DataObject({
    this.id,
    this.name,
    this.segments,
  });

  /// Exchange-specific ID for the data provider
  final String? id;

  /// Exchange-specific name for the data provider
  final String? name;

  /// Segment objects are essentially key-value pairs
  /// that convey specific units of data
  final List<DataObjectSegment>? segments;
}
