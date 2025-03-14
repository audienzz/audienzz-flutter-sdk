package com.audienzz.audienzz_sdk_flutter.platform_views

import android.view.View
import android.view.ViewGroup
import io.flutter.plugin.platform.PlatformView

class PlatformViewWrapper(private var view: View?) : PlatformView {
    override fun getView(): View? {
        return view
    }

    override fun dispose() {
        (view?.parent as? ViewGroup)?.removeView(view)
        this.view = null
    }
}
