import Flutter

protocol FAd {
    var adId: NSNumber { get }
    
    func load()
}

protocol FAdWithoutView {
    func show()
}

class FBaseAd: NSObject {
    let adId: NSNumber
    
    init(adId: NSNumber) {
        self.adId = adId
    }
}
