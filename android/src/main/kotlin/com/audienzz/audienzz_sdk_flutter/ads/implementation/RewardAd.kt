package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.app.Activity
import android.content.Context
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.OnUserEarnedRewardListener
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import org.audienzz.mobile.AudienzzContentObject
import org.audienzz.mobile.AudienzzResultCode
import org.audienzz.mobile.AudienzzRewardedVideoAdUnit
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzRewardedVideoAdHandler

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
    private val keyword: String?,
    private val keywords: List<String>?,
    private val rewardAppContent: AudienzzContentObject?,
    private val context: Context,
    private val rewardAdLoadedListener: RewardedAdLoadCallback,
    private val userEarnedRewardListener: OnUserEarnedRewardListener,
    private val fullScreenContentListener: FullScreenContentCallback,
) : OverlayAd() {
    private var rewardedAd: RewardedAd? = null

    fun setAdWithFullScreenContentListener(ad: RewardedAd){
        ad.fullScreenContentCallback = fullScreenContentListener
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
            appContent = rewardAppContent
            keyword?.let(::addExtKeyword)
            keywords?.let {
                addExtKeywords(it.toSet())
            }
        }

        AudienzzRewardedVideoAdHandler(adUnit, adUnitId).load(
            context,
            listener = rewardAdLoadedListener,
            resultCallback = {
                if(it != AudienzzResultCode.SUCCESS){
                    rewardAdLoadedListener.onAdFailedToLoad(LoadAdError(1, "Rewarded ad with adUnitId $adUnitId failed to load. Error code $it", "No domain", null, null))
                }
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
