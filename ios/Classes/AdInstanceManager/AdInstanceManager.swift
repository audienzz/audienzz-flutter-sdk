import Flutter

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
}

class AdInstanceManager : NSObject {
    let channel: FlutterMethodChannel
    private var ads: AdsCollection<NSNumber, FAd>
    
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
        ad.load()
    }
    
    func dispose(adId: NSNumber) {
        ads.removeObject(forKey: adId)
    }
    
    func showAd(withId adId: NSNumber) {
        let ad = ad(for: adId) as? FAdWithoutView
        ad?.show()
    }
    
    func onAdLoaded(ad: FAd) {
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdLoaded",
        ])
    }
    
    func onAdFailedToLoad(ad: FAd, error: FAdError) {
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdFailedToLoad",
            "adError":error,
        ])
    }
    
    func onAdClicked(ad: FAd){
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdClicked",
        ])
    }
    
    func onAdOpened(ad: FAd){
        channel.invokeMethod("onAdEvent", arguments: [
            "adId":ad.adId,
            "eventName":"onAdOpened",
        ])
    }
    
    func onAdClosed(ad: FAd){
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
        ads.removeAllObjects()
    }
}
