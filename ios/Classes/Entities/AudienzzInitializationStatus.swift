import GoogleMobileAds

enum AudienzzInitializationStatus : uint {
    
    init(status: InitializationStatus){
        let adapterStatuses = status.adapterStatusesByClassName
        let allAdaptersReady = adapterStatuses.allSatisfy { $0.value.state == .ready }
        
        self = allAdaptersReady ? .success : .fail
    }
    
    case success = 0
    case fail = 1
}
