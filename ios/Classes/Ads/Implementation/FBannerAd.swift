import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FBannerAd: FBaseAd, FAd, FlutterPlatformView, BannerViewDelegate {
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
        guard let view = auBannerView, let window = view.window else {
            // View left the window — treat as hidden.
            if smartRefreshWasVisible {
                smartRefreshWasVisible = false
                auBannerView?.adUnitConfiguration?.stopAutoRefresh()
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
            auBannerView?.adUnitConfiguration?.resumeAutoRefresh()
        } else if !isVisible && smartRefreshWasVisible {
            smartRefreshWasVisible = false
            auBannerView?.adUnitConfiguration?.stopAutoRefresh()
        }
    }

    deinit {
        stopSmartRefreshPolling()
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
        auBannerView?.bannerParameters?.api = apiParameters
        auBannerView?.addAdditionalSize(sizes: cgSizes)
        auBannerView?.videoParameters?.api = apiParameters
        auBannerView?.videoParameters?.protocols = videoProtocols
        auBannerView?.videoParameters?.placement = videoPlacement
        auBannerView?.videoParameters?.playbackMethod = videoPlaybackMethods
        auBannerView?.videoParameters?.minBitrate = videoBitrate.min.intValue
        auBannerView?.videoParameters?.maxBitrate = videoBitrate.max.intValue
        auBannerView?.videoParameters?.minDuration = videoDuration.min.intValue
        auBannerView?.videoParameters?.maxDuration = videoDuration.max.intValue
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

    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        manager?.onAdClosed(ad: self)
    }

    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        manager?.onAdClosed(ad: self)
    }
}
