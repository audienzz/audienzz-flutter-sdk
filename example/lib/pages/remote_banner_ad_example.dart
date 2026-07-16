import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// RemoteBannerAdLoader
// ---------------------------------------------------------------------------

/// Manages the lifecycle of a [RemoteBannerAd] and kicks off loading
/// immediately on construction so the Prebid + GAM round-trip can begin
/// *before* the widget tree is fully built.
///
/// Typical usage — pre-load during SDK initialisation, then hand the loader
/// to [RemoteBannerAdExample]:
///
/// ```dart
/// // In initializeSdk(), after all global SDK config is set:
/// _loader = RemoteBannerAdLoader(configId: '118');
///
/// // In build():
/// RemoteBannerAdExample(configId: '118', loader: _loader)
/// ```
///
/// When no loader is passed to [RemoteBannerAdExample], the widget creates and
/// owns one internally — identical behaviour to the pre-refactor version.
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
        print('RemoteBannerAdLoader [$configId] failed: $error');
      },
      onAdClicked: (_) {},
      onAdOpened: (_) {},
      onAdClosed: (_) {},
      onAdImpression: (_) => print('Remote Banner Ad [$configId] impression'),
    );
    _ad!.load();
    print('RemoteBannerAdLoader [$configId] load() called');
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// RemoteBannerAdExample
// ---------------------------------------------------------------------------

class RemoteBannerAdExample extends StatefulWidget {
  const RemoteBannerAdExample({
    required this.configId,
    this.loader,
    super.key,
  });

  final String configId;

  /// Optional pre-created loader. When provided this widget observes it but
  /// does NOT dispose it — the caller owns the loader's lifecycle.
  /// When null, a [RemoteBannerAdLoader] is created internally and disposed
  /// with this widget (same behaviour as before this refactor).
  final RemoteBannerAdLoader? loader;

  @override
  State<RemoteBannerAdExample> createState() => _RemoteBannerAdExampleState();
}

class _RemoteBannerAdExampleState extends State<RemoteBannerAdExample> {
  late RemoteBannerAdLoader _loader;

  /// True when this state created the loader and must dispose it.
  bool _ownsLoader = false;

  @override
  void initState() {
    super.initState();
    if (widget.loader != null) {
      _loader = widget.loader!;
      _ownsLoader = false;
    } else {
      _loader = RemoteBannerAdLoader(configId: widget.configId);
      _ownsLoader = true;
    }
    _loader.addListener(_onLoaderChanged);
  }

  @override
  void dispose() {
    _loader.removeListener(_onLoaderChanged);
    if (_ownsLoader) _loader.dispose();
    super.dispose();
  }

  // Rebuild when the loader notifies (ad loaded, failed, size resolved).
  void _onLoaderChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _loader.errorMessage;
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
    final ad = _loader.ad;
    if (ad == null || ad.sizes.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isLoaded = _loader.isLoaded;
    final adSize = _loader.adSize;
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
