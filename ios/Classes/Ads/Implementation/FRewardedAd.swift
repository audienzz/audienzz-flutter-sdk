import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FRewardedAd: FBaseAd, FAd, FAdWithoutView, GADFullScreenContentDelegate {
    private let adUnitId: String
    private let auConfigId: String
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
    private let rootViewController: UIViewController
    
    weak var manager: AdInstanceManager?
    
    var rewardedView: AURewardedView?
    var rewardedAd: GADRewardedAd?
    
    init(
        adUnitId: String,
        auConfigId: String,
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
        
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.api = apiParameters
        videoParameters.protocols = videoProtocols
        videoParameters.playbackMethod = videoPlaybackMethods
        videoParameters.placement = videoPlacement
        videoParameters.maxBitrate = videoBitrate.max.intValue
        videoParameters.minBitrate = videoBitrate.min.intValue
        videoParameters.maxDuration = videoDuration.max.intValue
        videoParameters.maxDuration = videoDuration.min.intValue
        
        rewardedView = AURewardedView(configId: auConfigId, isLazyLoad: false)
        rewardedView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: rootViewController.view.frame.size.width, height: rootViewController.view.frame.size.height))
        rewardedView?.backgroundColor = .magenta
        rewardedView?.parameters = videoParameters
        
        rewardedView?.adUnitConfiguration.adSlot = pbAdSlot
        if let keyword = keyword {
            rewardedView?.adUnitConfiguration.addExtKeyword(keyword)
        }
        if let keywords = keywords {
            rewardedView?.adUnitConfiguration.addExtKeywords(Set(keywords))
        }
        if let appContent = appContent {
            rewardedView?.adUnitConfiguration.setAppContent(appContent)
        }
        
        rewardedView?.adUnitConfiguration.setGPID(gpId)

        
        
        rewardedView?.createAd(with: request, adUnitID: adUnitId)
        
        rewardedView?.onLoadRequest = {[weak self]  gamRequest in
            guard let self = self else {
                return
            }
            
            GADRewardedAd.load(withAdUnitID: self.adUnitId, request: gamRequest as? GADRequest) { [weak self] ad, error in
                guard let self = self else {
                    return
                }
                
                if let ad = ad {
                    self.rewardedAd = ad
                    self.rewardedAd?.fullScreenContentDelegate = self
                    self.rewardedView?.connectHandler(AURewardedEventHandler(adUnit: ad))
                    self.manager?.onAdLoaded(ad:self)
                } else {
                    self.manager?.onAdFailedToLoad(ad:self, error: FAdError(code: 1, message: error?.localizedDescription ?? ""))
                    print("Failed to load rewarded ad with error: \(String(describing: error?.localizedDescription))")
                }
            }
        }
    }
    
    func show() {
        if let rewardedAd = rewardedAd {
            rewardedAd.present(fromRootViewController: nil) { [weak self] in
                guard let self = self,
                      let reward = self.rewardedAd?.adReward else { return }
                
                let fltReward = FRewardItem(
                    amount: reward.amount,
                    type: reward.type
                )
                self.manager?.onRewardedAdUserEarnedReward(ad:self, reward: fltReward)
            }
        } else {
            print("RewardedAd failed to show because the ad was not ready.")
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
