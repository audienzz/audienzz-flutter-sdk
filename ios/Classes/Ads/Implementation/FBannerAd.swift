import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FBannerAd: FBaseAd, FAd, FlutterPlatformView, BannerViewDelegate {
    private let adUnitId: String
    private let auConfigId: String
    private let size: FAdSize
    private let isAdaptiveSize: Bool
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
    private let rootViewController: UIViewController
    var auBannerView: AUBannerView?
    
    weak var manager: AdInstanceManager?
    
    init(
        adUnitId: String,
        auConfigId: String,
        size: FAdSize,
        isAdaptiveSize: Bool,
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
        rootViewController: UIViewController,
        adId: NSNumber,
        manager: AdInstanceManager
    ) {
        self.adUnitId = adUnitId
        self.size = size
        self.auConfigId = auConfigId
        self.isAdaptiveSize = isAdaptiveSize
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
        self.rootViewController = rootViewController
        self.manager = manager
        super.init(adId: adId)
    }
    
    func load() {
        let bannerViewInstance = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: size.width.intValue, height: size.height.intValue)))
        bannerViewInstance.adUnitID = adUnitId
        bannerViewInstance.delegate = self
        let request = AdManagerRequest()
        
        let bannerAdFormat:  [AUAdFormat]
        
        switch(adFormat){
        case FAdFormat.banner: bannerAdFormat = [AUAdFormat.banner]
        case FAdFormat.video: bannerAdFormat = [AUAdFormat.video]
        case FAdFormat.bannerAndVideo: bannerAdFormat = [AUAdFormat.banner, AUAdFormat.video]
        }
        
        auBannerView = AUBannerView(configId: auConfigId, adSize: CGSize(width: size.width.intValue, height: size.height.intValue), adFormats: bannerAdFormat, isLazyLoad: false)
        auBannerView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width:size.width.doubleValue, height: size.height.doubleValue))
        auBannerView?.backgroundColor = .clear
        
        auBannerView?.bannerParameters?.api = apiParameters
        auBannerView?.parameters?.api = apiParameters
        auBannerView?.parameters?.protocols = videoProtocols
        auBannerView?.parameters?.placement = videoPlacement
        auBannerView?.parameters?.playbackMethod = videoPlaybackMethods
        auBannerView?.parameters?.minBitrate = videoBitrate.min.intValue
        auBannerView?.parameters?.maxBitrate = videoBitrate.max.intValue
        auBannerView?.parameters?.minDuration = videoDuration.min.intValue
        auBannerView?.parameters?.maxDuration = videoDuration.max.intValue
        auBannerView?.adUnitConfiguration.adSlot = pbAdSlot
        auBannerView?.adUnitConfiguration?.setGPID(gpId)
        
        if let refreshTimeInterval = refreshTimeInterval {
            auBannerView?.adUnitConfiguration.setAutoRefreshMillis(time: refreshTimeInterval * 1000)
        }
        
        auBannerView?.createAd(with: request, gamBanner: bannerViewInstance,
                               eventHandler: AUBannerEventHandler(adUnitId: adUnitId, gamView: bannerViewInstance))
        
        auBannerView?.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request else {
                return
            }
            
            bannerViewInstance.load(request)
        }
        
    }
    
    func view() -> UIView {
        auBannerView!
    }
    
    
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
