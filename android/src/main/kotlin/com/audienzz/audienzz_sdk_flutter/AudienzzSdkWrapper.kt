package com.audienzz.audienzz_sdk_flutter

import android.content.Context
import org.audienzz.mobile.AudienzzPrebidMobile
import com.audienzz.audienzz_sdk_flutter.entities.InitializationStatus
import io.flutter.plugin.common.MethodChannel.Result

class AudienzzSdkWrapper {
    fun initialize(context: Context, companyId: String, result: Result){
        if (AudienzzPrebidMobile.isSdkInitialized) {
            result.success(InitializationStatus.SUCCESS)
        } else {
            AudienzzPrebidMobile.initializeSdk(context, companyId) { status ->
                when (status) {
                    org.audienzz.mobile.api.data.AudienzzInitializationStatus.SUCCEEDED -> result.success(InitializationStatus.SUCCESS)
                    org.audienzz.mobile.api.data.AudienzzInitializationStatus.SERVER_STATUS_WARNING -> result.success(InitializationStatus.SUCCESS)
                    else -> result.success(InitializationStatus.FAIL)
                }
            }
        }
    }
}
