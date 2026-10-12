package com.audienzz.audienzz_sdk_flutter

import com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.admanager.AdManagerAdRequest
import com.google.android.gms.ads.admanager.AdManagerAdView
import io.mockk.*
import org.audienzz.mobile.AudienzzBannerAdUnit
import org.audienzz.mobile.AudienzzResultCode
import org.audienzz.mobile.original.AudienzzAdViewHandler
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

/**
 * Ad config `resizeToPrebidCreative` (on by default): a Prebid bid that GAM rendered inside a
 * creative of another size. The view must take `hb_size` only when the Prebid creative rendered
 * (GAM's "Prebid" app event) AND Google finished this load — never for a creative GAM served
 * itself. Smaller fixes the off-centre gap, larger fixes the cut-off creative.
 */
@RunWith(RobolectricTestRunner::class)
class BannerAdResizeToPrebidTest {

    private var handoff: ((AdManagerAdRequest, AudienzzResultCode?) -> Unit)? = null

    /** The pending markup probes, in order: each answers with what the creative's page holds. */
    private val probes = mutableListOf<(AdSize?) -> Unit>()

    @Before
    fun setUp() {
        handoff = null
        probes.clear()
        mockkConstructor(AudienzzAdViewHandler::class)
        every { anyConstructed<AudienzzAdViewHandler>().setScreen(any()) } just Runs
        every { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) } answers {
            handoff = lastArg()
        }
    }

    @After
    fun tearDown() = unmockkAll()

    private val configured = listOf(AdSize(300, 250), AdSize(300, 600), AdSize(320, 50))

    private fun banner(resize: Boolean) = BannerAd(
        adUnitId = "/96628199/multi-size",
        auConfigId = "test",
        adSizes = configured,
        isAdaptiveSize = false,
        isLazyLoad = false,
        smartRefresh = false,
        prefetchMarginDp = 200,
        refreshTimeInterval = 7_000,
        adFormat = com.audienzz.audienzz_sdk_flutter.entities.AdFormat.BANNER,
        apiParameters = emptyList(),
        videoProtocols = emptyList(),
        videoPlacement = org.audienzz.mobile.AudienzzSignals.Placement.InBanner,
        playbackMethods = emptyList(),
        videoBitrate = com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate(300, 1500),
        videoDuration = com.audienzz.audienzz_sdk_flutter.entities.VideoDuration(1, 30),
        bannerPbAdSlot = null,
        gpId = null,
        customImpOrtbConfig = null,
        pageKey = "page",
        adListener = null,
        context = RuntimeEnvironment.getApplication(),
        resizeToPrebidCreative = resize,
    ).apply {
        adUnitFactory = { _, _, _, _ -> mockk<AudienzzBannerAdUnit>(relaxed = true) }
        loadGoogle = { _, _ -> }
        findPrebidCreativeSize = { _, found -> probes += found }
    }

    private fun BannerAd.view() =
        (platformView!!.view as android.view.ViewGroup).getChildAt(0) as AdManagerAdView

    private fun request(hbSize: String?) = AdManagerAdRequest.Builder().apply {
        if (hbSize != null) addCustomTargeting("hb_size", hbSize)
    }.build()

    /** Google delivered a creative of [width]x[height] for the request just handed off. */
    private fun BannerAd.googleDelivered(width: Int, height: Int) {
        view().setAdSizes(AdSize(width, height))
        onGoogleAdLoaded()
    }

    private fun BannerAd.prebidAppEvent() = view().appEventListener!!.onAppEvent("Prebid", "")

    /** "pending" while the markup probe decides the size: nothing is reported then. */
    private fun BannerAd.size() = getPlatformAdSize()?.let { "${it.width}x${it.height}" } ?: "pending"

    @Test
    fun `Prebid event before onAdLoaded shrinks without a separate size report`() {
        val ad = banner(resize = true)
        var adjusted = 0
        ad.onSizeAdjusted = { adjusted++ }
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)

        ad.prebidAppEvent()
        ad.googleDelivered(300, 600)

        assertEquals("300x250", ad.size())
        assertEquals("reported by the onAdLoaded path itself", 0, adjusted)
        ad.dispose()
    }

    @Test
    fun `Prebid event after onAdLoaded shrinks and asks for a new size report`() {
        val ad = banner(resize = true)
        var adjusted = 0
        ad.onSizeAdjusted = { adjusted++ }
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)

        ad.googleDelivered(300, 600)
        assertEquals("GAM's 300x600 is never reported", "pending", ad.size())
        ad.prebidAppEvent()

        assertEquals("300x250", ad.size())
        assertEquals(1, adjusted)
        ad.dispose()
    }

    @Test
    fun `a creative GAM served itself keeps GAM's size`() {
        // Prebid won the auction (hb_size present) but GAM served its own 300x600: no app event.
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)
        probes.single()(null) // no hb_size in the page

        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `turned off leaves GAM's size and installs no listener`() {
        val ad = banner(resize = false)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)

        assertNull(ad.view().appEventListener)
        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `the next request asks for every configured size again and forgets the old event`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.prebidAppEvent()
        ad.googleDelivered(300, 600)
        assertEquals("300x250", ad.size())

        requireNotNull(handoff)(request("300x250"), null) // refresh
        assertEquals(configured, ad.view().adSizes!!.toList())
        ad.googleDelivered(300, 600) // no Prebid event for this load
        probes.single()(null)
        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `an early Prebid event does not resize the previous creative`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600) // GAM's own creative, no Prebid event: stays 300x600
        probes.single()(null)

        requireNotNull(handoff)(request("300x250"), null) // refresh
        ad.view().setAdSizes(AdSize(300, 600)) // the old 300x600 is still on screen
        ad.prebidAppEvent() // arrives before this load's onAdLoaded
        assertEquals("the previous creative must not be cut", "300x600", ad.size())

        ad.googleDelivered(300, 600)
        assertEquals("300x250", ad.size())
        ad.dispose()
    }

    @Test
    fun `a larger Prebid creative grows the view instead of being cut off`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x600"), null)
        ad.prebidAppEvent()
        ad.googleDelivered(300, 250)

        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    /** nexx360's line items render Prebid creatives without dispatching the app event. */
    @Test
    fun `without the app event the creative's Prebid markup still resizes the view`() {
        val ad = banner(resize = true)
        var adjusted = 0
        ad.onSizeAdjusted = { adjusted++ }
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)
        assertEquals("probed once, after the load", 1, probes.size)

        probes.single()(AdSize(300, 250))

        assertEquals("300x250", ad.size())
        assertEquals(1, adjusted)
        ad.dispose()
    }

    @Test
    fun `the size is held back until the probe answers, then reported once`() {
        val ad = banner(resize = true)
        var adjusted = 0
        ad.onSizeAdjusted = { adjusted++ }
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)

        assertEquals("no 300x600 bounce before the answer", "pending", ad.size())
        assertEquals(0, adjusted)
        probes.single()(null) // not a Prebid creative
        assertEquals("300x600", ad.size())
        assertEquals(1, adjusted)
        ad.dispose()
    }

    @Test
    fun `a probe that never answers falls back to GAM's size`() {
        val ad = banner(resize = true)
        var adjusted = 0
        ad.onSizeAdjusted = { adjusted++ }
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)
        assertEquals("pending", ad.size())

        org.robolectric.Shadows.shadowOf(android.os.Looper.getMainLooper())
            .idleFor(java.time.Duration.ofMillis(ad.probeTimeoutMs))
        assertEquals("300x600", ad.size())
        assertEquals(1, adjusted)
        probes.single()(AdSize(300, 250)) // too late: the size is settled
        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `a late probe answer cannot resize the next load`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600)
        val stale = probes.single()

        requireNotNull(handoff)(request("300x250"), null) // refresh
        ad.googleDelivered(300, 600)
        stale(AdSize(300, 250))
        assertEquals("the stale answer settles nothing", "pending", ad.size())

        probes.last()(null)
        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `the app event makes the markup probe unnecessary, and off means no probe`() {
        val on = banner(resize = true)
        on.load()
        requireNotNull(handoff)(request("300x250"), null)
        on.prebidAppEvent()
        on.googleDelivered(300, 600)
        on.dispose()

        val off = banner(resize = false)
        off.load()
        requireNotNull(handoff)(request("300x250"), null)
        off.googleDelivered(300, 600)
        off.dispose()

        assertEquals(0, probes.size)
    }

    /** An inline adaptive banner's child fills Google's view: in a full-width slot the ad was left. */
    @Test
    fun `Google's view takes the delivered width and is centered in the slot`() {
        val ad = banner(resize = true)
        ad.load()
        val slot = ad.platformView!!.view as android.widget.FrameLayout
        val params = ad.view().layoutParams as android.widget.FrameLayout.LayoutParams
        assertEquals("fills the slot before an ad exists", android.view.ViewGroup.LayoutParams.MATCH_PARENT, params.width)
        assertEquals(android.view.Gravity.CENTER_HORIZONTAL, params.gravity and android.view.Gravity.HORIZONTAL_GRAVITY_MASK)

        requireNotNull(handoff)(request("300x250"), null)
        ad.prebidAppEvent()
        ad.googleDelivered(300, 600)

        val density = RuntimeEnvironment.getApplication().resources.displayMetrics.density
        assertEquals((300 * density).toInt(), (ad.view().layoutParams as android.widget.FrameLayout.LayoutParams).width)
        assertEquals(slot, ad.view().parent)
        ad.dispose()
    }

    /** A refresh that delivers a wider ad must not render it in the previous ad's width. */
    @Test
    fun `each request reserves the widest possible ad, then fits the delivered one`() {
        val ad = banner(resize = true)
        ad.load()
        val density = RuntimeEnvironment.getApplication().resources.displayMetrics.density
        fun width() = (ad.view().layoutParams as android.widget.FrameLayout.LayoutParams).width

        requireNotNull(handoff)(request("300x250"), null)
        assertEquals("widest configured size: 320x50", (320 * density).toInt(), width())
        ad.prebidAppEvent()
        ad.googleDelivered(300, 600)
        assertEquals((300 * density).toInt(), width())

        requireNotNull(handoff)(request(null), null) // refresh
        assertEquals((320 * density).toInt(), width())
        ad.googleDelivered(320, 50)
        assertEquals((320 * density).toInt(), width())
        ad.dispose()
    }

    @Test
    fun `a narrower Prebid creative is sized to its own width`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x50"), null)
        ad.prebidAppEvent()
        ad.googleDelivered(320, 50)

        assertEquals("300x50", ad.size())
        ad.dispose()
    }
}
