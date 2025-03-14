/// Describes supported video bid response protocols
enum Protocol {
  vast1_0(0),
  vast2_0(1),
  vast3_0(2),
  vast1_0wrapper(3),
  vast2_0wrapper(4),
  vast3_0wrapper(5),
  vast4_0(6),
  vast4_0wrapper(7),
  daast1_0(8),
  daast1_0wrapper(9);

  const Protocol(this.code);

  final int code;

  static Protocol? fromCode(int code) {
    return switch (code) {
      0 => Protocol.vast1_0,
      1 => Protocol.vast2_0,
      2 => Protocol.vast3_0,
      3 => Protocol.vast1_0wrapper,
      4 => Protocol.vast2_0wrapper,
      5 => Protocol.vast3_0wrapper,
      6 => Protocol.vast4_0,
      7 => Protocol.vast4_0wrapper,
      8 => Protocol.daast1_0,
      9 => Protocol.daast1_0wrapper,
      _ => null,
    };
  }
}
