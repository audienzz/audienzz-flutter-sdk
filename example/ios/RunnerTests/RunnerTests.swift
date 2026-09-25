import Flutter
import UIKit
import XCTest
import GoogleMobileAds
import AudienzziOSSDK
@testable import audienzz_sdk_flutter

final class RunnerTests: XCTestCase {
    final class Messenger: NSObject, FlutterBinaryMessenger {
        func send(onChannel channel: String, message: Data?) {}
        func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
            callback?(nil)
        }
        func setMessageHandlerOnChannel(_ channel: String,
                                       binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 1 }
        func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
    }

    final class Banner: FBaseAd, FAd, FFullScreenCoverableAd {
        var covered = false
        var coveredWhenLoaded: Bool?
        func load() { coveredWhenLoaded = covered }
        func setFullScreenCovered(_ covered: Bool) { self.covered = covered }
    }

    final class GoogleAd: NSObject, FullScreenPresentingAd {
        weak var fullScreenContentDelegate: FullScreenContentDelegate?
    }

    var manager: AdInstanceManager!
    var banner: Banner!
    var interstitial: FInterstitialAd!
    var google: GoogleAd!
    var reports: [(String, String)] = []
    var coveredDuringReport = false

    override func setUp() {
        super.setUp()
        manager = AdInstanceManager(binaryMessenger: Messenger())
        manager.isAppActive = { true }
        banner = Banner(adId: 1)
        manager.loadAd(ad: banner)
        manager.reportPage = { [unowned self] id, name in
            reports.append((id, name))
            coveredDuringReport = banner.covered
            // The real plugin's synchronous native page-impression observer does this.
            manager.didReportPageImpression(id)
        }
        manager.pageImpression(pageId: "route-1", name: "Article")
        reports.removeAll()
        interstitial = FInterstitialAd(adUnitId: "/test", auConfigId: "test",
            minSizePercentage: FMinSizePercentage(width: 80, height: 80),
            videoProtocols: [], videoPlacement: .Interstitial, videoPlaybackMethods: [],
            videoBitrate: FVideoBitrate(min: 0, max: 0), videoDuration: FVideoDuration(min: 0, max: 0),
            pbAdSlot: nil, gpId: nil, adId: 2, sizes: nil, customImpOrtbConfig: nil,
            rootViewController: UIViewController(), manager: manager)
        google = GoogleAd()
    }

    override func tearDown() {
        // No new page during teardown if a test left the native ad open.
        manager.isAppActive = { false }
        interstitial.adDidDismissFullScreenContent(google)
        interstitial.dispose()
        manager.disposeAllAds()
        interstitial = nil; manager = nil; banner = nil; google = nil
        reports = []
        super.tearDown()
    }

    func testRealInterstitialDelegatesHoldBannersAndReportOneReturnBeforeUnblocking() {
        interstitial.adWillPresentFullScreenContent(google)
        XCTAssertTrue(banner.covered)
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.0, "route-1")
        XCTAssertEqual(reports.first?.1, "Article")
        XCTAssertTrue(coveredDuringReport, "Unblocking first can start an overdue auction before the page replacement")
        XCTAssertFalse(banner.covered)
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertEqual(reports.count, 1, "Duplicate terminal callback must not re-auction")
    }

    func testBannersCreatedDuringPresentationAreHeldBeforeTheirFirstLoad() {
        interstitial.adWillPresentFullScreenContent(google)
        let lateBanner = Banner(adId: 3)
        manager.loadAd(ad: lateBanner)
        XCTAssertEqual(lateBanner.coveredWhenLoaded, true)
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertFalse(lateBanner.covered)
    }

    func testNativeForegroundImpressionAlreadyOwnsTheReturn() {
        interstitial.adWillPresentFullScreenContent(google)
        manager.didReportPageImpression("route-1")
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertTrue(reports.isEmpty)
        XCTAssertFalse(banner.covered)
    }

    func testNavigationWhilePresentedDoesNotReclaimTheOldPage() {
        interstitial.adWillPresentFullScreenContent(google)
        manager.pageImpression(pageId: "route-2", name: "Settings")
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.0, "route-2")
        XCTAssertFalse(banner.covered)
    }

    func testBackgroundDismissalLeavesTheImpressionToNativeForegroundRecovery() {
        interstitial.adWillPresentFullScreenContent(google)
        manager.isAppActive = { false }
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertTrue(reports.isEmpty)
        XCTAssertFalse(banner.covered)
    }

    func testFailedPresentationReleasesTheCoverWithoutAFalsePageReturn() {
        interstitial.adWillPresentFullScreenContent(google)
        interstitial.ad(google, didFailToPresentFullScreenContentWithError: NSError(domain: "test", code: 1))
        XCTAssertFalse(banner.covered)
        XCTAssertTrue(reports.isEmpty)
    }

    func testAdaptiveGoogleRequestUsesMountedWidthAndRetainsNonzeroPlaceholder() throws {
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        let ad = FBannerAd(adUnitId: "/test", auConfigId: "test",
            sizes: [FAdSize(width: 300, height: 250)], isAdaptiveSize: true, isLazyLoad: true,
            smartRefresh: false, prefetchMarginPoints: 0, refreshTimeInterval: nil,
            adFormat: .banner, apiParameters: [], videoProtocols: [], videoPlacement: .InBanner,
            videoPlaybackMethods: [], videoBitrate: FVideoBitrate(min: 0, max: 0),
            videoDuration: FVideoDuration(min: 0, max: 0), pbAdSlot: nil, gpId: nil,
            customImpOrtbConfig: nil, pageKey: "route-1", rootViewController: host,
            adId: 40, manager: manager)
        defer { ad.dispose(); window.isHidden = true }
        ad.pauseAutoRefresh() // No live auctions: exercise only the installed bridge handoff.
        var widths: [CGFloat] = []
        ad.loadGoogle = { google, _ in
            widths.append(google.adSize.size.width)
            XCTAssertEqual(google.adSize.size.height, 0, "must be inline adaptive, not the fixed 300x250")
            XCTAssertEqual(google.validAdSizes?.count, 2)
        }
        ad.load()
        let native = try XCTUnwrap(ad.auBannerView)
        XCTAssertGreaterThan(native.frame.height, 0, "lazy geometry must exist before a response")
        host.view.addSubview(native)
        native.frame = CGRect(x: 0, y: 100, width: 280, height: 250)
        let callback = try XCTUnwrap(native.onLoadRequest)
        callback(AdManagerRequest())
        native.frame.size.width = 360
        callback(AdManagerRequest())
        XCTAssertEqual(widths, [280, 360], "every handoff re-reads the mounted width")
        native.onAdSizeChanged?(CGSize(width: 280, height: 140))
        let rendered = try XCTUnwrap(ad.getPlatformAdSize())
        XCTAssertEqual(rendered.height, 140, "Dart needs the creative's height, not the zero-height descriptor")
    }

    func testPublisherAndInterstitialPausesCannotClearEachOther() throws {
        let realBanner = FBannerAd(adUnitId: "/test", auConfigId: "test",
            sizes: [FAdSize(width: 300, height: 250)], isAdaptiveSize: false, isLazyLoad: true,
            smartRefresh: false, prefetchMarginPoints: 0, refreshTimeInterval: nil,
            adFormat: .banner, apiParameters: [], videoProtocols: [], videoPlacement: .InBanner,
            videoPlaybackMethods: [], videoBitrate: FVideoBitrate(min: 0, max: 0),
            videoDuration: FVideoDuration(min: 0, max: 0), pbAdSlot: nil, gpId: nil,
            customImpOrtbConfig: nil, pageKey: "route-1", rootViewController: UIViewController(),
            adId: 4, manager: manager)
        // A real SDK configuration without network requests. Inspect its own state, not a test
        // mirror of the two booleans in FBannerAd; missing reflection fields fail loudly.
        realBanner.auBannerView = AUBannerView(configId: "test", adSize: CGSize(width: 300, height: 250), adFormats: [.banner])
        defer { realBanner.dispose() }
        realBanner.auBannerView!.adUnitConfiguration.setAutoRefreshMillis(time: 30_000)
        func refreshing() throws -> Bool {
            let configuration = realBanner.auBannerView!.adUnitConfiguration!
            let model = try XCTUnwrap(Mirror(reflecting: configuration).children.first { $0.label == "autorefreshEventModel" }?.value)
            return try XCTUnwrap(Mirror(reflecting: model).children.first { $0.label == "isAutorefresh" }?.value as? Bool)
        }
        XCTAssertTrue(try refreshing())
        realBanner.setFullScreenCovered(true)
        realBanner.resumeAutoRefresh()
        XCTAssertFalse(try refreshing(), "Publisher resume must not clear the interstitial cover")
        realBanner.pauseAutoRefresh()
        realBanner.setFullScreenCovered(false)
        XCTAssertFalse(try refreshing(), "Interstitial dismissal must not clear a publisher pause")
        realBanner.resumeAutoRefresh()
        XCTAssertTrue(try refreshing())
    }
}
