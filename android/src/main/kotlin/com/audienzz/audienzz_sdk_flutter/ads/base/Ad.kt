package com.audienzz.audienzz_sdk_flutter.ads.base

import io.flutter.plugin.platform.PlatformView

/** A native fullscreen ad covers Flutter without changing its route or hit-test tree. */
interface FullScreenCoverableAd {
    fun setFullScreenCovered(covered: Boolean)
}

abstract class Ad{
    open var platformView : PlatformView? = null

    abstract fun load()
    abstract fun dispose()
}
