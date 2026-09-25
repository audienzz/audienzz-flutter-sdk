package com.audienzz.audienzz_sdk_flutter

import com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd
import com.google.android.gms.ads.AdSize
import io.mockk.*
import org.audienzz.mobile.AudienzzBannerAdUnit
import org.audienzz.mobile.original.AudienzzAdViewHandler
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

/**
 * The receiving side of `prebidAdSizes`: GAM is sized from one list, the Prebid ad unit from the
 * other — the split the native remote banner makes.
 *
 * A Dart test can only prove the list was SENT. Whether the plugin builds the ad unit from it is
 * decided here, and a Dart test asserting the payload stays green even if this side ignores it.
 */
@RunWith(RobolectricTestRunner::class)
class BannerAdPrebidSizesTest {

    private lateinit var prebidPrimary: MutableList<String>
    private lateinit var prebidAdditional: MutableList<String>
    private var headerBiddingSetTo: Boolean? = null

    @Before
    fun setUp() {
        prebidPrimary = mutableListOf()
        prebidAdditional = mutableListOf()
        headerBiddingSetTo = null
        mockkConstructor(AudienzzAdViewHandler::class)
        every { anyConstructed<AudienzzAdViewHandler>().setScreen(any()) } just Runs
        every { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) } just Runs
        // Captured at the setter: a constructor mock's getter answers its default, not the field.
        every {
            anyConstructed<AudienzzAdViewHandler>() setProperty "headerBiddingEnabled" value any<Boolean>()
        } answers { headerBiddingSetTo = firstArg() }
    }

    @After
    fun tearDown() = unmockkAll()

    private fun size(s: String) = s.split('x').let { AdSize(it[0].toInt(), it[1].toInt()) }

    private fun banner(
        adSizes: List<String>,
        prebidAdSizes: List<String>?,
        headerBidding: Boolean = true,
        adaptive: Boolean = false,
        adaptiveConfig: Map<String, Any?>? = null,
    ) = BannerAd(
        adUnitId = "/1234/test",
        auConfigId = "test",
        adSizes = adSizes.map(::size),
        isAdaptiveSize = adaptive,
        isLazyLoad = false,
        smartRefresh = false,
        prefetchMarginDp = 200,
        refreshTimeInterval = 30_000,
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
        prebidAdSizes = prebidAdSizes?.map(::size),
        headerBidding = headerBidding,
        adaptiveBannerConfig = adaptiveConfig,
    ).apply {
        adUnitFactory = { _, width, height, _ ->
            prebidPrimary += "${width}x$height"
            mockk<AudienzzBannerAdUnit>(relaxed = true).also { unit ->
                every { unit.addAdditionalSize(any(), any()) } answers {
                    prebidAdditional += "${firstArg<Int>()}x${secondArg<Int>()}"
                }
            }
        }
    }

    private fun prebid() = prebidPrimary + prebidAdditional
    private fun BannerAd.gam() = gamAdSizes.map { "${it.width}x${it.height}" }

    @Test
    fun `adaptive handoff uses mounted width on every request and keeps Prebid sizes`() {
        var handoff: ((com.google.android.gms.ads.admanager.AdManagerAdRequest, org.audienzz.mobile.AudienzzResultCode?) -> Unit)? = null
        every { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) } answers {
            handoff = lastArg()
        }
        val ad = banner(listOf("300x250"), listOf("300x250"), adaptive = true)
        val widths = mutableListOf<Int>()
        ad.loadGoogle = { google, _ ->
            widths += google.adSizes!!.first().width
            assertEquals(0, google.adSizes!!.first().height)
            assertEquals(2, google.adSizes!!.size)
        }
        ad.load()
        val view = ad.platformView!!.view
        val context = RuntimeEnvironment.getApplication()
        val container = android.widget.FrameLayout(context)
        container.addView(view)
        val density = context.resources.displayMetrics.density
        for (width in listOf(280, 360)) {
            container.layout(0, 0, (width * density).toInt(), (250 * density).toInt())
            requireNotNull(handoff)(com.google.android.gms.ads.admanager.AdManagerAdRequest.Builder().build(), null)
        }
        assertEquals(listOf(280, 360), widths)
        assertEquals(listOf("300x250"), prebid())
        ad.dispose()
    }

    @Test
    fun `custom adaptive width and max height reach Google unchanged`() {
        val ad = banner(listOf("300x250"), null, adaptive = true,
            adaptiveConfig = mapOf("widthStrategy" to "CUSTOM", "customWidth" to 280.0, "maxHeight" to 180.0))
        ad.load()
        val view = ad.platformView!!.view as com.google.android.gms.ads.admanager.AdManagerAdView
        ad.prepareGoogleSize(view)
        assertEquals(AdSize.getInlineAdaptiveBannerAdSize(280, 180), view.adSizes!!.first())
        ad.dispose()
    }

    @Test
    fun `a GAM-only size reaches GAM and never reaches the Prebid ad unit`() {
        // dev config 192: 300x600 is sold direct in GAM and kept out of header bidding.
        val ad = banner(listOf("300x250", "300x600", "320x480"), listOf("320x480", "300x250"))
        ad.load()

        assertTrue("direct-sold 300x600 must still be able to serve", "300x600" in ad.gam())
        assertEquals(listOf("320x480", "300x250"), prebid())
    }

    @Test
    fun `the Prebid primary size is the first Prebid size, not the first GAM size`() {
        // The primary is the constructor argument; everything else is "additional". Building it
        // from the GAM list put the wrong size first even when the SETS matched (dev config 118).
        val ad = banner(listOf("300x250", "320x480"), listOf("320x480", "300x250"))
        ad.load()

        assertEquals(listOf("320x480"), prebidPrimary)
        assertEquals(listOf("300x250"), prebidAdditional)
    }

    @Test
    fun `without prebid sizes the ad unit is built from the GAM sizes, as before`() {
        // What Dart sends for a hand-built banner, and for an empty Prebid list (config 49).
        val ad = banner(listOf("300x250", "320x50"), null)
        ad.load()

        assertEquals(listOf("300x250", "320x50"), prebid())
        assertEquals(listOf("300x250", "320x50"), ad.gam())
    }

    @Test
    fun `an empty prebid list falls back instead of crashing`() {
        // The ad unit is built from the first size; an empty list has none.
        val ad = banner(listOf("300x250"), emptyList())
        ad.load()

        assertEquals(listOf("300x250"), prebid())
    }

    @Test
    fun `the primary size is not added again as an additional size`() {
        val ad = banner(listOf("300x250"), listOf("320x480", "300x250", "320x50"))
        ad.load()

        assertEquals(listOf("320x480"), prebidPrimary)
        assertEquals(listOf("300x250", "320x50"), prebidAdditional)
    }

    @Test
    fun `header bidding off reaches the handler`() {
        // Dart sends headerBidding=false for a remote banner with no Prebid sizes (config 49).
        banner(listOf("300x250"), null, headerBidding = false).load()

        assertEquals(false, headerBiddingSetTo)
    }

    @Test
    fun `header bidding stays on by default`() {
        // Control: proves the capture sees the setter, so the case above is not vacuous.
        banner(listOf("300x250"), null).load()

        assertEquals(true, headerBiddingSetTo)
    }
}
