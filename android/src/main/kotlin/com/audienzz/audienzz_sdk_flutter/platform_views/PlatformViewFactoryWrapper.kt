package com.audienzz.audienzz_sdk_flutter.platform_views

import android.content.Context
import android.view.View
import com.audienzz.audienzz_sdk_flutter.ad_instance_manager.AdInstanceManager
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PlatformViewFactoryWrapper(private val adInstanceManager: AdInstanceManager) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        if (args == null) {
            return getErrorView(context)
        }

        val adId = args as? Int
        val ad = adInstanceManager.adFor(adId)

        return  ad?.platformView ?: return getErrorView(context)
    }

    private fun getErrorView(context: Context): PlatformView {
        return object : PlatformView {
            override fun getView(): View {
                return View(context)
            }

            override fun dispose() {
                // Do nothing.
            }
        }
    }
}
