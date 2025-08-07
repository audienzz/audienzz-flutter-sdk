import AudienzziOSSDK
import Flutter

class AudienzzTargetingWrapper {

    func setUserLatLng(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any] else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments",
                    details: nil
                )
            )
            return
        }

        if let latitude = args["latitude"] as? Double,
            let longitude = args["longitude"] as? Double 
        {
            AUTargeting.shared.setLatitude(latitude, longitude: longitude)
        } else {
            // Clear location if null values provided
            AUTargeting.shared.location = nil
        }
        result(nil)
    }

    func getUserLatLng(result: @escaping FlutterResult) {
        if let location = AUTargeting.shared.location {
            result([
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
            ])
        } else {
            result(nil)
        }
    }

    func setUserExt(_ call: FlutterMethodCall, result: @escaping FlutterResult)
    {
        guard let args = call.arguments as? [String: Any] else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments",
                    details: nil
                )
            )
            return
        }

        if let ext = args["ext"] as? [String: Any] {
            // Convert to [String: AnyHashable] for iOS compatibility
            let hashableExt = ext.mapValues { value -> AnyHashable in
                if let hashable = value as? AnyHashable {
                    return hashable
                }
                return "\(value)" as AnyHashable
            }
            AUTargeting.shared.userExt = hashableExt
        } else {
            AUTargeting.shared.userExt = nil
        }
        result(nil)
    }

    func setExternalUserIds(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any] else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Invalid arguments",
                    details: nil
                )
            )
            return
        }

        if let externalUserIds = args["externalUserIds"] as? [[String: Any]] {
            AUTargeting.shared.eids = externalUserIds
        } else {
            AUTargeting.shared.eids = nil
        }
        result(nil)
    }

    func getExternalUserIds(result: @escaping FlutterResult) {
        if let eids = AUTargeting.shared.eids {
            // Convert to format expected by Flutter
            let flutterEids = eids.map { eid -> [String: Any] in
                var flutterEid: [String: Any] = [:]

                if let source = eid["source"] as? String {
                    flutterEid["source"] = source
                }

                if let uids = eid["uids"] as? [[String: Any]] {
                    let flutterUids = uids.map { uid -> [String: Any] in
                        var flutterUid: [String: Any] = [:]
                        if let id = uid["id"] as? String {
                            flutterUid["id"] = id
                        }
                        if let atype = uid["atype"] as? NSNumber {
                            flutterUid["atype"] = atype.intValue
                        }
                        return flutterUid
                    }
                    flutterEid["uniqueIds"] = flutterUids  // Use uniqueIds to match Android
                }

                return flutterEid
            }
            result(flutterEids)
        } else {
            result(nil)
        }
    }

    func addGlobalTargeting(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String
        else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Key cannot be null",
                    details: nil
                )
            )
            return
        }

        if let value = args["value"] as? String {
            AUTargeting.shared.addGlobalTargeting(key: key, value: value)
            result(nil)
        } else if let values = args["values"] as? [String] {
            AUTargeting.shared.addGlobalTargeting(key: key, values: Set(values))
            result(nil)
        } else {
            result(
                FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "Either value or values must be provided",
                    details: nil
                )
            )
        }
    }

}
