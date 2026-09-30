/// Class for describing errors
final class AdError {
  const AdError({
    required this.code,
    required this.message,
    this.domain,
  });

  /// Error code
  final int code;

  /// Native error domain, when supplied by a presentation failure.
  final String? domain;

  /// Descriptive message for the error
  final String message;

  @override
  String toString() => 'AdError(code: $code, message: $message)';
}
