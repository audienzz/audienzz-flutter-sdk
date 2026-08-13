import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FInterstitialAd: FBaseAd, FAd, FAdWithoutView, FDisposableAd, FullScreenContentDelegate {
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

        interstitialView?.createAd(with: gamRequest, adUnitID: adUnitId)

        interstitialView?.onLoadRequest = { [weak self] gamRequest in
            guard let self = self else {
                return
            }

            InterstitialAd.load(with: self.adUnitId, request: gamRequest as? AdManagerRequest) {[weak self] ad, error in
                guard let self = self else {
                    return
                }
                
                if let ad = ad {
                    self.interstitialAd = ad
                    self.interstitialAd?.fullScreenContentDelegate = self
                    self.interstitialView?.connectHandler(AUInterstitialEventHandler(adUnit: ad))
                    self.manager?.onAdLoaded(ad: self)
                } else {
                    self.manager?.onAdFailedToLoad(ad: self, error: FAdError(code: 1, message: error?.localizedDescription ?? ""))
                    print("Failed to load interstitial ad with error: \(String(describing: error?.localizedDescription))")
                }
            }
        }
    }
    
    func show() {
        if let interstitialAd = interstitialAd {
            interstitialAd.present(from: nil)
        } else {
            print("Interstitial Ad failed to show because the ad was not ready.")
        }
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

    func adWillDismissFullScreenContent(_ ad: any FullScreenPresentingAd){
        self.manager?.onAdClosed(ad: self)
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        // GAM full-screen ads are single-use. Drop the reference so a second
        // show() reports "not ready" instead of silently no-op-ing.
        self.interstitialAd = nil
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        // Surface the show failure (previously invisible) and unblock any Dart
        // flow awaiting onAdClosed, then release the consumed ad.
        print("Interstitial ad failed to present: \(error.localizedDescription)")
        self.manager?.onAdClosed(ad: self)
        self.interstitialAd = nil
    }

    // MARK: - FDisposableAd

    func dispose() {
        interstitialView?.removeFromSuperview()
        interstitialView = nil
        interstitialAd = nil
    }
}
