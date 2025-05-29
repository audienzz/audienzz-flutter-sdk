package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.app.Activity
import android.content.Context
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import org.audienzz.mobile.api.data.AudienzzAdUnitFormat
import com.google.android.gms.ads.admanager.AdManagerInterstitialAd
import com.google.android.gms.ads.admanager.AdManagerInterstitialAdLoadCallback
import org.audienzz.mobile.AudienzzInterstitialAdUnit
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzInterstitialAdHandler
import org.audienzz.mobile.util.AudienzzFullScreenContentCallback
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
    private val context: Context,
    private val interstitialAdLoadedListener: AdManagerInterstitialAdLoadCallback,
    private val fullScreenContentListener: AudienzzFullScreenContentCallback,
) : OverlayAd() {
    private var interstitialAd: AdManagerInterstitialAd? = null

    fun setAd(ad: AdManagerInterstitialAd) {
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
            AdFormat.VIDEO -> createInterstitialVideoAdUnit()
            AdFormat.BANNER_AND_VIDEO -> createInterstitialMultiformatAdUnit()
        }

        adUnit.apply {
            gpid = gpId
            pbAdSlot = interstitialPbAdSlot
        }


        AudienzzInterstitialAdHandler(adUnit, adUnitId).load(
            adLoadCallback = interstitialAdLoadedListener,
            fullScreenContentCallback = fullScreenContentListener,
            resultCallback = { resultCode, request, adLoadCallback ->
                AdManagerInterstitialAd.load(context, adUnitId, request, adLoadCallback)
            },
        )
    }

    private fun createInterstitialBannerAdUnit(): AudienzzInterstitialAdUnit {
        return AudienzzInterstitialAdUnit(
            auConfigId,
            minSizePercentage.width,
            minSizePercentage.height
        )
    }

    private fun createInterstitialVideoAdUnit(): AudienzzInterstitialAdUnit {
        val adUnit = AudienzzInterstitialAdUnit(
            auConfigId,
            EnumSet.of(AudienzzAdUnitFormat.VIDEO),
        )
        adUnit.videoParameters = configureVideoParameters()

        return adUnit
    }

    private fun createInterstitialMultiformatAdUnit(): AudienzzInterstitialAdUnit {
        val adUnit = AudienzzInterstitialAdUnit(
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
