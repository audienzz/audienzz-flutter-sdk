import 'dart:async';

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
class AudienzzBanner extends StatefulWidget {
  const AudienzzBanner({
    required this.adConfigId,
    required this.slotKey,
    this.placeholderHeight = 250,
    this.isLazyLoad = true,
    this.prefetchMargin,
    this.onAdLoaded,
    this.onAdFailedToLoad,
    super.key,
  });

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

  @override
  void dispose() {
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
    final previous = _ad;
    _ownedSlot = slot;
    _ad = null;
    unawaited(previous?.dispose().catchError((_) {}));
    _createAd();
  }

  void _createAd() {
    final slotAtCreate = _ownedSlot;
    final ad = RemoteBannerAd(
      configId: widget.adConfigId,
      isLazyLoad: widget.isLazyLoad,
      prefetchMargin: widget.prefetchMargin,
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
        widget.onAdFailedToLoad?.call(widget, error);
      },
    );
    _ad = ad;
    unawaited(
      ad.load().catchError((_) {
        // Surfaced through onAdFailedToLoad; the slot keeps its reservation.
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
    return SizedBox(
      width: double.infinity,
      height: widget.placeholderHeight,
      child: ad == null ? null : AdWidget(ad: ad),
    );
  }
}
