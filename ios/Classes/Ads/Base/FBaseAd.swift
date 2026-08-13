import Flutter

protocol FAd {
    var adId: NSNumber { get }
    
    func load()
}

protocol FAdWithoutView {
    func show()
}

/// Explicit teardown for ads. Called from AdInstanceManager on dispose so
/// native resources (refresh timers, banner views, retained GAM ads) are
/// released deterministically instead of waiting on ARC — disposed banners
/// were otherwise firing Prebid auctions invisibly, and full-screen ads leaked
/// their view + handler + GAM ad on every load.
protocol FDisposableAd {
    func dispose()
}

class FBaseAd: NSObject {
    let adId: NSNumber
    
    init(adId: NSNumber) {
        self.adId = adId
    }
}
