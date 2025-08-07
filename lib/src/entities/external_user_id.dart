import 'package:audienzz_sdk_flutter/src/entities/unique_id.dart';

final class ExternalUserId {
  const ExternalUserId({
    required this.source,
    required this.uniqueIds,
  });

  factory ExternalUserId.fromMap(Map<dynamic, dynamic> map) {
    return ExternalUserId(
      source: map['source'] as String,
      uniqueIds: (map['uniqueIds'] as List<dynamic>)
          .map((e) => UniqueId.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  final String source;
  final List<UniqueId> uniqueIds;

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'uniqueIds': uniqueIds.map((e) => e.toMap()).toList(),
    };
  }
}
