package com.audienzz.audienzz_sdk_flutter.ads.implementation

import android.content.Context
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
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
import org.audienzz.mobile.addentum.AudienzzAdViewUtils
import org.audienzz.mobile.addentum.AudienzzPbFindSizeListener
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
     * Ad config `resizeToPrebidCreative`: when the Prebid creative rendered inside a GAM creative
     * of another size, size the view to the winning `hb_size`. A 300x250 bid in a 300x600 creative
     * was left smaller and off-centre; a 300x600 bid in a 300x250 one was cut off. A creative GAM
     * served itself keeps GAM's size. On unless the ad config turns it off.
     */
    private val resizeToPrebidCreative: Boolean = true,
    /**
     * Ad config `gamConfig.includeFluid`: also ask GAM for the fluid size, next to [adSizes] (e.g.
     * fluid GAM native styles). Prebid is unaffected. A fluid ad spans the slot and its height,
     * which only the creative knows, is measured and reported to Dart like any delivered size.
     */
    private val includeFluid: Boolean = false,
) : Ad(), FullScreenCoverableAd {
    /**
     * GAM is sized from [adSizes], Prebid from this — the split the native remote banner makes.
     * A publisher can allow a size in GAM (for direct-sold line items) that they keep out of
     * header bidding, and one list for both asked bidders for it anyway. Falls back to [adSizes]
     * because the ad unit is built from the first size and an empty list would crash.
     */
    private val prebidSizes: List<AdSize> = prebidAdSizes?.takeIf { it.isNotEmpty() } ?: adSizes

    /** What GAM is asked for: [adSizes], then the fluid size when [includeFluid]. */
    private val gamSizes: List<AdSize> = if (includeFluid) adSizes + AdSize.FLUID else adSizes

    /**
     * With [includeFluid]: the delivered creative's own height in pixels, measured without the
     * slot's height limit (see [SlotLayout]); 0 until known. Google does not report a fluid ad as
     * fluid: on a device it reported 320x50 for a 427 dp creative and 300x600 for a 303 dp one, so
     * the slot is sized from this measurement, not from the reported size.
     */
    private var contentHeightPx = 0

    /** This load's creative was not measured within [probeTimeoutMs]: report Google's size. */
    private var measureTimedOut = false

    private val fluidDelivered: Boolean
        get() = adView?.adSize == AdSize.FLUID

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

    /**
     * What Flutter mounts: the slot, at the size Dart gives it. Google's view sits inside it,
     * centered horizontally. Google's view centers its own child, but an inline adaptive banner's
     * child is as wide as the view, with the ad drawn at its left edge, so in a full-width slot
     * the ad was not centered. Narrowing Google's view to the delivered width fixes that whatever
     * Google does inside it. Until the first delivery it fills the slot, which lazy loading needs
     * (the slot has to be measurable before an ad exists). Top-aligned, as on iOS.
     */
    private var container: SlotLayout? = null

    /**
     * The slot Flutter sizes. A fluid ad is as tall as its creative, but a child measured inside
     * a slot of fixed height is capped at that height, so its real height would never be known.
     * After the normal pass this measures Google's view once more without the cap, records that
     * height, and reports it when it changes; Dart then resizes the slot to it.
     */
    private inner class SlotLayout(context: Context) : FrameLayout(context) {
        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            val view = adView ?: return
            if (!includeFluid || !googleLoaded || view.measuredWidth <= 0) return
            // Google's view keeps the width it was laid out with (full width, or the delivered ad's).
            val viewWidth = MeasureSpec.makeMeasureSpec(view.measuredWidth, MeasureSpec.EXACTLY)
            view.measure(viewWidth, MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
            val natural = view.measuredHeight

            // Back to the slot's own height for this layout pass.
            view.measure(viewWidth, MeasureSpec.makeMeasureSpec(measuredHeight, MeasureSpec.EXACTLY))
            if (natural > 0 && natural != contentHeightPx) {
                contentHeightPx = natural
                // Not from inside a measure pass: reporting resizes the slot. Not View.post,
                // which waits for an attach that may not have happened yet.
                android.os.Handler(android.os.Looper.getMainLooper()).post { onSizeAdjusted?.invoke() }
            }
        }
    }
    private var adViewHandler: AudienzzAdViewHandler? = null
    // Kept as a field so pauseAutoRefresh() / resumeAutoRefresh() can reach it
    // after load() returns. Dart-side visibility detection (RenderBox.localToGlobal)
    // drives these calls via method channel.
    private var bannerAdUnit: AudienzzBannerAdUnit? = null

    /**
     * The delivered size, or null while the markup probe is still deciding which size this load
     * shows. Reporting Google's size first made the slot bounce: 250 (reserved) → 600 (GAM's
     * creative) → 250 (the Prebid bid). Null keeps the slot as it is until the answer.
     */
    fun getPlatformAdSize(): AdSize? {
        if (probePending) return null
        if (includeFluid) return measuredSize()
        return adView?.adSize
    }

    /**
     * With [includeFluid]: the width Google's view has and the creative's measured height, in dp.
     * Falls back to Google's reported size until the creative has been measured (a fluid one, which
     * reports no size, gives nothing until then).
     */
    private fun measuredSize(): AdSize? {
        val view = adView ?: return null
        val reported = view.adSize?.takeIf { it.width > 0 && it.height > 0 }
        // Not measured yet: hold the report rather than send Google's size and then the real one
        // (the slot jumped 50 -> 427). After [probeTimeoutMs] the reported size stands in.
        val height = contentHeightPx.takeIf { it > 0 }
            ?: return if (measureTimedOut) reported else null
        val widthPx = if (fluidDelivered) container?.width else view.width
        val resources = context.resources
        val widthDp = widthPx?.takeIf { it > 0 }?.let { resources.pxToDp(it) }
            ?: reported?.width ?: return null
        return AdSize(widthDp, resources.pxToDp(height))
    }

    // ── resizeToPrebidCreative ──────────────────────────────────────────────────────────────
    //
    // Two signals per Google load, in either order: Google finished loading (onAdLoaded), and the
    // Prebid creative rendered (GAM's "Prebid" app event, forwarded by the native handler). Only
    // when both hold for the CURRENT load is the view sized to the winning hb_size. Acting on
    // the app event alone would read the previous creative's size, and acting without it would
    // resize a creative GAM served itself.

    /** Called by the instance manager after a resize that happened after onAdLoaded. */
    internal var onSizeAdjusted: (() -> Unit)? = null

    /**
     * The fallback when this load ended without the "Prebid" app event: the Prebid line item's
     * creative does not always dispatch it (nexx360's do not). Prebid's own finder reads the
     * winning size out of the creative's markup (`hb_size`), which a creative GAM served itself
     * does not contain. Answers the Prebid size, or null when there is none. A seam for tests:
     * the real one needs a page.
     */
    internal var findPrebidCreativeSize: (android.view.View, (AdSize?) -> Unit) -> Unit = { view, answer ->
        AudienzzAdViewUtils.findPrebidCreativeSize(view, object : AudienzzPbFindSizeListener {
            override fun success(width: Int, height: Int) {
                answer(if (width > 0 && height > 0) AdSize(width, height) else null)
            }

            override fun failure(errorCode: Int) = answer(null)
        })
    }

    /** How long a load's size may wait for the probe before Google's size is reported anyway. */
    internal var probeTimeoutMs = 1_000L

    /** The probe for the current load has not answered yet: its size is not reported. */
    private var probePending = false

    /** Bumped for every Google request, so a late markup probe cannot act on a newer load. */
    private var loadGeneration = 0

    private var prebidCreativeSize: AdSize? = null
    private var prebidRendered = false
    private var googleLoaded = false
    private var resized = false

    /** A new Google request is starting: forget the previous delivery's signals. */
    private fun beginGoogleLoad(request: com.google.android.gms.ads.admanager.AdManagerAdRequest) {
        loadGeneration++
        probePending = false
        prebidRendered = false
        googleLoaded = false
        contentHeightPx = 0
        measureTimedOut = false
        prebidCreativeSize = if (resizeToPrebidCreative) {
            parseSize(request.customTargeting.getString(HB_SIZE_KEY))
        } else null
        // A previous resize narrowed the view to one size. Request every configured size again.
        val view = adView
        if (resized && view != null && !isAdaptiveSize) {
            view.setAdSizes(*gamSizes.toTypedArray())
        }
        resized = false
    }

    /** Called by the instance manager on onAdLoaded, before it reports the size to Dart. */
    internal fun onGoogleAdLoaded() {
        googleLoaded = true
        if (includeFluid && contentHeightPx == 0) {
            val generation = loadGeneration
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (generation != loadGeneration || contentHeightPx > 0 || adView == null) return@postDelayed
                measureTimedOut = true
                onSizeAdjusted?.invoke()
            }, probeTimeoutMs)
        }
        val resized = applyPrebidSize()
        fitToDeliveredWidth()
        if (resized || prebidRendered) return
        probePrebidCreative()
    }

    /** Narrows Google's view to the delivered ad's width so the container can center it. */
    internal fun fitToDeliveredWidth() {
        // A fluid ad takes its width from Google's view, so that view spans the slot.
        if (fluidDelivered) {
            setViewWidth(ViewGroup.LayoutParams.MATCH_PARENT)
            return
        }
        val width = adView?.adSize?.getWidthInPixels(context)?.takeIf { it > 0 } ?: return
        setViewWidth(width)
    }

    /**
     * Before each Google request: widen Google's view to the widest ad this request can return,
     * a GAM size (adaptive included) or a Prebid size, which a Prebid resize may switch to. The
     * previous ad stays centered meanwhile, and the incoming one cannot be cut by the width the
     * previous one left; [fitToDeliveredWidth] narrows it again once it arrives.
     */
    private fun reserveRequestWidth() {
        val view = adView ?: return
        // A request that may return a fluid ad needs the whole slot: that ad is as wide as the view.
        if (includeFluid) {
            setViewWidth(ViewGroup.LayoutParams.MATCH_PARENT)
            return
        }
        val requested = view.adSizes.orEmpty().map { it.width } + prebidSizes.map { it.width }
        val widestDp = requested.filter { it > 0 }.maxOrNull() ?: return
        setViewWidth(AdSize(widestDp, 50).getWidthInPixels(context))
    }

    private fun setViewWidth(width: Int) {
        val view = adView ?: return
        val params = view.layoutParams as? FrameLayout.LayoutParams ?: return
        if (params.width == width) return
        params.width = width
        view.layoutParams = params
    }

    /**
     * Without the app event: is this load's creative Prebid's? See [findPrebidCreativeSize]. The
     * load's size is held back until the answer (or [probeTimeoutMs]), then reported once: the
     * Prebid size, or Google's when the creative is not Prebid's.
     */
    private fun probePrebidCreative() {
        if (!resizeToPrebidCreative || prebidCreativeSize == null) return
        val view = adView ?: return
        val generation = loadGeneration
        probePending = true
        val settle: (AdSize?) -> Unit = settle@{ size ->
            if (generation != loadGeneration || !probePending || adView == null) return@settle
            probePending = false
            if (size != null) {
                prebidRendered = true
                prebidCreativeSize = size
                applyPrebidSize()
            }
            fitToDeliveredWidth()
            onSizeAdjusted?.invoke()
        }
        // Not view.postDelayed: on a view that is not attached yet it waits for the attach.
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ settle(null) }, probeTimeoutMs)
        findPrebidCreativeSize(view, settle)
    }

    private fun onPrebidCreativeRendered() {
        prebidRendered = true
        val wasPending = probePending
        probePending = false
        if (applyPrebidSize() || wasPending) {
            fitToDeliveredWidth()
            onSizeAdjusted?.invoke()
        }
    }

    /**
     * Returns true when the view was sized to the Prebid creative. The single gate for both
     * orders: before onAdLoaded the view still holds the PREVIOUS creative's size. Both
     * directions: smaller fixes the off-centre gap, larger fixes the cut-off creative.
     */
    private fun applyPrebidSize(): Boolean {
        if (!resizeToPrebidCreative || !prebidRendered || !googleLoaded || resized) return false
        val target = prebidCreativeSize ?: return false
        val view = adView ?: return false
        val current = view.adSize ?: return false
        if (current.width <= 0 || current.height <= 0) return false
        if (target.width == current.width && target.height == current.height) return false
        view.setAdSizes(target)
        resized = true
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
        container = SlotLayout(context).apply {
            addView(
                currentAdView,
                FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    Gravity.CENTER_HORIZONTAL or Gravity.TOP,
                ),
            )
        }

        currentAdView?.setAdSizes(*gamSizes.toTypedArray())
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
                reserveRequestWidth()
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
        val fluid = if (includeFluid) listOf(AdSize.FLUID) else emptyList()
        view.setAdSizes(adaptive, *(reservations + fluid).toTypedArray())
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
        container?.removeAllViews()
        adViewHandler = null
        bannerAdUnit = null
        adView = null
        container = null
    }

     override var platformView: PlatformView? = null
         get() {
             if (adView == null) {
                 return null
             }

             field = PlatformViewWrapper(container)
             return field
         }

    private companion object {
        const val HB_SIZE_KEY = "hb_size"
        const val PREBID_APP_EVENT = "Prebid"
    }
}
