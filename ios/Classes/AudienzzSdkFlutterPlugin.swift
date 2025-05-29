import Flutter
import UIKit
import AudienzziOSSDK

public class AudienzzSdkFlutterPlugin: NSObject, FlutterPlugin {
    
    private var manager: AdInstanceManager
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        manager = AdInstanceManager(binaryMessenger: binaryMessenger)
        super.init()
    }
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = AudienzzSdkFlutterPlugin(binaryMessenger: messenger)
        let channel = FlutterMethodChannel(name: "audienzz_sdk_flutter", binaryMessenger: messenger, codec: FlutterStandardMethodCodec(readerWriter: AdReaderWriter()))
        let viewFactory = FAdViewFactory(manager: instance.manager)
        registrar.register(
            viewFactory,
            withId: "audienzz_sdk_flutter/ad_widget"
        )
        
        registrar.publish(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    var rootController: UIViewController {
        var root = UIApplication.shared.delegate?.window??.rootViewController
        
        if root == nil {
#if swift(>=5.0)
            root = UIApplication.shared.windows.first?.rootViewController
#else
            @available(*, deprecated)
            root = UIApplication.shared.keyWindow?.rootViewController
#endif
        }
        
        return root!
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let rootViewController = self.rootController
        
        switch call.method {
        case "_init":
            manager.disposeAllAds()
            result(nil)
        case "initialize":
            if let args = call.arguments as? Dictionary<String, Any>,
               let companyId = args["companyId"] as? String {
                Audienzz.shared.configureSDK(companyId: companyId)
                AudienzzGAMUtils.shared.initializeGAM()
                
                result(AudienzzInitializationStatus.success)
            } else {
                result(FlutterError.init(code: "SDK Initialize Error", message: "Initialization error: No company id provided", details: nil))
            }
        case "loadBannerAd":
            guard let args = call.arguments as? Dictionary<String, Any>,
                  let adId = args["adId"] as? NSNumber,
                  let adUnitId = args["adUnitId"] as? String,
                  let auConfigId = args["auConfigId"] as? String,
                  let adSize = args["adSize"] as? FAdSize,
                  let isAdaptiveSize = args["isAdaptiveSize"] as? Bool,
                  let adFormat = args["adFormat"] as? FAdFormat,
                  let apiParameters = args["apiParameters"] as? [AUApi],
                  let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                  let videoPlacement = args["placement"] as? AUPlacement,
                  let videoPlaybackMethods = args["playbackMethods"] as? [AUVideoPlaybackMethod],
                  let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                  let videoDuration = args["videoDuration"] as? FVideoDuration else  {
                result(FlutterError.init(code: "Load Banner Ad Error", message: "Missing or unexpected call parameters", details: nil))
                return
            }
            
            let refreshTimeInterval = args["refreshTimeInterval"] as? NSNumber
            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            
            let bannerAd = FBannerAd(
                adUnitId: adUnitId,
                auConfigId: auConfigId,
                size: adSize,
                isAdaptiveSize: isAdaptiveSize,
                refreshTimeInterval: refreshTimeInterval?.doubleValue,
                adFormat: adFormat,
                apiParameters: apiParameters,
                videoProtocols: videoProtocols,
                videoPlacement: videoPlacement,
                videoPlaybackMethods: videoPlaybackMethods,
                videoBitrate: videoBitrate,
                videoDuration: videoDuration,
                pbAdSlot: pbAdSlot,
                gpId: gpId,
                rootViewController: rootViewController,
                adId: adId,
                manager: manager)
            
            manager.loadAd(ad: bannerAd)
            result(nil)
            
            
        case "loadRewardedAd":
            guard let args = call.arguments as? Dictionary<String, Any>,
                  let adId = args["adId"] as? NSNumber,
                  let adUnitId = args["adUnitId"] as? String,
                  let auConfigId = args["auConfigId"] as? String,
                  let apiParameters = args["apiParameters"] as? [AUApi],
                  let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                  let videoPlacement = args["placement"] as? AUPlacement,
                  let videoPlaybackMethods = args["playbackMethods"] as? [AUVideoPlaybackMethod],
                  let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                  let videoDuration = args["videoDuration"] as? FVideoDuration else {
                result(FlutterError.init(code: "Rewarded Ad Loading Error", message: "Missing or unexpected call parameters", details: nil))
                return
            }
            
            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            
            let rewardedAd = FRewardedAd(
                adUnitId: adUnitId,
                auConfigId: auConfigId,
                apiParameters: apiParameters,
                videoProtocols: videoProtocols,
                videoPlacement: videoPlacement,
                videoPlaybackMethods: videoPlaybackMethods,
                videoBitrate: videoBitrate,
                videoDuration: videoDuration,
                pbAdSlot: pbAdSlot,
                gpId: gpId,
                adId: adId,
                rootViewController: rootViewController,
                manager: manager)
            
            manager.loadAd(ad:rewardedAd)
            result(nil)
            
            
        case "loadInterstitialAd":
            guard let args = call.arguments as? Dictionary<String, Any>,
                  let adId = args["adId"] as? NSNumber,
                  let adUnitId = args["adUnitId"] as? String,
                  let auConfigId = args["auConfigId"] as? String,
                  let adFormat = args["adFormat"] as? FAdFormat,
                  let minSizePercentage = args["minSizePercentage"] as? FMinSizePercentage,
                  let apiParameters = args["apiParameters"] as? [AUApi],
                  let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                  let videoPlacement = args["placement"] as? AUPlacement,
                  let videoPlaybackMethods = args["playbackMethods"] as? [AUVideoPlaybackMethod],
                  let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                  let videoDuration = args["videoDuration"] as? FVideoDuration else {
                result(FlutterError.init(code: "Interstitial Ad Loading Error", message: "Missing or unexpected call parameters", details: nil))
                return
            }
            
            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            
            let interstitialAd = FInterstitialAd(
                adUnitId: adUnitId,
                auConfigId: auConfigId,
                adFormat: adFormat,
                minSizePercentage: minSizePercentage,
                apiParameters: apiParameters,
                videoProtocols: videoProtocols,
                videoPlacement: videoPlacement,
                videoPlaybackMethods: videoPlaybackMethods,
                videoBitrate: videoBitrate,
                videoDuration: videoDuration,
                pbAdSlot: pbAdSlot,
                gpId: gpId,
                adId: adId,
                rootViewController: rootViewController,
                manager: manager)
            
            manager.loadAd(ad:interstitialAd)
            result(nil)
            
        case "showAdWithoutView":
            if let args = call.arguments as? Dictionary<String, Any>,
               let adId = args["adId"] as? NSNumber
            {
                manager.showAd(withId: adId)
                result(nil)
                
            } else {
                result(FlutterError.init(code: "Show Ad Without View Error", message: "Missing or unexpected call parameters", details: nil))
            }
            
        case "disposeAd":
            if let args = call.arguments as? Dictionary<String, Any>,
               let adId = args["adId"] as? NSNumber
            {
                manager.dispose(adId: adId)
                result(nil)
                
            } else {
                result(FlutterError.init(code: "Dispose Ad Error", message: "Missing or unexpected call parameters", details: nil))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
