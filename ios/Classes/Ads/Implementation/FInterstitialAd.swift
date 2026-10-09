import Flutter
import GoogleMobileAds
// SPI: the one bridge-only entry point that hands the ad config's raw interstitial values to the
// native SDK. Formats and API frameworks are backend-controlled; this is not a publisher setting.
@_spi(AudienzzBridge) import AudienzziOSSDK

class FInterstitialAd: FBaseAd, FAd, FAdWithoutView, FDisposableAd, FullScreenContentDelegate {
    var requestContext = AUAdRequestContext()

    private let adUnitId: String
    private let auConfigId: String
    private let rootViewController: UIViewController
    private let minSizePercentage: FMinSizePercentage
    /// The interstitial's `prebidConfig.format` (Dart sends `banner` unless the ad config asks for
    /// video) and the ad config's raw `prebidConfig.apis`; nil means the native default.
    private let backendFormat: String?
    private let backendApis: [Int]?
    private let videoProtocols: [AUVideoProtocols]
    private let videoPlacement: AUPlacement
    private let videoPlaybackMethods: [AUVideoPlaybackMethod]
    private let videoBitrate: FVideoBitrate
    private let videoDuration: FVideoDuration
    private let pbAdSlot: String?
    private let gpId: String?
    private let sizes: [FAdSize]?
    private let customImpOrtbConfig: String?
    
    weak var manager: AdInstanceManager?
    
    var interstitialView: AUInterstitialView?
    var interstitialAd: InterstitialAd?
    private(set) var isPresenting = false
    private var disposed = false
    private var loadedAt: TimeInterval?
    
    init(adUnitId: String,
         auConfigId: String,
         minSizePercentage: FMinSizePercentage,
         backendFormat: String? = nil,
         backendApis: [Int]? = nil,
         videoProtocols: [AUVideoProtocols],
         videoPlacement: AUPlacement,
         videoPlaybackMethods: [AUVideoPlaybackMethod],
         videoBitrate: FVideoBitrate,
         videoDuration: FVideoDuration,
         pbAdSlot: String?,
         gpId: String?,
         adId: NSNumber,
         sizes: [FAdSize]?,
         customImpOrtbConfig: String?,
         rootViewController: UIViewController,
         manager: AdInstanceManager) {
        self.adUnitId = adUnitId
        self.auConfigId = auConfigId
        self.minSizePercentage = minSizePercentage
        self.backendFormat = backendFormat
        self.backendApis = backendApis
        self.videoProtocols = videoProtocols
        self.videoPlacement = videoPlacement
        self.videoPlaybackMethods = videoPlaybackMethods
        self.videoBitrate = videoBitrate
        self.videoDuration = videoDuration
        self.pbAdSlot = pbAdSlot
        self.gpId = gpId
        self.sizes = sizes
        self.customImpOrtbConfig = customImpOrtbConfig
        self.rootViewController = rootViewController
        self.manager = manager
        super.init(adId: adId)
    }
    
    func load() {
        let request = AdManagerRequest()
        
        loadInterstitialAd(gamRequest: request)
    }

    /// The publisher's interstitial sizes, if any.
    private var explicitSizes: [CGSize] {
        (sizes ?? []).map { CGSize(width: $0.width, height: $0.height) }
    }

    /// The minimum size percentages are only sent when there are no sizes. With them, Prebid
    /// Server replaces `banner.format` with sizes from its own interstitial list, so a placement
    /// configured for 320x480 asked bidders for sizes it never named. Before 0.3.0 a banner-only
    /// interstitial never sent them.
    var sendsMinSizePercentage: Bool { explicitSizes.isEmpty }

    private func makeInterstitialView() -> AUInterstitialView {
        guard sendsMinSizePercentage else {
            return AUInterstitialView(configId: auConfigId, isLazyLoad: false)
        }
        return AUInterstitialView(
            configId: auConfigId,
            isLazyLoad: false,
            minWidthPerc: minSizePercentage.width.intValue,
            minHeightPerc: minSizePercentage.height.intValue)
    }
    
    private func loadInterstitialAd(gamRequest: AdManagerRequest) {
        // One ad unit whatever the format: formats and API frameworks are backend-controlled. The
        // native view resolves them from the values Dart sent (banner unless the ad config asks
        // for video), validated exactly as the native remote interstitial does.
        interstitialView = makeInterstitialView()
        interstitialView?.setBackendCapabilities(format: backendFormat, apis: backendApis)

        // The video settings Dart sent. Used only when the backend asks for video, and without an
        // `api` list: the native view sets that from the backend.
        let videoParameters: AUVideoParameters? = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters?.protocols = videoProtocols
        videoParameters?.playbackMethod = videoPlaybackMethods
        videoParameters?.placement = videoPlacement
        // OpenRTB 2.6 placement, which modern DSPs read instead of `placement`. Always an
        // interstitial here, as the native default sets it.
        videoParameters?.plcmnt = .interstitial
        videoParameters?.minBitrate = videoBitrate.min.intValue
        videoParameters?.maxBitrate = videoBitrate.max.intValue
        videoParameters?.minDuration = videoDuration.min.intValue
        videoParameters?.maxDuration = videoDuration.max.intValue

        interstitialView?.adUnitConfiguration.adSlot = pbAdSlot
        interstitialView?.adUnitConfiguration.setGPID(gpId)
        

        if let params = videoParameters {
            interstitialView?.videoParameters = params
        }
        
        // Prebid turns these into `banner.format` itself, as the native remote interstitial
        // relies on. The #1135 workaround that also wrote them into impOrtbConfig sent every
        // size twice.
        let bannerParameters = AUBannerParameters()
        if !explicitSizes.isEmpty {
            bannerParameters.adSizes = explicitSizes
        }
        if let customImpOrtbConfig = customImpOrtbConfig {
            interstitialView?.setImpOrtbConfig(ortbConfig: customImpOrtbConfig)
        }

        interstitialView?.bannerParameters = bannerParameters

        interstitialView?.onLoadRequest = { [weak self] gamRequest in
            guard let self = self, !self.disposed else {
                return
            }

            AdManagerInterstitialAd.load(with: self.adUnitId, request: gamRequest as? AdManagerRequest) {[weak self] ad, error in
                guard let self = self, !self.disposed else {
                    return
                }
                
                if let ad = ad {
                    self.interstitialAd = ad
                    self.loadedAt = ProcessInfo.processInfo.systemUptime
                    self.interstitialAd?.fullScreenContentDelegate = self
                    self.interstitialView?.connectHandler(AUInterstitialEventHandler(adUnit: ad))
                    self.manager?.onAdLoaded(ad: self, responseId: ad.responseInfo.responseIdentifier)
                } else {
                    let failure = (error as NSError?) ?? NSError(domain: "audienzz", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Google returned neither an interstitial nor an error."])
                    self.manager?.onAdFailedToLoad(ad: self, error: FAdError(error: failure), domain: failure.domain)
                    print("Failed to load interstitial ad with error: \(String(describing: error?.localizedDescription))")
                }
            }
        }
        // Install the handoff before starting demand (including synchronous failures).
        interstitialView?.requestContext = requestContext
        interstitialView?.createAd(with: gamRequest, adUnitID: adUnitId)
    }
    
    func show() { _ = showIfReady() }

    func showIfReady() -> FlutterError? {
        guard !disposed, !isPresenting, let ad = interstitialAd, let loadedAt else {
            return FlutterError(code: "-1", message: "Interstitial is not ready or already presenting.", details: "audienzz")
        }
        guard ProcessInfo.processInfo.systemUptime - loadedAt < 3600 else {
            interstitialAd = nil
            return FlutterError(code: "-2", message: "Interstitial expired. Load a new ad.", details: "audienzz")
        }
        guard UIApplication.shared.applicationState == .active else {
            return FlutterError(code: "-3", message: "Cannot present an interstitial while the app is inactive.", details: "audienzz")
        }
        do { try ad.canPresent(from: nil) }
        catch {
            let nsError = error as NSError
            return FlutterError(code: String(nsError.code), message: nsError.localizedDescription, details: nsError.domain)
        }
        isPresenting = true
        ad.present(from: nil)
        return nil
    }

    func adDidRecordImpression(_ ad: any FullScreenPresentingAd){
        self.manager?.onAdImpression(ad: self)
    }

    func adDidRecordClick(_ ad: any FullScreenPresentingAd){
        self.manager?.onAdClicked(ad: self)
    }

    func adWillPresentFullScreenContent(_ ad: any FullScreenPresentingAd){
        guard !disposed else { return }
        isPresenting = true
        self.manager?.onAdOpened(ad: self)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        guard isPresenting else { return }
        isPresenting = false
        interstitialAd = nil
        loadedAt = nil
        manager?.onAdClosed(ad: self)
        manager?.dispose(adId: adId)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        guard isPresenting else { return }
        isPresenting = false
        interstitialAd = nil
        loadedAt = nil
        let nsError = error as NSError
        manager?.onAdFailedToShow(ad: self, error: FAdError(code: NSNumber(value: nsError.code),
            message: nsError.localizedDescription), domain: nsError.domain)
        manager?.dispose(adId: adId)
    }

    // MARK: - FDisposableAd

    func dispose() {
        guard !isPresenting else { return }
        disposed = true
        interstitialView?.removeFromSuperview()
        interstitialView = nil
        interstitialAd = nil
    }
}
