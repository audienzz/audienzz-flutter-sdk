final class UniqueId {
  const UniqueId({
    required this.id,
    this.atype,
    this.ext,
  });

  factory UniqueId.fromMap(Map<dynamic, dynamic> map) {
    return UniqueId(
      id: map['id'] as String,
      atype: map['atype'] as int?,
      ext: map['ext'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final int? atype;
  final Map<String, dynamic>? ext;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'atype': atype,
      'ext': ext,
    };
  }
}
