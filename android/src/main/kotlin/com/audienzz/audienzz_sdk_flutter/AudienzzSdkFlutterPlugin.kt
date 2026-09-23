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
import org.audienzz.mobile.AudienzzPrebidMobile
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
        observeNativePageImpressions()
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            NATIVE_VIEW_NAME,
            PlatformViewFactoryWrapper(adInstanceManager!!)
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (pluginBinding == null) {
            // Reply so the awaiting Dart Future completes instead of hanging.
            result.error(
                "NOT_ATTACHED",
                "Plugin is not attached to a Flutter engine",
                null
            )
            return
        }

        val context = pluginBinding!!.applicationContext

        when (call.method) {
            "_init" -> {
                adInstanceManager?.disposeAllAds()
                result.success(null)
            }

            "initialize" -> {
                // Flutter fetches the publisher config in Dart, so the native SDK never sees it and
                // cannot read this itself. An absent value stays null and native keeps its default.
                AudienzzPrebidMobile.applyBackendPpidConfig(
                    ppidEnabled = call.argument<Boolean?>("ppidEnabled"),
                )
                audienzzSdkWrapper.initialize(
                    context,
                    call.argument<String>("companyId")!!,
                    call.argument<String?>("prebidServerUrl"),
                    result
                )
            }

            "loadBannerAd" -> {
                val adId = call.argument<Int>("adId")!!

                val bannerAd = BannerAd(
                    call.argument<String>("adUnitId")!!,
                    call.argument<String>("auConfigId")!!,
                    call.argument<List<AdSize>>("adSizes")!!,
                    call.argument<Boolean>("isAdaptiveSize")!!,
                    call.argument<Boolean>("isLazyLoad") ?: true,
                    call.argument<Boolean>("smartRefresh") ?: false,
                    call.argument<Int>("prefetchMargin") ?: 200,
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
                    call.argument<String?>("pageKey"),
                    adInstanceManager?.createBannerAdListener(adId),
                    context,
                    // Absent from Dart unless it differs; BannerAd falls back to adSizes.
                    call.argument<List<AdSize>>("prebidAdSizes"),
                    // Absent from Dart unless header bidding is off.
                    call.argument<Boolean>("headerBidding") ?: true,
                )

                call.argument<String>("requestSlot")?.let {
                    bannerAd.requestContext = org.audienzz.mobile.targeting.AudienzzAdRequestContext.forSlot(it, call.argument<String>("pageKey"))
                }
                adInstanceManager?.trackAd(bannerAd, adId)
                // Before load(): an eager banner requests as soon as it loads, so a pause
                // installed afterwards would arrive after that first request.
                if (call.argument<Boolean>("publisherPaused") == true) {
                    bannerAd.pauseAutoRefresh()
                }
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
                    call.argument<List<AdSize>>("adSizes") ?: emptyList(),
                    call.argument<String?>("impOrtbConfig"),
                    context,
                    adInstanceManager!!.createInterstitialAdLoadedListener(adId),
                    adInstanceManager!!.createOverlayAdFullscreenContentListener(adId),
                )

                call.argument<String>("requestSlot")?.let {
                    interstitialAd.requestContext = org.audienzz.mobile.targeting.AudienzzAdRequestContext.forSlot(it)
                }
                adInstanceManager?.trackAd(interstitialAd, adId)
                interstitialAd.load()
                result.success(null)
            }

            "showAdWithoutView" -> {
                val adId = call.argument<Int>("adId")!!

                val adShown = adInstanceManager?.showAdWithId(adId) == true

                if (!adShown) {
                    result.error("-1", (adInstanceManager?.adFor(adId) as? InterstitialAd)?.showError ?: "Ad with id $adId failed to show", "audienzz")
                } else {
                    result.success(null)
                }
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

            "setBannerViewportVisible" -> {
                val ad = adInstanceManager?.adFor(call.argument<Int>("adId")!!)
                (ad as? BannerAd)?.setViewportVisible(call.argument<Boolean>("visible") == true)
                result.success(null)
            }

            "pauseBannerAutoRefresh" -> {
                val ad = adInstanceManager?.adFor(call.argument<Int>("adId")!!)
                (ad as? com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd)?.pauseAutoRefresh()
                result.success(null)
            }

            "resumeBannerAutoRefresh" -> {
                val ad = adInstanceManager?.adFor(call.argument<Int>("adId")!!)
                (ad as? com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd)?.resumeAutoRefresh()
                result.success(null)
            }

            "reloadBanner" -> {
                // Force a fresh auction now — used when this banner's screen
                // (route or tab) becomes active again (pageImpression broadcast).
                val ad = adInstanceManager?.adFor(call.argument<Int>("adId")!!)
                (ad as? com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd)?.forceReload()
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
            "updateGlobalTargeting" -> audienzzTargetingWrapper.updateGlobalTargeting(call, result)
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

            "setSchainObject" -> {
                val schain = call.argument<String>("schain")
                if(schain != null){
                    AudienzzPrebidMobile.setSchainObject(schain)
                }
                result.success(null)
            }


            "setPublisherPpid" -> {
                AudienzzPrebidMobile.ppidManager?.setPublisherPpid(call.argument<String?>("ppid"))
                result.success(null)
            }

            "getPpid" -> {
                result.success(AudienzzPrebidMobile.ppidManager?.getPpid())
            }

            "setAppVolume" -> {
                val volume = call.argument<Double>("volume")?.toFloat() ?: 0f
                AudienzzPrebidMobile.setAppVolume(volume)
                result.success(null)
            }

            // One greppable AUDZ line per slot decision; see AudienzzDiagnostics.
            "setDiagnosticsEnabled" -> {
                AudienzzPrebidMobile.diagnosticsEnabled = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            }

            // Force smart-refresh v2 on/off, overriding the backend smartRefreshV2 config.
            "setSmartRefreshV2Enabled" -> {
                AudienzzPrebidMobile.smartRefreshV2Override = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            }

            // When true, a banner blanks its slot during a screen-resume reload.
            "setBlankOnScreenReload" -> {
                AudienzzPrebidMobile.blankOnScreenReload = call.argument<Boolean>("enabled") ?: false
                result.success(null)
            }

            // Report the active screen by an opaque route key; fires a pageImpression + a fresh
            // page-impression id tying this visit's ad events together.
            "pageImpression" -> {
                val name = call.argument<String>("name")
                val pageId = call.argument<String>("pageId")
                if (name != null) {
                    // Identity and analytics name are separate. Every Flutter ad lives in the one
                    // host Activity, so host identity can never separate two routes — the id is the
                    // only thing that can, and a screen name repeats.
                    if (pageId != null) {
                        AudienzzPrebidMobile.pageImpression(pageId, name)
                    } else {
                        AudienzzPrebidMobile.pageImpression(name)
                    }
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Forward every native page impression to Dart — including the automatic one fired on returning
     * to the foreground, which never passes through the Dart API. Native owns foreground reporting;
     * Dart just advances its page epoch so mounted AdWidgets remount their platform views.
     */
    private fun observeNativePageImpressions() {
        AudienzzPrebidMobile.pageImpressionObserver = { name ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                methodChannel?.invokeMethod("onPageImpression", mapOf("name" to name))
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AudienzzPrebidMobile.pageImpressionObserver = null
        // Tear down every live ad so auctions/refresh loops don't continue with
        // no Dart side to receive events (add-to-app / multi-engine teardown).
        adInstanceManager?.disposeAllAds()
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
