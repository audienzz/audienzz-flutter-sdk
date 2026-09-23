import 'dart:async';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/remote_banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_diagnostics.dart';
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

  final void Function(AudienzzBanner banner)? onAdLoaded;
  final void Function(AudienzzBanner banner, AdError? error)? onAdFailedToLoad;

  @override
  State<AudienzzBanner> createState() => _AudienzzBannerState();
}

class _AudienzzBannerState extends State<AudienzzBanner> {
  RemoteBannerAd? _ad;
  /// The slot this state currently owns: page instance plus slot key.
  String? _ownedSlot;

  /// Identifies the current OWNER, not the slot.
  ///
  /// Callbacks used to compare the slot string, which a replacement for the
  /// same slot reuses — so a terminal callback from a retired delivery matched
  /// its successor.
  ///
  /// With ownership cleanup fixed, a retired owner is always deregistered and
  /// the instance manager drops its late events by id before any guard here
  /// runs, so no reachable sequence now distinguishes this from the slot
  /// string and a mutation back to it survives the suite. It is kept because
  /// identity is what the guard actually means: the slot string is reused by
  /// design, and any future path that retires an owner without deregistering
  /// it would silently reintroduce the defect.
  int _ownerGeneration = 0;
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
  ///
  /// The publisher stop travels with creation via `startPublisherPaused`, which
  /// is what gets it in place before an eager banner requests. It is ALSO
  /// re-sent here: that is what keeps subsequent refreshes blocked if the
  /// creation-time path is ever missed, and it costs one idempotent command.
  /// Dropping it left the stop lost entirely when the native wrappers
  /// discarded the flag.
  ///
  /// The cover is deliberately only on this path: a first prefetch is exempt
  /// from the host cover, and installing it at creation would quietly change
  /// that separate policy.
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
      AudienzzDiagnostics.log('slot', 'hold', {
        'slot': widget.slotKey,
        'config': widget.adConfigId,
        'page': scope.page.id,
        'reason': 'pageNotActive',
      });
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
    AudienzzDiagnostics.log('slot', 'retire', {
      'slot': widget.slotKey,
      'config': widget.adConfigId,
    });
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
    _ownerGeneration++;
    final owner = _ownerGeneration;
    final scope = AudienzzPageScope.maybeOf(context);
    // The ownership question, answered at birth: which page this slot belongs
    // to. A slot whose page is not the one the reader is on is the shape of
    // every "my banner never loads" report.
    AudienzzDiagnostics.log('slot', 'create', {
      'slot': widget.slotKey,
      'config': widget.adConfigId,
      'page': scope?.page.id,
      'paused': _publisherStopped,
      'gen': owner,
    });
    final ad = RemoteBannerAd(
      configId: widget.adConfigId,
      // Lazy loading and the margin come from the ad config. When it says
      // nothing this widget waits for the viewport — unlike a bare
      // [RemoteBannerAd] — because it owns the sized placeholder that makes
      // deferral safe.
      lazyLoadWhenUnconfigured: true,
      // Explicit, not inherited. A banner created on a retained-but-unfocused
      // screen would otherwise capture the foreground page.
      pageKey: scope?.page.id,
      // Carried into creation rather than applied afterwards: an eager banner
      // starts its request while the plugin is still handling the load call,
      // so a stop replayed after `load()` arrived too late for a slot the
      // publisher had already stopped.
      startPublisherPaused: _publisherStopped,
      onAdLoaded: (_) {
        // A response can arrive after this state was disposed, or after the
        // slot was replaced. Neither may touch the replacement.
        if (_disposed || _ownerGeneration != owner) {
          return;
        }
        setState(() {});
        widget.onAdLoaded?.call(widget);
      },
      onAdFailedToLoad: (failed, error) {
        if (_disposed || _ownerGeneration != owner) {
          return;
        }
        // Two different failures arrive here and they are NOT the same thing.
        //
        // A setup failure — no remote configuration for this placement,
        // initialization still in flight — happens before native registers
        // anything. There is no owner to keep and nothing to dispose, so the
        // slot is released and an ordinary rebuild can try again. That is the
        // case the recovery was written for: RemoteBannerAd reports it here and
        // returns normally rather than failing the Future.
        //
        // An ordinary delivery failure — a Google no-fill, a transport error —
        // happens to a REGISTERED owner that still holds its native scheduler
        // and, on a failed refresh, its displayed creative. Releasing the slot
        // there abandoned that owner in the instance manager (nothing disposed
        // it, so a rebuild registered a second one alongside it) and turned
        // every parent rebuild into an unbounded first-load retry outside the
        // scheduler's own policy.
        final registered = adInstanceManager.adIdFor(failed) != null;
        if (!registered) {
          setState(() {
            _ad = null;
            _ownedSlot = null;
          });
        }
        widget.onAdFailedToLoad?.call(widget, error);
      },
    );
    adInstanceManager.bindRequestSlot(ad, this);
    _ad = ad;
    unawaited(
      ad
          .load()
          // Standing intent is applied only once the ad is REGISTERED: both
          // controls are keyed by the native ad id, so applying them before
          // `load` has allocated one silently does nothing.
          .then((_) {
        if (!_disposed && _ownerGeneration == owner) {
          _applyRetainedIntent(ad);
        }
      }).catchError((Object error) {
        // A setup failure — no remote configuration for this placement yet,
        // initialization still in flight — leaves the ad unregistered. Mounting
        // AdWidget for it throws "AdWidget requires Ad.load to be called", which
        // takes down the whole screen. Drop the owner instead, keep the
        // reservation, and let the slot be retried.
        if (_disposed || _ownerGeneration != owner) {
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
