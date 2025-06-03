import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FInterstitialAd: FBaseAd, FAd, FAdWithoutView, FullScreenContentDelegate {
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
    private func createInterstitialORTBConfig(sizes: [CGSize]) -> String {
        let formatStrings = sizes.map { size in
            return "{ \"w\": \(Int(size.width)), \"h\": \(Int(size.height)) }"
        }
        
        let formatArrayString = formatStrings.joined(separator: ", ")
        
        return """
        {
          "banner": {
            "format": [ \(formatArrayString) ]
          }
        }
        """
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
        
        if let customImpOrtbConfig = customImpOrtbConfig {
            interstitialView?.setImpOrtbConfig(ortbConfig: customImpOrtbConfig)
        }
        
        let bannerParameters = AUBannerParameters()
        if let sizes = sizes {
            let cgSizes: [CGSize] = sizes.map {
                CGSize(width: $0.width, height: $0.height)
            }
            bannerParameters.adSizes = cgSizes
            
            //TODO: remove this hack when fixed https://github.com/prebid/prebid-mobile-ios/issues/1135
            let customOrtb = createInterstitialORTBConfig(sizes: cgSizes)
            
            interstitialView?.setImpOrtbConfig(ortbConfig: customOrtb)
            
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
}
