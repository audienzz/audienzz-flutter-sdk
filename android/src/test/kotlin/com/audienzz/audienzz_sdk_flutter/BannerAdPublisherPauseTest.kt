package com.audienzz.audienzz_sdk_flutter

import com.audienzz.audienzz_sdk_flutter.ads.implementation.BannerAd
import io.mockk.*
import org.audienzz.mobile.original.AudienzzAdViewHandler
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

/**
 * The receiving side of Dart's `publisherPaused` flag.
 *
 * Dart sends it with creation so an eager banner cannot issue a request the publisher has already
 * stopped, and the plugin acts on it by calling [BannerAd.pauseAutoRefresh] before [BannerAd.load].
 * That only works if this wrapper REMEMBERS the pause: its handler does not exist until load()
 * builds it, so forwarding through the nullable reference dropped the call entirely — and a Dart
 * test asserting the outgoing payload stayed green throughout.
 */
@RunWith(RobolectricTestRunner::class)
class BannerAdPublisherPauseTest {

    private lateinit var stops: MutableList<String>

    @Before
    fun setUp() {
        stops = mutableListOf()
        mockkConstructor(AudienzzAdViewHandler::class)
        every { anyConstructed<AudienzzAdViewHandler>().stopAutoRefresh() } answers {
            stops += "stop"
        }
        every { anyConstructed<AudienzzAdViewHandler>().setScreen(any()) } just Runs
        every { anyConstructed<AudienzzAdViewHandler>().load(any(), any(), any(), any()) } answers {
            stops += "load"
        }
    }

    @After
    fun tearDown() = unmockkAll()

    private fun banner() = BannerAd(
        adUnitId = "/1234/test",
        auConfigId = "test",
        adSizes = listOf(com.google.android.gms.ads.AdSize(320, 50)),
        isAdaptiveSize = false,
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
    )

    @Test
    fun `a pause requested before load is installed before the handler loads`() {
        val ad = banner()
        ad.pauseAutoRefresh()
        ad.load()

        assertTrue("the handler must have been built and loaded", stops.contains("load"))
        assertTrue(
            "the publisher stop must reach the handler, and before it loads",
            stops.indexOf("stop") in 0 until stops.indexOf("load"),
        )
    }

    @Test
    fun `no pause is installed when the publisher did not ask for one`() {
        val ad = banner()
        ad.load()

        assertTrue(stops.contains("load"))
        assertTrue("nothing must be stopped that was not asked for", !stops.contains("stop"))
    }

    @Test
    fun `a resume before load cancels the retained pause`() {
        val ad = banner()
        ad.pauseAutoRefresh()
        ad.resumeAutoRefresh()
        ad.load()

        assertTrue(stops.contains("load"))
        assertTrue("a resume must clear the intent, not latch it", !stops.contains("stop"))
    }
}
