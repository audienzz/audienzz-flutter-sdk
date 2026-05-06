/// Describes SDK initialization status
enum InitializationStatus {
  success(0),
  fail(1),
  fallbackPolling(2);

  const InitializationStatus(this.code);

  final int code;

  static InitializationStatus? fromCode(int code) {
    return switch (code) {
      0 => InitializationStatus.success,
      1 => InitializationStatus.fail,
      2 => InitializationStatus.fallbackPolling,
      _ => null,
    };
  }
}
