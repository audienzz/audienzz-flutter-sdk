package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.app.Activity
import android.content.Context
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import org.audienzz.mobile.api.data.AudienzzAdUnitFormat
import com.google.android.gms.ads.admanager.AdManagerInterstitialAd
import com.google.android.gms.ads.admanager.AdManagerInterstitialAdLoadCallback
import org.audienzz.mobile.AudienzzContentObject
import org.audienzz.mobile.AudienzzInterstitialAdUnit
import org.audienzz.mobile.AudienzzResultCode
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzInterstitialAdHandler
import java.util.EnumSet

class InterstitialAd(
    private val adUnitId: String,
    private val auConfigId: String,
    private val adFormat: AdFormat,
    private val minSizePercentage: MinSizePercentage,
    private val apiParameters: List<AudienzzSignals.Api>,
    private val videoProtocols: List<AudienzzSignals.Protocols>,
    private val videoPlacement: AudienzzSignals.Placement,
    private val playbackMethods: List<AudienzzSignals.PlaybackMethod>,
    private val videoBitrate: VideoBitrate,
    private val videoDuration: VideoDuration,
    private val interstitialPbAdSlot: String?,
    private val gpId: String?,
    private val keyword: String?,
    private val keywords: List<String>?,
    private val interstitialAppContent: AudienzzContentObject?,
    private val context: Context,
    private val interstitialAdLoadedListener: AdManagerInterstitialAdLoadCallback,
    private val fullScreenContentListener: FullScreenContentCallback,
) : OverlayAd() {
    private var interstitialAd: AdManagerInterstitialAd? = null

    fun setAdWithFullScreenContentListener(ad: AdManagerInterstitialAd){
        ad.fullScreenContentCallback = fullScreenContentListener
        interstitialAd = ad
    }

    override fun show(activity: Activity?) {
        activity?.let {
            interstitialAd?.show(it)
        }
    }

    override fun load() {
        val adUnit = when (adFormat) {
            AdFormat.BANNER -> createInterstitialBannerAdUnit()
            AdFormat.VIDEO ->  createInterstitialVideoAdUnit()
            AdFormat.BANNER_AND_VIDEO ->  createInterstitialMultiformatAdUnit()
        }

        adUnit.apply {
            gpid = gpId
            pbAdSlot = interstitialPbAdSlot
            appContent = interstitialAppContent
            keyword?.let(::addExtKeyword)
            keywords?.let {
                addExtKeywords(it.toSet())
            }
        }


        AudienzzInterstitialAdHandler(adUnit, adUnitId).load(
            context,
            listener = interstitialAdLoadedListener,
            resultCallback = {
                if(it != AudienzzResultCode.SUCCESS){
                    interstitialAdLoadedListener.onAdFailedToLoad(LoadAdError(1, "Interstitial ad with adUnitId: $adUnitId failed to load. Error code $it", "No domain", null, null))
                }
            },
        )
    }

    private fun createInterstitialBannerAdUnit() : AudienzzInterstitialAdUnit {
        return AudienzzInterstitialAdUnit(auConfigId, minSizePercentage.width, minSizePercentage.height)
    }

    private fun createInterstitialVideoAdUnit() : AudienzzInterstitialAdUnit {
        val adUnit = AudienzzInterstitialAdUnit(
            auConfigId,
            EnumSet.of(AudienzzAdUnitFormat.VIDEO),
        )
        adUnit.videoParameters = configureVideoParameters()

        return adUnit
    }

    private fun createInterstitialMultiformatAdUnit() : AudienzzInterstitialAdUnit {
        val adUnit =  AudienzzInterstitialAdUnit(
            auConfigId,
            EnumSet.of(AudienzzAdUnitFormat.BANNER, AudienzzAdUnitFormat.VIDEO),
        )
        adUnit.setMinSizePercentage(minSizePercentage.width, minSizePercentage.height)
        adUnit.videoParameters = configureVideoParameters()

        return adUnit
    }

    private fun configureVideoParameters(): AudienzzVideoParameters {
        return AudienzzVideoParameters(listOf("video/x-flv", "video/mp4")).apply {
            placement = AudienzzSignals.Placement.Interstitial
            api = apiParameters
            maxBitrate = videoBitrate.maxBitrate
            minBitrate = videoBitrate.minBitrate
            maxDuration = videoDuration.maxDuration
            minDuration = videoDuration.minDuration
            playbackMethod = playbackMethods
            protocols = videoProtocols
            placement = videoPlacement
        }
    }

    override fun dispose() {
        interstitialAd = null
    }
}
