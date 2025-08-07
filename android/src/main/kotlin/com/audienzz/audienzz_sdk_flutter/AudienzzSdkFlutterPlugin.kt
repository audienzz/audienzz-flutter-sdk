package com.audienzz.audienzz_sdk_flutter

import com.audienzz.audienzz_sdk_flutter.ad_instance_manager.AdInstanceManager
import com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd
import com.audienzz.audienzz_sdk_flutter.ads.implementation.InterstitialAd
import com.audienzz.audienzz_sdk_flutter.ads.implementation.RewardAd
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.audienzz.audienzz_sdk_flutter.message_codec.AdMessageCodec
import com.audienzz.audienzz_sdk_flutter.platform_views.PlatformViewFactoryWrapper
import com.google.android.gms.ads.AdSize
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMethodCodec
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzTargetingParams
import org.json.JSONObject

class AudienzzSdkFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var adMessageCodec: AdMessageCodec? = null
    private var adInstanceManager: AdInstanceManager? = null
    private val audienzzSdkWrapper = AudienzzSdkWrapper()
    private val audienzzTargetingWrapper = AudienzzTargetingWrapper()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = flutterPluginBinding
        adMessageCodec = AdMessageCodec(flutterPluginBinding.applicationContext)
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            CHANNEL_NAME,
            StandardMethodCodec(adMessageCodec!!)
        )
        methodChannel?.setMethodCallHandler(this)
        adInstanceManager = AdInstanceManager(methodChannel!!)
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            NATIVE_VIEW_NAME,
            PlatformViewFactoryWrapper(adInstanceManager!!)
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (pluginBinding == null) {
            return
        }

        val context = pluginBinding!!.applicationContext

        when (call.method) {
            "_init" -> {
                adInstanceManager?.disposeAllAds()
                result.success(null)
            }

            "initialize" -> audienzzSdkWrapper.initialize(
                context,
                call.argument<String>("companyId")!!,
                result
            )

            "loadBannerAd" -> {
                val adId = call.argument<Int>("adId")!!

                val bannerAd = BannerAd(
                    call.argument<String>("adUnitId")!!,
                    call.argument<String>("auConfigId")!!,
                    call.argument<List<AdSize>>("adSizes")!!,
                    call.argument<Boolean>("isAdaptiveSize")!!,
                    call.argument<Int?>("refreshTimeInterval"),
                    call.argument<AdFormat>("adFormat")!!,
                    call.argument<List<AudienzzSignals.Api>>("apiParameters")!!,
                    call.argument<List<AudienzzSignals.Protocols>>("protocols")!!,
                    call.argument<AudienzzSignals.Placement>("placement")!!,
                    call.argument<List<AudienzzSignals.PlaybackMethod>>("playbackMethods")!!,
                    call.argument<VideoBitrate>("videoBitrate")!!,
                    call.argument<VideoDuration>("videoDuration")!!,
                    call.argument<String?>("pbAdSlot"),
                    call.argument<String?>("gpId"),
                    call.argument<String?>("impOrtbConfig"),
                    adInstanceManager?.createBannerAdListener(adId),
                    context,
                )

                adInstanceManager?.trackAd(bannerAd, adId)
                bannerAd.load()
                result.success(null)
            }

            "loadRewardedAd" -> {
                val adId = call.argument<Int>("adId")!!

                val rewardAd = RewardAd(
                    call.argument<String>("adUnitId")!!,
                    call.argument<String>("auConfigId")!!,
                    call.argument<List<AudienzzSignals.Api>>("apiParameters")!!,
                    call.argument<List<AudienzzSignals.Protocols>>("protocols")!!,
                    call.argument<AudienzzSignals.Placement>("placement")!!,
                    call.argument<List<AudienzzSignals.PlaybackMethod>>("playbackMethods")!!,
                    call.argument<VideoBitrate>("videoBitrate")!!,
                    call.argument<VideoDuration>("videoDuration")!!,
                    call.argument<String?>("pbAdSlot"),
                    call.argument<String?>("gpId"),
                    call.argument<String?>("impOrtbConfig"),
                    context,
                    adInstanceManager!!.createRewardedAdLoadedListener(adId),
                    adInstanceManager!!.createRewardedAdUserEarnedRewardListener(adId),
                    adInstanceManager!!.createOverlayAdFullscreenContentListener(adId),
                )

                adInstanceManager?.trackAd(rewardAd, adId)
                rewardAd.load()
                result.success(null)
            }

            "loadInterstitialAd" -> {
                val adId = call.argument<Int>("adId")!!

                val interstitialAd = InterstitialAd(
                    call.argument<String>("adUnitId")!!,
                    call.argument<String>("auConfigId")!!,
                    call.argument<AdFormat>("adFormat")!!,
                    call.argument<MinSizePercentage>("minSizePercentage")!!,
                    call.argument<List<AudienzzSignals.Api>>("apiParameters")!!,
                    call.argument<List<AudienzzSignals.Protocols>>("protocols")!!,
                    call.argument<AudienzzSignals.Placement>("placement")!!,
                    call.argument<List<AudienzzSignals.PlaybackMethod>>("playbackMethods")!!,
                    call.argument<VideoBitrate>("videoBitrate")!!,
                    call.argument<VideoDuration>("videoDuration")!!,
                    call.argument<String?>("pbAdSlot"),
                    call.argument<String?>("gpId"),
                    call.argument<List<AdSize>>("adSizes")!!,
                    call.argument<String?>("impOrtbConfig"),
                    context,
                    adInstanceManager!!.createInterstitialAdLoadedListener(adId),
                    adInstanceManager!!.createOverlayAdFullscreenContentListener(adId),
                )

                adInstanceManager?.trackAd(interstitialAd, adId)
                interstitialAd.load()
                result.success(null)
            }

            "showAdWithoutView" -> {
                val adId = call.argument<Int>("adId")!!

                val adShown = adInstanceManager?.showAdWithId(adId) == true

                if (!adShown) {
                    result.error("Ad Show Error", "Ad with id $adId failed to show", null)
                }

                result.success(null)
            }

            "getPlatformAdSize" -> {
                val adId = call.argument<Int>("adId")!!
                val ad = adInstanceManager?.adFor(adId)

                if(ad is BannerAd) {
                    result.success(ad.getPlatformAdSize())
                } else {
                    result.success(null)
                }
            }


            "disposeAd" -> {
                adInstanceManager?.disposeAd(call.argument<Int>("adId")!!)
                result.success(null)
            }

            "setUserLatLng" -> audienzzTargetingWrapper.setUserLatLng(call, result)
            "getUserLatLng" -> audienzzTargetingWrapper.getUserLatLng(result)

            "getUserKeywords" -> result.success(AudienzzTargetingParams.userKeywords)
            "getKeywordSet" -> result.success(AudienzzTargetingParams.keywordSet.toList())

            "setPublisherName" -> {
                AudienzzTargetingParams.publisherName = call.argument<String?>("value")
                result.success(null)
            }
            "getPublisherName" -> result.success(AudienzzTargetingParams.publisherName)

            "setDomain" -> {
                AudienzzTargetingParams.domain = call.argument<String>("value") ?: ""
                result.success(null)
            }
            "getDomain" -> result.success(AudienzzTargetingParams.domain)

            "setStoreUrl" -> {
                AudienzzTargetingParams.storeUrl = call.argument<String>("value") ?: ""
                result.success(null)
            }
            "getStoreUrl" -> result.success(AudienzzTargetingParams.storeUrl)

            "getAccessControlList" -> result.success(AudienzzTargetingParams.accessControlList.toList())

            "setOmidPartnerName" -> {
                AudienzzTargetingParams.omidPartnerName = call.argument<String?>("value")
                result.success(null)
            }
            "getOmidPartnerName" -> result.success(AudienzzTargetingParams.omidPartnerName)

            "setOmidPartnerVersion" -> {
                AudienzzTargetingParams.omidPartnerVersion = call.argument<String?>("value")
                result.success(null)
            }
            "getOmidPartnerVersion" -> result.success(AudienzzTargetingParams.omidPartnerVersion)

            "setSubjectToCOPPA" -> {
                AudienzzTargetingParams.isSubjectToCOPPA = call.argument<Boolean?>("value")
                result.success(null)
            }
            "isSubjectToCOPPA" -> result.success(AudienzzTargetingParams.isSubjectToCOPPA)

            "setSubjectToGDPR" -> {
                AudienzzTargetingParams.isSubjectToGDPR = call.argument<Boolean?>("value")
                result.success(null)
            }
            "isSubjectToGDPR" -> result.success(AudienzzTargetingParams.isSubjectToGDPR)

            "setGdprConsentString" -> {
                AudienzzTargetingParams.gdprConsentString = call.argument<String?>("value")
                result.success(null)
            }
            "getGdprConsentString" -> result.success(AudienzzTargetingParams.gdprConsentString)

            "setPurposeConsents" -> {
                AudienzzTargetingParams.purposeConsents = call.argument<String?>("value")
                result.success(null)
            }
            "getPurposeConsents" -> result.success(AudienzzTargetingParams.purposeConsents)

            "setBundleName" -> {
                AudienzzTargetingParams.bundleName = call.argument<String?>("value")
                result.success(null)
            }
            "getBundleName" -> result.success(AudienzzTargetingParams.bundleName)

            "getExtDataDictionary" -> audienzzTargetingWrapper.getExtDataDictionary(result)
            "isDeviceAccessConsent" -> result.success(AudienzzTargetingParams.isDeviceAccessConsent)

            "setUserExt" -> audienzzTargetingWrapper.setUserExt(call, result)
            "getUserExt" -> audienzzTargetingWrapper.getUserExt(result)

            "addUserKeyword" -> {
                val keyword = call.argument<String>("keyword")
                if (keyword != null) {
                    AudienzzTargetingParams.addUserKeyword(keyword)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Keyword cannot be null", null)
                }
            }

            "addUserKeywords" -> {
                val keywords = call.argument<List<String>>("keywords")
                if (keywords != null) {
                    AudienzzTargetingParams.addUserKeywords(keywords.toSet())
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Keywords cannot be null", null)
                }
            }

            "removeUserKeyword" -> {
                val keyword = call.argument<String>("keyword")
                if (keyword != null) {
                    AudienzzTargetingParams.removeUserKeyword(keyword)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Keyword cannot be null", null)
                }
            }

            "clearUserKeywords" -> {
                AudienzzTargetingParams.clearUserKeywords()
                result.success(null)
            }

            "setExternalUserIds" -> audienzzTargetingWrapper.setExternalUserIds(call, result)
            "getExternalUserIds" -> audienzzTargetingWrapper.getExternalUserIds(result)

            "addExtData" -> {
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key != null && value != null) {
                    AudienzzTargetingParams.addExtData(key, value)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Key and value cannot be null", null)
                }
            }

            "updateExtData" -> {
                val key = call.argument<String>("key")
                val values = call.argument<List<String>>("values")
                if (key != null && values != null) {
                    AudienzzTargetingParams.updateExtData(key, values.toSet())
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Key and values cannot be null", null)
                }
            }

            "removeExtData" -> {
                val key = call.argument<String>("key")
                if (key != null) {
                    AudienzzTargetingParams.removeExtData(key)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Key cannot be null", null)
                }
            }

            "clearExtData" -> {
                AudienzzTargetingParams.clearExtData()
                result.success(null)
            }

            "addBidderToAccessControlList" -> {
                val bidderName = call.argument<String>("bidderName")
                if (bidderName != null) {
                    AudienzzTargetingParams.addBidderToAccessControlList(bidderName)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Bidder name cannot be null", null)
                }
            }

            "removeBidderFromAccessControlList" -> {
                val bidderName = call.argument<String>("bidderName")
                if (bidderName != null) {
                    AudienzzTargetingParams.removeBidderFromAccessControlList(bidderName)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Bidder name cannot be null", null)
                }
            }

            "clearAccessControlList" -> {
                AudienzzTargetingParams.clearAccessControlList()
                result.success(null)
            }

            "getPurposeConsent" -> {
                val index = call.argument<Int>("index")
                if (index != null) {
                    result.success(AudienzzTargetingParams.getPurposeConsent(index))
                } else {
                    result.error("INVALID_ARGUMENT", "Index cannot be null", null)
                }
            }

            "getGlobalOrtbConfig" -> result.success(AudienzzTargetingParams.getGlobalOrtbConfig())

            "setGlobalOrtbConfig" -> {
                val config = call.argument<Map<String, Any>>("config")
                if (config != null) {
                    val jsonObject = JSONObject(config)
                    AudienzzTargetingParams.setGlobalOrtbConfig(jsonObject)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Config cannot be null", null)
                }
            }

            "addGlobalTargeting" -> audienzzTargetingWrapper.addGlobalTargeting(call, result)
            "removeGlobalTargeting" -> {
                val key = call.argument<String>("key")
                if (key != null) {
                    AudienzzTargetingParams.removeGlobalTargeting(key)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENT", "Key cannot be null", null)
                }
            }

            "clearGlobalTargeting" -> {
                AudienzzTargetingParams.clearGlobalTargeting()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        adMessageCodec?.setContext(binding.activity)
        adInstanceManager?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        pluginBinding?.let { bindings ->
            adMessageCodec?.setContext(bindings.applicationContext)
        }

        adInstanceManager?.setActivity(null)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        adMessageCodec?.setContext(binding.activity)
        adInstanceManager?.setActivity(binding.activity)
    }

    override fun onDetachedFromActivity() {
        pluginBinding?.let { bindings ->
            adMessageCodec?.setContext(bindings.applicationContext)
        }

        adInstanceManager?.setActivity(null)
    }

    companion object {
        private const val CHANNEL_NAME = "audienzz_sdk_flutter"
        private const val NATIVE_VIEW_NAME = "${CHANNEL_NAME}/ad_widget"
    }
}
