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
 * Gallery ads ask the SDK to keep their ad across page transitions. The property arrives with the
 * next Android SDK release, so the plugin sets it reflectively and must keep working without it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "mdpi")
class BannerAdKeepsAdAcrossPagesTest {

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

    private fun banner(keeps: Boolean) = BannerAd(
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
        keepsAdAcrossPages = keeps,
    ).apply {
        adUnitFactory = { _, _, _, _ -> mockk<AudienzzBannerAdUnit>(relaxed = true) }
        loadGoogle = { _, _ -> }
        onSizeAdjusted = { reports++ }
    }

    @Test
    fun `a gallery banner still loads when the SDK has no keepsAdAcrossPages yet`() {
        val ad = banner(keeps = true)
        ad.load()
        verify(exactly = 1) { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) }
        val supported = runCatching {
            AudienzzAdViewHandler::class.java.getMethod("setKeepsAdAcrossPages", Boolean::class.javaPrimitiveType)
        }.isSuccess
        assertEquals("reported to Dart as applied only if the SDK took it", supported, ad.keepsAdAcrossPagesApplied)
    }

    @Test
    fun `setting it reports whether the SDK supports it, never throws`() {
        val handler = mockk<AudienzzAdViewHandler>(relaxed = true)
        val supported = runCatching {
            AudienzzAdViewHandler::class.java.getMethod(
                "setKeepsAdAcrossPages",
                Boolean::class.javaPrimitiveType,
            )
        }.isSuccess
        assertEquals(supported, banner(keeps = true).applyKeepsAdAcrossPages(handler))
    }

    @Test
    fun `an ordinary banner loads unchanged`() {
        banner(keeps = false).load()
        verify(exactly = 1) { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) }
    }
}
