package com.audienzz.audienzz_sdk_flutter

import android.view.View
import android.view.ViewGroup
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
import org.robolectric.annotation.Config

/**
 * Ad config `gamConfig.includeFluid`: GAM is also asked for the fluid size (e.g. fluid GAM native
 * styles), Prebid keeps its fixed sizes, a fluid ad spans the slot, and its height — known only to
 * the creative — is measured and reported to Dart.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class BannerAdFluidTest {

    private var handoff: ((AdManagerAdRequest, AudienzzResultCode?) -> Unit)? = null
    private var reports = 0

    @Before
    fun setUp() {
        handoff = null
        reports = 0
        mockkConstructor(AudienzzAdViewHandler::class)
        every { anyConstructed<AudienzzAdViewHandler>().setScreen(any()) } just Runs
        every { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) } answers {
            handoff = lastArg()
        }
    }

    @After
    fun tearDown() = unmockkAll()

    private val configured = listOf(AdSize(300, 250), AdSize(320, 50))

    private fun banner(includeFluid: Boolean) = BannerAd(
        adUnitId = "/96628199/multi-size",
        auConfigId = "test",
        adSizes = configured,
        isAdaptiveSize = false,
        isLazyLoad = false,
        smartRefresh = false,
        prefetchMarginDp = 200,
        refreshTimeInterval = 0,
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
        includeFluid = includeFluid,
    ).apply {
        adUnitFactory = { _, _, _, _ -> mockk<AudienzzBannerAdUnit>(relaxed = true) }
        loadGoogle = { _, _ -> }
        onSizeAdjusted = { reports++ }
    }

    private fun BannerAd.slot() = platformView!!.view as ViewGroup
    private fun BannerAd.view() = slot().getChildAt(0) as AdManagerAdView

    /** Lays the slot out at the size Flutter gives it, in px (mdpi: 1 px = 1 dp). */
    private fun BannerAd.layOut(width: Int, height: Int) {
        slot().measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY),
        )
        slot().layout(0, 0, width, height)
    }

    @Test
    fun `off - GAM gets only the fixed sizes`() {
        val ad = banner(includeFluid = false).apply { load() }
        assertEquals(configured, ad.gamAdSizes)
    }

    @Test
    fun `on - fluid follows the fixed sizes`() {
        val ad = banner(includeFluid = true).apply { load() }
        assertEquals(configured + AdSize.FLUID, ad.gamAdSizes)
    }

    @Test
    fun `on - a request reserves the whole slot`() {
        val ad = banner(includeFluid = true).apply { load() }
        handoff!!(AdManagerAdRequest.Builder().build(), AudienzzResultCode.SUCCESS)
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, ad.view().layoutParams.width)
    }

    /** Google delivered: reports [reported], while the creative it rendered is [contentPx] tall. */
    private fun BannerAd.delivered(reported: AdSize, contentPx: Int) {
        handoff!!(AdManagerAdRequest.Builder().build(), AudienzzResultCode.SUCCESS)
        view().setAdSizes(reported)
        view().addView(
            View(RuntimeEnvironment.getApplication()),
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, contentPx),
        )
        onGoogleAdLoaded()
    }

    @Test
    fun `a fixed creative is narrowed to its width and keeps its size`() {
        val ad = banner(includeFluid = true).apply { load() }
        ad.delivered(AdSize(320, 50), contentPx = 50)
        assertEquals(AdSize(320, 50).getWidthInPixels(RuntimeEnvironment.getApplication()), ad.view().layoutParams.width)
        ad.layOut(360, 50)
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        assertEquals(AdSize(320, 50), ad.getPlatformAdSize())
    }

    @Test
    fun `a creative taller than Google reports gets its measured height, not a cut slot`() {
        // Seen on a device: Google reported 320x50 for a 427 dp fluid creative.
        val ad = banner(includeFluid = true).apply { load() }
        ad.delivered(AdSize(320, 50), contentPx = 427)
        assertNull("held until measured, not reported as 320x50 first", ad.getPlatformAdSize())
        ad.layOut(360, 50)
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        assertEquals(AdSize(320, 427), ad.getPlatformAdSize())
        assertEquals(1, reports)
    }

    @Test
    fun `a creative shorter than Google reports does not get a huge slot`() {
        // Seen on a device: Google reported 300x600 for a 303 dp creative.
        val ad = banner(includeFluid = true).apply { load() }
        ad.delivered(AdSize(300, 600), contentPx = 303)
        ad.layOut(360, 600)
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        assertEquals(AdSize(300, 303), ad.getPlatformAdSize())
    }

    @Test
    fun `fluid ad - full width, measured height`() {
        val ad = banner(includeFluid = true).apply { load() }
        ad.delivered(AdSize.FLUID, contentPx = 410)
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, ad.view().layoutParams.width)
        ad.layOut(360, 250)
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        assertEquals("the slot's height must not cap it", AdSize(360, 410), ad.getPlatformAdSize())
        assertEquals(1, reports)
    }

    @Test
    fun `never measured - Google's size stands in after the timeout`() {
        val ad = banner(includeFluid = true).apply { load(); probeTimeoutMs = 50 }
        handoff!!(AdManagerAdRequest.Builder().build(), AudienzzResultCode.SUCCESS)
        ad.view().setAdSizes(AdSize(300, 250))
        ad.onGoogleAdLoaded()
        assertNull(ad.getPlatformAdSize())
        org.robolectric.shadows.ShadowLooper.idleMainLooper(100, java.util.concurrent.TimeUnit.MILLISECONDS)
        assertEquals(AdSize(300, 250), ad.getPlatformAdSize())
        assertEquals(1, reports)
    }
}
