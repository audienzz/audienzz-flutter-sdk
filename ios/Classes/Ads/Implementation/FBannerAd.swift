import Flutter
import GoogleMobileAds
import AudienzziOSSDK

class FBannerAd: FBaseAd, FAd, FlutterPlatformView, BannerViewDelegate {
    private let adUnitId: String
    private let auConfigId: String
    private let sizes: [FAdSize]
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
    private let customImpOrtbConfig: String?
    private let rootViewController: UIViewController
    var auBannerView: AUBannerView?
    
    weak var manager: AdInstanceManager?
    
    private var bannerViewInstance: AdManagerBannerView?
    
    init(
        adUnitId: String,
        auConfigId: String,
        sizes: [FAdSize],
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
        customImpOrtbConfig: String?,
        rootViewController: UIViewController,
        adId: NSNumber,
        manager: AdInstanceManager
    ) {
        self.adUnitId = adUnitId
        self.sizes = sizes
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
        self.customImpOrtbConfig = customImpOrtbConfig
        self.rootViewController = rootViewController
        self.manager = manager
        super.init(adId: adId)
    }
    
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
        
        let bannerAdFormat:  [AUAdFormat]
        
        switch(adFormat){
        case FAdFormat.banner: bannerAdFormat = [AUAdFormat.banner]
        case FAdFormat.video: bannerAdFormat = [AUAdFormat.video]
        case FAdFormat.bannerAndVideo: bannerAdFormat = [AUAdFormat.banner, AUAdFormat.video]
        }
        
        auBannerView = AUBannerView(configId: auConfigId, adSize: CGSize(width: mainSize.width, height: mainSize.height), adFormats: bannerAdFormat, isLazyLoad: false)
        auBannerView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width:mainSize.width, height: mainSize.height))
        auBannerView?.backgroundColor = .clear
        
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
            auBannerView?.adUnitConfiguration.setAutoRefreshMillis(time: refreshTimeInterval * 1000)
        }
        
        auBannerView?.createAd(with: request, gamBanner: bannerViewInstance!,
                               eventHandler: AUBannerEventHandler(adUnitId: adUnitId, gamView: bannerViewInstance!))
        
        auBannerView?.onLoadRequest = { gamRequest in
            guard let request = gamRequest as? Request,
                  let bannerViewInstance = self.bannerViewInstance else {
                return
            }
            
            bannerViewInstance.load(request)
        }
        
    }
    
    func view() -> UIView {
        auBannerView!
    }
    
    func getPlatformAdSize() -> FAdSize? {
        let assignedSize = bannerViewInstance?.adSize
        guard let assignedSize = assignedSize else {
            return nil
        }
        
        return FAdSize(width: Int(assignedSize.size.width), height: Int(assignedSize.size.height))
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
