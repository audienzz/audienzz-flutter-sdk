package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.content.Context
import androidx.core.view.doOnNextLayout
import com.audienzz.audienzz_sdk_flutter.ads.base.Ad
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.audienzz.audienzz_sdk_flutter.platform_views.PlatformViewWrapper
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.admanager.AdManagerAdView
import io.flutter.plugin.platform.PlatformView
import org.audienzz.mobile.AudienzzBannerAdUnit
import org.audienzz.mobile.AudienzzBannerParameters
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.api.data.AudienzzAdUnitFormat
import org.audienzz.mobile.original.AudienzzAdViewHandler
import org.audienzz.mobile.util.pxToDp
import java.util.EnumSet

class BannerAd(
    private val adUnitId: String,
    private val auConfigId: String,
    private val adSizes: List<AdSize>,
    private val isAdaptiveSize: Boolean,
    private val refreshTimeInterval: Int?,
    private val adFormat: AdFormat,
    private val apiParameters: List<AudienzzSignals.Api>,
    private val videoProtocols: List<AudienzzSignals.Protocols>,
    private val videoPlacement: AudienzzSignals.Placement,
    private val playbackMethods: List<AudienzzSignals.PlaybackMethod>,
    private val videoBitrate: VideoBitrate,
    private val videoDuration: VideoDuration,
    private val bannerPbAdSlot: String?,
    private val gpId: String?,
    private val customImpOrtbConfig: String?,
    private val adListener: AdListener?,
    private val context: Context,
) : Ad() {
    private var adView: AdManagerAdView? = null

    fun getPlatformAdSize(): AdSize? {
        return adView?.adSize
    }

    override fun load() {
        adView = AdManagerAdView(context)

        val currentAdView = adView

        if (isAdaptiveSize && currentAdView != null) {
            currentAdView.doOnNextLayout {
                currentAdView.setAdSizes(
                    AdSize.getInlineAdaptiveBannerAdSize(
                        context.resources.pxToDp(currentAdView.width),
                        context.resources.pxToDp(currentAdView.height),
                    )
                )
            }
        }

        currentAdView?.setAdSizes(*adSizes.toTypedArray())
        currentAdView?.adUnitId = adUnitId
        adListener?.let { currentAdView?.adListener = it }

        val customBannerParameters = AudienzzBannerParameters()
        customBannerParameters.api = apiParameters

        val customVideoParameters = AudienzzVideoParameters(listOf("video/x-flv", "video/mp4")).apply {
            api = apiParameters
            protocols = videoProtocols
            placement = videoPlacement
            playbackMethod = playbackMethods
            minBitrate = videoBitrate.minBitrate
            maxBitrate = videoBitrate.maxBitrate
            minDuration = videoDuration.minDuration
            maxDuration = videoDuration.maxDuration
        }

        val adUnit = when (adFormat) {
            AdFormat.BANNER -> AudienzzBannerAdUnit(auConfigId, adSizes.first().width, adSizes.first().height, EnumSet.of(AudienzzAdUnitFormat.BANNER))
            AdFormat.VIDEO ->  AudienzzBannerAdUnit(auConfigId, adSizes.first().width, adSizes.first().height, EnumSet.of(AudienzzAdUnitFormat.VIDEO))
            AdFormat.BANNER_AND_VIDEO ->  AudienzzBannerAdUnit(auConfigId,adSizes.first().width, adSizes.first().height, EnumSet.of(AudienzzAdUnitFormat.BANNER, AudienzzAdUnitFormat.VIDEO))
        }

        adUnit.apply {
            bannerParameters = customBannerParameters
            videoParameters = customVideoParameters
            pbAdSlot = bannerPbAdSlot
            gpid = gpId
            adSizes.forEach { size ->
                addAdditionalSize(size.width, size.height)
            }
            refreshTimeInterval?.let(::setAutoRefreshInterval)
            customImpOrtbConfig?.let { impOrtbConfig = it }
        }

        currentAdView?.let { adView ->
            AudienzzAdViewHandler(adView, adUnit).load { request, _ ->
                adView.loadAd(request)
            }
        }
    }

    override fun dispose() {
        adView?.destroy()
        adView = null
    }

     override var platformView: PlatformView? = null
         get() {
             if (adView == null) {
                 return null
             }

             field = PlatformViewWrapper(adView)
             return field
         }
}
