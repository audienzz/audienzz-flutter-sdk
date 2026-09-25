import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FBannerAd: FBaseAd, FAd, FDisposableAd, FFullScreenCoverableAd, FlutterPlatformView, BannerViewDelegate {
    var requestContext = AUAdRequestContext()
    internal var loadGoogle: (AdManagerBannerView, Request) -> Void = { $0.load($1) }

    private let adUnitId: String
    private let auConfigId: String
    private let sizes: [FAdSize]
    /// Sizes for the Prebid ad unit when they differ from [sizes]; nil or empty means use [sizes].
    private let prebidSizes: [FAdSize]?
    /// False serves GAM-only; a remote banner with no Prebid sizes turns it off.
    private let headerBidding: Bool
    private let adaptiveBannerConfig: [String: Any]?
    private var renderedSize: CGSize?
    private let isAdaptiveSize: Bool
    private let isLazyLoad: Bool
    private let smartRefresh: Bool
    /// The viewport gate resolved by Dart. v2 is the directional rule; v1 is
    /// the legacy 20% threshold. Held here so this poll cannot resume a banner
    /// Dart's stricter rule has rejected, which is what made the public v2
    /// switch unobservable on Flutter.
    private let smartRefreshV2: Bool
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
    private let pageKey: String?
    private let rootViewController: UIViewController
    var auBannerView: AUBannerView?

    weak var manager: AdInstanceManager?

    private var bannerViewInstance: AdManagerBannerView?

    // MARK: - Flutter smart-refresh visibility polling
    //
    // AUBannerView (VisibleView) detects scroll events via KVO on UIScrollView ancestor
    // contentOffset. Flutter platform views have no UIScrollView in their ancestor chain,
    // so that mechanism never fires. Instead we poll every 0.5 s and pause/resume
    // the SDK-owned refresh controller; Dart also reports viewport/cover state.

    private var smartRefreshTimer: Timer?
    private var smartRefreshWasVisible = false

    // Dart viewport state includes overlays that native geometry cannot see.
    // Publisher pause is a separate native block and is never cleared by this poll.
    private var isViewportPaused = false

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
        guard !isViewportPaused else { return }
        guard let view = auBannerView, let window = view.window else {
            // View left the window — treat as hidden.
            if smartRefreshWasVisible {
                smartRefreshWasVisible = false
                auBannerView?.pauseSmartRefresh()
            }
            return
        }

        let frameInWindow = window.convert(view.frame, from: view.superview)
        guard frameInWindow.height > 0, frameInWindow.width > 0 else { return }

        let intersection = frameInWindow.intersection(window.bounds)
        // `intersection` is `.null` when the rects are disjoint, and a null
        // rect's height is infinite — so a banner moved off the side of the
        // window used to read as fully visible here.
        guard !intersection.isNull, intersection.width > 0 else {
            if smartRefreshWasVisible {
                smartRefreshWasVisible = false
                auBannerView?.pauseSmartRefresh()
            }
            return
        }
        let isVisible = Self.satisfiesViewportRule(
            adRect: frameInWindow,
            visible: intersection,
            directional: smartRefreshV2
        )

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

    /// The same rule Dart applies, so the two layers cannot disagree.
    /// v1: at least 20% of the ad's height on screen. v2: the ad's top edge
    /// fully on screen and no more than half its height below the viewport,
    /// matching `ViewUtil.isRefreshEligible` on Android and
    /// `VisibleView.computeRefreshEligible` on iOS.
    internal static func satisfiesViewportRule(
        adRect: CGRect,
        visible: CGRect,
        directional: Bool
    ) -> Bool {
        guard adRect.height > 0 else { return false }
        if !directional {
            return visible.height / adRect.height >= 0.2
        }
        let topOffscreen = visible.minY - adRect.minY
        let bottomOffscreen = adRect.maxY - visible.maxY
        return topOffscreen < 1 && bottomOffscreen <= adRect.height * 0.5
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

    /// Publisher pause requested before `load()` built the banner.
    ///
    /// The banner does not exist until load() runs, so forwarding through an optional dropped a
    /// pause installed beforehand — and the banner built afterwards held nothing. Dart sends
    /// `publisherPaused` with creation precisely so an eager banner cannot issue a request the
    /// publisher has already stopped, and that only works if the state is remembered here until
    /// there is something to apply it to.
    private var publisherPaused = false
    private var fullScreenCovered = false

    func pauseAutoRefresh() {
        publisherPaused = true
        syncRefreshPause()
    }

    func resumeAutoRefresh() {
        publisherPaused = false
        syncRefreshPause()
    }

    func setFullScreenCovered(_ covered: Bool) {
        fullScreenCovered = covered
        syncRefreshPause()
    }

    private func syncRefreshPause() {
        // Two owners of one native block. A visibility poll, publisher resume, or interstitial
        // dismissal must never release a pause still owned by the other source.
        if publisherPaused || fullScreenCovered {
            auBannerView?.adUnitConfiguration.stopAutoRefresh()
        } else {
            auBannerView?.adUnitConfiguration.resumeAutoRefresh()
        }
    }

    func setViewportVisible(_ visible: Bool) {
        isViewportPaused = !visible
        if !visible {
            smartRefreshWasVisible = false
            auBannerView?.pauseSmartRefresh()
        } else if smartRefresh {
            checkSmartRefreshVisibility()
        } else {
            auBannerView?.resumeSmartRefresh()
        }
    }

    /// Force a fresh auction now, ignoring the stale-aware refresh timing — used
    /// by the `pageImpression` reload broadcast. The Dart layer only calls this
    /// for on-screen banners, so the visibility poll keeps it active afterwards.
    func forceReload() {
        auBannerView?.reloadAd()
    }

    // MARK: - Init

    init(
        adUnitId: String,
        auConfigId: String,
        sizes: [FAdSize],
        prebidSizes: [FAdSize]? = nil,
        headerBidding: Bool = true,
        isAdaptiveSize: Bool,
        adaptiveBannerConfig: [String: Any]? = nil,
        isLazyLoad: Bool,
        smartRefresh: Bool,
        smartRefreshV2: Bool = false,
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
        pageKey: String?,
        rootViewController: UIViewController,
        adId: NSNumber,
        manager: AdInstanceManager
    ) {
        self.adUnitId = adUnitId
        self.sizes = sizes
        self.prebidSizes = prebidSizes
        self.headerBidding = headerBidding
        self.auConfigId = auConfigId
        self.isAdaptiveSize = isAdaptiveSize
        self.adaptiveBannerConfig = adaptiveBannerConfig
        self.isLazyLoad = isLazyLoad
        self.smartRefresh = smartRefresh
        self.smartRefreshV2 = smartRefreshV2
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
        self.pageKey = pageKey
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

        // GAM is sized from `sizes`, Prebid from `prebidSizes` — the split AURemoteConfigBannerView
        // makes. A publisher can allow a size in GAM (for direct-sold line items) that they keep out
        // of header bidding; one list for both asked bidders for it anyway. Falls back to `sizes`,
        // because an empty list has no primary size to build the ad unit from. The view's frame
        // below stays on the GAM size: that is what renders, so layout does not move.
        let prebidList = (prebidSizes?.isEmpty == false) ? prebidSizes! : sizes
        let prebidMainSize = prebidList.first ?? mainSize
        let prebidAdditionalSizes: [CGSize] = prebidList.dropFirst().map {
            CGSize(width: $0.width, height: $0.height)
        }

        auBannerView = AUBannerView(
            configId: auConfigId,
            adSize: CGSize(width: prebidMainSize.width, height: prebidMainSize.height),
            adFormats: bannerAdFormat,
            isLazyLoad: isLazyLoad
        )
        // False serves GAM-only: the banner never asks Prebid and reports no bid events. A remote
        // banner with no Prebid sizes turns it off. Must precede createAd, which starts the first load.
        auBannerView?.headerBiddingEnabled = headerBidding
        // A Flutter banner lives in the single FlutterViewController, so the native page
        // coordinator cannot tell one route's ads from another's by host identity. Tag the view with
        // the route key reported to pageImpression so it matches by value instead — this is what
        // makes page-scoped release/recreate work for Flutter at all. Must precede createAd, which
        // is where the ad joins the current page.
        if let pageKey { auBannerView?.setScreen(pageKey) }
        auBannerView?.frame = CGRect(origin: .zero, size: CGSize(width: mainSize.width, height: mainSize.height))
        auBannerView?.backgroundColor = .clear
        // Flutter owns viewport/cover reporting: UIKit cannot see Flutter's scroll clips or
        // painted overlays. Keep the native viewport gate off and feed the SDK-owned refresh
        // controller through the host pause/resume API instead.
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

        auBannerView?.addAdditionalSize(sizes: prebidAdditionalSizes)
        auBannerView?.adUnitConfiguration.adSlot = pbAdSlot
        auBannerView?.adUnitConfiguration?.setGPID(gpId)

        if let refreshTimeInterval = refreshTimeInterval {
            // refreshTimeInterval is already in milliseconds (sent from Dart as seconds * 1000).
            // setAutoRefreshMillis expects milliseconds — no conversion needed.
            auBannerView?.adUnitConfiguration.setAutoRefreshMillis(time: refreshTimeInterval)
        }

        // Before createAd: the banner requests inside that call for an eager slot, so a pause the
        // publisher installed before this ad existed has to be in place first.
        if publisherPaused || fullScreenCovered {
            auBannerView?.adUnitConfiguration.stopAutoRefresh()
        }

        auBannerView?.requestContext = requestContext
        auBannerView?.onAdSizeChanged = { [weak self] size in
            guard size.width > 0, size.height > 0 else { return }
            self?.renderedSize = size
        }
        auBannerView?.onLoadRequest = { [weak self] gamRequest in
            guard let self, let request = gamRequest as? Request,
                  let bannerView = self.bannerViewInstance else { return }
            // The mounted platform view has the publisher's actual available width.
            // Resolve before EVERY Google request, including after orientation changes.
            self.prepareGoogleSize()
            self.loadGoogle(bannerView, request)
        }
        prepareGoogleSize()
        auBannerView?.createAd(
            with: request,
            gamBanner: bannerViewInstance!,
            eventHandler: AUBannerEventHandler(adUnitId: adUnitId, gamView: bannerViewInstance!)
        )

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
        guard let size = renderedSize ?? bannerViewInstance?.adSize.size,
              size.width > 0, size.height > 0 else { return nil }
        return FAdSize(width: Int(size.width), height: Int(size.height))
    }

    // Internal so bridge tests can exercise the actual request-size preparation.
    func prepareGoogleSize() {
        guard isAdaptiveSize, let banner = bannerViewInstance else { return }
        let mountedWidth = auBannerView?.window != nil ? auBannerView?.bounds.width : nil
        let available = mountedWidth ?? rootViewController.view.bounds.width
        let customWidth = (adaptiveBannerConfig?["customWidth"] as? NSNumber)?.doubleValue ?? 0
        let width = adaptiveBannerConfig?["widthStrategy"] as? String == "CUSTOM" && customWidth > 0
            ? CGFloat(customWidth) : (available > 0 ? available : UIScreen.main.bounds.width)
        let maxHeight = (adaptiveBannerConfig?["maxHeight"] as? NSNumber)?.doubleValue ?? 0
        banner.adSize = maxHeight > 0
            ? inlineAdaptiveBanner(width: width, maxHeight: CGFloat(maxHeight))
            : currentOrientationInlineAdaptiveBanner(width: width)
        // Keep configured fixed reservation sizes available alongside the adaptive descriptor.
        banner.validAdSizes = [nsValue(for: banner.adSize)] + sizes.map {
            nsValue(for: adSizeFor(cgSize: CGSize(width: $0.width, height: $0.height)))
        }
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
