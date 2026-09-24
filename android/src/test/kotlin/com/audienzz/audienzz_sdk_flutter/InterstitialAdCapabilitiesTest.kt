package com.audienzz.audienzz_sdk_flutter

import com.audienzz.audienzz_sdk_flutter.ads.implementation.InterstitialAd
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import io.mockk.*
import org.audienzz.mobile.AudienzzBridgeApi
import org.audienzz.mobile.AudienzzInterstitialAdUnit
import org.audienzz.mobile.AudienzzSignals
import org.audienzz.mobile.AudienzzVideoParameters
import org.audienzz.mobile.original.AudienzzInterstitialAdHandler
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

/**
 * The receiving side of the backend interstitial values Dart forwards.
 *
 * Formats and API frameworks are backend-controlled: the plugin must hand the ad config's raw
 * values to the native unit, which validates them, and must not set an `api` list of its own —
 * a Dart test asserting the outgoing payload stays green even if this side ignores it.
 */
@OptIn(AudienzzBridgeApi::class)
@RunWith(RobolectricTestRunner::class)
class InterstitialAdCapabilitiesTest {

    private val handed = mutableListOf<Pair<String?, List<Int>?>>()
    private var videoMimes: List<String>? = null

    @Before
    fun setUp() {
        handed.clear(); videoMimes = null
        mockkConstructor(AudienzzInterstitialAdUnit::class)
        every { anyConstructed<AudienzzInterstitialAdUnit>().setBackendCapabilities(any(), any()) } answers {
            handed += firstArg<String?>() to secondArg<List<Int>?>()
        }
        every {
            anyConstructed<AudienzzInterstitialAdUnit>() setProperty "videoParameters" value any<AudienzzVideoParameters>()
        } answers {
            val video = firstArg<AudienzzVideoParameters>()
            videoMimes = video.mimes
        }
        mockkConstructor(AudienzzInterstitialAdHandler::class)
        every { anyConstructed<AudienzzInterstitialAdHandler>().load(any(), any(), any(), any()) } just Runs
    }

    @After
    fun tearDown() = unmockkAll()

    private fun interstitial(format: String?, apis: List<Int>?) = InterstitialAd(
        adUnitId = "/1/int",
        auConfigId = "p",
        minSizePercentage = MinSizePercentage(80, 60),
        videoProtocols = emptyList(),
        videoPlacement = AudienzzSignals.Placement.Interstitial,
        playbackMethods = emptyList(),
        videoBitrate = VideoBitrate(300, 1500),
        videoDuration = VideoDuration(1, 30),
        interstitialPbAdSlot = null,
        gpId = null,
        adSizes = emptyList(),
        customImpOrtbConfig = null,
        context = RuntimeEnvironment.getApplication(),
        interstitialAdLoadedListener = mockk(relaxed = true),
        fullScreenContentListener = mockk(relaxed = true),
        backendFormat = format,
        backendApis = apis,
    )

    @Test
    fun `the ad config values reach the native unit`() {
        interstitial("banner", listOf(7, 3)).load()
        assertEquals(listOf("banner" to listOf(7, 3)), handed)
    }

    @Test
    fun `a hand-built interstitial hands over nothing, so native applies its default`() {
        interstitial(null, null).load()
        assertEquals(listOf<Pair<String?, List<Int>?>>(null to null), handed)
    }

    /** `video/x-flv` was advertised here without Google's player being able to render it. */
    @Test
    fun `only a playable video container is advertised`() {
        interstitial(null, null).load()
        assertEquals(listOf("video/mp4"), videoMimes)
    }
}
