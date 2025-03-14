/// Defines producer of the content
/// in which the ad will be shown
final class ProducerObject {
  const ProducerObject({
    this.id,
    this.name,
    this.domain,
    this.categories,
  });

  /// Content producer or originator ID.
  final String? id;

  /// Content producer or originator name
  final String? name;

  /// Highest level domain of the content producer.
  final String? domain;

  /// Array of IAB content categories that describe the content producer.
  final List<String>? categories;
}
