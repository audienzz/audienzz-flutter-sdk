package com.audienzz.audienzz_sdk_flutter.ads.base

import android.app.Activity

abstract class OverlayAd : Ad() {
    abstract fun show(activity: Activity?)
}
