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
import org.audienzz.mobile.AudienzzContentObject
import org.audienzz.mobile.AudienzzSignals

class AudienzzSdkFlutterPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {
    private var methodChannel: MethodChannel? = null
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var adMessageCodec: AdMessageCodec? = null
    private var adInstanceManager: AdInstanceManager? = null
    private val audienzzSdkWrapper = AudienzzSdkWrapper()

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
                    call.argument<AdSize>("adSize")!!,
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
                    call.argument<String?>("keyword"),
                    call.argument<List<String>?>("keywords"),
                    call.argument<AudienzzContentObject?>("appContent"),
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
                    call.argument<String?>("keyword"),
                    call.argument<List<String>?>("keywords"),
                    call.argument<AudienzzContentObject?>("appContent"),
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
                    call.argument<String?>("keyword"),
                    call.argument<List<String>?>("keywords"),
                    call.argument<AudienzzContentObject?>("appContent"),
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

                val adShown = adInstanceManager?.showAdWithId(adId) ?: false

                if (!adShown) {
                    result.error("Ad Show Error", "Ad with id $adId failed to show", null)
                }

                result.success(null)
            }


            "disposeAd" -> {
                adInstanceManager?.disposeAd(call.argument<Int>("adId")!!)
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
