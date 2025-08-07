package com.audienzz.audienzz_sdk_flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.audienzz.mobile.AudienzzExternalUserId
import org.audienzz.mobile.AudienzzTargetingParams
import org.audienzz.mobile.rendering.models.openrtb.bidRequests.AudienzzExt
import org.json.JSONObject
import android.util.Pair

class AudienzzTargetingWrapper {

     fun setUserLatLng(call: MethodCall, result: MethodChannel.Result) {
        val latitude = call.argument<Double>("latitude")
        val longitude = call.argument<Double>("longitude")

        if (latitude != null && longitude != null) {
            AudienzzTargetingParams.userLatLng = Pair(latitude.toFloat(), longitude.toFloat())
            result.success(null)
        } else {
            AudienzzTargetingParams.userLatLng = null
            result.success(null)
        }
    }

     fun getUserLatLng(result: MethodChannel.Result) {
        val latLng = AudienzzTargetingParams.userLatLng
        if (latLng != null) {
            result.success(mapOf(
                "latitude" to latLng.first.toDouble(),
                "longitude" to latLng.second.toDouble()
            ))
        } else {
            result.success(null)
        }
    }

     fun getExtDataDictionary(result: MethodChannel.Result) {
        val extData = AudienzzTargetingParams.extDataDictionary
        val flutterMap = extData.mapValues { entry -> entry.value.toList() }
        result.success(flutterMap)
    }

     fun setUserExt(call: MethodCall, result: MethodChannel.Result) {
        val extMap = call.argument<Map<String, Any>>("ext")
        if (extMap != null) {
            val jsonObject = JSONObject(extMap)
            AudienzzTargetingParams.userExt = AudienzzExt().apply {  put(jsonObject) }
            result.success(null)
        } else {
            AudienzzTargetingParams.userExt = null
            result.success(null)
        }
    }

     fun getUserExt(result: MethodChannel.Result) {
        val userExt = AudienzzTargetingParams.userExt
        if (userExt?.jsonObject != null) {
            val map = jsonObjectToMap(userExt.jsonObject)
            result.success(map)
        } else {
            result.success(null)
        }
    }

     fun setExternalUserIds(call: MethodCall, result: MethodChannel.Result) {
        val externalUserIds = call.argument<List<Map<String, Any>>>("externalUserIds")
        if (externalUserIds != null) {
            val audienzzExternalUserIds = externalUserIds.map { userIdMap ->
                val source = userIdMap["source"] as String
                val uniqueIds = (userIdMap["uniqueIds"] as List<Map<String, Any>>).map { uniqueIdMap ->
                    val id = uniqueIdMap["id"] as String
                    val atype = uniqueIdMap["atype"] as Int
                    val ext = uniqueIdMap["ext"] as? Map<String, Any>

                    AudienzzExternalUserId.AudienzzUniqueId(id, atype).apply {
                        if (ext != null) {
                            this.ext = ext.toMutableMap()
                        }
                    }
                }
                AudienzzExternalUserId(source, uniqueIds)
            }
            AudienzzTargetingParams.setExternalUserIds(audienzzExternalUserIds)
            result.success(null)
        } else {
            AudienzzTargetingParams.setExternalUserIds(null)
            result.success(null)
        }
    }

    fun getExternalUserIds(result: MethodChannel.Result) {
        val externalUserIds = AudienzzTargetingParams.getExternalUserIds()
        if (externalUserIds != null) {
            val flutterList = externalUserIds.map { externalUserId ->
                mapOf(
                    "source" to externalUserId.source,
                    "ext" to externalUserId.ext,
                    //TODO: add uniqueIds
//                    "uniqueIds" to externalUserId.uniqueIds.map { uniqueId ->
//                        mapOf(
//                            "id" to uniqueId.id,
//                            "atype" to uniqueId.atype
//                        )
//                    }
                )
            }
            result.success(flutterList)
        } else {
            result.success(null)
        }
    }

     fun addGlobalTargeting(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        val value = call.argument<String>("value")
        val values = call.argument<List<String>>("values")

        when {
            key != null && value != null -> {
                AudienzzTargetingParams.addGlobalTargeting(key, value)
                result.success(null)
            }
            key != null && values != null -> {
                AudienzzTargetingParams.addGlobalTargeting(key, values.toSet())
                result.success(null)
            }
            else -> {
                result.error("INVALID_ARGUMENT", "Key and either value or values must be provided", null)
            }
        }
    }

    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = jsonObject.get(key)
            when (value) {
                is JSONObject -> map[key] = jsonObjectToMap(value)
                else -> map[key] = value
            }
        }
        return map
    }
}