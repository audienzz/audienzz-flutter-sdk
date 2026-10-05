package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.content.Context
import androidx.core.view.doOnAttach
import com.audienzz.audienzz_sdk_flutter.ads.base.Ad
import com.audienzz.audienzz_sdk_flutter.ads.base.FullScreenCoverableAd
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.audienzz.audienzz_sdk_flutter.platform_views.PlatformViewWrapper
import com.google.android.gms.ads.AdListener
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.admanager.AdManagerAdView
import com.google.android.gms.ads.admanager.AppEventListener
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
    private val pageKey: String?,
    private val adListener: AdListener?,
    private val context: Context,
    /**
     * Sizes for the Prebid ad unit when they differ from [adSizes]; null or empty means use
     * [adSizes]. Last and defaulted so positional callers are unchanged.
     */
    private val prebidAdSizes: List<AdSize>? = null,
    /**
     * False serves GAM-only: the handler never asks Prebid, and reports no bid events. A remote
     * banner with no Prebid sizes turns it off.
     */
    private val headerBidding: Boolean = true,
    private val adaptiveBannerConfig: Map<String, Any?>? = null,
    /**
     * Ad config `resizeToPrebidCreative`: when the Prebid creative rendered inside a larger GAM
     * creative (a 300x250 bid placed in a 300x600 creative), size the view to the winning
     * `hb_size`. Only shrinks; a creative GAM served itself keeps GAM's size. Off by default.
     */
    private val resizeToPrebidCreative: Boolean = false,
) : Ad(), FullScreenCoverableAd {
    /**
     * GAM is sized from [adSizes], Prebid from this — the split the native remote banner makes.
     * A publisher can allow a size in GAM (for direct-sold line items) that they keep out of
     * header bidding, and one list for both asked bidders for it anyway. Falls back to [adSizes]
     * because the ad unit is built from the first size and an empty list would crash.
     */
    private val prebidSizes: List<AdSize> = prebidAdSizes?.takeIf { it.isNotEmpty() } ?: adSizes

    internal var loadGoogle: (AdManagerAdView, com.google.android.gms.ads.admanager.AdManagerAdRequest) -> Unit =
        { view, request -> view.loadAd(request) }

    /**
     * Builds the Prebid ad unit. A seam so a test can see which size it was built from: the size
     * lives inside Prebid's own ad unit, with no public way to read it back.
     */
    internal var adUnitFactory: (String, Int, Int, EnumSet<AudienzzAdUnitFormat>) -> AudienzzBannerAdUnit =
        { configId, width, height, formats -> AudienzzBannerAdUnit(configId, width, height, formats) }

    /** The sizes GAM was given. Read-only, for tests. */
    internal val gamAdSizes: List<AdSize>
        get() = adView?.adSizes?.toList().orEmpty()
    var requestContext = org.audienzz.mobile.targeting.AudienzzAdRequestContext()

    private var adView: AdManagerAdView? = null
    private var adViewHandler: AudienzzAdViewHandler? = null
    // Kept as a field so pauseAutoRefresh() / resumeAutoRefresh() can reach it
    // after load() returns. Dart-side visibility detection (RenderBox.localToGlobal)
    // drives these calls via method channel.
    private var bannerAdUnit: AudienzzBannerAdUnit? = null

    fun getPlatformAdSize(): AdSize? {
        return adView?.adSize
    }

    // ── resizeToPrebidCreative ──────────────────────────────────────────────────────────────
    //
    // Two signals per Google load, in either order: Google finished loading (onAdLoaded), and the
    // Prebid creative rendered (GAM's "Prebid" app event, forwarded by the native handler). Only
    // when both hold for the CURRENT load is the view shrunk to the winning hb_size. Acting on
    // the app event alone would read the previous creative's size, and acting without it would
    // cut a creative GAM served itself.

    /** Called by the instance manager after a shrink that happened after onAdLoaded. */
    internal var onSizeAdjusted: (() -> Unit)? = null

    private var prebidCreativeSize: AdSize? = null
    private var prebidRendered = false
    private var googleLoaded = false
    private var shrunk = false

    /** A new Google request is starting: forget the previous delivery's signals. */
    private fun beginGoogleLoad(request: com.google.android.gms.ads.admanager.AdManagerAdRequest) {
        prebidRendered = false
        googleLoaded = false
        prebidCreativeSize = if (resizeToPrebidCreative) {
            parseSize(request.customTargeting.getString(HB_SIZE_KEY))
        } else null
        // A previous shrink narrowed the view to one size. Request every configured size again.
        val view = adView
        if (shrunk && view != null && !isAdaptiveSize) {
            view.setAdSizes(*adSizes.toTypedArray())
        }
        shrunk = false
    }

    /** Called by the instance manager on onAdLoaded, before it reports the size to Dart. */
    internal fun onGoogleAdLoaded() {
        googleLoaded = true
        applyPrebidSize()
    }

    private fun onPrebidCreativeRendered() {
        prebidRendered = true
        if (applyPrebidSize()) onSizeAdjusted?.invoke()
    }

    /**
     * Returns true when the view was shrunk to the Prebid creative. The single gate for both
     * orders: before onAdLoaded the view still holds the PREVIOUS creative's size.
     */
    private fun applyPrebidSize(): Boolean {
        if (!resizeToPrebidCreative || !prebidRendered || !googleLoaded || shrunk) return false
        val target = prebidCreativeSize ?: return false
        val view = adView ?: return false
        val current = view.adSize ?: return false
        if (current.width <= 0 || current.height <= 0) return false
        if (target.width == current.width && target.height == current.height) return false
        // Only ever cut: a Prebid size larger than what GAM delivered is not this case.
        if (target.width > current.width || target.height > current.height) return false
        view.setAdSizes(target)
        shrunk = true
        return true
    }

    private fun parseSize(value: String?): AdSize? {
        val parts = value?.lowercase()?.split('x') ?: return null
        if (parts.size != 2) return null
        val width = parts[0].trim().toIntOrNull() ?: return null
        val height = parts[1].trim().toIntOrNull() ?: return null
        return if (width > 0 && height > 0) AdSize(width, height) else null
    }

    override fun load() {
        adView = AdManagerAdView(context)

        val currentAdView = adView

        currentAdView?.setAdSizes(*adSizes.toTypedArray())
        currentAdView?.adUnitId = adUnitId
        adListener?.let { currentAdView?.adListener = it }
        if (resizeToPrebidCreative) {
            // Installed before the handler, which captures and forwards it on every load.
            currentAdView?.appEventListener = AppEventListener { name, _ ->
                if (name.equals(PREBID_APP_EVENT, ignoreCase = true)) onPrebidCreativeRendered()
            }
        }

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

        val formats = when (adFormat) {
            AdFormat.BANNER -> EnumSet.of(AudienzzAdUnitFormat.BANNER)
            AdFormat.VIDEO -> EnumSet.of(AudienzzAdUnitFormat.VIDEO)
            AdFormat.BANNER_AND_VIDEO -> EnumSet.of(AudienzzAdUnitFormat.BANNER, AudienzzAdUnitFormat.VIDEO)
        }
        val prebidPrimary = prebidSizes.first()
        val adUnit = adUnitFactory(auConfigId, prebidPrimary.width, prebidPrimary.height, formats)
        bannerAdUnit = adUnit

        adUnit.apply {
            bannerParameters = customBannerParameters
            videoParameters = customVideoParameters
            pbAdSlot = bannerPbAdSlot
            gpid = gpId
            // The primary size is already set via the AudienzzBannerAdUnit
            // constructor (prebidSizes.first()). Only the remaining sizes are
            // "additional" — adding the first again duplicated it in the request.
            prebidSizes.drop(1).forEach { size ->
                addAdditionalSize(size.width, size.height)
            }
            // refreshTimeInterval arrives in milliseconds from Dart (seconds * 1000).
            // setAutoRefreshInterval expects seconds — divide by 1000.
            refreshTimeInterval?.let { setAutoRefreshInterval(it / 1000) }
            customImpOrtbConfig?.let { impOrtbConfig = it }
        }

        currentAdView?.let { adView ->
            val handler = AudienzzAdViewHandler(adView, adUnit, requestContext)
            adViewHandler = handler
            handler.headerBiddingEnabled = headerBidding
            // A Flutter banner lives in the single FlutterActivity, so the native page coordinator
            // cannot tell one route's ads from another's by host identity. Tag the handler with the
            // route key reported to pageImpression so it matches by value instead — this is what
            // makes page-scoped release/recreate work for Flutter at all.
            handler.setScreen(pageKey)
            // Before handler.load(): an eager banner requests inside that call, so a pause the
            // publisher installed before this ad existed has to be in place first.
            if (publisherPaused || fullScreenCovered) {
                handler.stopAutoRefresh()
            }
            handler.load(
                withLazyLoading = isLazyLoad,
                prefetchMarginDp = prefetchMarginDp,
            ) { request, _ ->
                // Always call loadAd() immediately so onAdLoaded can fire even when the
                // customer gates AdWidget behind the load callback (legacy pattern).
                beginGoogleLoad(request)
                prepareGoogleSize(adView)
                loadGoogle(adView, request)
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

    /**
     * Publisher pause requested before [load] built the handler.
     *
     * The handler does not exist until load() runs, so forwarding through a nullable reference
     * dropped a pause installed beforehand — and the handler that arrived afterwards held nothing.
     * Dart sends `publisherPaused` with creation precisely so an eager banner cannot issue a
     * request the publisher has already stopped, and that only works if the state is remembered
     * here until there is something to apply it to.
     */
    private var publisherPaused = false
    private var fullScreenCovered = false

    fun pauseAutoRefresh() {
        publisherPaused = true
        syncRefreshPause()
    }

    fun resumeAutoRefresh() {
        publisherPaused = false
        syncRefreshPause()
    }

    override fun setFullScreenCovered(covered: Boolean) {
        fullScreenCovered = covered
        syncRefreshPause()
    }

    private fun syncRefreshPause() {
        if (publisherPaused || fullScreenCovered) adViewHandler?.stopAutoRefresh()
        else adViewHandler?.resumeAutoRefresh()
    }

    fun setViewportVisible(visible: Boolean) {
        if (visible) adViewHandler?.resumeSmartRefresh() else adViewHandler?.pauseSmartRefresh()
    }

    /// Force a fresh auction now, ignoring the stale-aware refresh timing — used
    /// by the pageImpression reload broadcast (only for on-screen banners).
    fun forceReload() {
        adViewHandler?.reloadAd()
    }

    internal fun prepareGoogleSize(view: AdManagerAdView) {
        if (!isAdaptiveSize) return
        val configuredWidth = (adaptiveBannerConfig?.get("customWidth") as? Number)?.toInt() ?: 0
        val availablePx = (view.parent as? android.view.View)?.width?.takeIf { it > 0 }
            ?: view.width.takeIf { it > 0 } ?: context.resources.displayMetrics.widthPixels
        val width = if (adaptiveBannerConfig?.get("widthStrategy") == "CUSTOM" && configuredWidth > 0)
            configuredWidth else context.resources.pxToDp(availablePx)
        val maxHeight = (adaptiveBannerConfig?.get("maxHeight") as? Number)?.toInt() ?: 0
        val type = adaptiveBannerConfig?.get("type") as? String
        val adaptive = when {
            type.equals("ANCHORED", ignoreCase = true) ->
                AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(context, width)
            maxHeight > 0 -> AdSize.getInlineAdaptiveBannerAdSize(width, maxHeight)
            else -> AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(context, width)
        }
        // Preserve legacy defaults, but respect explicit backend delivery choices.
        val reservations = if (adaptiveBannerConfig?.get("includeReservationSizes") == false)
            emptyList() else adSizes
        view.setAdSizes(adaptive, *reservations.toTypedArray())
    }

    override fun dispose() {
        // Stop Prebid auto-refresh before releasing references. Nulling the
        // handler/unit alone left a pending smart-refresh runnable alive, so a
        // disposed banner kept running fetchDemand → loadAd() auction loops
        // (accumulating on every navigation and on hot restart).
        // destroy() — not just pauseSmartRefresh() — is what deregisters the handler from the page
        // coordinator and from AppForegroundMonitor. Pausing alone left the handler globally
        // reachable through the foreground listener, retaining the GAM view and its Activity, and
        // left it in the coordinator registry so a later page impression could reload a slot that
        // no longer exists.
        adViewHandler?.destroy()
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

    private companion object {
        const val HB_SIZE_KEY = "hb_size"
        const val PREBID_APP_EVENT = "Prebid"
    }
}
