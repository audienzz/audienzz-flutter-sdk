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

    @Test
    fun `on - a fixed creative is still narrowed to its width`() {
        val ad = banner(includeFluid = true).apply { load() }
        handoff!!(AdManagerAdRequest.Builder().build(), AudienzzResultCode.SUCCESS)
        ad.view().setAdSizes(AdSize(320, 50))
        ad.onGoogleAdLoaded()
        assertEquals(AdSize(320, 50).getWidthInPixels(RuntimeEnvironment.getApplication()), ad.view().layoutParams.width)
        assertEquals(AdSize(320, 50), ad.getPlatformAdSize())
    }

    @Test
    fun `fluid ad - full width, and its measured height is reported once known`() {
        val ad = banner(includeFluid = true).apply { load() }
        handoff!!(AdManagerAdRequest.Builder().build(), AudienzzResultCode.SUCCESS)
        ad.view().setAdSizes(AdSize.FLUID)
        ad.onGoogleAdLoaded()
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, ad.view().layoutParams.width)

        // Height unknown until the creative is measured: nothing to report yet.
        ad.layOut(360, 250)
        assertNull("no creative height yet", ad.getPlatformAdSize())

        // The creative is 410 tall — taller than the 250 the slot reserved.
        val creative = View(RuntimeEnvironment.getApplication())
        ad.view().addView(creative, ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 410))
        ad.layOut(360, 250)
        org.robolectric.shadows.ShadowLooper.idleMainLooper()

        assertEquals("the slot's height must not cap it", AdSize(360, 410), ad.getPlatformAdSize())
        assertEquals(1, reports)
    }
}
