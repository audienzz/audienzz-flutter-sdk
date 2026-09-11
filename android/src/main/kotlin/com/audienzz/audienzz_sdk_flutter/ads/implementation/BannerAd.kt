package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.content.Context
import androidx.core.view.doOnAttach
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
    private val isLazyLoad: Boolean,
    private val smartRefresh: Boolean,
    private val prefetchMarginDp: Int,
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
    private var adViewHandler: AudienzzAdViewHandler? = null
    // Kept as a field so pauseAutoRefresh() / resumeAutoRefresh() can reach it
    // after load() returns. Dart-side visibility detection (RenderBox.localToGlobal)
    // drives these calls via method channel.
    private var bannerAdUnit: AudienzzBannerAdUnit? = null

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
        bannerAdUnit = adUnit

        adUnit.apply {
            bannerParameters = customBannerParameters
            videoParameters = customVideoParameters
            pbAdSlot = bannerPbAdSlot
            gpid = gpId
            // The primary size is already set via the AudienzzBannerAdUnit
            // constructor (adSizes.first()). Only the remaining sizes are
            // "additional" — adding the first again duplicated it in the request.
            adSizes.drop(1).forEach { size ->
                addAdditionalSize(size.width, size.height)
            }
            // refreshTimeInterval arrives in milliseconds from Dart (seconds * 1000).
            // setAutoRefreshInterval expects seconds — divide by 1000.
            refreshTimeInterval?.let { setAutoRefreshInterval(it / 1000) }
            customImpOrtbConfig?.let { impOrtbConfig = it }
        }

        currentAdView?.let { adView ->
            val handler = AudienzzAdViewHandler(adView, adUnit)
            adViewHandler = handler
            handler.load(
                withLazyLoading = isLazyLoad,
                prefetchMarginDp = prefetchMarginDp,
            ) { request, _ ->
                // Always call loadAd() immediately so onAdLoaded can fire even when the
                // customer gates AdWidget behind the load callback (legacy pattern).
                adView.loadAd(request)
                // Race-condition guard: if loadAd() fired before Flutter embedded the
                // platform view, GAM's internal invalidate() is a no-op (no window token).
                // We register doOnAttach so the creative is drawn once the view attaches.
                //
                // Important: only register when the view is NOT yet attached.
                //   • Already attached → GAM's own invalidate() inside loadAd() reaches
                //     the ViewRootImpl directly; adding doOnAttach here would fire
                //     synchronously on the main thread during the fetchDemand callback,
                //     triggering an expensive AdManagerAdView draw pass that causes
                //     Choreographer frame skips (Davey! jank).
                //   • Not yet attached → register doOnAttach. Use post{} so the
                //     invalidate() runs on the next Looper iteration, after Flutter's
                //     platform-view embedding pass has fully completed.
                if (!adView.isAttachedToWindow) {
                    adView.doOnAttach {
                        adView.post { adView.invalidate() }
                    }
                }
            }
            // Smart refresh is driven from the Dart layer: RemoteBannerAdExample uses
            // RenderBox.localToGlobal() (Flutter coordinates) to detect ≥20% visibility
            // and calls pauseAutoRefresh() / resumeAutoRefresh() via method channel.
        }
    }

    fun pauseAutoRefresh() {
        // Delegate to the handler so it can also cancel any pending scheduled
        // refresh runnable (the plain stopAutoRefresh() on bannerAdUnit would
        // leave a postDelayed Runnable alive and it would fire despite the pause).
        adViewHandler?.pauseSmartRefresh()
    }

    fun resumeAutoRefresh() {
        // Stale-aware resume: if elapsed time since last fetch >= refresh interval
        // the handler force-fetches demand immediately instead of restarting the
        // 30 s timer from zero (which is what bannerAdUnit.resumeAutoRefresh() does).
        adViewHandler?.resumeSmartRefresh()
    }

    /// Force a fresh auction now, ignoring the stale-aware refresh timing — used
    /// by the pageImpression reload broadcast (only for on-screen banners).
    fun forceReload() {
        adViewHandler?.reloadAd()
    }

    override fun dispose() {
        // Stop Prebid auto-refresh before releasing references. Nulling the
        // handler/unit alone left a pending smart-refresh runnable alive, so a
        // disposed banner kept running fetchDemand → loadAd() auction loops
        // (accumulating on every navigation and on hot restart).
        adViewHandler?.pauseSmartRefresh()
        bannerAdUnit?.stopAutoRefresh()
        bannerAdUnit?.destroy()
        adView?.destroy()
        adViewHandler = null
        bannerAdUnit = null
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
