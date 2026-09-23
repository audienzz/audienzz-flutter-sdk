package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.app.Activity
import android.content.Context
import android.os.SystemClock
import com.audienzz.audienzz_sdk_flutter.ads.base.OverlayAd
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.admanager.AdManagerInterstitialAd
import com.google.android.gms.ads.admanager.AdManagerInterstitialAdLoadCallback
import org.audienzz.mobile.AudienzzAdSize
import org.audienzz.mobile.AudienzzBridgeApi
import org.audienzz.mobile.AudienzzInterstitialAdUnit
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzInterstitialAdHandler
import org.audienzz.mobile.original.callbacks.AudienzzFullScreenContentCallback
import org.audienzz.mobile.original.callbacks.AudienzzInterstitialAdLoadCallback

class InterstitialAd(
    private val adUnitId: String,
    private val auConfigId: String,
    private val minSizePercentage: MinSizePercentage,
    private val videoProtocols: List<AudienzzSignals.Protocols>,
    private val videoPlacement: AudienzzSignals.Placement,
    private val playbackMethods: List<AudienzzSignals.PlaybackMethod>,
    private val videoBitrate: VideoBitrate,
    private val videoDuration: VideoDuration,
    private val interstitialPbAdSlot: String?,
    private val gpId: String?,
    private val adSizes: List<AdSize>,
    private val customImpOrtbConfig: String?,
    private val context: Context,
    private val interstitialAdLoadedListener: AudienzzInterstitialAdLoadCallback,
    private val fullScreenContentListener: AudienzzFullScreenContentCallback,
    /** The ad config's raw `prebidConfig.format`, for a remote interstitial; null otherwise. */
    private val backendFormat: String? = null,
    /** The ad config's raw `prebidConfig.apis`, for a remote interstitial; null otherwise. */
    private val backendApis: List<Int>? = null,
) : OverlayAd() {
    var requestContext = org.audienzz.mobile.targeting.AudienzzAdRequestContext()

    private var interstitialAd: AdManagerInterstitialAd? = null

    // GAM interstitials are single-use; guard against a silent second show().
    private var shown = false
    private var disposed = false
    private var loadedAt = 0L
    private var adUnit: AudienzzInterstitialAdUnit? = null
    var showError: String? = null
        private set

    fun setAd(ad: AdManagerInterstitialAd) {
        if (disposed) return
        interstitialAd = ad
        loadedAt = SystemClock.elapsedRealtime()
    }

    override fun show(activity: Activity?): Boolean {
        val ad = interstitialAd
        if (disposed || activity == null || activity.isFinishing || activity.isDestroyed || ad == null || shown) {
            showError = "Interstitial is not ready, already presented, or has no active Activity."
            return false
        }
        if (SystemClock.elapsedRealtime() - loadedAt >= 3_600_000) {
            interstitialAd = null
            showError = "Interstitial expired. Load a new ad."
            return false
        }
        shown = true
        return try {
            ad.show(activity)
            true
        } catch (error: RuntimeException) {
            showError = error.message ?: "Interstitial presentation failed."
            false
        }
    }

    @OptIn(AudienzzBridgeApi::class)
    override fun load() {
        // One ad unit whatever the format: formats and API frameworks are backend-controlled.
        // The native unit resolves them from the ad config values Dart sent for a remote
        // interstitial (validated exactly as the native remote interstitial does), and otherwise
        // requests banner + video with MRAID 1/2/3 + OMID 1.
        val adUnit = AudienzzInterstitialAdUnit(auConfigId, minSizePercentage.width, minSizePercentage.height)
        adUnit.setBackendCapabilities(backendFormat, backendApis)
        adUnit.videoParameters = configureVideoParameters()

        this.adUnit = adUnit
        adUnit.apply {
            gpid = gpId
            pbAdSlot = interstitialPbAdSlot
            bannerParameters?.adSizes =
                adSizes.map { AudienzzAdSize(width = it.width, height = it.height) }.toSet()
            customImpOrtbConfig?.let { impOrtbConfig = it }
        }


        AudienzzInterstitialAdHandler(adUnit, adUnitId, requestContext).load(
            adLoadCallback = interstitialAdLoadedListener,
            fullScreenContentCallback = fullScreenContentListener,
            resultCallback = { resultCode, request, adLoadCallback ->
                if (!disposed) AdManagerInterstitialAd.load(context, adUnitId, request, adLoadCallback)
            },
        )
    }

    /**
     * The video settings Dart sent. Used only when the backend asks for video, and without an
     * `api` list: the native unit sets that from the backend. MP4 only — the one container Google's
     * player renders; `video/x-flv` was advertised here without being playable.
     */
    private fun configureVideoParameters(): AudienzzVideoParameters {
        return AudienzzVideoParameters(listOf("video/mp4")).apply {
            placement = AudienzzSignals.Placement.Interstitial
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
        disposed = true
        adUnit?.stopAutoRefresh()
        adUnit = null
        interstitialAd = null
    }
}
