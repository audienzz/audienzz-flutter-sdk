import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_diagnostics.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:audienzz_sdk_flutter/src/widgets/ad_widget.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One ad placement inside a [PageView], for [AudienzzGalleryAds].
@immutable
class AudienzzGalleryAdSlot {
  const AudienzzGalleryAdSlot({
    required this.slotKey,
    required this.adConfigId,
    required this.pageIndex,
  });

  /// Stable identity of the slot within its gallery. The tile shows it with
  /// `AudienzzGalleryAd(slotKey: …)`. Must be unique among the gallery's slots.
  final String slotKey;

  /// Remote configuration id, as for `AudienzzBanner` / `RemoteBannerAd`: the
  /// ad unit, sizes, refresh and the preload distance come from it.
  final String adConfigId;

  /// Index of the [PageView] page (ePaper tile) that shows this slot.
  final int pageIndex;

  @override
  bool operator ==(Object other) =>
      other is AudienzzGalleryAdSlot &&
      other.slotKey == slotKey &&
      other.adConfigId == adConfigId &&
      other.pageIndex == pageIndex;

  @override
  int get hashCode => Object.hash(slotKey, adConfigId, pageIndex);

  @override
  String toString() =>
      'AudienzzGalleryAdSlot($slotKey, config: $adConfigId, page: $pageIndex)';
}

/// Preloads the ads of a horizontally paged screen (an ePaper: one tile per
/// printed page) a few pages before the reader reaches them.
///
/// A [PageView] builds only the page on screen, so an ad tile further along
/// does not exist until the reader swipes to it. Requesting the ad then is too
/// late — the reader swipes past before it arrives — and requesting every ad
/// slot when the screen opens buys ads for tiles most readers never reach.
/// This widget owns the slots' ads instead of the tiles: each slot requests its
/// ad once the reader is within its preload distance, keeps it while the tiles
/// are built and disposed, and an [AudienzzGalleryAd] in the tile shows it.
///
/// The preload distance is the ad config's `config.preloadDistancePages`,
/// [defaultPreloadDistancePages] when the ad config does not set it. Distance
/// is counted in pages in both directions, from the page the reader is on
/// (fractional while swiping).
///
/// Refresh is the ad config's `refreshTimeSeconds`, as for a `RemoteBanner`,
/// counted only while the ad's tile is on screen.
///
/// Like `AudienzzBanner` it must be built inside an [AudienzzPage], and ads are
/// requested only while that page is active. Unlike `AudienzzBanner`, a gallery
/// ad is not reloaded when the reader leaves the page and comes back (an
/// article opened on top, the app sent to the background): it is paused while
/// the page is away and shown again on return, with its refresh resuming where
/// it stopped — unless the slot's ad config sets `config.refreshOnBack: true`,
/// which reloads it on return like an `AudienzzBanner`. Swiping between tiles
/// is not a page impression; the whole gallery is one page.
///
/// ```dart
/// AudienzzPage(
///   name: 'epaper',
///   child: AudienzzGalleryAds(
///     controller: pageController,
///     slots: const [
///       AudienzzGalleryAdSlot(
///           slotKey: 'epaper-1', adConfigId: '123', pageIndex: 4),
///       AudienzzGalleryAdSlot(
///           slotKey: 'epaper-2', adConfigId: '124', pageIndex: 12),
///     ],
///     child: PageView.builder(
///       controller: pageController,
///       itemCount: tiles.length,
///       itemBuilder: (context, index) => switch (index) {
///         4 => const AudienzzGalleryAd(slotKey: 'epaper-1'),
///         12 => const AudienzzGalleryAd(slotKey: 'epaper-2'),
///         _ => EpaperTile(tiles[index]),
///       },
///     ),
///   ),
/// )
/// ```
class AudienzzGalleryAds extends StatefulWidget {
  const AudienzzGalleryAds({
    required this.controller,
    required this.slots,
    required this.child,
    this.onAdLoaded,
    this.onAdSizeChanged,
    this.onAdFailedToLoad,
    super.key,
  });

  /// Pages ahead (and behind) of the reader at which a slot requests its ad
  /// when the ad config has no `config.preloadDistancePages`.
  static const int defaultPreloadDistancePages = 2;

  /// The preload distance for [adConfigId]: the ad config's
  /// `config.preloadDistancePages`, else [defaultPreloadDistancePages].
  static int preloadDistanceFor(String adConfigId) =>
      AudienzzRemoteConfig.instance
          .remoteConfigFor(adConfigId)
          ?.config
          .preloadDistancePages ??
      defaultPreloadDistancePages;

  /// The controller of the [PageView] in [child]. Its page decides which
  /// slots are within their preload distance.
  final PageController controller;

  /// The ad slots in the gallery. Slots are matched by
  /// [AudienzzGalleryAdSlot.slotKey] across rebuilds: changing a slot's
  /// `adConfigId` replaces its ad, changing only its `pageIndex` keeps the ad
  /// already loaded.
  final List<AudienzzGalleryAdSlot> slots;

  /// The pager, usually the [PageView] driven by [controller].
  final Widget child;

  /// A slot received a creative (also after each refresh). The host can use
  /// it, with [onAdFailedToLoad], to keep or drop the ad tile.
  final void Function(String slotKey)? onAdLoaded;

  /// A slot's delivered creative size changed, in logical pixels.
  final void Function(String slotKey, AdSize size)? onAdSizeChanged;

  /// A slot failed to load: a no-fill or transport error, or a placement
  /// without a remote configuration (that slot then waits until the page is
  /// active again or the slot changes).
  final void Function(String slotKey, AdError? error)? onAdFailedToLoad;

  @override
  State<AudienzzGalleryAds> createState() => _AudienzzGalleryAdsState();
}

class _GallerySlotAd {
  _GallerySlotAd({required this.identity, required this.ad});

  /// Page instance and ad config the ad was requested for. A change of either
  /// is a different ad; a change of page index is not.
  final String identity;
  final RemoteBannerAd ad;
}

class _AudienzzGalleryAdsState extends State<AudienzzGalleryAds> {
  /// Ads by slot key.
  final _ads = <String, _GallerySlotAd>{};

  /// Stable request-slot owner per slot key, so analytics sees one slot across
  /// the ads it holds over time (page reactivation, config change).
  final _requestOwners = <String, Object>{};

  /// Slot identities whose ad could not be set up although its remote
  /// configuration exists (no sizes, a platform error). Not retried until the
  /// page becomes active again or the slot changes: retrying on every scroll
  /// tick would repeat the same failure.
  final _setupFailed = <String>{};

  /// Slot identities whose ad could not be set up because their remote
  /// configuration does not exist (yet). Retried once it does (a late remote
  /// config refresh), not on every scroll tick before that.
  final _missingConfig = <String>{};

  /// Whether the page was active at the last sync, to notice a return.
  bool _pageActive = false;

  AudienzzPageScope? _scope;
  PageController? _listening;
  bool _disposed = false;
  bool _evaluateScheduled = false;

  /// Bumped whenever the set of shown ads changes, so tiles rebuild.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _listenTo(widget.controller);
    assert(() {
      final keys = <String>{};
      for (final slot in widget.slots) {
        if (!keys.add(slot.slotKey)) {
          throw FlutterError(
            'AudienzzGalleryAds: duplicate slotKey "${slot.slotKey}". Each slot '
            'needs its own key.',
          );
        }
      }
      return true;
    }());
  }

  void _listenTo(PageController controller) {
    if (identical(_listening, controller)) {
      return;
    }
    _listening?.removeListener(_onScroll);
    _listening = controller..addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = AudienzzPageScope.maybeOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(AudienzzGalleryAds oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listenTo(widget.controller);
    _sync();
  }

  @override
  void dispose() {
    _disposed = true;
    _listening?.removeListener(_onScroll);
    _listening = null;
    for (final key in _ads.keys.toList()) {
      _retire(key, reason: 'dispose');
    }
    super.dispose();
  }

  void _onScroll() => _evaluate();

  /// Reconciles the owned ads with the page state and the slot list, then
  /// preloads what is within range. Runs during build (dependency or widget
  /// change), so it mutates state without `setState`: a build follows anyway.
  void _sync() {
    final scope = _scope;
    if (scope == null) {
      assert(() {
        debugPrint(
          '[Audienzz] AudienzzGalleryAds is not inside an AudienzzPage. Its ads '
          'cannot be tied to a page and will not be requested. Wrap the route '
          'in AudienzzPage(name: …).',
        );
        return true;
      }());
      _retireAll(reason: 'noPage');
      return;
    }
    // Reconciled whatever the page state: a slot the host removed or changed
    // while the page is away must not keep its ad (nor have its callbacks
    // delivered), and a failure belongs to the slot identity that had it — a
    // slot removed and added again gets a fresh attempt.
    final slots = {for (final slot in widget.slots) slot.slotKey: slot};
    final identities = {
      for (final slot in widget.slots) _identity(scope, slot),
    };
    _setupFailed.retainWhere(identities.contains);
    _missingConfig.retainWhere(identities.contains);
    for (final key in _ads.keys.toList()) {
      final slot = slots[key];
      if (slot == null || _ads[key]!.identity != _identity(scope, slot)) {
        _retire(key, reason: slot == null ? 'slotRemoved' : 'slotChanged');
      }
    }
    if (!scope.isActive) {
      // The ads stay: native pauses them while their page is away and resumes
      // them on return without a new auction (`keepsAdAcrossPages`). Nothing
      // new is requested meanwhile; `_evaluate` checks the page too.
      if (_pageActive && _ads.isNotEmpty) {
        AudienzzDiagnostics.log('gallery', 'hold', {
          'page': scope.page.id,
          'slots': _ads.length,
          'reason': 'pageNotActive',
        });
      }
      _pageActive = false;
      return;
    }
    if (!_pageActive) {
      // A placement that could not be set up gets another chance on return.
      _setupFailed.clear();
      _missingConfig.clear();
      _pageActive = true;
    }
    _evaluate();
    // A PageView attaches to its controller during its first layout, after
    // this build, and attaching notifies nobody. Until then the position read
    // is `initialPage`, but a page restored from PageStorage can differ: read
    // it again once the PageView exists.
    _scheduleEvaluate();
  }

  void _scheduleEvaluate() {
    if (_evaluateScheduled) {
      return;
    }
    _evaluateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _evaluateScheduled = false;
      if (!_disposed) {
        _evaluate();
      }
    });
  }

  String _identity(AudienzzPageScope scope, AudienzzGalleryAdSlot slot) =>
      '${scope.page.id}:${slot.slotKey}:${slot.adConfigId}';

  /// The page the reader is on, fractional while swiping; `null` when the
  /// controller cannot say (no pager attached yet, or several).
  double? _currentPage() {
    final controller = widget.controller;
    if (!controller.hasClients) {
      return controller.initialPage.toDouble();
    }
    if (controller.positions.length != 1) {
      return null;
    }
    return controller.page ?? controller.initialPage.toDouble();
  }

  /// Requests the ads of the slots now within their preload distance.
  void _evaluate() {
    final scope = _scope;
    if (_disposed || scope == null || !scope.isActive) {
      return;
    }
    final page = _currentPage();
    if (page == null) {
      return;
    }
    var created = false;
    for (final slot in widget.slots) {
      if (_ads.containsKey(slot.slotKey)) {
        continue;
      }
      final identity = _identity(scope, slot);
      if (_setupFailed.contains(identity)) {
        continue;
      }
      if (_missingConfig.contains(identity)) {
        // Retried as soon as its configuration exists.
        if (AudienzzRemoteConfig.instance.remoteConfigFor(slot.adConfigId) ==
            null) {
          continue;
        }
        _missingConfig.remove(identity);
      }
      final distance = AudienzzGalleryAds.preloadDistanceFor(slot.adConfigId);
      // A hair of tolerance: a settled PageView can report 3.9999999 for 4.
      if ((slot.pageIndex - page).abs() > distance + 1e-6) {
        continue;
      }
      _create(scope, slot, page: page, distance: distance);
      created = true;
    }
    if (created) {
      _changed();
    }
  }

  void _create(
    AudienzzPageScope scope,
    AudienzzGalleryAdSlot slot, {
    required double page,
    required int distance,
  }) {
    final key = slot.slotKey;
    final identity = _identity(scope, slot);
    AudienzzDiagnostics.log('gallery', 'preload', {
      'slot': key,
      'config': slot.adConfigId,
      'pageIndex': slot.pageIndex,
      'readerPage': page.toStringAsFixed(2),
      'distance': distance,
      'page': scope.page.id,
    });
    bool current(Object ad) => !_disposed && identical(_ads[key]?.ad, ad);
    // A deferred callback still describes this slot: the slot still exists
    // with the same page and ad config, and its ad is still this one (or none:
    // a setup failure drops the ad, and the host still has to hear about it).
    bool stillDescribes(Object ad) {
      if (_disposed) {
        return false;
      }
      final scope = _scope;
      final now = widget.slots.where((s) => s.slotKey == key).firstOrNull;
      if (scope == null || now == null || _identity(scope, now) != identity) {
        return false;
      }
      final owned = _ads[key];
      return owned == null || identical(owned.ad, ad);
    }

    final ad = preloadRemoteBannerAd(
      configId: slot.adConfigId,
      pageKey: scope.page.id,
      onAdSizeChanged: (ad, size) {
        if (current(ad)) {
          _notify(ad, stillDescribes,
              () => widget.onAdSizeChanged?.call(key, size));
        }
      },
      onAdLoaded: (ad) {
        if (!current(ad)) {
          return;
        }
        // Records the delivered size for the tile, refreshes included: a
        // multi-size placement can serve a different size each time.
        unawaited(
          ad.getPlatformAdSize().then<void>((_) {}, onError: (Object _) {}),
        );
        _notify(ad, stillDescribes, () => widget.onAdLoaded?.call(key));
      },
      onAdFailedToLoad: (ad, error) {
        if (!current(ad)) {
          return;
        }
        // A no-fill or transport error happens to a registered ad whose native
        // scheduler still owns the slot; it stays. Only a setup failure (no
        // remote configuration) leaves nothing registered, and is dropped.
        if (adInstanceManager.adIdFor(ad) == null) {
          _dropSetupFailure(key, identity, slot.adConfigId);
        }
        _notify(ad, stillDescribes,
            () => widget.onAdFailedToLoad?.call(key, error));
      },
    );
    adInstanceManager.bindRequestSlot(
      ad,
      _requestOwners.putIfAbsent(key, Object.new),
    );
    _ads[key] = _GallerySlotAd(identity: identity, ad: ad);
    unawaited(
      ad.load().then((_) {
        if (!current(ad)) {
          return;
        }
        final id = adInstanceManager.adIdFor(ad);
        if (id == null) {
          return;
        }
        // Loaded ahead of its tile: hidden until the tile's AdWidget reports
        // otherwise, so refresh and viewability never run for an ad nobody
        // can see. A tile already showing it has reported for itself.
        if (!adInstanceManager.isWidgetAdIdMounted(id)) {
          unawaited(
            adInstanceManager
                .setBannerViewportVisible(ad, visible: false)
                .catchError((Object _) {}),
          );
        }
        _changed();
      }).catchError((Object _) {
        if (current(ad)) {
          _dropSetupFailure(key, identity, slot.adConfigId);
        }
      }),
    );
  }

  void _dropSetupFailure(String key, String identity, String adConfigId) {
    _ads.remove(key);
    if (AudienzzRemoteConfig.instance.remoteConfigFor(adConfigId) == null) {
      _missingConfig.add(identity);
    } else {
      _setupFailed.add(identity);
    }
    _changed();
  }

  void _retireAll({required String reason}) {
    for (final key in _ads.keys.toList()) {
      _retire(key, reason: reason);
    }
  }

  /// Releases [key]'s ad. Does not notify: callers are either in build or
  /// notify themselves.
  void _retire(String key, {required String reason}) {
    final owned = _ads.remove(key);
    if (owned == null) {
      return;
    }
    _version++;
    AudienzzDiagnostics.log('gallery', 'retire', {
      'slot': key,
      'reason': reason,
    });
    final ad = owned.ad;
    // Hidden first: disposing deregisters the ad, after which a tile's
    // AdWidget has no id left to report against.
    unawaited(
      adInstanceManager
          .setBannerViewportVisible(ad, visible: false)
          .catchError((Object _) {}),
    );
    unawaited(ad.dispose().catchError((Object _) {}));
  }

  /// Delivers a publisher callback. A missing configuration fails inside
  /// `load()`, which runs while this widget builds or while the pager lays out
  /// a scroll; a callback that rebuilds the host (dropping the ad tile with
  /// `setState`) would be rejected there, so it is delivered at the end of the
  /// frame instead — and dropped if by then it no longer describes its slot
  /// ([stillDescribes]: this widget is gone, or the slot holds another ad).
  void _notify(
    Object ad,
    bool Function(Object ad) stillDescribes,
    void Function() callback,
  ) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (stillDescribes(ad)) {
            callback();
          }
        })
        ..ensureVisualUpdate();
      return;
    }
    callback();
  }

  /// Rebuilds the tiles. Deferred to the end of the frame when it lands
  /// during a build or layout (a scroll position can notify from layout).
  void _changed() {
    _version++;
    if (_disposed || !mounted) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && mounted) {
          setState(() {});
        }
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => _AudienzzGalleryAdsScope(
        version: _version,
        ads: {for (final entry in _ads.entries) entry.key: entry.value.ad},
        child: widget.child,
      );
}

class _AudienzzGalleryAdsScope extends InheritedWidget {
  const _AudienzzGalleryAdsScope({
    required this.version,
    required this.ads,
    required super.child,
  });

  final int version;
  final Map<String, RemoteBannerAd> ads;

  static _AudienzzGalleryAdsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AudienzzGalleryAdsScope>();

  @override
  bool updateShouldNotify(_AudienzzGalleryAdsScope oldWidget) =>
      oldWidget.version != version;
}

/// Shows the ad that [AudienzzGalleryAds] preloaded for [slotKey]. Place it in
/// the slot's [PageView] page (ePaper tile).
///
/// The ad spans the tile's width, is as tall as its creative and is centered
/// vertically in the tile. A fixed-size creative is centered by Google inside
/// the full-width slot; a fluid one (`gamConfig.includeFluid`) fills it.
class AudienzzGalleryAd extends StatelessWidget {
  const AudienzzGalleryAd({
    required this.slotKey,
    this.placeholder,
    this.placeholderHeight = 250,
    super.key,
  });

  /// The [AudienzzGalleryAdSlot.slotKey] of the slot to show.
  final String slotKey;

  /// Shown while the slot has no ad: not yet within its preload distance, or
  /// without a remote configuration. Defaults to an empty tile.
  final Widget? placeholder;

  /// Height of the ad view before its creative has reported a size.
  final double placeholderHeight;

  @override
  Widget build(BuildContext context) {
    final scope = _AudienzzGalleryAdsScope.maybeOf(context);
    assert(() {
      if (scope == null) {
        debugPrint(
          '[Audienzz] AudienzzGalleryAd(slotKey: "$slotKey") is not inside an '
          'AudienzzGalleryAds. Wrap the PageView in AudienzzGalleryAds.',
        );
      }
      return true;
    }());
    final ad = scope?.ads[slotKey];
    // `adIdFor` is null until native registered the ad; AdWidget throws then.
    if (ad == null || adInstanceManager.adIdFor(ad) == null) {
      return placeholder ?? const SizedBox.expand();
    }
    return Center(
      child: ValueListenableBuilder<AdSize?>(
        valueListenable: ad.adSizeListenable,
        child: AdWidget(ad: ad),
        builder: (context, size, child) => SizedBox(
          width: double.infinity,
          height: size?.height.toDouble() ?? placeholderHeight,
          child: child,
        ),
      ),
    );
  }
}
