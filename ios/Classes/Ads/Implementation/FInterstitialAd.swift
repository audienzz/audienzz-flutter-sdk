import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FInterstitialAd: FBaseAd, FAd, FAdWithoutView, FDisposableAd, FullScreenContentDelegate {
    var requestContext = AUAdRequestContext()

    private let adUnitId: String
    private let auConfigId: String
    private let rootViewController: UIViewController
    private let adFormat: FAdFormat
    private let minSizePercentage: FMinSizePercentage
    private let apiParameters: [AUApi]
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
         adFormat: FAdFormat,
         minSizePercentage: FMinSizePercentage,
         apiParameters: [AUApi],
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
        self.adFormat = adFormat
        self.minSizePercentage = minSizePercentage
        self.apiParameters = apiParameters
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
        
        loadInterstitialAd(gamRequest: request,adFormat: adFormat)
    }
    
    //TODO: remove this hack when fixed https://github.com/prebid/prebid-mobile-ios/issues/1135
    // Merges the #1135 banner.format sizes into the publisher's own
    // impOrtbConfig instead of overwriting it — a second setImpOrtbConfig call
    // used to clobber the publisher's deals/floors/first-party data. The
    // publisher config wins for every key it sets; we only fill in
    // banner.format when the publisher didn't specify it.
    private func mergedInterstitialORTBConfig(publisher: String?, sizes: [CGSize]) -> String? {
        let formats: [[String: Int]] = sizes.map {
            ["w": Int($0.width), "h": Int($0.height)]
        }

        var root: [String: Any] = [:]
        if let publisher = publisher,
           let data = publisher.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        }

        var banner = (root["banner"] as? [String: Any]) ?? [:]
        if banner["format"] == nil {
            banner["format"] = formats
        }
        root["banner"] = banner

        guard let out = try? JSONSerialization.data(withJSONObject: root),
              let json = String(data: out, encoding: .utf8) else {
            // Serialization failed — fall back to the publisher config so at
            // least the customer's own signals still reach the request.
            return publisher
        }
        return json
    }
    
    private func loadInterstitialAd(gamRequest: AdManagerRequest, adFormat: FAdFormat) {
        let adFormats: [AUAdFormat]
        let videoParameters: AUVideoParameters?

        switch adFormat {
        case .banner:
            adFormats = [.banner]
            videoParameters = nil
            interstitialView = AUInterstitialView(
                configId: auConfigId,
                adFormats: adFormats,
                isLazyLoad: false)
        case .video:
            adFormats = [.video]
            videoParameters = AUVideoParameters(mimes: ["video/mp4"])
            videoParameters?.protocols = videoProtocols
            videoParameters?.playbackMethod = videoPlaybackMethods
            videoParameters?.placement = videoPlacement
            videoParameters?.api = apiParameters
            videoParameters?.minBitrate = videoBitrate.min.intValue
            videoParameters?.maxBitrate = videoBitrate.max.intValue
            videoParameters?.minDuration = videoDuration.min.intValue
            videoParameters?.maxDuration = videoDuration.max.intValue
            interstitialView = AUInterstitialView(
                configId: auConfigId,
                adFormats: adFormats,
                isLazyLoad: false,
                minWidthPerc: minSizePercentage.width.intValue,
                minHeightPerc:  minSizePercentage.height.intValue)
        case .bannerAndVideo:
            adFormats = [.banner, .video]
            videoParameters = AUVideoParameters(mimes: ["video/mp4"])
            videoParameters?.protocols = videoProtocols
            videoParameters?.playbackMethod = videoPlaybackMethods
            videoParameters?.placement = videoPlacement
            videoParameters?.api = apiParameters
            videoParameters?.minBitrate = videoBitrate.min.intValue
            videoParameters?.maxBitrate = videoBitrate.max.intValue
            videoParameters?.minDuration = videoDuration.min.intValue
            videoParameters?.maxDuration = videoDuration.max.intValue
            interstitialView = AUInterstitialView(
                configId: auConfigId,
                adFormats: adFormats,
                isLazyLoad: false,
                minWidthPerc: minSizePercentage.width.intValue,
                minHeightPerc:  minSizePercentage.height.intValue)
        }
        
        interstitialView?.adUnitConfiguration.adSlot = pbAdSlot
        interstitialView?.adUnitConfiguration.setGPID(gpId)
        

        if let params = videoParameters {
            interstitialView?.videoParameters = params
        }
        
        let bannerParameters = AUBannerParameters()
        if let sizes = sizes {
            let cgSizes: [CGSize] = sizes.map {
                CGSize(width: $0.width, height: $0.height)
            }
            bannerParameters.adSizes = cgSizes

            //TODO: remove this hack when fixed https://github.com/prebid/prebid-mobile-ios/issues/1135
            // Merge the sizes into (not over) the publisher's impOrtbConfig.
            if let merged = mergedInterstitialORTBConfig(publisher: customImpOrtbConfig, sizes: cgSizes) {
                interstitialView?.setImpOrtbConfig(ortbConfig: merged)
            }
        } else if let customImpOrtbConfig = customImpOrtbConfig {
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
