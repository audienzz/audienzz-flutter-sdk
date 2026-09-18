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

/// A page whose identity is its name.
///
/// This is the long-standing contract and the default everywhere: the
/// navigator observer, [AudienzzPage] and `pageImpression(name:)` all produce
/// the same id for the same name, so reporting a screen again matches the
/// banners already on it and refreshes them.
///
/// An earlier revision minted a fresh id per call. That silently broke the
/// contract — a second report of the same name released the screen's banners
/// instead of refreshing them, and they could never match again — and it made
/// the observer and the wrapper disagree about who owned a page.
AudienzzPageHandle createAudienzzPage(String name) =>
    AudienzzPageHandle(id: name, name: name);

int _managedSeq = 0;

/// A uniquely owned page instance, for the managed integration.
///
/// The managed components use this rather than [createAudienzzPage] so that two
/// article routes own their banners separately without the publisher having to
/// configure matching ids in two places — which would defeat the point of
/// providing a managed integration at all.
///
/// The legacy `pageImpression(name:)` keeps name identity, because reporting a
/// screen again must match the banners already on it. Compatibility is
/// preserved at the old API boundary, not by weakening the new one.
AudienzzPageHandle createManagedAudienzzPage(String name) {
  _managedSeq += 1;
  return AudienzzPageHandle(id: '$name#$_managedSeq', name: name);
}

/// A page identified by route instance rather than by name, so two routes that
/// share a screen name own their banners separately.
///
/// Opt-in, and it must be opted into on **both** sides: construct
/// [AudienzzNavigatorObserver] with `perInstance: true` and give the matching
/// [AudienzzPage] the same `id`, or the two will disagree.
AudienzzPageHandle audienzzPageForObject(Object instance, String name) =>
    AudienzzPageHandle(id: '$name#${identityHashCode(instance)}', name: name);
