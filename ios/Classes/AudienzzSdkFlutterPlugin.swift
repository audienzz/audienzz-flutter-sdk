import AudienzziOSSDK
import Flutter
import UIKit

public class AudienzzSdkFlutterPlugin: NSObject, FlutterPlugin {

    private var manager: AdInstanceManager
    private var targetingWrapper: AudienzzTargetingWrapper

    init(binaryMessenger: FlutterBinaryMessenger) {
        manager = AdInstanceManager(binaryMessenger: binaryMessenger)
        targetingWrapper = AudienzzTargetingWrapper()
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let instance = AudienzzSdkFlutterPlugin(binaryMessenger: messenger)
        let channel = FlutterMethodChannel(
            name: "audienzz_sdk_flutter",
            binaryMessenger: messenger,
            codec: FlutterStandardMethodCodec(readerWriter: AdReaderWriter())
        )
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

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let rootViewController = self.rootController

        switch call.method {
        case "_init":
            manager.disposeAllAds()
            result(nil)
        case "initialize":
            if let args = call.arguments as? [String: Any],
                let companyId = args["companyId"] as? String
            {
                Audienzz.shared.configureSDK(companyId: companyId)
                AudienzzGAMUtils.shared.initializeGAM()

                result(AudienzzInitializationStatus.success)
            } else {
                result(
                    FlutterError.init(
                        code: "SDK Initialize Error",
                        message: "Initialization error: No company id provided",
                        details: nil
                    )
                )
            }
        case "loadBannerAd":
            guard let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber,
                let adUnitId = args["adUnitId"] as? String,
                let auConfigId = args["auConfigId"] as? String,
                let adSizes = args["adSizes"] as? [FAdSize],
                let isAdaptiveSize = args["isAdaptiveSize"] as? Bool,
                let adFormat = args["adFormat"] as? FAdFormat,
                let apiParameters = args["apiParameters"] as? [AUApi],
                let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                let videoPlacement = args["placement"] as? AUPlacement,
                let videoPlaybackMethods = args["playbackMethods"]
                    as? [AUVideoPlaybackMethod],
                let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                let videoDuration = args["videoDuration"] as? FVideoDuration
            else {
                result(
                    FlutterError.init(
                        code: "Load Banner Ad Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            let refreshTimeInterval = args["refreshTimeInterval"] as? NSNumber
            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            let customImpOrtbConfig = args["impOrtbConfig"] as? String

            let bannerAd = FBannerAd(
                adUnitId: adUnitId,
                auConfigId: auConfigId,
                sizes: adSizes,
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
                customImpOrtbConfig: customImpOrtbConfig,
                rootViewController: rootViewController,
                adId: adId,
                manager: manager
            )

            manager.loadAd(ad: bannerAd)
            result(nil)

        case "loadRewardedAd":
            guard let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber,
                let adUnitId = args["adUnitId"] as? String,
                let auConfigId = args["auConfigId"] as? String,
                let apiParameters = args["apiParameters"] as? [AUApi],
                let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                let videoPlacement = args["placement"] as? AUPlacement,
                let videoPlaybackMethods = args["playbackMethods"]
                    as? [AUVideoPlaybackMethod],
                let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                let videoDuration = args["videoDuration"] as? FVideoDuration
            else {
                result(
                    FlutterError.init(
                        code: "Rewarded Ad Loading Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            let customImpOrtbConfig = args["impOrtbConfig"] as? String

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
                customImpOrtbConfig: customImpOrtbConfig,
                adId: adId,
                rootViewController: rootViewController,
                manager: manager
            )

            manager.loadAd(ad: rewardedAd)
            result(nil)

        case "loadInterstitialAd":
            guard let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber,
                let adUnitId = args["adUnitId"] as? String,
                let auConfigId = args["auConfigId"] as? String,
                let adFormat = args["adFormat"] as? FAdFormat,
                let minSizePercentage = args["minSizePercentage"]
                    as? FMinSizePercentage,
                let apiParameters = args["apiParameters"] as? [AUApi],
                let videoProtocols = args["protocols"] as? [AUVideoProtocols],
                let videoPlacement = args["placement"] as? AUPlacement,
                let videoPlaybackMethods = args["playbackMethods"]
                    as? [AUVideoPlaybackMethod],
                let videoBitrate = args["videoBitrate"] as? FVideoBitrate,
                let videoDuration = args["videoDuration"] as? FVideoDuration
            else {
                result(
                    FlutterError.init(
                        code: "Interstitial Ad Loading Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            let adSizes = args["adSizes"] as? [FAdSize]
            let customImpOrtbConfig = args["impOrtbConfig"] as? String

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
                sizes: adSizes,
                customImpOrtbConfig: customImpOrtbConfig,
                rootViewController: rootViewController,
                manager: manager
            )

            manager.loadAd(ad: interstitialAd)
            result(nil)

        case "showAdWithoutView":
            if let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber
            {
                manager.showAd(withId: adId)
                result(nil)

            } else {
                result(
                    FlutterError.init(
                        code: "Show Ad Without View Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
            }
        case "getPlatformAdSize":
            if let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber
            {
                let ad = manager.ad(for: adId)

                if let bannerAd = ad as? FBannerAd {
                    let adSize = bannerAd.getPlatformAdSize()
                    result(adSize)
                } else {
                    result(nil)
                }

            } else {
                result(nil)
            }

        case "disposeAd":
            if let args = call.arguments as? [String: Any],
                let adId = args["adId"] as? NSNumber
            {
                manager.dispose(adId: adId)
                result(nil)

            } else {
                result(
                    FlutterError.init(
                        code: "Dispose Ad Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
            }

        case "setUserLatLng":
            targetingWrapper.setUserLatLng(call, result: result)

        case "getUserLatLng":
            targetingWrapper.getUserLatLng(result: result)

        // Basic property getters/setters
        case "getUserKeywords":
            let keywords = AUTargeting.shared.getUserKeywords().joined(
                separator: ","
            )
            result(keywords.isEmpty ? nil : keywords)

        case "getKeywordSet":
            result(AUTargeting.shared.getUserKeywords())

        case "setPublisherName":
            if let value = call.arguments as? [String: Any],
                let publisherName = value["value"] as? String?
            {
                AUTargeting.shared.publisherName = publisherName
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid publisher name",
                        details: nil
                    )
                )
            }

        case "getPublisherName":
            result(AUTargeting.shared.publisherName)

        case "setDomain":
            if let value = call.arguments as? [String: Any],
                let domain = value["value"] as? String
            {
                AUTargeting.shared.domain = domain
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Domain cannot be null",
                        details: nil
                    )
                )
            }

        case "getDomain":
            result(AUTargeting.shared.domain ?? "")

        case "setStoreUrl":
            if let value = call.arguments as? [String: Any],
                let storeUrl = value["value"] as? String
            {
                AUTargeting.shared.storeURL = storeUrl
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Store URL cannot be null",
                        details: nil
                    )
                )
            }

        case "getStoreUrl":
            result(AUTargeting.shared.storeURL ?? "")

        case "getAccessControlList":
            result(AUTargeting.shared.getAccessControlList())

        case "setOmidPartnerName":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.omidPartnerName = value["value"] as? String
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "getOmidPartnerName":
            result(AUTargeting.shared.omidPartnerName)

        case "setOmidPartnerVersion":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.omidPartnerVersion =
                    value["value"] as? String
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "getOmidPartnerVersion":
            result(AUTargeting.shared.omidPartnerVersion)

        case "setSubjectToCOPPA":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.subjectToCOPPA = value["value"] as? Bool
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "isSubjectToCOPPA":
            result(AUTargeting.shared.subjectToCOPPA)

        case "setSubjectToGDPR":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.subjectToGDPR = value["value"] as? Bool
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "isSubjectToGDPR":
            result(AUTargeting.shared.subjectToGDPR)

        case "setGdprConsentString":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.gdprConsentString = value["value"] as? String
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "getGdprConsentString":
            result(AUTargeting.shared.gdprConsentString)

        case "setPurposeConsents":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.purposeConsents = value["value"] as? String
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "getPurposeConsents":
            result(AUTargeting.shared.purposeConsents)

        case "setBundleName":
            if let value = call.arguments as? [String: Any] {
                // iOS uses sourceapp for bundle name equivalent
                AUTargeting.shared.sourceapp = value["value"] as? String
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Invalid arguments",
                        details: nil
                    )
                )
            }

        case "getBundleName":
            result(AUTargeting.shared.sourceapp)

        case "getExtDataDictionary":
            result(AUTargeting.shared.getAppExtData())

        case "isDeviceAccessConsent":
            result(AUTargeting.shared.getDeviceAccessConsent())

        case "setUserExt":
            targetingWrapper.setUserExt(call, result: result)

        case "getUserExt":
            result(AUTargeting.shared.userExt)

        // User keyword methods
        case "addUserKeyword":
            if let args = call.arguments as? [String: Any],
                let keyword = args["keyword"] as? String
            {
                AUTargeting.shared.addUserKeyword(keyword)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Keyword cannot be null",
                        details: nil
                    )
                )
            }

        case "addUserKeywords":
            if let args = call.arguments as? [String: Any],
                let keywords = args["keywords"] as? [String]
            {
                AUTargeting.shared.addUserKeywords(Set(keywords))
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Keywords cannot be null",
                        details: nil
                    )
                )
            }

        case "removeUserKeyword":
            if let args = call.arguments as? [String: Any],
                let keyword = args["keyword"] as? String
            {
                AUTargeting.shared.removeUserKeyword(keyword)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Keyword cannot be null",
                        details: nil
                    )
                )
            }

        case "clearUserKeywords":
            AUTargeting.shared.clearUserKeywords()
            result(nil)

        case "setExternalUserIds":
            targetingWrapper.setExternalUserIds(call, result: result)

        case "getExternalUserIds":
            targetingWrapper.getExternalUserIds(result: result)

        case "addExtData":
            if let args = call.arguments as? [String: Any],
                let key = args["key"] as? String,
                let value = args["value"] as? String
            {
                AUTargeting.shared.addAppExtData(key: key, value: value)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Key and value cannot be null",
                        details: nil
                    )
                )
            }

        case "updateExtData":
            if let args = call.arguments as? [String: Any],
                let key = args["key"] as? String,
                let values = args["values"] as? [String]
            {
                AUTargeting.shared.updateAppExtData(
                    key: key,
                    value: Set(values)
                )
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Key and values cannot be null",
                        details: nil
                    )
                )
            }

        case "removeExtData":
            if let args = call.arguments as? [String: Any],
                let key = args["key"] as? String
            {
                AUTargeting.shared.removeAppExtData(for: key)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Key cannot be null",
                        details: nil
                    )
                )
            }

        case "clearExtData":
            AUTargeting.shared.clearAppExtData()
            result(nil)

        case "addBidderToAccessControlList":
            if let args = call.arguments as? [String: Any],
                let bidderName = args["bidderName"] as? String
            {
                AUTargeting.shared.addBidderToAccessControlList(bidderName)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Bidder name cannot be null",
                        details: nil
                    )
                )
            }

        case "removeBidderFromAccessControlList":
            if let args = call.arguments as? [String: Any],
                let bidderName = args["bidderName"] as? String
            {
                AUTargeting.shared.removeBidderFromAccessControlList(bidderName)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Bidder name cannot be null",
                        details: nil
                    )
                )
            }

        case "clearAccessControlList":
            AUTargeting.shared.clearAccessControlList()
            result(nil)

        case "getPurposeConsent":
            if let args = call.arguments as? [String: Any],
                let index = args["index"] as? Int
            {
                result(AUTargeting.shared.getPurposeConsent(index: index))
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Index cannot be null",
                        details: nil
                    )
                )
            }

        case "getGlobalOrtbConfig":
            result(AUTargeting.shared.getGlobalOrtbConfig())

        case "setGlobalOrtbConfig":
            if let args = call.arguments as? [String: Any],
                let config = args["config"] as? [String: Any]
            {
                do {
                    let jsonData = try JSONSerialization.data(
                        withJSONObject: config
                    )
                    let jsonString =
                        String(data: jsonData, encoding: .utf8) ?? "{}"
                    AUTargeting.shared.setGlobalOrtbConfig(
                        ortbConfig: jsonString
                    )
                    result(nil)
                } catch {
                    result(
                        FlutterError(
                            code: "JSON_ERROR",
                            message: "Failed to serialize config",
                            details: error.localizedDescription
                        )
                    )
                }
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Config cannot be null",
                        details: nil
                    )
                )
            }

        case "addGlobalTargeting":
            targetingWrapper.addGlobalTargeting(call, result: result)

        case "removeGlobalTargeting":
            if let args = call.arguments as? [String: Any],
                let key = args["key"] as? String
            {
                AUTargeting.shared.removeGlobalTargeting(key: key)
                result(nil)
            } else {
                result(
                    FlutterError(
                        code: "INVALID_ARGUMENT",
                        message: "Key cannot be null",
                        details: nil
                    )
                )
            }

        case "clearGlobalTargeting":
            AUTargeting.shared.clearGlobalTargeting()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
