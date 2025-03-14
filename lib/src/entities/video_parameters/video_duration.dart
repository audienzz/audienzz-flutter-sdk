/// Class for describing video duration
final class VideoDuration {
  const VideoDuration({
    required this.min,
    required this.max,
  });

  /// Minimum video duration in seconds
  final int min;

  /// Maximum video duration in seconds
  final int max;
}
