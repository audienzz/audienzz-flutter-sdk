/// Class for describing video bitrate
final class VideoBitrate {
  const VideoBitrate({
    required this.min,
    required this.max,
  });

  /// Minimum video bitrate in kbts
  final int min;

  /// Maximum video bitrate in kbts
  final int max;
}
