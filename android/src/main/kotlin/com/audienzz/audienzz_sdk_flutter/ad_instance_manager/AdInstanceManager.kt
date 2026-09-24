package com.audienzz.audienzz_sdk_flutter.ad_instance_manager

import android.app.Activity
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import com.audienzz.audienzz_sdk_flutter.ads.base.FullScreenCoverableAd
import com.audienzz.audienzz_sdk_flutter.entities.RewardAdItem
import com.google.android.gms.ads.AdError
import io.flutter.plugin.common.MethodChannel
import com.audienzz.audienzz_sdk_flutter.ads.base.Ad
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.ads.implementation.InterstitialAd
import com.audienzz.audienzz_sdk_flutter.ads.implementation.RewardAd
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.OnUserEarnedRewardListener
import com.google.android.gms.ads.admanager.AdManagerInterstitialAd
import com.google.android.gms.ads.rewarded.RewardedAd
import org.audienzz.mobile.original.callbacks.AudienzzFullScreenContentCallback
import org.audienzz.mobile.original.callbacks.AudienzzInterstitialAdLoadCallback
import org.audienzz.mobile.original.callbacks.AudienzzRewardedAdLoadCallback
import org.audienzz.mobile.AudienzzPrebidMobile

class AdInstanceManager(private val channel: MethodChannel) {
    private val ads = mutableMapOf<Int, Ad>()

    private var activity: Activity? = null
    private var hostLifecycle: Lifecycle? = null
    private var hostResumed = false
    private var currentPage: Pair<String, String>? = null
    private var pageRevision = 0L
    private val interstitialPresentations = mutableMapOf<Int, Long>()
    private var pendingReturnRevision: Long? = null
    internal var reportPage: (String, String) -> Unit = { id, name ->
        AudienzzPrebidMobile.pageImpression(id, name)
    }

    // Google can dismiss before OR after the Flutter host resumes. Observe the host's actual
    // lifecycle so a return is completed once, with no delay or second foreground timer.
    private val hostObserver = LifecycleEventObserver { _, event ->
        if (event == Lifecycle.Event.ON_RESUME) {
            hostResumed = true
            completeInterstitialReturn()
        } else if (event == Lifecycle.Event.ON_PAUSE || event == Lifecycle.Event.ON_STOP ||
            event == Lifecycle.Event.ON_DESTROY) {
            hostResumed = false
        }
    }

    fun setActivity(activity: Activity?) {
        hostLifecycle?.removeObserver(hostObserver)
        this.activity = activity
        hostLifecycle = (activity as? LifecycleOwner)?.lifecycle
        hostResumed = hostLifecycle?.currentState?.isAtLeast(Lifecycle.State.RESUMED)
            ?: (activity?.hasWindowFocus() == true)
        hostLifecycle?.addObserver(hostObserver)
        completeInterstitialReturn()
    }

    fun pageImpression(pageId: String, name: String) {
        currentPage = pageId to name
        reportPage(pageId, name)
    }

    /** Every native report, including automatic foreground recovery, owns a new revision. */
    fun didReportPageImpression(pageId: String) {
        pageRevision++
        if (currentPage?.first != pageId) currentPage = null
    }

    private fun beginInterstitialPresentation(adId: Int) {
        if (adFor(adId) !is InterstitialAd || interstitialPresentations.containsKey(adId)) return
        interstitialPresentations[adId] = pageRevision
        syncBannerCover()
    }

    private fun endInterstitialPresentation(adId: Int, dismissed: Boolean) {
        // The publisher may dispose its Dart controller while the native ad is still showing.
        // Match the presentation, not the ad registry, so that cannot strand every banner.
        val revision = interstitialPresentations.remove(adId) ?: return
        if (dismissed) {
            pendingReturnRevision = revision
            completeInterstitialReturn()
        } else {
            syncBannerCover()
        }
    }

    private fun completeInterstitialReturn() {
        val revision = pendingReturnRevision ?: return
        if (!hostResumed || interstitialPresentations.isNotEmpty()) return
        // Report BEFORE releasing the cover, otherwise an overdue periodic refresh can start
        // first and immediately be replaced by this page impression. Native cancels its pending
        // foreground impression; if one already ran, its revision prevents a second report here.
        if (revision == pageRevision) currentPage?.let { reportPage(it.first, it.second) }
        pendingReturnRevision = null
        syncBannerCover()
    }

    private fun syncBannerCover() {
        val covered = interstitialPresentations.isNotEmpty() || pendingReturnRevision != null
        ads.values.filterIsInstance<FullScreenCoverableAd>().forEach { it.setFullScreenCovered(covered) }
    }

    fun adFor(id: Int?): Ad? {
        if (id == null) {
            return null
        }

        return ads[id]
    }

    fun trackAd(ad: Ad, adId: Int) {
        if (ads[adId] != null) {
            throw IllegalArgumentException(
                String.format(
                    "Ad for following adId already exists: %d",
                    adId
                )
            )
        }

        ads[adId] = ad
        if (interstitialPresentations.isNotEmpty() || pendingReturnRevision != null) {
            (ad as? FullScreenCoverableAd)?.setFullScreenCovered(true)
        }
    }

    fun disposeAd(adId: Int) {
        if (!ads.containsKey(adId)) {
            return
        }

        ads[adId]?.dispose()
        ads.remove(adId)
    }

    fun disposeAllAds() {
        ads.values.forEach(Ad::dispose)

        ads.clear()
    }

    fun onAdLoaded(adId: Int, responseId: String? = null) {
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            "responseId" to responseId,
            EVENT_NAME_KEY to ON_AD_LOADED_EVENT
        )

        invokeOnAdEvent(args)
    }

    fun onAdFailedToLoad(adId: Int, adError: AdError) {
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_AD_FAILED_TO_LOAD_EVENT,
            AD_ERROR_KEY to adError,
            "errorDomain" to adError.domain,
        )

        invokeOnAdEvent(args)
    }

    fun onAdClicked(adId: Int) {
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_AD_CLICKED_EVENT,
        )

        invokeOnAdEvent(args)
    }

    fun onAdOpened(adId: Int) {
        beginInterstitialPresentation(adId)
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_AD_OPENED_EVENT,
        )

        invokeOnAdEvent(args)
    }

    fun onAdClosed(adId: Int) {
        endInterstitialPresentation(adId, dismissed = true)
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_AD_CLOSED_EVENT,
        )

        invokeOnAdEvent(args)
    }

    fun onAdImpression(adId: Int) {
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_AD_IMPRESSION_EVENT
        )

        invokeOnAdEvent(args)
    }

    private fun onUserEarnedReward(adId: Int, rewardAdItem: RewardAdItem) {
        val args = mapOf<String, Any?>(
            AD_ID_KEY to adId,
            EVENT_NAME_KEY to ON_USER_EARNED_REWARD_EVENT,
            REWARD_ITEM_KEY to rewardAdItem,
        )

        invokeOnAdEvent(args)
    }

    fun showAdWithId(id: Int): Boolean {
        val ad = adFor(id) ?: return false

        // Return the real show result (false = not an overlay, no activity, not
        // loaded yet, or already shown) so the plugin can report a show failure
        // instead of a silent success.
        return if (ad is OverlayAd) ad.show(activity) else false
    }


    fun createBannerAdListener(adId: Int): AdListener {
        return object : AdListener() {
            override fun onAdClicked() {
                onAdClicked(adId)
                super.onAdClicked()
            }

            override fun onAdOpened() {
                onAdOpened(adId)
                super.onAdOpened()
            }

            override fun onAdClosed() {
                onAdClosed(adId)
                super.onAdClosed()
            }

            override fun onAdImpression() {
                onAdImpression(adId)
                super.onAdImpression()
            }

            override fun onAdLoaded() {
                onAdLoaded(adId)
                super.onAdLoaded()
            }

            override fun onAdFailedToLoad(loadError: LoadAdError) {
                onAdFailedToLoad(adId, loadError)
                super.onAdFailedToLoad(loadError)
            }
        }
    }

    fun createRewardedAdLoadedListener(adId: Int): AudienzzRewardedAdLoadCallback {
        return object : AudienzzRewardedAdLoadCallback() {
            override fun onAdLoaded(ad: RewardedAd) {
                onAdLoaded(adId)
                val rewardAd = adFor(adId) as? RewardAd
                rewardAd?.setAd(ad)
                super.onAdLoaded(ad)
            }


            override fun onAdFailedToLoad(adError: LoadAdError) {
                onAdFailedToLoad(adId, adError)
                super.onAdFailedToLoad(adError)
            }
        }
    }

    fun createOverlayAdFullscreenContentListener(adId: Int): AudienzzFullScreenContentCallback {
        return object: AudienzzFullScreenContentCallback(){
            override fun onAdClicked() {
                super.onAdClicked()
                onAdClicked(adId)
            }

            override fun onAdDismissedFullScreenContent() {
                super.onAdDismissedFullScreenContent()
                onAdClosed(adId)
            }

            override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                super.onAdFailedToShowFullScreenContent(adError)
                endInterstitialPresentation(adId, dismissed = false)
                if (adFor(adId) is InterstitialAd) {
                    invokeOnAdEvent(mapOf(AD_ID_KEY to adId, EVENT_NAME_KEY to "onAdFailedToShow",
                        AD_ERROR_KEY to adError, "errorDomain" to adError.domain))
                } else { onAdFailedToLoad(adId, adError) }
            }

            override fun onAdImpression() {
                super.onAdImpression()
                onAdImpression(adId)
            }

            override fun onAdShowedFullScreenContent() {
                super.onAdShowedFullScreenContent()
                onAdOpened(adId)
            }
        }
    }

    fun createRewardedAdUserEarnedRewardListener(adId: Int): OnUserEarnedRewardListener {
        return OnUserEarnedRewardListener {
            onUserEarnedReward(
                adId,
                RewardAdItem(it.amount, it.type)
            )
        }
    }

    fun createInterstitialAdLoadedListener(adId: Int): AudienzzInterstitialAdLoadCallback {
        return object : AudienzzInterstitialAdLoadCallback() {
            override fun onAdLoaded(ad: AdManagerInterstitialAd) {
                val interstitialAd = adFor(adId) as? InterstitialAd ?: return
                interstitialAd.setAd(ad)
                onAdLoaded(adId, ad.responseInfo?.responseId)
            }

            override fun onAdFailedToLoad(adError: LoadAdError) {
                onAdFailedToLoad(adId, adError)
            }
        }
    }

    private fun invokeOnAdEvent(args: Map<String, Any?>) {
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod(ON_AD_EVENT_METHOD, args)
        }
    }

    companion object {
        private const val AD_ID_KEY = "adId"
        private const val EVENT_NAME_KEY = "eventName"
        private const val AD_ERROR_KEY = "adError"
        private const val REWARD_ITEM_KEY = "rewardItem"

        private const val ON_AD_EVENT_METHOD = "onAdEvent"

        private const val ON_AD_LOADED_EVENT = "onAdLoaded"
        private const val ON_AD_FAILED_TO_LOAD_EVENT = "onAdFailedToLoad"
        private const val ON_AD_CLICKED_EVENT = "onAdClicked"
        private const val ON_AD_OPENED_EVENT = "onAdOpened"
        private const val ON_AD_CLOSED_EVENT = "onAdClosed"
        private const val ON_AD_IMPRESSION_EVENT = "onAdImpression"
        private const val ON_USER_EARNED_REWARD_EVENT = "onUserEarnedReward"
    }
}
