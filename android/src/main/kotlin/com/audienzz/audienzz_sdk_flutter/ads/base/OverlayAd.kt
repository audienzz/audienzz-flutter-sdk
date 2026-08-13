package com.audienzz.audienzz_sdk_flutter.ads.base

import android.app.Activity

abstract class OverlayAd : Ad() {
    /// Returns true only when the ad was actually presented. False means the
    /// show was a no-op (no activity, ad not loaded yet, or already shown) —
    /// the caller surfaces that as a show failure instead of a silent success.
    abstract fun show(activity: Activity?): Boolean
}
