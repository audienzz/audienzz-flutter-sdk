package com.audienzz.audienzz_sdk_flutter.ads.base

import io.flutter.plugin.platform.PlatformView

abstract class Ad{
    open var platformView : PlatformView? = null

    abstract fun load()
    abstract fun dispose()
}
