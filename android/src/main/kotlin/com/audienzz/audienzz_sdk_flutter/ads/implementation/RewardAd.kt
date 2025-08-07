package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.app.Activity
import android.content.Context
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.google.android.gms.ads.OnUserEarnedRewardListener
import com.google.android.gms.ads.rewarded.RewardedAd
import org.audienzz.mobile.AudienzzRewardedVideoAdUnit
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzRewardedVideoAdHandler
import org.audienzz.mobile.original.callbacks.AudienzzFullScreenContentCallback
import org.audienzz.mobile.original.callbacks.AudienzzRewardedAdLoadCallback

class RewardAd(
    private val adUnitId: String,
    private val auConfigId: String,
    private val apiParameters: List<AudienzzSignals.Api>,
    private val videoProtocols: List<AudienzzSignals.Protocols>,
    private val videoPlacement: AudienzzSignals.Placement,
    private val playbackMethods: List<AudienzzSignals.PlaybackMethod>,
    private val videoBitrate: VideoBitrate,
    private val videoDuration: VideoDuration,
    private val rewardPbAdSlot: String?,
    private val gpId: String?,
    private val customImpOrtbConfig: String?,
    private val context: Context,
    private val rewardAdLoadedListener: AudienzzRewardedAdLoadCallback,
    private val userEarnedRewardListener: OnUserEarnedRewardListener,
    private val fullScreenContentListener: AudienzzFullScreenContentCallback,
) : OverlayAd() {
    private var rewardedAd: RewardedAd? = null

    fun setAd(ad: RewardedAd) {
        rewardedAd = ad
    }

    override fun show(activity: Activity?) {
        activity?.let {
            rewardedAd?.show(it, userEarnedRewardListener)
        }
    }

    override fun load() {
        val adUnit = AudienzzRewardedVideoAdUnit(auConfigId)
        adUnit.videoParameters = configureVideoParameters()

        adUnit.apply {
            pbAdSlot = rewardPbAdSlot
            gpid = gpId
            customImpOrtbConfig?.let { impOrtbConfig = it }
        }

        AudienzzRewardedVideoAdHandler(adUnit, adUnitId).load(
            adLoadCallback = rewardAdLoadedListener,
            fullScreenContentCallback = fullScreenContentListener,
            resultCallback = { resultCode, request, adLoadListener ->
                RewardedAd.load(context, adUnitId, request, adLoadListener)
            },
        )
    }

    private fun configureVideoParameters(): AudienzzVideoParameters {
        return AudienzzVideoParameters(listOf("video/mp4")).apply {
            api = apiParameters
            protocols = videoProtocols
            playbackMethod = playbackMethods
            placement = videoPlacement
            minBitrate = videoBitrate.minBitrate
            maxBitrate = videoBitrate.maxBitrate
            minDuration = videoDuration.minDuration
            maxDuration = videoDuration.maxDuration
        }
    }

    override fun dispose() {
        rewardedAd = null
    }
}
