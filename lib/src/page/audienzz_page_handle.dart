/// A page instance.
///
/// [id] is identity and [name] is what analytics records, and they are
/// different things: a name repeats — two article routes are both "article" —
/// while ownership must not. When the name is used as identity, the second
/// article's page impression matches the first article's banners and recreates
/// them instead of releasing them, so they keep auctioning for a screen the
/// reader has left.
class AudienzzPageHandle {
  const AudienzzPageHandle({required this.id, required this.name});

  /// Identity. Sent to native as the page token and matched against a banner's
  /// page key.
  final String id;

  /// What analytics records. May repeat freely.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is AudienzzPageHandle && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'AudienzzPageHandle($id, "$name")';
}

int _pageSeq = 0;

/// Mint a page instance. Call once per route instance.
AudienzzPageHandle createAudienzzPage(String name) {
  _pageSeq += 1;
  return AudienzzPageHandle(id: '$name#$_pageSeq', name: name);
}

/// Mint a page instance whose identity comes from an existing object — a
/// `Route`, a tab controller, any per-instance thing the host already has.
/// Two routes with the same name produce different ids.
AudienzzPageHandle audienzzPageForObject(Object instance, String name) =>
    AudienzzPageHandle(id: '$name#${identityHashCode(instance)}', name: name);
