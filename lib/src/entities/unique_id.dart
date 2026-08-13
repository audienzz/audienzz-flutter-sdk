final class UniqueId {
  const UniqueId({
    required this.id,
    this.atype,
    this.ext,
  });

  factory UniqueId.fromMap(Map<dynamic, dynamic> map) {
    final ext = map['ext'];
    return UniqueId(
      id: map['id'] as String,
      atype: map['atype'] as int?,
      // The platform codec delivers Map<Object?, Object?>; a direct
      // `as Map<String, dynamic>?` cast throws. Convert element-wise.
      ext: ext == null ? null : Map<String, dynamic>.from(ext as Map),
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
