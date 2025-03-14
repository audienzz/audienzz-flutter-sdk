/// Describes supported playback methods
enum PlaybackMethod {
  autoPlaySoundOn(0),
  autoPlaySoundOff(1),
  clickToPlay(2),
  mouseOver(3),
  enterSoundOn(4),
  enterSoundOff(5);

  const PlaybackMethod(this.code);

  final int code;

  static PlaybackMethod? fromCode(int code) {
    return switch (code) {
      0 => PlaybackMethod.autoPlaySoundOn,
      1 => PlaybackMethod.autoPlaySoundOff,
      2 => PlaybackMethod.clickToPlay,
      3 => PlaybackMethod.mouseOver,
      4 => PlaybackMethod.enterSoundOn,
      5 => PlaybackMethod.enterSoundOff,
      _ => null,
    };
  }
}
