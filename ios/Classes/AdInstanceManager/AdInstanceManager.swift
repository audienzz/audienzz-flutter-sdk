import Flutter
import AudienzziOSSDK
import UIKit

class AdsCollection<KeyType:  NSCopying & Hashable, ObjectType> {
    private var storage: [KeyType: ObjectType] = [:]
    
    func setObject(_ object: ObjectType, forKey key: KeyType) {
        storage[key] = object
    }
    
    func removeObject(forKey key: KeyType) {
        storage.removeValue(forKey: key)
    }
    
    func object(forKey key: KeyType) -> ObjectType? {
        return storage[key]
    }
    
    func allKeys(forObject object: ObjectType) -> [KeyType] {
        return storage.filter {
            (($0.value as AnyObject).isEqual(object))
        }.map { $0.key }
    }
    
    func removeAllObjects() {
        storage.removeAll()
    }

    func allObjects() -> [ObjectType] {
        return Array(storage.values)
    }
}

class AdInstanceManager : NSObject {
    let channel: FlutterMethodChannel
    private var ads: AdsCollection<NSNumber, FAd>
    private var currentPage: (id: String, name: String)?
    private var pageRevision = 0
    private var interstitialPresentations: [NSNumber: Int] = [:]

    // Internal seams for deterministic lifecycle tests; production uses the real native sink.
    var reportPage: (String, String) -> Void = { id, name in
        Audienzz.shared.pageImpression(pageId: id, name: name)
    }
    var isAppActive: () -> Bool = { UIApplication.shared.applicationState == .active }

    func pageImpression(pageId: String, name: String) {
        currentPage = (pageId, name)
        reportPage(pageId, name)
    }

    /// Called synchronously by the native observer, before its asynchronous echo to Dart.
    /// Includes automatic foreground impressions, so closing an interstitial cannot double-report
    /// a page already recovered by native or by navigation while the ad was on screen.
    func didReportPageImpression(_ pageId: String) {
        pageRevision += 1
        if currentPage?.id != pageId { currentPage = nil }
    }

    private func beginInterstitialPresentation(adId: NSNumber) {
        guard interstitialPresentations[adId] == nil else { return }
        interstitialPresentations[adId] = pageRevision
        for case let banner as FFullScreenCoverableAd in ads.allObjects() {
            banner.setFullScreenCovered(true)
        }
    }

    private func endInterstitialPresentation(adId: NSNumber, dismissed: Bool) {
        guard let startingRevision = interstitialPresentations.removeValue(forKey: adId),
              interstitialPresentations.isEmpty else { return }
        // Recreate while the cover still holds requests, then unblock. Reversing the order lets
        // an overdue periodic refresh auction first and the page impression replace it again.
        // A real background return belongs to native's existing foreground recovery instead.
        if dismissed, isAppActive(), startingRevision == pageRevision, let page = currentPage {
            reportPage(page.id, page.name)
        }
        for case let banner as FFullScreenCoverableAd in ads.allObjects() {
            banner.setFullScreenCovered(false)
        }
    }
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.ads = AdsCollection()
        let methodCodec = FlutterStandardMethodCodec(readerWriter: AdReaderWriter())
        self.channel = FlutterMethodChannel(name: "audienzz_sdk_flutter", binaryMessenger: binaryMessenger, codec: methodCodec)
    }
    
    func ad(for adId: NSNumber) -> FAd? {
        return ads.object(forKey: adId)
    }
    
    func adId(for ad: FAd) -> NSNumber? {
        let keys = ads.allKeys(forObject: ad)
        
        if(keys.count > 1){
            print("Multiple keys for a single ad")
        }
        
        if(keys.count > 0){
            return keys.first
        } else {
            return nil
        }
        
    }
    
    func loadAd(ad: FAd) {
        ads.setObject(ad, forKey: ad.adId)
        if !interstitialPresentations.isEmpty {
            (ad as? FFullScreenCoverableAd)?.setFullScreenCovered(true)
        }
        ad.load()
    }
    
    func dispose(adId: NSNumber) {
        if let interstitial = ads.object(forKey: adId) as? FInterstitialAd, interstitial.isPresenting { return }
        (ads.object(forKey: adId) as? FDisposableAd)?.dispose()
        ads.removeObject(forKey: adId)
    }
    
    func showAd(withId adId: NSNumber) -> FlutterError? {
        if let interstitial = ad(for: adId) as? FInterstitialAd { return interstitial.showIfReady() }
        guard let ad = ad(for: adId) as? FAdWithoutView else {
            return FlutterError(code: "-1", message: "No fullscreen ad for this ID.", details: "audienzz")
        }
        ad.show()
        return nil
    }
    
    func onAdFailedToShow(ad: FAd, error: FAdError, domain: String) {
        if ad is FInterstitialAd { endInterstitialPresentation(adId: ad.adId, dismissed: false) }
        channel.invokeMethod("onAdEvent", arguments: ["adId": ad.adId,
            "eventName": "onAdFailedToShow", "adError": error, "errorDomain": domain])
    }

    func onAdLoaded(ad: FAd, responseId: String? = nil) {
        var arguments: [String: Any] = ["adId": ad.adId, "eventName": "onAdLoaded"]
        if let responseId { arguments["responseId"] = responseId }
        channel.invokeMethod("onAdEvent", arguments: arguments)
    }
    
    func onAdFailedToLoad(ad: FAd, error: FAdError, domain: String? = nil) {
        var arguments: [String: Any] = [
            "adId":ad.adId,
            "eventName":"onAdFailedToLoad",
            "adError":error,
        ]
        if let domain { arguments["errorDomain"] = domain }
        channel.invokeMethod("onAdEvent", arguments: arguments)
    }
    
    func onAdClicked(ad: FAd){
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdClicked",
        ])
    }
    
    func onAdOpened(ad: FAd){
        if ad is FInterstitialAd { beginInterstitialPresentation(adId: ad.adId) }
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdOpened",
        ])
    }
    
    func onAdClosed(ad: FAd){
        if ad is FInterstitialAd { endInterstitialPresentation(adId: ad.adId, dismissed: true) }
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdClosed",
        ])
    }
    
    func onAdImpression(ad: FAd){
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdImpression",
        ])
    }
    
    func onRewardedAdUserEarnedReward(ad: FRewardedAd, reward: FRewardItem) {
            channel.invokeMethod("onAdEvent", arguments: [
                "adId":ad.adId,
                "eventName": "onUserEarnedReward",
                "rewardItem": reward,
            ])
        }

    
    func disposeAllAds() {
        for ad in ads.allObjects() {
            (ad as? FDisposableAd)?.dispose()
        }
        ads.removeAllObjects()
    }
}
