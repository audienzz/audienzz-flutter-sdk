import Flutter
import AudienzziOSSDK

enum FAdField: UInt8 {
    case initializationStatus = 128
    case adSize = 129
    case adError = 130
    case rewardItem = 131
    case adFormat = 132
    case apiParameter = 133
    case videoProtocol = 134
    case placement = 135
    case playbackMethod = 136
    case videoBitrate = 137
    case videoDuration = 138
    case minSizePercentage = 143
}

class AdReaderWriter : FlutterStandardReaderWriter {
    override func reader(with data: Data) -> FlutterStandardReader {
        return AdReader(data: data)
    }
    
    override func writer(with data: NSMutableData) -> FlutterStandardWriter {
        return AdWriter(data: data)
    }
}

class AdReader : FlutterStandardReader {
    override init(data: Data) {
        super.init(data: data)
    }
    
    override func readValue(ofType type: UInt8) -> Any? {
        guard let field = FAdField(rawValue: type) else {
            return super.readValue(ofType: type)
        }
        
        switch field {
        case .initializationStatus:
            let code = readValue(ofType: readByte()) as? NSNumber?
            
            if code == 0 {
                return AudienzzInitializationStatus.success
            } else if code == 1 {
                return AudienzzInitializationStatus.fail
            }
            
            return nil
        case .adSize:
            let width = readValue(ofType: readByte()) as? Int
            let height = readValue(ofType: readByte()) as? Int
            
            if let width = width, let height = height {
                return FAdSize(width: width, height: height)
            } else {
                return nil
            }
        case .adError:
            
            let code = readValue(ofType: readByte()) as? NSNumber
            let message = readValue(ofType: readByte()) as? String
            
            if let code = code, let message = message {
                return FAdError(code: code, message: message)
            } else {
                return nil
            }
        case .rewardItem:
            let amount = readValue(ofType: readByte()) as? NSNumber
            let rewardItemType = readValue(ofType: readByte()) as? String
            
            if let amount = amount, let rewardItemType = rewardItemType {
                return FRewardItem(amount: amount, type: rewardItemType)
            } else {
                return nil
            }
            
        case .adFormat:
            let adFormatCode = readValue(ofType: readByte()) as? NSNumber
            
            switch adFormatCode {
            case 0:
                return FAdFormat.banner
            case 1:
                return FAdFormat.video
            case 2:
                return FAdFormat.bannerAndVideo
            default:
                return nil
            }
            
        case .apiParameter:
            let apiParameterCode = readValue(ofType: readByte()) as? NSNumber
            
            let apiParameter: AUApi?
            
            switch apiParameterCode {
            case 0: apiParameter = AUApi(apiType: AUApiType.VPAID_1)
            case 1: apiParameter = AUApi(apiType: AUApiType.VPAID_2)
            case 2: apiParameter = AUApi(apiType: AUApiType.MRAID_1)
            case 3: apiParameter = AUApi(apiType: AUApiType.ORMMA)
            case 4: apiParameter = AUApi(apiType: AUApiType.MRAID_2)
            case 5: apiParameter = AUApi(apiType: AUApiType.MRAID_3)
            case 6: apiParameter = AUApi(apiType: AUApiType.OMID_1)
            default:
                apiParameter = nil
            }
            
            return apiParameter
            
        case .videoProtocol:
            let videoProtocolCode = readValue(ofType: readByte()) as? NSNumber
            
            let auVideoProtocol: AUVideoProtocols?
            
            switch videoProtocolCode {
            case 0: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_1_0)
            case 1: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_2_0)
            case 2: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_3_0)
            case 3: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_1_0_Wrapped)
            case 4: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_2_0_Wrapped)
            case 5: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_3_0_Wrapped)
            case 6: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_4_0)
            case 7: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.VAST_4_0_Wrapped)
            case 8: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.DAAST_1_0)
            case 9: auVideoProtocol = AUVideoProtocols(type: AUVideoProtocolsType.DAAST_1_0_Wrapped)
            default:
                auVideoProtocol = nil
            }
            
            return auVideoProtocol
            
        case .placement:
            let placementCode = readValue(ofType: readByte()) as? NSNumber
            
            switch placementCode {
            case 0: return AUPlacement.InStream
            case 1: return AUPlacement.InBanner
            case 2: return AUPlacement.InArticle
            case 3: return AUPlacement.InFeed
            case 4: return AUPlacement.Interstitial
            case 5: return AUPlacement.Interstitial
            case 6: return AUPlacement.Interstitial
            default: return nil
            }
            
        case .playbackMethod:
            let playbackMethodCode = readValue(ofType: readByte()) as? NSNumber
            
            let playbackMethod: AUVideoPlaybackMethod?
            
            switch playbackMethodCode {
            case 0: playbackMethod = AUVideoPlaybackMethod(type:  AUVideoPlaybackMethodType.AutoPlaySoundOn)
            case 1: playbackMethod = AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.AutoPlaySoundOff)
            case 2: playbackMethod = AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.ClickToPlay)
            case 3: playbackMethod = AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.MouseOver)
            case 4: playbackMethod = AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.EnterSoundOn)
            case 5: playbackMethod = AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.EnterSoundOff)
            default: playbackMethod = nil
            }
            
            return playbackMethod
            
        case .videoBitrate:
            let minBitrate = readValue(ofType: readByte()) as? NSNumber
            let maxBitrate = readValue(ofType: readByte()) as? NSNumber
            
            if let minBitrate = minBitrate, let maxBitrate = maxBitrate {
                return FVideoBitrate(min: minBitrate, max: maxBitrate)
            } else {
                return nil
            }
            
        case .videoDuration:
            
            let minDuration = readValue(ofType: readByte()) as? NSNumber
            let maxDuration = readValue(ofType: readByte()) as? NSNumber
            
            if let minDuration = minDuration, let maxDuration = maxDuration {
                return FVideoDuration(min: minDuration, max: maxDuration)
            } else {
                return nil
            }
            
        case .minSizePercentage:
            let width = readValue(ofType: readByte()) as? NSNumber
            let height = readValue(ofType: readByte()) as? NSNumber
            
            if let width = width, let height = height {
                return FMinSizePercentage(width: width, height: height)
            } else {
                return nil
            }
        }
    }
}

class AdWriter : FlutterStandardWriter {
    override func writeValue(_ value: Any) {
        switch value {
        case let status as AudienzzInitializationStatus:
            writeByte(FAdField.initializationStatus.rawValue)
            
            switch status {
            case .fail: writeValue(1)
            case .success: writeValue(0)
            }
        case let size as FAdSize:
            writeByte(FAdField.adSize.rawValue)
            writeValue(size.width)
            writeValue(size.height)
        case let error as FAdError:
            writeByte(FAdField.adError.rawValue)
            writeValue(error.code)
            writeValue(error.message)
        case let rewardItem as FRewardItem:
            writeByte(FAdField.rewardItem.rawValue)
            writeValue(rewardItem.amount)
            writeValue(rewardItem.type)
        case let adFormat as FAdFormat:
            writeByte(FAdField.adFormat.rawValue)
            writeValue(adFormat.rawValue)
        case let apiParam as AUApi:
            writeByte(FAdField.apiParameter.rawValue)
            
            switch apiParam {
            case AUApi(apiType: AUApiType.VPAID_1): writeValue(0)
            case AUApi(apiType:AUApiType.VPAID_2): writeValue(1)
            case AUApi(apiType:AUApiType.MRAID_1): writeValue(2)
            case AUApi(apiType:AUApiType.ORMMA): writeValue(3)
            case AUApi(apiType:AUApiType.MRAID_2): writeValue(4)
            case AUApi(apiType:AUApiType.MRAID_3): writeValue(5)
            case AUApi(apiType:AUApiType.OMID_1): writeValue(6)
            default: return
            }
        case let videoProtocol as AUVideoProtocols:
            writeByte(FAdField.videoProtocol.rawValue)
            
            
            switch videoProtocol {
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_1_0): writeValue(0)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_2_0): writeValue(1)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_3_0): writeValue(2)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_1_0_Wrapped): writeValue(3)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_2_0_Wrapped): writeValue(4)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_3_0_Wrapped): writeValue(5)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_4_0): writeValue(6)
            case AUVideoProtocols(type:AUVideoProtocolsType.VAST_4_0_Wrapped): writeValue(7)
            case AUVideoProtocols(type:AUVideoProtocolsType.DAAST_1_0): writeValue(8)
            case AUVideoProtocols(type:AUVideoProtocolsType.DAAST_1_0_Wrapped): writeValue(9)
            default: return
            }
        case let placement as AUPlacement:
            writeByte(FAdField.placement.rawValue)
            switch placement {
            case AUPlacement.InStream: writeValue(0)
            case AUPlacement.InBanner: writeValue(1)
            case AUPlacement.InArticle: writeValue(2)
            case AUPlacement.InFeed: writeValue(3)
            case AUPlacement.Interstitial: writeValue(4)
            }
            
        case let playbackMethod as AUVideoPlaybackMethod:
            writeByte(FAdField.playbackMethod.rawValue)
            
            switch playbackMethod {
            case AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.AutoPlaySoundOn): writeValue(0)
            case AUVideoPlaybackMethod(type: AUVideoPlaybackMethodType.AutoPlaySoundOff): writeValue(1)
            case AUVideoPlaybackMethod(type:AUVideoPlaybackMethodType.ClickToPlay): writeValue(2)
            case AUVideoPlaybackMethod(type:AUVideoPlaybackMethodType.MouseOver): writeValue(3)
            case AUVideoPlaybackMethod(type:AUVideoPlaybackMethodType.EnterSoundOn): writeValue(4)
            case AUVideoPlaybackMethod(type:AUVideoPlaybackMethodType.EnterSoundOff): writeValue(5)
            default: return
            }
        case let videoBitrate as FVideoBitrate:
            writeByte(FAdField.videoBitrate.rawValue)
            writeValue(videoBitrate.min)
            writeValue(videoBitrate.max)
        case let videoDuration as FVideoDuration:
            writeByte(FAdField.videoDuration.rawValue)
            writeValue(videoDuration.min)
            writeValue(videoDuration.max)
        case let minSizePercentage as FMinSizePercentage:
            writeByte(FAdField.minSizePercentage.rawValue)
            writeValue(minSizePercentage.width)
            writeValue(minSizePercentage.height)
        default:
            super.writeValue(value)
            
        }
    }
}


