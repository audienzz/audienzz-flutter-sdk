import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FInterstitialAd: FBaseAd, FAd, FAdWithoutView, GADFullScreenContentDelegate {
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
    private let keyword: String?
    private let keywords: [String]?
    private let appContent: AUMORTBAppContent?
    
    weak var manager: AdInstanceManager?
    
    var interstitialView: AUInterstitialView?
    var interstitialAd: GADInterstitialAd?
    
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
         keyword: String?,
         keywords: [String]?,
         appContent: AUMORTBAppContent?,
         adId: NSNumber,
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
        self.keyword = keyword
        self.keywords = keywords
        self.appContent = appContent
        self.rootViewController = rootViewController
        self.manager = manager
        super.init(adId: adId)
    }
    
    func load() {
        let request = GAMRequest()
        
        loadInterstitialAd(gamRequest: request,adFormat: adFormat)
    }
    
    private func loadInterstitialAd(gamRequest: GAMRequest, adFormat: FAdFormat) {
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
        if let keyword = keyword {
            interstitialView?.adUnitConfiguration.addExtKeyword(keyword)
        }
        if let keywords = keywords {
            interstitialView?.adUnitConfiguration.addExtKeywords(Set(keywords))
        }
        if let appContent = appContent {
            interstitialView?.adUnitConfiguration.setAppContent(appContent)
        }
        
        interstitialView?.adUnitConfiguration.setGPID(gpId)

        if let params = videoParameters {
            interstitialView?.parameters = params
        }

        interstitialView?.createAd(with: gamRequest, adUnitID: adUnitId)

        interstitialView?.onLoadRequest = { [weak self] gamRequest in
            guard let self = self else {
                return
            }

            GAMInterstitialAd.load(withAdManagerAdUnitID: self.adUnitId, request: gamRequest as? GAMRequest) {[weak self] ad, error in
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
            interstitialAd.present(fromRootViewController: nil)
        } else {
            print("Interstitial Ad failed to show because the ad was not ready.")
        }
    }
    
    func adDidRecordImpression(_ ad: any GADFullScreenPresentingAd){
        self.manager?.onAdImpression(ad: self)
    }
    
    func adDidRecordClick(_ ad: any GADFullScreenPresentingAd){
        self.manager?.onAdClicked(ad: self)
    }
    
    func adWillPresentFullScreenContent(_ ad: any GADFullScreenPresentingAd){
        self.manager?.onAdOpened(ad: self)
    }
    
    func adWillDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd){
        self.manager?.onAdClosed(ad: self)
    }
}
