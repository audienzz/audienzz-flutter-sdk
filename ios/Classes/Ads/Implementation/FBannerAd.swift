import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FBannerAd: FBaseAd, FAd, FDisposableAd, FlutterPlatformView, BannerViewDelegate {
    private let adUnitId: String
    private let auConfigId: String
    private let sizes: [FAdSize]
    private let isAdaptiveSize: Bool
    private let isLazyLoad: Bool
    private let smartRefresh: Bool
    private let prefetchMarginPoints: CGFloat
    private let refreshTimeInterval: Double?
    private let adFormat: FAdFormat
    private let apiParameters: [AUApi]
    private let videoProtocols: [AUVideoProtocols]
    private let videoPlacement: AUPlacement
    private let videoPlaybackMethods: [AUVideoPlaybackMethod]
    private let videoBitrate: FVideoBitrate
    private let videoDuration: FVideoDuration
    private let pbAdSlot: String?
    private let gpId: String?
    private let customImpOrtbConfig: String?
    private let rootViewController: UIViewController
    var auBannerView: AUBannerView?

    weak var manager: AdInstanceManager?

    private var bannerViewInstance: AdManagerBannerView?

    // MARK: - Flutter smart-refresh visibility polling
    //
    // AUBannerView (VisibleView) detects scroll events via KVO on UIScrollView ancestor
    // contentOffset. Flutter platform views have no UIScrollView in their ancestor chain,
    // so that mechanism never fires. Instead we poll every 0.5 s and pause/resume
    // Prebid auto-refresh ourselves using the public adUnitConfiguration API.

    private var smartRefreshTimer: Timer?
    private var smartRefreshWasVisible = false

    // Set by the Dart layer via pauseAutoRefresh()/resumeAutoRefresh(). While
    // true, the visibility poll below is suppressed so it can't auto-resume an
    // ad the publisher explicitly paused — this is how a same-route overlay
    // (OverlayEntry / modal) that the native geometry poll can't see is honored.
    private var isManuallyPaused = false

    private func startSmartRefreshPolling() {
        smartRefreshTimer?.invalidate()
        smartRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkSmartRefreshVisibility()
        }
    }

    private func stopSmartRefreshPolling() {
        smartRefreshTimer?.invalidate()
        smartRefreshTimer = nil
    }

    private func checkSmartRefreshVisibility() {
        // A manual pause wins over geometric visibility — never auto-resume an
        // ad the publisher paused explicitly (e.g. behind an overlay).
        guard !isManuallyPaused else { return }
        guard let view = auBannerView, let window = view.window else {
            // View left the window — treat as hidden.
            if smartRefreshWasVisible {
                smartRefreshWasVisible = false
                auBannerView?.pauseSmartRefresh()
            }
            return
        }

        let frameInWindow = window.convert(view.frame, from: view.superview)
        guard frameInWindow.height > 0 else { return }

        let intersection = frameInWindow.intersection(window.bounds)
        let visibleFraction = intersection.height / frameInWindow.height
        let isVisible = visibleFraction >= 0.2

        if isVisible && !smartRefreshWasVisible {
            smartRefreshWasVisible = true
            // Stale-aware resume: if the ad has been off-screen for longer than the
            // refresh interval, fetch demand immediately; otherwise schedule the fetch
            // for the exact remaining time.  Plain resumeAutoRefresh() would always
            // restart the full interval from zero, producing the "timer starts from 0"
            // behaviour the user noticed.
            auBannerView?.resumeSmartRefresh()
        } else if !isVisible && smartRefreshWasVisible {
            smartRefreshWasVisible = false
            auBannerView?.pauseSmartRefresh()
        }
    }

    deinit {
        stopSmartRefreshPolling()
    }

    // MARK: - FDisposableAd

    func dispose() {
        // Stop the polling timer and Prebid auto-refresh, then remove the
        // banner from its superview — removeFromSuperview() is AUBannerView's
        // native destructor. Without this a disposed/refreshing banner keeps
        // firing Prebid auctions invisibly.
        stopSmartRefreshPolling()
        auBannerView?.pauseSmartRefresh()
        auBannerView?.removeFromSuperview()
        auBannerView = nil
        bannerViewInstance = nil
    }

    // MARK: - Manual pause / resume (Dart-driven)
    //
    // Called from the plugin when the Dart visibility layer detects a condition
    // the native geometry poll cannot — most importantly a same-route overlay
    // covering the ad. pause() suppresses the poll and stops Prebid auto-refresh;
    // resume() hands control back to the poll (or resumes directly when smart
    // refresh polling isn't running, e.g. a plain auto-refresh banner).

    func pauseAutoRefresh() {
        isManuallyPaused = true
        smartRefreshWasVisible = false
        auBannerView?.pauseSmartRefresh()
    }

    func resumeAutoRefresh() {
        isManuallyPaused = false
        if smartRefresh {
            // Re-evaluate now instead of waiting up to 0.5s for the next tick;
            // this also preserves the stale-aware resume timing.
            checkSmartRefreshVisibility()
        } else {
            auBannerView?.resumeSmartRefresh()
        }
    }

    /// Force a fresh auction now, ignoring the stale-aware refresh timing — used
    /// by the `onScreenResumed` reload broadcast. The Dart layer only calls this
    /// for on-screen banners, so the visibility poll keeps it active afterwards.
    func forceReload() {
        isManuallyPaused = false
        smartRefreshWasVisible = smartRefresh
        auBannerView?.reloadAd()
    }

    // MARK: - Init

    init(
        adUnitId: String,
        auConfigId: String,
        sizes: [FAdSize],
        isAdaptiveSize: Bool,
        isLazyLoad: Bool,
        smartRefresh: Bool,
        prefetchMarginPoints: CGFloat,
        refreshTimeInterval: Double?,
        adFormat: FAdFormat,
        apiParameters: [AUApi],
        videoProtocols: [AUVideoProtocols],
        videoPlacement: AUPlacement,
        videoPlaybackMethods: [AUVideoPlaybackMethod],
        videoBitrate: FVideoBitrate,
        videoDuration: FVideoDuration,
        pbAdSlot: String?,
        gpId: String?,
        customImpOrtbConfig: String?,
        rootViewController: UIViewController,
        adId: NSNumber,
        manager: AdInstanceManager
    ) {
        self.adUnitId = adUnitId
        self.sizes = sizes
        self.auConfigId = auConfigId
        self.isAdaptiveSize = isAdaptiveSize
        self.isLazyLoad = isLazyLoad
        self.smartRefresh = smartRefresh
        self.prefetchMarginPoints = prefetchMarginPoints
        self.refreshTimeInterval = refreshTimeInterval
        self.adFormat = adFormat
        self.apiParameters = apiParameters
        self.videoProtocols = videoProtocols
        self.videoPlacement = videoPlacement
        self.videoPlaybackMethods = videoPlaybackMethods
        self.videoBitrate = videoBitrate
        self.videoDuration = videoDuration
        self.pbAdSlot = pbAdSlot
        self.gpId = gpId
        self.customImpOrtbConfig = customImpOrtbConfig
        self.rootViewController = rootViewController
        self.manager = manager
        super.init(adId: adId)
    }

    // MARK: - Load

    func load() {
        let mainSize = sizes.first ?? FAdSize(width: 1, height: 1)
        let cgSizes: [CGSize] = sizes.dropFirst().map {
            CGSize(width: $0.width, height: $0.height)
        }

        bannerViewInstance = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: mainSize.width, height: mainSize.height)))
        bannerViewInstance!.adUnitID = adUnitId
        bannerViewInstance!.delegate = self
        // GMA requires a rootViewController on the banner before load(); without it the
        // load can fail and impressions/clicks aren't recorded. This was set on the
        // SDK's own reference banner but missing here — an iOS-only gap (Android needs
        // only a Context, which it has).
        bannerViewInstance!.rootViewController = rootViewController

        var validAdSizes: [NSValue] = [nsValue(for: adSizeFor(cgSize: CGSize(width: mainSize.width, height: mainSize.height)))]

        for cgSize in cgSizes {
            validAdSizes.append(nsValue(for: adSizeFor(cgSize: cgSize)))
        }

        bannerViewInstance!.validAdSizes = validAdSizes

        let request = AdManagerRequest()

        let bannerAdFormat: [AUAdFormat]

        switch adFormat {
        case FAdFormat.banner: bannerAdFormat = [AUAdFormat.banner]
        case FAdFormat.video: bannerAdFormat = [AUAdFormat.video]
        case FAdFormat.bannerAndVideo: bannerAdFormat = [AUAdFormat.banner, AUAdFormat.video]
        }

        auBannerView = AUBannerView(
            configId: auConfigId,
            adSize: CGSize(width: mainSize.width, height: mainSize.height),
            adFormats: bannerAdFormat,
            isLazyLoad: isLazyLoad
        )
        auBannerView?.frame = CGRect(origin: .zero, size: CGSize(width: mainSize.width, height: mainSize.height))
        auBannerView?.backgroundColor = .clear
        // Always set smartRefresh = false on AUBannerView in Flutter.
        // When smartRefresh = true, AUBannerView_Private.onBecameVisible() schedules a
        // DispatchWorkItem that calls fetchRequest() directly after the remaining interval.
        // Because Flutter has no UIScrollView ancestors, onBecameHidden() never fires to
        // cancel that work item — so fetchRequest() fires even when the ad is off-screen,
        // bypassing our external stopAutoRefresh() call.
        // With smartRefresh = false the guard in onBecameVisible() exits after
        // super.onBecameVisible() (which handles lazy load via detectVisible()), so no
        // work item is ever scheduled. Our 0.5s polling timer owns stop/resume entirely.
        auBannerView?.smartRefresh = false
        auBannerView?.prefetchMarginPoints = prefetchMarginPoints

        if let customImpOrtbConfig = customImpOrtbConfig {
            auBannerView?.setImpOrtbConfig(ortbConfig: customImpOrtbConfig)
        }

        // AUBannerView.bannerParameters / .videoParameters are Optional and nil
        // by default (unlike AUInterstitialView, which instantiates them). The
        // previous `auBannerView?.bannerParameters?.api = …` optional-chained
        // into nil, so every banner/video signal (API frameworks, protocols,
        // placement, playback, bitrate, duration) was silently dropped from the
        // bid request. Build the parameter objects and assign them whole.
        let bannerParameters = AUBannerParameters()
        bannerParameters.api = apiParameters
        auBannerView?.bannerParameters = bannerParameters

        let videoParameters = AUVideoParameters(mimes: ["video/x-flv", "video/mp4"])
        videoParameters.api = apiParameters
        videoParameters.protocols = videoProtocols
        videoParameters.placement = videoPlacement
        videoParameters.playbackMethod = videoPlaybackMethods
        videoParameters.minBitrate = videoBitrate.min.intValue
        videoParameters.maxBitrate = videoBitrate.max.intValue
        videoParameters.minDuration = videoDuration.min.intValue
        videoParameters.maxDuration = videoDuration.max.intValue
        auBannerView?.videoParameters = videoParameters

        auBannerView?.addAdditionalSize(sizes: cgSizes)
        auBannerView?.adUnitConfiguration.adSlot = pbAdSlot
        auBannerView?.adUnitConfiguration?.setGPID(gpId)

        if let refreshTimeInterval = refreshTimeInterval {
            // refreshTimeInterval is already in milliseconds (sent from Dart as seconds * 1000).
            // setAutoRefreshMillis expects milliseconds — no conversion needed.
            auBannerView?.adUnitConfiguration.setAutoRefreshMillis(time: refreshTimeInterval)
        }

        auBannerView?.createAd(
            with: request,
            gamBanner: bannerViewInstance!,
            eventHandler: AUBannerEventHandler(adUnitId: adUnitId, gamView: bannerViewInstance!)
        )

        auBannerView?.onLoadRequest = { [weak self] gamRequest in
            guard let request = gamRequest as? Request,
                  let bannerViewInstance = self?.bannerViewInstance else { return }
            bannerViewInstance.load(request)
        }

        if smartRefresh {
            startSmartRefreshPolling()
        }
    }

    // MARK: - FlutterPlatformView

    func view() -> UIView {
        auBannerView!
    }

    // MARK: - Size

    func getPlatformAdSize() -> FAdSize? {
        guard let size = bannerViewInstance?.adSize else { return nil }
        return FAdSize(width: Int(size.size.width), height: Int(size.size.height))
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        manager?.onAdLoaded(ad: self)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
        manager?.onAdFailedToLoad(ad: self, error: FAdError(code: 1, message: error.localizedDescription))
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        manager?.onAdClicked(ad: self)
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        manager?.onAdImpression(ad: self)
    }

    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        manager?.onAdOpened(ad: self)
    }

    // onAdClosed fires once, on actual dismissal. (Previously both
    // will-dismiss and did-dismiss mapped to onAdClosed → duplicate event.)
    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        manager?.onAdClosed(ad: self)
    }
}
