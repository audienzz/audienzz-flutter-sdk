/// Describes supported placement types
enum Placement {
  inStream(0),
  inBanner(1),
  inArticle(2),
  inFeed(3),
  interstitial(4),
  slider(5),
  floating(6);

  const Placement(this.code);

  final int code;

  static Placement? fromCode(int code) {
    return switch (code) {
      0 => Placement.inStream,
      1 => Placement.inBanner,
      2 => Placement.inArticle,
      3 => Placement.inFeed,
      4 => Placement.interstitial,
      5 => Placement.slider,
      6 => Placement.floating,
      _ => null,
    };
  }
}
