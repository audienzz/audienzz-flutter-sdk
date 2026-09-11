import AudienzziOSSDK
import Flutter
import PrebidMobile
import UIKit

private let flutterSdkVersion = "0.1.9"

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

    // Optional — do NOT force-unwrap. Scene-based / add-to-app hosts can call
    // channel methods before a root view controller exists; force-unwrapping on
    // every call (the old behaviour) crashed those hosts even for methods that
    // don't need a root controller (targeting, initialize, …).
    var rootController: UIViewController? {
        var root = UIApplication.shared.delegate?.window??.rootViewController

        if root == nil {
            #if swift(>=5.0)
                root = UIApplication.shared.windows.first?.rootViewController
            #else
                @available(*, deprecated)
                root = UIApplication.shared.keyWindow?.rootViewController
            #endif
        }

        return root
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "_init":
            manager.disposeAllAds()
            result(nil)
            
        case "initialize":
            if let args = call.arguments as? [String: Any],
               let companyId = args["companyId"] as? String,
               let isAutomaticPpidEnabled = args["isAutomaticPpidEnabled"] as? Bool
            {
                Audienzz.shared.configureSDK(companyId: companyId, enablePPID: isAutomaticPpidEnabled)
                AudienzzGAMUtils.shared.initializeGAM()
                Audienzz.shared.setAppVolume(0.0)
                AUTargeting.shared.setBridgeTargeting(key: "au_flutter_v", value: flutterSdkVersion)

                if let prebidServerUrl = args["prebidServerUrl"] as? String {
                    do {
                        try Prebid.initializeSDK(serverURL: prebidServerUrl)
                    } catch {
                        print("Audienzz: Prebid.initializeSDK(serverURL:) failed for \(prebidServerUrl): \(error.localizedDescription)")
                    }
                }

                result(AudienzzInitializationStatus.success)
            } else {
                result(
                    FlutterError(
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
                    FlutterError(
                        code: "Load Banner Ad Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            guard let rootViewController = rootController else {
                result(
                    FlutterError(
                        code: "Load Banner Ad Error",
                        message: "No root view controller available",
                        details: nil
                    )
                )
                return
            }

            let refreshTimeInterval = args["refreshTimeInterval"] as? NSNumber
            let pbAdSlot = args["pbAdSlot"] as? String
            let gpId = args["gpId"] as? String
            let customImpOrtbConfig = args["impOrtbConfig"] as? String
            // Default to false to match the Dart BannerAd default; on iOS a lazy-load
            // banner inside a Flutter platform view never fetches (VisibleView relies on
            // a UIScrollView ancestor that doesn't exist here), so an accidental default
            // of true would silently produce no fill.
            let isLazyLoad = args["isLazyLoad"] as? Bool ?? false
            let smartRefresh = args["smartRefresh"] as? Bool ?? false
            let prefetchMarginPoints = CGFloat((args["prefetchMargin"] as? Int) ?? 200)

            let bannerAd = FBannerAd(
                adUnitId: adUnitId,
                auConfigId: auConfigId,
                sizes: adSizes,
                isAdaptiveSize: isAdaptiveSize,
                isLazyLoad: isLazyLoad,
                smartRefresh: smartRefresh,
                prefetchMarginPoints: prefetchMarginPoints,
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
                    FlutterError(
                        code: "Rewarded Ad Loading Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            guard let rootViewController = rootController else {
                result(
                    FlutterError(
                        code: "Rewarded Ad Loading Error",
                        message: "No root view controller available",
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
                    FlutterError(
                        code: "Interstitial Ad Loading Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
                return
            }

            guard let rootViewController = rootController else {
                result(
                    FlutterError(
                        code: "Interstitial Ad Loading Error",
                        message: "No root view controller available",
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
                    FlutterError(
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
                    FlutterError(
                        code: "Dispose Ad Error",
                        message: "Missing or unexpected call parameters",
                        details: nil
                    )
                )
            }

        case "pauseBannerAutoRefresh":
            // The Dart layer pauses a specific banner (e.g. when a same-route
            // overlay covers it — a case the native geometry poll can't detect).
            if let args = call.arguments as? [String: Any],
               let adId = args["adId"] as? NSNumber,
               let bannerAd = manager.ad(for: adId) as? FBannerAd
            {
                bannerAd.pauseAutoRefresh()
            }
            result(nil)

        case "resumeBannerAutoRefresh":
            if let args = call.arguments as? [String: Any],
               let adId = args["adId"] as? NSNumber,
               let bannerAd = manager.ad(for: adId) as? FBannerAd
            {
                bannerAd.resumeAutoRefresh()
            }
            result(nil)

        case "reloadBanner":
            // Force a fresh auction now — used when this banner's screen (route
            // or tab) becomes active again (pageImpression broadcast).
            if let args = call.arguments as? [String: Any],
               let adId = args["adId"] as? NSNumber,
               let bannerAd = manager.ad(for: adId) as? FBannerAd
            {
                bannerAd.forceReload()
            }
            result(nil)

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

        case "setItunesID":
            if let value = call.arguments as? [String: Any] {
                AUTargeting.shared.itunesID = value["value"] as? String
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

        case "updateGlobalTargeting":
            if let args = call.arguments as? [String: Any],
               let key = args["key"] as? String,
               let values = args["values"] as? [String]
            {
                AUTargeting.shared.updateGlobalTargeting(key: key, values: Set(values))
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

        case "setSchainObject":
            if let args = call.arguments as? [String: Any],
               let schain = args["schain"] as? String
            {
                Audienzz.shared.setSchainObject(schain: schain)
            }
            result(nil)
            
        case "isAutomaticPpidEnabled":
            result(PPIDManager.shared.getAutomaticPpidEnabled())
            
        case "setAutomaticPpidEnabled":
            if let args = call.arguments as? [String: Any],
               let isAutomaticPpidEnabled = args["isAutomaticPpidEnabled"] as? Bool {
                PPIDManager.shared.setAutomaticPpidEnabled(isAutomaticPpidEnabled)
            }
            result(nil)
            
        case "getPpid":
            result(PPIDManager.shared.getPPID())


        // Force smart-refresh v2 on/off, overriding the backend smartRefreshV2 config.
        case "setSmartRefreshV2Enabled":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                Audienzz.shared.smartRefreshV2Override = enabled
            }
            result(nil)

        // When true, a banner blanks its slot during a screen-resume reload.
        case "setBlankOnScreenReload":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                Audienzz.shared.blankOnScreenReload = enabled
            }
            result(nil)

        // Report the active screen by an opaque route key; fires a pageImpression + a fresh
        // page-impression id tying this visit's ad events together.
        case "pageImpression":
            if let args = call.arguments as? [String: Any],
               let name = args["name"] as? String {
                Audienzz.shared.pageImpression(name)
            }
            result(nil)

        case "setAppVolume":
            if let args = call.arguments as? [String: Any],
               let volume = args["volume"] as? Double {
                Audienzz.shared.setAppVolume(Float(volume))
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT",
                                    message: "Missing or invalid volume argument",
                                    details: nil))
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
