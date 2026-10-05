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
 * Ad config `resizeToPrebidCreative`: a 300x250 Prebid bid that GAM rendered inside a 300x600
 * creative. The view must shrink to `hb_size` only when the Prebid creative rendered (GAM's
 * "Prebid" app event) AND Google finished this load — never for a creative GAM served itself.
 */
@RunWith(RobolectricTestRunner::class)
class BannerAdResizeToPrebidTest {

    private var handoff: ((AdManagerAdRequest, AudienzzResultCode?) -> Unit)? = null

    @Before
    fun setUp() {
        handoff = null
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
    }

    private fun BannerAd.view() = platformView!!.view as AdManagerAdView

    private fun request(hbSize: String?) = AdManagerAdRequest.Builder().apply {
        if (hbSize != null) addCustomTargeting("hb_size", hbSize)
    }.build()

    /** Google delivered a creative of [width]x[height] for the request just handed off. */
    private fun BannerAd.googleDelivered(width: Int, height: Int) {
        view().setAdSizes(AdSize(width, height))
        onGoogleAdLoaded()
    }

    private fun BannerAd.prebidAppEvent() = view().appEventListener!!.onAppEvent("Prebid", "")

    private fun BannerAd.size() = getPlatformAdSize()!!.let { "${it.width}x${it.height}" }

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
        assertEquals("300x600", ad.size())
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

        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `off by default leaves GAM's size and installs no listener`() {
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
        assertEquals("300x600", ad.size())
        ad.dispose()
    }

    @Test
    fun `an early Prebid event does not resize the previous creative`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x250"), null)
        ad.googleDelivered(300, 600) // GAM's own creative, no Prebid event: stays 300x600

        requireNotNull(handoff)(request("300x250"), null) // refresh
        ad.view().setAdSizes(AdSize(300, 600)) // the old 300x600 is still on screen
        ad.prebidAppEvent() // arrives before this load's onAdLoaded
        assertEquals("the previous creative must not be cut", "300x600", ad.size())

        ad.googleDelivered(300, 600)
        assertEquals("300x250", ad.size())
        ad.dispose()
    }

    @Test
    fun `never grows past what GAM delivered`() {
        val ad = banner(resize = true)
        ad.load()
        requireNotNull(handoff)(request("300x600"), null)
        ad.prebidAppEvent()
        ad.googleDelivered(300, 250)

        assertEquals("300x250", ad.size())
        ad.dispose()
    }
}
