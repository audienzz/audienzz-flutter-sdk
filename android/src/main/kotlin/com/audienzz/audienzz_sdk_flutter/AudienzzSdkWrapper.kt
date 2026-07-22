package com.audienzz.audienzz_sdk_flutter

import android.content.Context
import com.google.android.gms.ads.MobileAds
import org.audienzz.mobile.AudienzzPrebidMobile
import org.audienzz.mobile.AudienzzTargetingParams
import com.audienzz.audienzz_sdk_flutter.entities.InitializationStatus
import io.flutter.plugin.common.MethodChannel.Result

private const val FLUTTER_SDK_VERSION = "0.1.7"

class AudienzzSdkWrapper {
    fun initialize(context: Context, companyId: String, isAutomaticPpidEnabled: Boolean, prebidServerUrl: String?, result: Result){
        if (AudienzzPrebidMobile.isSdkInitialized) {
            result.success(InitializationStatus.SUCCESS)
        } else {
            AudienzzPrebidMobile.initializeSdk(
                context,
                companyId,
                isAutomaticPpidEnabled,
                prebidServerUrl,
            ) { status ->
                when (status) {
                    org.audienzz.mobile.api.data.AudienzzInitializationStatus.SUCCEEDED -> {
                        setupOmid()
                        setupFlutterSdkIdentity()
                        result.success(InitializationStatus.SUCCESS)
                    }
                    org.audienzz.mobile.api.data.AudienzzInitializationStatus.SERVER_STATUS_WARNING -> {
                        setupOmid()
                        setupFlutterSdkIdentity()
                        result.success(InitializationStatus.SUCCESS)
                    }
                    else -> result.success(InitializationStatus.FAIL)
                }
            }
        }
    }

    private fun setupOmid() {
        val v = MobileAds.getVersion()
        AudienzzTargetingParams.omidPartnerName = "Google"
        AudienzzTargetingParams.omidPartnerVersion = "${v.majorVersion}.${v.minorVersion}.${v.microVersion}"
    }

    private fun setupFlutterSdkIdentity() {
        AudienzzTargetingParams.setBridgeTargeting("au_flutter_v", FLUTTER_SDK_VERSION)
    }
}
