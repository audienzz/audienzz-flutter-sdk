import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page.dart';
import 'package:audienzz_sdk_flutter/src/widgets/ad_widget.dart';
import 'package:flutter/widgets.dart';

/// A RemoteBanner that owns its own lifetime.
///
/// The publisher places it and does nothing else: no `load()`, no refresh
/// timer, no reload after a page impression or an app resume, no `dispose()`.
///
/// It must be built inside an [AudienzzPage]. That is not a convention — it is
/// how the banner learns which page instance owns it while it is being built,
/// rather than reading whichever page was reported last.
/// Publisher controls for a managed banner.
///
/// Attach one with [AudienzzBanner.controller]. Both controls are durable and
/// independent of geometry: a scroll, a page impression or a return to the
/// foreground will not undo either of them.
class AudienzzBannerController extends ChangeNotifier {
  _AudienzzBannerState? _state;

  void _attach(_AudienzzBannerState state) => _state = state;

  void _detach(_AudienzzBannerState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  /// Report a cover the SDK cannot infer — an `IgnorePointer` veil, a painted
  /// overlay, anything that hides the ad without appearing in the hit path.
  ///
  /// This is current state, not an event: pass `false` when the cover goes
  /// away. It is cleared automatically when the banner is disposed. Arbitrary
  /// overlays are **not** claimed to be detectable without it.
  Future<void> reportCover({required bool covered}) async =>
      _state?._reportCover(covered: covered);

  /// Durable publisher pause. Only [resumeAutoRefresh] clears it.
  Future<void> stopAutoRefresh() async => _state?._pause();

  /// Clears the pause set by [stopAutoRefresh].
  Future<void> resumeAutoRefresh() async => _state?._resume();
}

class AudienzzBanner extends StatefulWidget {
  const AudienzzBanner({
    required this.adConfigId,
    required this.slotKey,
    this.placeholderHeight = 250,
    this.isLazyLoad = true,
    this.prefetchMargin,
    this.controller,
    this.onAdLoaded,
    this.onAdFailedToLoad,
    super.key,
  });

  /// Publisher controls for this slot: custom cover reporting and a durable
  /// pause. Optional — a banner needs none of it to work.
  final AudienzzBannerController? controller;

  /// Remote configuration id for this placement.
  final String adConfigId;

  /// Stable identity for this slot within its page. Required, because an
  /// [adConfigId] is not unique: the same placement legitimately appears twice
  /// on one page, and `(page instance, slotKey)` is what tells those two apart
  /// across rebuilds and list recycling.
  final String slotKey;

  /// Height reserved before the creative arrives. The reservation is the point:
  /// the slot must be laid out and sized *before* the viewport check runs, or
  /// lazy loading can never trigger. An integration that mounts its ad view
  /// only after `onAdLoaded` deadlocks for exactly this reason.
  final double placeholderHeight;

  /// Defer the auction until the slot approaches the viewport. Defaults to
  /// `true` here, unlike [RemoteBannerAd], because this widget owns the sized
  /// placeholder that makes deferral work.
  final bool isLazyLoad;

  /// How far ahead of the viewport the auction starts, in logical pixels.
  final int? prefetchMargin;

  final void Function(AudienzzBanner banner)? onAdLoaded;
  final void Function(AudienzzBanner banner, AdError? error)? onAdFailedToLoad;

  @override
  State<AudienzzBanner> createState() => _AudienzzBannerState();
}

class _AudienzzBannerState extends State<AudienzzBanner> {
  RemoteBannerAd? _ad;
  /// The slot this state currently owns: page instance plus slot key.
  String? _ownedSlot;
  bool _disposed = false;

  /// Requested publisher state, held by the SLOT rather than by whichever ad
  /// currently occupies it.
  ///
  /// The ad is created late — after the page activates — and recreated on
  /// replacement, so forwarding a control straight to `_ad` lost it whenever
  /// there was no ad yet, and a recreated ad came back unpaused and uncovered
  /// although the publisher had never resumed it.
  bool _coverRequested = false;
  bool _publisherStopped = false;

  Future<void> _reportCover({required bool covered}) async {
    _coverRequested = covered;
    _ad?.reportObscured(covered);
  }

  Future<void> _pause() async {
    _publisherStopped = true;
    await _ad?.pauseAutoRefresh();
  }

  Future<void> _resume() async {
    _publisherStopped = false;
    await _ad?.resumeAutoRefresh();
  }

  /// Re-applies the slot's standing intent to a newly created ad.
  void _applyRetainedIntent(RemoteBannerAd ad) {
    if (_coverRequested) {
      ad.reportObscured(true);
    }
    if (_publisherStopped) {
      unawaited(ad.pauseAutoRefresh());
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _disposed = true;
    final ad = _ad;
    _ad = null;
    // Unawaited on purpose: dispose cannot be async, and the ad's own teardown
    // retires the scheduler and cancels callbacks. Errors are swallowed rather
    // than thrown into the framework's disposal path.
    unawaited(ad?.dispose().catchError((_) {}));
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWithPage();
  }

  @override
  void didUpdateWidget(AudienzzBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      // Attaching only in initState left a replaced controller inert while the
      // old one kept the reference, and dispose then detached a controller that
      // had never been attached. The retained intent belongs to the SLOT, so it
      // survives the swap and the new controller can clear it.
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // Unconditionally: `_syncWithPage` is the single place that decides whether
    // this rebuild is a genuinely different slot. Pre-filtering here would put
    // that decision in two places and let them drift.
    _syncWithPage();
  }

  void _syncWithPage() {
    final scope = AudienzzPageScope.maybeOf(context);
    if (scope == null) {
      assert(() {
        debugPrint(
          '[Audienzz] AudienzzBanner(slotKey: "${widget.slotKey}") is not '
          'inside an AudienzzPage. Without a page it cannot be released when '
          'the reader navigates away, and it will keep refreshing on a screen '
          'nobody is looking at. Wrap the route in AudienzzPage(name: …).',
        );
        return true;
      }());
      return;
    }
    if (!scope.isActive) {
      // A pre-built, unfocused tab must not buy an ad, and an ad created before
      // its page is reported would be swept as belonging to the previous page.
      //
      // Withdrawing focus must also stop a banner that already exists. Merely
      // declining to create one left the previous ad mounted and reporting
      // itself visible, refreshing on a page the host had said was no longer in
      // front — and nothing was coming to release it, because no successor page
      // had been reported. Retire the owner; the slot keeps its reservation and
      // its standing publisher intent, and reactivation builds a fresh one.
      _retireCurrentAd();
      return;
    }
    // Identity, not decoration. Changing any part is a genuinely different slot
    // and must replace the owner; everything else — a parent rebuild, a changed
    // placeholder height, a new callback closure — reuses it and requests
    // nothing.
    //
    // The page part is defence-in-depth: today a page change necessarily
    // rebuilds this subtree with a fresh state, so no reachable sequence hands
    // one mounted banner a different page, and a mutation that drops it
    // survives the suite. It is kept because a custom router that swaps the
    // scope in place would otherwise keep serving the old page's slot.
    final slot = '${scope.page.id}:${widget.slotKey}:${widget.adConfigId}';
    if (slot == _ownedSlot) {
      return;
    }
    _retireCurrentAd();
    _ownedSlot = slot;
    _createAd();
  }

  /// Disposes the ad this slot owns, if any, without touching the slot's
  /// standing publisher intent.
  void _retireCurrentAd() {
    final previous = _ad;
    if (previous == null) {
      return;
    }
    _ad = null;
    _ownedSlot = null;
    // Report the hold explicitly before disposing. Relying on AdWidget's own
    // dispose to send it is a race: `dispose()` deregisters the ad first, and
    // AdWidget then has no id to report against, so the last verdict native saw
    // stayed `visible` on a page the host had just withdrawn.
    unawaited(
      adInstanceManager
          .setBannerViewportVisible(previous, visible: false)
          .catchError((_) {}),
    );
    unawaited(previous.dispose().catchError((_) {}));
    if (mounted) {
      setState(() {});
    }
  }

  void _createAd() {
    final slotAtCreate = _ownedSlot;
    final scope = AudienzzPageScope.maybeOf(context);
    final ad = RemoteBannerAd(
      configId: widget.adConfigId,
      isLazyLoad: widget.isLazyLoad,
      prefetchMargin: widget.prefetchMargin,
      // Explicit, not inherited. A banner created on a retained-but-unfocused
      // screen would otherwise capture the foreground page.
      pageKey: scope?.page.id,
      onAdLoaded: (_) {
        // A response can arrive after this state was disposed, or after the
        // slot was replaced. Neither may touch the replacement.
        if (_disposed || _ownedSlot != slotAtCreate) {
          return;
        }
        setState(() {});
        widget.onAdLoaded?.call(widget);
      },
      onAdFailedToLoad: (_, error) {
        if (_disposed || _ownedSlot != slotAtCreate) {
          return;
        }
        // RemoteBannerAd reports a missing configuration here and returns
        // normally — it does NOT fail the Future, so the catchError below never
        // ran for the failure it was written for, and _ownedSlot stayed set and
        // blocked recreation once configuration arrived. Release the slot so an
        // ordinary rebuild can try again.
        setState(() {
          _ad = null;
          _ownedSlot = null;
        });
        widget.onAdFailedToLoad?.call(widget, error);
      },
    );
    _ad = ad;
    unawaited(
      ad
          .load()
          // Standing intent is applied only once the ad is REGISTERED: both
          // controls are keyed by the native ad id, so applying them before
          // `load` has allocated one silently does nothing.
          .then((_) {
        if (!_disposed && _ownedSlot == slotAtCreate) {
          _applyRetainedIntent(ad);
        }
      }).catchError((Object error) {
        // A setup failure — no remote configuration for this placement yet,
        // initialization still in flight — leaves the ad unregistered. Mounting
        // AdWidget for it throws "AdWidget requires Ad.load to be called", which
        // takes down the whole screen. Drop the owner instead, keep the
        // reservation, and let the slot be retried.
        if (_disposed || _ownedSlot != slotAtCreate) {
          return;
        }
        setState(() {
          _ad = null;
          // Cleared so an ordinary rebuild once configuration arrives builds
          // the slot again rather than treating it as already owned.
          _ownedSlot = null;
        });
      }),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // The reservation is always laid out, loaded or not, so the surrounding
    // content does not jump and the slot has a real size the moment its page
    // activates — which is what lets the lazy viewport check run at all.
    // `adIdFor` is null until native has registered the ad. AdWidget asserts on
    // that and throws into the widget tree, so the reservation is shown alone
    // until registration succeeds.
    final registered = ad != null && adInstanceManager.adIdFor(ad) != null;
    return SizedBox(
      width: double.infinity,
      height: widget.placeholderHeight,
      child: registered ? AdWidget(ad: ad!) : null,
    );
  }
}
