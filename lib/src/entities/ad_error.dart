/// Class for describing errors
final class AdError {
  const AdError({
    required this.code,
    required this.message,
  });

  /// Error code
  final int code;

  /// Descriptive message for the error
  final String message;
}
