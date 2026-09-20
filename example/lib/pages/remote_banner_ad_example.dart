import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// RemoteBannerAdLoader
// ---------------------------------------------------------------------------

/// Manages the lifecycle of a [RemoteBannerAd] and starts loading as soon as it
/// is constructed.
///
/// **This is the advanced, low-level sample.** The recommended integration is
/// `AudienzzPage` + `AudienzzBanner` (see `ManagedBannerExample`), which owns
/// all of this for you. Everything below exists because a publisher who wants
/// to drive the ad object directly has to reproduce it by hand — and the part
/// that is easy to get wrong is the ORDER.
///
/// A [RemoteBannerAd] is stamped with the page that is current when it is
/// created. Constructing it during `initState`, or during SDK initialisation,
/// happens before the navigator observer has reported the route the widget is
/// on, so the ad carries no page (or the previous one) and the next page
/// impression sweeps it as belonging somewhere else. [RemoteBannerAdExample]
/// therefore waits for its page before creating this loader; do not construct
/// one eagerly and pass it in.
class RemoteBannerAdLoader extends ChangeNotifier {
  RemoteBannerAdLoader({required this.configId}) {
    _createAndLoad();
  }

  final String configId;

  RemoteBannerAd? _ad;
  bool isLoaded = false;
  AdSize? adSize;
  String? errorMessage;

  RemoteBannerAd? get ad => _ad;

  void _createAndLoad() {
    _ad = RemoteBannerAd(
      configId: configId,
      onAdLoaded: (ad) async {
        adSize = await ad.getPlatformAdSize();
        isLoaded = true;
        notifyListeners();
        print('RemoteBannerAdLoader [$configId] loaded');
      },
      onAdFailedToLoad: (ad, error) {
        errorMessage = error?.message ?? 'Ad failed to load';
        _ad = null; // null BEFORE notifying so build() sees consistent state
        notifyListeners();
        ad.dispose();
        print(
          'RemoteBannerAdLoader [$configId] failed: '
          'code=${error?.code} message=${error?.message}',
        );
      },
      onAdClicked: (_) {},
      onAdOpened: (_) {},
      onAdClosed: (_) {},
      onAdImpression: (_) => print('Remote Banner Ad [$configId] impression'),
    );
    _ad!.load();
    print('RemoteBannerAdLoader [$configId] load() called');
  }

  /// Dispose the current ad and start a fresh auction. Used when the ad's
  /// screen (e.g. a tab) becomes active again, mirroring the native
  /// screen-change reload — a fresh creative under the new page impression.
  void reload() {
    _ad?.dispose();
    _ad = null;
    isLoaded = false;
    errorMessage = null;
    // Show the empty placeholder for a frame (slot blanks, like the native
    // blankOnScreenReload), then start the fresh auction.
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      _createAndLoad();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// RemoteBannerAdExample
// ---------------------------------------------------------------------------

/// The low-level RemoteBanner sample. Prefer `ManagedBannerExample`.
class RemoteBannerAdExample extends StatefulWidget {
  const RemoteBannerAdExample({
    required this.configId,
    super.key,
  });

  final String configId;

  @override
  State<RemoteBannerAdExample> createState() => _RemoteBannerAdExampleState();
}

class _RemoteBannerAdExampleState extends State<RemoteBannerAdExample> {
  RemoteBannerAdLoader? _loader;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _createWhenPageIsKnown();
  }

  /// Create the ad only once this widget's page has been reported.
  ///
  /// Two cases, and both are ordinary app situations rather than test
  /// scaffolding:
  ///
  ///  * Inside an `AudienzzPage`, the scope says when its page has been
  ///    activated. Creating before that stamps the ad with the previous page.
  ///  * On a bare route, `AudienzzNavigatorObserver` reports in a post-frame
  ///    callback it registered when the route was pushed — which is before this
  ///    widget's own. Deferring by that one frame is what makes the ad belong
  ///    to the screen it is on. It used to be created in `initState`, i.e.
  ///    before the report, and the very next page impression released it.
  void _createWhenPageIsKnown() {
    if (_loader != null) {
      return;
    }
    final scope = AudienzzPageScope.maybeOf(context);
    if (scope != null) {
      if (scope.isActive) {
        _attach(RemoteBannerAdLoader(configId: widget.configId));
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loader != null) {
        return;
      }
      setState(() {
        _attach(RemoteBannerAdLoader(configId: widget.configId));
      });
    });
  }

  void _attach(RemoteBannerAdLoader loader) {
    _loader = loader;
    loader.addListener(_onLoaderChanged);
  }

  @override
  void dispose() {
    _loader?.removeListener(_onLoaderChanged);
    _loader?.dispose();
    super.dispose();
  }

  // Rebuild when the loader notifies (ad loaded, failed, size resolved).
  void _onLoaderChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final loader = _loader;
    if (loader == null) {
      // Waiting for this widget's page to be reported. Reserving the height
      // here is what keeps the article from reflowing when the ad appears.
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final errorMessage = loader.errorMessage;
    if (errorMessage != null) {
      return Center(child: Text('Error: $errorMessage'));
    }

    // AdWidget must be in the tree from the very first build so the native
    // platform view is attached to the iOS/Android view hierarchy immediately.
    // With isLazyLoad = true the demand fetch is only triggered once the
    // native view enters the viewport — but that can only happen if the view
    // is already embedded in the hierarchy. Gating AdWidget behind isLoaded
    // creates a deadlock: the view never attaches, the fetch never fires, and
    // onAdLoaded never arrives.
    //
    // If the ad or its sizes aren't available yet (e.g. remote config hasn't
    // loaded or the ad failed) fall back to a 50 dp placeholder.
    final ad = loader.ad;
    if (ad == null || ad.sizes.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isLoaded = loader.isLoaded;
    final adSize = loader.adSize;
    final width = adSize?.width.toDouble() ?? ad.sizes.first.width.toDouble();
    final height = adSize?.height.toDouble() ?? ad.sizes.first.height.toDouble();

    // NOTE: SmartRefresh is fully managed by the SDK. As long as the ad was
    // created with smartRefresh: true, AdWidget itself pauses auto-refresh when
    // the ad scrolls off-screen, is covered by another route, or the app is
    // backgrounded — and resumes when it becomes visible again. The app does
    // not need any visibility/route/lifecycle handling here.
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        // Stack the AdWidget behind a spinner so the native view is always
        // attached (enabling lazy-load visibility detection) while a loading
        // indicator is shown until the first creative arrives.
        child: Stack(
          children: [
            AdWidget(ad: ad),
            if (!isLoaded) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
