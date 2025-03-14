/// Describes supported API frameworks for the ad
enum ApiParameter {
  vpaid1(0),
  vpaid2(1),
  mraid1(2),
  ormma(3),
  mraid2(4),
  mraid3(5),
  omid1(6);

  const ApiParameter(this.code);

  final int code;

  static ApiParameter? fromCode(int code) {
    return switch (code) {
      0 => ApiParameter.vpaid1,
      1 => ApiParameter.vpaid2,
      2 => ApiParameter.mraid1,
      3 => ApiParameter.ormma,
      4 => ApiParameter.mraid2,
      5 => ApiParameter.mraid3,
      6 => ApiParameter.omid1,
      _ => null,
    };
  }
}
