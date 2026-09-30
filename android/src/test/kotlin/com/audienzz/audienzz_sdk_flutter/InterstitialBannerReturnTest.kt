package com.audienzz.audienzz_sdk_flutter

import android.app.Activity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.audienzz.audienzz_sdk_flutter.ad_instance_manager.AdInstanceManager
import com.audienzz.audienzz_sdk_flutter.ads.base.Ad
import com.audienzz.audienzz_sdk_flutter.ads.base.FullScreenCoverableAd
import com.audienzz.audienzz_sdk_flutter.ads.implementation.InterstitialAd
import com.google.android.gms.ads.AdError
import io.mockk.mockk
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class InterstitialBannerReturnTest {
    class HostActivity : Activity(), LifecycleOwner {
        val registry = LifecycleRegistry(this)
        override val lifecycle: Lifecycle get() = registry
    }

    private class Banner : Ad(), FullScreenCoverableAd {
        var covered = false
        var coveredAtLoad: Boolean? = null
        override fun setFullScreenCovered(covered: Boolean) { this.covered = covered }
        override fun load() { coveredAtLoad = covered }
        override fun dispose() = Unit
    }

    private lateinit var manager: AdInstanceManager
    private lateinit var host: HostActivity
    private lateinit var banner: Banner
    private val reports = mutableListOf<Pair<String, String>>()
    private val callbacks get() = manager.createOverlayAdFullscreenContentListener(2)

    @Before
    fun setUp() {
        host = Robolectric.buildActivity(HostActivity::class.java).get()
        host.registry.currentState = Lifecycle.State.RESUMED
        manager = AdInstanceManager(mockk(relaxed = true))
        manager.setActivity(host)
        banner = Banner()
        manager.trackAd(banner, 1)
        manager.trackAd(mockk<InterstitialAd>(relaxed = true), 2)
        manager.reportPage = { id, name ->
            reports += id to name
        }
        manager.pageImpression("route-1", "Article")
        reports.clear()
    }

    @After
    fun tearDown() {
        manager.setActivity(null)
        manager.disposeAllAds()
    }

    private fun open() {
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
        callbacks.onAdShowedFullScreenContent()
        assertTrue(banner.covered)
    }

    @Test
    fun `dismiss then resume releases cover without reporting a page`() {
        open()
        callbacks.onAdDismissedFullScreenContent()
        assertTrue(banner.covered)
        assertTrue(reports.isEmpty())
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertTrue(reports.isEmpty())
        assertFalse(banner.covered)
        callbacks.onAdDismissedFullScreenContent()
        assertTrue(reports.isEmpty())
    }

    @Test
    fun `resume then dismiss also preserves the page`() {
        open()
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertTrue(reports.isEmpty())
        assertTrue(banner.covered)
        callbacks.onAdDismissedFullScreenContent()
        assertTrue(reports.isEmpty())
        assertFalse(banner.covered)
    }

    @Test
    fun `repeated presentation cycles do not report extra pages or retain covers`() {
        repeat(3) {
            open()
            callbacks.onAdDismissedFullScreenContent()
            host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
            assertTrue(reports.isEmpty())
            assertFalse(banner.covered)
        }
    }

    @Test
    fun `navigation under the interstitial retains the new page`() {
        open()
        manager.pageImpression("route-2", "Settings")
        callbacks.onAdDismissedFullScreenContent()
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertEquals(listOf("route-2" to "Settings"), reports)
        assertFalse(banner.covered)
    }

    @Test
    fun `failed presentation releases the hold without a false impression`() {
        open()
        callbacks.onAdFailedToShowFullScreenContent(AdError(1, "failed", "test"))
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertTrue(reports.isEmpty())
        assertFalse(banner.covered)
    }

    @Test
    fun `new banners are held before loading including the wait for host resume`() {
        open()
        callbacks.onAdDismissedFullScreenContent()
        val late = Banner()
        manager.trackAd(late, 3)
        late.load()
        assertEquals(true, late.coveredAtLoad)
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertFalse(late.covered)
    }

    @Test
    fun `disposing the Dart ad while showing cannot strand the banner hold`() {
        open()
        manager.disposeAd(2)
        callbacks.onAdDismissedFullScreenContent()
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertTrue(reports.isEmpty())
        assertFalse(banner.covered)
    }

    @Test
    fun `background dismissal waits until a host is actually resumed`() {
        open()
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
        callbacks.onAdDismissedFullScreenContent()
        assertTrue(reports.isEmpty())
        assertTrue(banner.covered)
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        assertTrue(reports.isEmpty())
        host.registry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
        assertTrue(reports.isEmpty())
        assertFalse(banner.covered)
    }
}
