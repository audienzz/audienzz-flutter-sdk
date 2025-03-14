/// Describes supported ad formats
enum AdFormat {
  banner(0),
  video(1),
  bannerAndVideo(2);

  const AdFormat(this.code);

  final int code;

  static AdFormat? fromCode(int code) {
    return switch (code) {
      0 => AdFormat.banner,
      1 => AdFormat.video,
      2 => AdFormat.bannerAndVideo,
      _ => null,
    };
  }
}
