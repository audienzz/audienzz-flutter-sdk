import 'dart:async';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ads/base/ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/base/ad_without_view.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/banner_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/interstitial_ad.dart';
import 'package:audienzz_sdk_flutter/src/ads/implementation/rewarded_ad.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/ad_size_required_exception.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/sdk_initialization_failed_exception.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/entities/interstitial_ad_event.dart';
import 'package:audienzz_sdk_flutter/src/entities/reward_item.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final adInstanceManager = AdInstanceManager();

final class AdInstanceManager {
  AdInstanceManager() {
    methodChannel.setMethodCallHandler(
      (call) async {
        // Native owns page impressions, including the automatic one on
        // returning to the foreground. Dart used to observe app lifecycle and
        // report one itself, which meant two independent owners each
        // scheduling and de-duplicating — no ordering of the two came out
        // right. Now the epoch only ever advances here, once per real native
        // page impression, so mounted AdWidgets remount exactly once.
        if (call.method == 'onPageImpression') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final name = args?['name'] as String?;
          // Drop a stale echo. Reporting B then C before either echo lands
          // would otherwise let B's confirmation arrive last and reset the
          // page, handing ads created in that window permanent ownership of
          // the wrong screen. `currentPage` is set synchronously by
          // pageImpression, so it is always the authoritative latest; an echo
          // that disagrees is out of date.
          //
          // A null currentPage means the impression originated natively (the
          // automatic foreground one), which is always current.
          if (name != null && (currentPage == null || currentPage == name)) {
            lastReportedPage = name;
            lastPageImpressionAt = DateTime.now();
            pageEpoch.value++;
          }
          return;
        }
        if (call.method != 'onAdEvent') {
          log('Unsupported ad event method: ${call.method}');
          return;
        }

        final args = call.arguments as Map<dynamic, dynamic>?;

        final adId = args?['adId'] as int?;
        final eventName = args?['eventName'] as String?;

        final ad = adFor(adId);

        if (ad != null && eventName != null) {
          _onAdEvent(ad, eventName, args);
        } else {
          log('$Ad with id $adId is not available for $eventName');
        }
      },
    );
  }

  int _nextAdId = 0;
  final _loadedAds = <int, Ad>{};
  final _interstitialLoads = <int, _InterstitialLoad>{};

  @visibleForTesting
  DateTime Function() interstitialClock = DateTime.now;

  bool isInterstitialReady(InterstitialAd ad) {
    final state = _interstitialLoads[adIdFor(ad)];
    return state?.phase == _InterstitialPhase.ready &&
        state!.loadedAt != null &&
        interstitialClock().difference(state.loadedAt!) <
            const Duration(hours: 1);
  }

  Ad? adFor(int? adId) => _loadedAds[adId];

  // Look ads up by object identity, not by `==`. `Ad extends Equatable`, so two
  // distinct instances with identical configuration compare equal — an
  // equality-based lookup would collide them (a second load() would no-op, and
  // dispose() could remove the wrong ad's native view).
  int? adIdFor(Ad ad) => _loadedAds.keys.firstWhereOrNull(
        (key) => identical(_loadedAds[key], ad),
      );

  final Set<int> _mountedWidgetAdIds = <int>{};

  bool isWidgetAdIdMounted(int adId) => _mountedWidgetAdIds.contains(adId);

  void mountWidgetAdId(int adId) => _mountedWidgetAdIds.add(adId);

  void unmountWidgetAdId(int adId) => _mountedWidgetAdIds.remove(adId);

  // No Dart-side reload fan-out. A page impression's fresh auction is issued by
  // the native page coordinator, which recreates every banner on the incoming
  // page; Dart's only job on that signal is to remount the platform view so the
  // new creative is actually painted (see [pageEpoch]). A registry that also
  // called reload() lived here and was never invoked — leaving it in place was
  // an invitation to re-wire a second auction owner for the same transition.

  final methodChannel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );

  Future<InitializationStatus> initialize({
    required String companyId,
    String? prebidServerUrl,
    bool? ppidEnabled,
    bool? automaticPpidEnabled,
  }) async {
    try {
      final initializationStatus =
          await methodChannel.invokeMethod<InitializationStatus>(
        'initialize',
        {
          'companyId': companyId,
          if (prebidServerUrl != null) 'prebidServerUrl': prebidServerUrl,
          if (ppidEnabled != null) 'ppidEnabled': ppidEnabled,
          if (automaticPpidEnabled != null)
            'automaticPpidEnabled': automaticPpidEnabled,
        },
      );

      if (initializationStatus != null) {
        return initializationStatus;
      } else {
        throw const SdkInitializationFailedException();
      }
    } on PlatformException {
      throw const SdkInitializationFailedException();
    }
  }

  void _onAdEvent(Ad ad, String eventName, Map<dynamic, dynamic>? arguments) {
    if (ad is InterstitialAd) {
      _onInterstitialEvent(ad, eventName, arguments);
      return;
    }
    return switch (eventName) {
      'onAdLoaded' => _invokeOnAdLoaded(ad, eventName),
      'onAdFailedToLoad' => _invokeOnAdFailedToLoad(ad, eventName, arguments),
      'onAdClicked' => _invokeOnAdClicked(ad, eventName),
      'onAdOpened' => _invokeOnAdOpened(ad, eventName),
      'onAdClosed' => _invokeOnAdClosed(ad, eventName),
      'onAdImpression' => _invokeOnAdImpression(ad, eventName),
      'onUserEarnedReward' =>
        _invokeOnUserEarnedReward(ad, eventName, arguments),
      _ => log('Invalid ad event name: $eventName'),
    };
  }

  void _invokeOnAdLoaded(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdLoaded.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdLoaded.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdLoaded.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdClicked(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdClicked?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdClicked?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdClicked?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdOpened(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdOpened?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdOpened?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdOpened?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdClosed(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdClosed?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdClosed?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdClosed?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdImpression(Ad ad, String eventName) {
    if (ad is BannerAd) {
      ad.onAdImpression?.call(ad);
    } else if (ad is RewardedAd) {
      ad.onAdImpression?.call(ad);
    } else if (ad is InterstitialAd) {
      ad.onAdImpression?.call(ad);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnAdFailedToLoad(
    Ad ad,
    String eventName,
    Map<dynamic, dynamic>? arguments,
  ) {
    if (ad is BannerAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else if (ad is RewardedAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else if (ad is InterstitialAd) {
      ad.onAdFailedToLoad.call(ad, arguments?['adError'] as AdError?);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  void _invokeOnUserEarnedReward(
    Ad ad,
    String eventName,
    Map<dynamic, dynamic>? arguments,
  ) {
    final rewardItem = arguments?['rewardItem'] as RewardItem?;

    if (rewardItem == null) {
      // Throwing here would surface as an unhandled async error inside the
      // method-channel handler — the app gets neither the reward nor a
      // catchable error. Log and drop instead.
      log('$eventName received without a reward item; ignoring');
      return;
    }

    if (ad is RewardedAd) {
      ad.onUserEarnedRewardCallback.call(ad, rewardItem);
    } else {
      log('Invalid ad: $ad, for event name: $eventName');
    }
  }

  /// The page name reported by the most recent `pageImpression`, stamped onto
  /// every banner created afterwards so the native page coordinator can tell
  /// this screen's ads from the previous screen's.
  ///
  /// A Flutter banner lives in the single FlutterActivity /
  /// FlutterViewController, so native host-screen resolution (Fragment /
  /// Activity / UIViewController identity) can never match a route key on its
  /// own — the key has to travel with the ad. `null` means the app created an
  /// ad before ever calling `pageImpression`, which the native side reports.
  String? currentPage;

  /// The page reported by the most recent page impression, alongside a counter.
  /// [AdWidget] listens and remounts only when the reported page is its own.
  String? lastReportedPage;

  /// When the last page impression was reported, so the foreground observer can
  /// tell whether the app already reported one itself.
  DateTime? lastPageImpressionAt;

  /// Bumped on every page impression. [AdWidget] rebuilds its platform view
  /// when this changes, so a recreated ad gets a fresh texture — an in-place
  /// re-auction does not repaint an AndroidViewSurface / UiKitView on its own.
  final ValueNotifier<int> pageEpoch = ValueNotifier<int>(0);

  /// The page each ad was created under, so an [AdWidget] can tell whether a
  /// page impression is for ITS page. Matching on `ModalRoute.isCurrent`
  /// instead would remount whichever route happens to be on top when the
  /// notification arrives, which is not necessarily the page being reported.
  final Map<int, String?> _adPages = <int, String?>{};

  String? pageFor(Ad ad) {
    final adId = adIdFor(ad);
    return adId == null ? null : _adPages[adId];
  }

  Future<void> loadBannerAd(BannerAd ad) async {
    if (adIdFor(ad) != null) {
      return;
    }

    if (ad.sizes.isEmpty) {
      throw const AdSizeRequiredException();
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;
    _adPages[adId] = currentPage;
    if (currentPage == null) {
      log(
        'Ad created before any pageImpression() call. Page-scoped release and '
        'reload cannot work for it: call AudienzzSdkFlutter.instance'
        '.pageImpression() for this screen BEFORE creating its ads.',
        name: 'AudienzzSdkFlutter',
      );
    }

    try {
      await methodChannel.invokeMethod<void>(
        'loadBannerAd',
        {
          'adId': adId,
          'adUnitId': ad.adUnitId,
          'auConfigId': ad.auConfigId,
          if (currentPage != null) 'pageKey': currentPage,
          'adSizes': ad.sizes.toList(),
          'isAdaptiveSize': ad.isAdaptiveSize,
          'isLazyLoad': ad.isLazyLoad,
          'smartRefresh': ad.smartRefresh,
          'prefetchMargin': ad.prefetchMargin,
          if (ad.refreshTimeInterval != null)
            'refreshTimeInterval': ad.refreshTimeInterval,
          'adFormat': ad.adFormat,
          'apiParameters': ad.apiParameters.toList(),
          'protocols': ad.protocols.toList(),
          'placement': ad.placement,
          'playbackMethods': ad.playbackMethods.toList(),
          'videoBitrate': ad.videoBitrate,
          'videoDuration': ad.videoDuration,
          if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
          if (ad.gpId != null) 'gpId': ad.gpId,
          if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
        },
      );
    } on PlatformException catch (e) {
      _handleLoadChannelFailure(adId, ad, e);
    }
  }

  Future<void> loadRewardedAd(RewardedAd ad) async {
    if (adIdFor(ad) != null) {
      return;
    }

    final adId = _nextAdId++;

    _loadedAds[adId] = ad;

    try {
      await methodChannel.invokeMethod<void>(
        'loadRewardedAd',
        {
          'adId': adId,
          'adUnitId': ad.adUnitId,
          'auConfigId': ad.auConfigId,
          'apiParameters': ad.apiParameters.toList(),
          'protocols': ad.protocols.toList(),
          'placement': ad.placement,
          'playbackMethods': ad.playbackMethods.toList(),
          'videoBitrate': ad.videoBitrate,
          'videoDuration': ad.videoDuration,
          if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
          if (ad.gpId != null) 'gpId': ad.gpId,
          if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
        },
      );
    } on PlatformException catch (e) {
      _handleLoadChannelFailure(adId, ad, e);
    }
  }

  Future<void> loadInterstitialAd(InterstitialAd ad) {
    var existing = _interstitialLoads[adIdFor(ad)];
    if (existing?.phase == _InterstitialPhase.ready &&
        !isInterstitialReady(ad)) {
      _releaseInterstitial(ad, existing!, 'expired');
      existing = null;
    }
    if (existing != null) {
      if (existing.phase == _InterstitialPhase.presenting) {
        return Future.error(
            StateError('The interstitial is still presenting.'));
      }
      return existing.ready.future;
    }
    final adId = _nextAdId++;
    final state = _InterstitialLoad(adId);
    _loadedAds[adId] = ad;
    _interstitialLoads[adId] = state;
    state.timeout = Timer(const Duration(seconds: 120), () {
      _failInterstitialLoad(
          ad,
          state,
          const AdError(
              code: -1,
              domain: 'audienzz',
              message: 'Interstitial load timed out after 120 seconds.'));
    });
    _interstitialEvent(ad, state, 'loadRequested');
    unawaited(methodChannel.invokeMethod<void>(
      'loadInterstitialAd',
      {
        'adId': adId,
        'adUnitId': ad.adUnitId,
        'auConfigId': ad.auConfigId,
        'adFormat': ad.adFormat,
        'apiParameters': ad.apiParameters.toList(),
        'protocols': ad.protocols.toList(),
        'placement': ad.placement,
        'playbackMethods': ad.playbackMethods.toList(),
        'videoBitrate': ad.videoBitrate,
        'videoDuration': ad.videoDuration,
        'minSizePercentage': ad.minSizePercentage,
        if (ad.sizes.isNotEmpty) 'adSizes': ad.sizes.toList(),
        if (ad.pbAdSlot != null) 'pbAdSlot': ad.pbAdSlot,
        if (ad.gpId != null) 'gpId': ad.gpId,
        if (ad.impOrtbConfig != null) 'impOrtbConfig': ad.impOrtbConfig,
      },
    ).then<void>((_) {}, onError: (Object error, StackTrace stack) {
      _failInterstitialLoad(ad, state, _interstitialError(error));
    }));
    return state.ready.future;
  }

  AdError _interstitialError(Object error) => error is AdError
      ? error
      : AdError(
          code:
              error is PlatformException ? int.tryParse(error.code) ?? -1 : -1,
          domain: error is PlatformException && error.details is String
              ? error.details as String
              : 'audienzz',
          message: error is PlatformException
              ? error.message ?? error.code
              : error.toString());

  void _interstitialEvent(
      InterstitialAd ad, _InterstitialLoad state, String name,
      {String? reason, AdError? error}) {
    ad.onLifecycleEvent?.call(
        ad,
        InterstitialAdEvent(
            loadId: state.id,
            name: name,
            timestamp: interstitialClock(),
            responseId: state.responseId,
            loadAgeMillis: state.loadedAt == null
                ? null
                : interstitialClock()
                    .difference(state.loadedAt!)
                    .inMilliseconds,
            reason: reason,
            error: error));
  }

  void _failInterstitialLoad(
      InterstitialAd ad, _InterstitialLoad state, AdError error) {
    if (_interstitialLoads[state.id] != state ||
        state.phase != _InterstitialPhase.loading) return;
    state.timeout?.cancel();
    // Remove the old generation before callbacks, so retrying from a callback works.
    _releaseInterstitial(ad, state, 'loadFailed', error: error);
    state.ready.completeError(error);
    ad.onAdFailedToLoad(ad, error);
  }

  void _releaseInterstitial(
      InterstitialAd ad, _InterstitialLoad state, String reason,
      {AdError? error}) {
    state.timeout?.cancel();
    _interstitialLoads.remove(state.id);
    _loadedAds.remove(state.id);
    unawaited(
        methodChannel.invokeMethod<void>('disposeAd', {'adId': state.id}));
    if (reason == 'loadFailed' ||
        reason == 'showFailed' ||
        reason == 'dismissed') {
      _interstitialEvent(ad, state, reason, error: error);
    }
    _interstitialEvent(ad, state, 'disposed', reason: reason);
  }

  void _onInterstitialEvent(
      InterstitialAd ad, String name, Map<dynamic, dynamic>? args) {
    final state = _interstitialLoads[adIdFor(ad)];
    if (state == null) return;
    final rawError = args?['adError'] as AdError?;
    final error = AdError(
        code: rawError?.code ?? -1,
        message: rawError?.message ?? 'Interstitial presentation failed.',
        domain: args?['errorDomain'] as String?);
    switch (name) {
      case 'onAdLoaded':
        if (state.phase != _InterstitialPhase.loading) return;
        state.timeout?.cancel();
        state.phase = _InterstitialPhase.ready;
        state.loadedAt = interstitialClock();
        state.responseId = args?['responseId'] as String?;
        state.ready.complete();
        _interstitialEvent(ad, state, 'loaded');
        ad.onAdLoaded(ad);
      case 'onAdFailedToLoad':
        _failInterstitialLoad(ad, state, error);
      case 'onAdFailedToShow':
        _failInterstitialShow(ad, state, error);
      case 'onAdOpened':
        if (state.phase != _InterstitialPhase.presenting || state.opened)
          return;
        state.opened = true;
        _interstitialEvent(ad, state, 'presented');
        ad.onAdOpened?.call(ad);
      case 'onAdImpression':
        if (state.phase != _InterstitialPhase.presenting || state.impression)
          return;
        state.impression = true;
        _interstitialEvent(ad, state, 'impression');
        ad.onAdImpression?.call(ad);
      case 'onAdClosed':
        if (state.phase != _InterstitialPhase.presenting) return;
        _releaseInterstitial(ad, state, 'dismissed');
        ad.onAdClosed?.call(ad);
      case 'onAdClicked':
        if (state.phase == _InterstitialPhase.presenting)
          ad.onAdClicked?.call(ad);
    }
  }

  void _failInterstitialShow(
      InterstitialAd ad, _InterstitialLoad state, AdError error) {
    if (_interstitialLoads[state.id] != state) return;
    _releaseInterstitial(ad, state, 'showFailed', error: error);
    ad.onAdFailedToShow?.call(ad, error);
  }

  /// Undo a failed native load: drop the registry entry (so a retry actually
  /// re-loads instead of early-returning "already registered") and surface the
  /// failure through the ad's own `onAdFailedToLoad` callback.
  void _handleLoadChannelFailure(int adId, Ad ad, PlatformException e) {
    _loadedAds.remove(adId);
    final error = AdError(
      code: int.tryParse(e.code) ?? -1,
      message: e.message ?? 'Failed to load ad',
    );
    if (ad is BannerAd) {
      ad.onAdFailedToLoad(ad, error);
    } else if (ad is RewardedAd) {
      ad.onAdFailedToLoad(ad, error);
    } else if (ad is InterstitialAd) {
      ad.onAdFailedToLoad(ad, error);
    }
  }

  Future<void> showAdWithoutView(AdWithoutView ad) async {
    final adId = adIdFor(ad);

    // A real throw, not an assert: asserts are stripped in release builds, so
    // an unloaded ad would otherwise send {'adId': null} to the native side.
    if (adId == null) {
      throw StateError(
        'Ad has not been loaded or has already been disposed.',
      );
    }

    if (ad is InterstitialAd) {
      final state = _interstitialLoads[adId];
      if (state?.phase != _InterstitialPhase.ready) {
        throw StateError(
            'Interstitial is not ready or is already presenting. Await load() first.');
      }
      state!.phase = _InterstitialPhase.presenting;
      _interstitialEvent(ad, state, 'showAttempted');
      try {
        await methodChannel
            .invokeMethod<void>('showAdWithoutView', {'adId': adId});
      } on PlatformException catch (error) {
        _failInterstitialShow(ad, state, _interstitialError(error));
        rethrow;
      }
      return;
    }
    return methodChannel.invokeMethod<void>(
      'showAdWithoutView',
      {'adId': adId},
    );
  }

  Future<AdSize?> getPlatformAdSize(BannerAd ad) async {
    final adId = adIdFor(ad);

    if (adId == null) {
      throw StateError(
        'Ad has not been loaded or has already been disposed.',
      );
    }

    return methodChannel.invokeMethod<AdSize?>(
      'getPlatformAdSize',
      {'adId': adId},
    );
  }

  Future<void> disposeAd(Ad ad) {
    final adId = adIdFor(ad);
    if (ad is InterstitialAd) {
      final state = _interstitialLoads[adId];
      if (state == null) return Future.value();
      if (state.phase == _InterstitialPhase.presenting) {
        _interstitialEvent(ad, state, 'disposeDeferred',
            reason: 'presentationInProgress');
      } else {
        _releaseInterstitial(ad, state, 'publisher');
        if (!state.ready.isCompleted) {
          state.ready.completeError(
              StateError('Interstitial disposed while loading.'));
        }
      }
      return Future.value();
    }
    _adPages.remove(adId);
    final disposedAd = _loadedAds.remove(adId);

    if (disposedAd == null) {
      return Future<void>.value();
    }

    return methodChannel.invokeMethod<void>(
      'disposeAd',
      {'adId': adId},
    );
  }

  /// Internal widget visibility signal, independent of the publisher pause API.
  Future<void> setBannerViewportVisible(BannerAd ad, {required bool visible}) {
    final adId = adIdFor(ad);
    if (adId == null) {
      return Future<void>.value();
    }
    return methodChannel.invokeMethod<void>(
      'setBannerViewportVisible',
      {'adId': adId, 'visible': visible},
    );
  }

  Future<void> pauseBannerAutoRefresh(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'pauseBannerAutoRefresh',
      {'adId': adId},
    );
  }

  Future<void> resumeBannerAutoRefresh(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'resumeBannerAutoRefresh',
      {'adId': adId},
    );
  }

  /// Force a fresh auction now for [ad], regardless of the refresh timer —
  /// calls the native `AUBannerView.reloadAd()` / `AudienzzAdViewHandler.reloadAd()`.
  Future<void> reloadBanner(BannerAd ad) {
    final adId = adIdFor(ad);
    if (adId == null) return Future<void>.value();
    return methodChannel.invokeMethod<void>(
      'reloadBanner',
      {'adId': adId},
    );
  }

  /// Pauses auto-refresh for every currently loaded banner ad.
  Future<void> pauseAllBannerAutoRefresh() async {
    for (final entry in _loadedAds.entries) {
      if (entry.value is BannerAd) {
        await methodChannel.invokeMethod<void>(
          'pauseBannerAutoRefresh',
          {'adId': entry.key},
        );
      }
    }
  }

  /// Resumes auto-refresh for every currently loaded banner ad.
  Future<void> resumeAllBannerAutoRefresh() async {
    for (final entry in _loadedAds.entries) {
      if (entry.value is BannerAd) {
        await methodChannel.invokeMethod<void>(
          'resumeBannerAutoRefresh',
          {'adId': entry.key},
        );
      }
    }
  }
}

enum _InterstitialPhase { loading, ready, presenting }

final class _InterstitialLoad {
  _InterstitialLoad(this.id);
  final int id;
  final ready = Completer<void>();
  _InterstitialPhase phase = _InterstitialPhase.loading;
  Timer? timeout;
  DateTime? loadedAt;
  String? responseId;
  bool opened = false;
  bool impression = false;
}
