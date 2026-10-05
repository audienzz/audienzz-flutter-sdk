import Flutter
import UIKit
import XCTest
import GoogleMobileAds
import AudienzziOSSDK
@testable import audienzz_sdk_flutter

final class RunnerTests: XCTestCase {
    final class Messenger: NSObject, FlutterBinaryMessenger {
        var calls: [FlutterMethodCall] = []
        var sentOnMainThread: [Bool] = []
        func send(onChannel channel: String, message: Data?) {
            guard let message else { return }
            calls.append(FlutterStandardMethodCodec(readerWriter: AdReaderWriter()).decodeMethodCall(message))
            sentOnMainThread.append(Thread.isMainThread)
        }
        func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
            send(onChannel: channel, message: message)
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

    var messenger: Messenger!
    var manager: AdInstanceManager!
    var banner: Banner!
    var interstitial: FInterstitialAd!
    var google: GoogleAd!
    var reports: [(String, String)] = []

    override func setUp() {
        super.setUp()
        messenger = Messenger()
        manager = AdInstanceManager(binaryMessenger: messenger)
        banner = Banner(adId: 1)
        manager.loadAd(ad: banner)
        manager.reportPage = { [unowned self] id, name in
            reports.append((id, name))
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
        interstitial.adDidDismissFullScreenContent(google)
        interstitial.dispose()
        manager.disposeAllAds()
        interstitial = nil; manager = nil; banner = nil; google = nil
        reports = []
        super.tearDown()
    }

    func testRealInterstitialDelegatesReleaseCoverWithoutReportingAnotherPage() {
        for _ in 0..<3 {
            interstitial.adWillPresentFullScreenContent(google)
            XCTAssertTrue(banner.covered)
            interstitial.adDidDismissFullScreenContent(google)
            XCTAssertTrue(reports.isEmpty)
            XCTAssertFalse(banner.covered)
            interstitial.adDidDismissFullScreenContent(google)
            XCTAssertTrue(reports.isEmpty)
        }
    }

    func testNativeDiagnosticsReachDartOnceOnMainAndRestoreTheSinkOnDisable() {
        let originalSink = AUDiagnostics.sink
        let wasEnabled = Audienzz.shared.diagnosticsEnabled
        var fallback: [String] = []
        AUDiagnostics.sink = { fallback.append($0) }
        let plugin = AudienzzSdkFlutterPlugin(binaryMessenger: messenger)
        func enable(_ enabled: Bool) {
            plugin.handle(FlutterMethodCall(methodName: "setDiagnosticsEnabled",
                arguments: ["enabled": enabled])) { _ in }
        }
        defer {
            enable(false)
            AUDiagnostics.sink = originalSink
            Audienzz.shared.diagnosticsEnabled = wasEnabled
        }
        enable(true)
        enable(true) // Must not stack forwarding sinks on repeated initialization.
        let line = "AUDZ slot blank config=test"
        let forwarded = expectation(description: "background log forwarded on main")
        DispatchQueue.global().async {
            AUDiagnostics.sink(line)
            DispatchQueue.main.async { forwarded.fulfill() }
        }
        wait(for: [forwarded], timeout: 2)
        XCTAssertEqual(messenger.calls.map(\.method), ["onDiagnosticLog"])
        XCTAssertEqual(messenger.calls.first?.arguments as? String, line)
        XCTAssertEqual(messenger.sentOnMainThread, [true])
        XCTAssertTrue(fallback.isEmpty, "Only Dart prints, avoiding duplicate console lines")

        AUDiagnostics.sink("AUDZ slot reveal config=test") // pending main-thread forwarding
        enable(false)
        AUDiagnostics.sink("restored sink")
        let drained = expectation(description: "disabled forwarding drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        XCTAssertEqual(messenger.calls.count, 1, "Disabling also drops queued diagnostics")
        XCTAssertEqual(fallback, ["restored sink"])
    }

    func testDiagnosticForwardingDoesNotRetainThePluginOrReplaceTheSinkAfterTeardown() {
        let originalSink = AUDiagnostics.sink
        let wasEnabled = Audienzz.shared.diagnosticsEnabled
        defer {
            AUDiagnostics.sink = originalSink
            Audienzz.shared.diagnosticsEnabled = wasEnabled
        }
        var fallback: [String] = []
        AUDiagnostics.sink = { fallback.append($0) }
        var plugin: AudienzzSdkFlutterPlugin? = AudienzzSdkFlutterPlugin(binaryMessenger: messenger)
        weak var weakPlugin = plugin
        plugin?.handle(FlutterMethodCall(methodName: "setDiagnosticsEnabled",
            arguments: ["enabled": true])) { _ in }
        plugin = nil
        XCTAssertNil(weakPlugin)
        AUDiagnostics.sink("restored after teardown")
        XCTAssertEqual(fallback, ["restored after teardown"])
        XCTAssertTrue(messenger.calls.isEmpty)
    }

    func testBannersCreatedDuringPresentationAreHeldBeforeTheirFirstLoad() {
        interstitial.adWillPresentFullScreenContent(google)
        let lateBanner = Banner(adId: 3)
        manager.loadAd(ad: lateBanner)
        XCTAssertEqual(lateBanner.coveredWhenLoaded, true)
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertFalse(lateBanner.covered)
    }

    func testNavigationWhilePresentedDoesNotReclaimTheOldPage() {
        interstitial.adWillPresentFullScreenContent(google)
        manager.pageImpression(pageId: "route-2", name: "Settings")
        interstitial.adDidDismissFullScreenContent(google)
        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports.first?.0, "route-2")
        XCTAssertFalse(banner.covered)
    }

    func testDismissalDoesNotRequireAStoredBridgePage() {
        interstitial.adWillPresentFullScreenContent(google)
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
            XCTAssertEqual(nsValue(for: google.adSize),
                           nsValue(for: currentOrientationInlineAdaptiveBanner(width: google.adSize.size.width)))
            XCTAssertEqual(google.validAdSizes?.count, 1)
            // Model the native delegate resizing to a returned creative. The next request
            // must restore the adaptive descriptor without using the request-triggering setter.
            google.resize(adSizeFor(cgSize: CGSize(width: google.adSize.size.width, height: 140)))
        }
        ad.load()
        let native = try XCTUnwrap(ad.auBannerView)
        XCTAssertGreaterThan(native.frame.height, 0, "lazy geometry must exist before a response")
        host.view.addSubview(native)
        native.frame = CGRect(x: 0, y: 100, width: 280, height: 250)
        let callback = try XCTUnwrap(native.onLoadRequest)
        callback(AdManagerRequest())
        XCTAssertGreaterThan(native.bounds.height, 0, "only the host owns the lazy placeholder")
        native.frame.size.width = 360
        callback(AdManagerRequest())
        XCTAssertEqual(widths, [280, 360], "every handoff re-reads the mounted width")
        // Exercise the installed bridge callback AFTER load, as Google's size delegate can fire.
        manager.onAdLoaded(ad: ad)
        messenger.calls.removeAll()
        let sizeCallback = try XCTUnwrap(native.onAdSizeChanged)
        sizeCallback(CGSize(width: 280, height: 140))
        let event = try XCTUnwrap(messenger.calls.last?.arguments as? [String: Any])
        XCTAssertEqual(event["eventName"] as? String, "onAdSizeChanged")
        XCTAssertEqual(event["adId"] as? NSNumber, 40)
        XCTAssertEqual(event["width"] as? Int, 280)
        XCTAssertEqual(event["height"] as? Int, 140)
        sizeCallback(CGSize(width: 280, height: 140))
        sizeCallback(.zero)
        XCTAssertEqual(messenger.calls.count, 1, "No duplicate or zero-size notifications")
        let rendered = try XCTUnwrap(ad.getPlatformAdSize())
        XCTAssertEqual(rendered.height, 140, "Dart needs the creative's height, not the zero-height descriptor")
        ad.dispose()
        sizeCallback(CGSize(width: 280, height: 200))
        XCTAssertEqual(messenger.calls.count, 1, "A retired banner must not notify Dart")
    }

    // MARK: resizeToPrebidCreative — a 300x250 Prebid bid rendered in a 300x600 GAM creative

    private func prebidResizeBanner(enabled: Bool, adId: NSNumber) -> FBannerAd {
        let ad = FBannerAd(adUnitId: "/96628199/multi-size", auConfigId: "test",
            sizes: [FAdSize(width: 300, height: 250), FAdSize(width: 300, height: 600)],
            isAdaptiveSize: false, isLazyLoad: true,
            smartRefresh: false, prefetchMarginPoints: 0, refreshTimeInterval: nil,
            adFormat: .banner, apiParameters: [], videoProtocols: [], videoPlacement: .InBanner,
            videoPlaybackMethods: [], videoBitrate: FVideoBitrate(min: 0, max: 0),
            videoDuration: FVideoDuration(min: 0, max: 0), pbAdSlot: nil, gpId: nil,
            customImpOrtbConfig: nil, pageKey: "route-1", rootViewController: UIViewController(),
            adId: adId, manager: manager, resizeToPrebidCreative: enabled)
        ad.pauseAutoRefresh() // No live auctions: drive the installed callbacks directly.
        ad.loadGoogle = { _, _ in }
        ad.currentPrebidCreativeSize = { CGSize(width: 300, height: 250) }
        ad.load()
        return ad
    }

    private func reportedHeights() -> [Int] {
        messenger.calls.compactMap { call in
            guard let args = call.arguments as? [String: Any],
                  args["eventName"] as? String == "onAdSizeChanged" else { return nil }
            return args["height"] as? Int
        }
    }

    func testPrebidEventBeforeLoadReportsOnlyThePrebidSize() throws {
        let ad = prebidResizeBanner(enabled: true, adId: 50)
        defer { ad.dispose() }
        let native = try XCTUnwrap(ad.auBannerView)
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
        messenger.calls.removeAll()
        try XCTUnwrap(native.onLoadRequest)(AdManagerRequest())
        ad.adView(google, didReceiveAppEvent: "Prebid", with: nil)
        try XCTUnwrap(native.onAdSizeChanged)(CGSize(width: 300, height: 600))
        ad.bannerViewDidReceiveAd(google)
        XCTAssertEqual(reportedHeights(), [250])
        XCTAssertEqual(ad.getPlatformAdSize()?.height, 250)
    }

    func testPrebidEventAfterLoadCorrectsTheReportedSize() throws {
        let ad = prebidResizeBanner(enabled: true, adId: 51)
        defer { ad.dispose() }
        let native = try XCTUnwrap(ad.auBannerView)
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
        messenger.calls.removeAll()
        try XCTUnwrap(native.onLoadRequest)(AdManagerRequest())
        try XCTUnwrap(native.onAdSizeChanged)(CGSize(width: 300, height: 600))
        ad.bannerViewDidReceiveAd(google)
        ad.adView(google, didReceiveAppEvent: "Prebid", with: nil)
        XCTAssertEqual(reportedHeights(), [600, 250])
    }

    func testGamOwnCreativeAndDisabledFlagKeepGamSize() throws {
        for enabled in [true, false] {
            let ad = prebidResizeBanner(enabled: enabled, adId: enabled ? 52 : 53)
            let native = try XCTUnwrap(ad.auBannerView)
            let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
            messenger.calls.removeAll()
            try XCTUnwrap(native.onLoadRequest)(AdManagerRequest())
            if !enabled { ad.adView(google, didReceiveAppEvent: "Prebid", with: nil) }
            try XCTUnwrap(native.onAdSizeChanged)(CGSize(width: 300, height: 600))
            ad.bannerViewDidReceiveAd(google)
            XCTAssertEqual(reportedHeights(), [600], "enabled=\(enabled)")
            ad.dispose()
        }
    }

    func testEarlyPrebidEventDoesNotCutThePreviousCreative() throws {
        let ad = prebidResizeBanner(enabled: true, adId: 54)
        defer { ad.dispose() }
        let native = try XCTUnwrap(ad.auBannerView)
        let google = AdManagerBannerView(adSize: adSizeFor(cgSize: CGSize(width: 300, height: 600)))
        let request = try XCTUnwrap(native.onLoadRequest)
        let size = try XCTUnwrap(native.onAdSizeChanged)
        request(AdManagerRequest())
        size(CGSize(width: 300, height: 600)) // GAM's own creative, no Prebid event
        ad.bannerViewDidReceiveAd(google)
        messenger.calls.removeAll()

        request(AdManagerRequest()) // refresh; the old 300x600 is still on screen
        ad.adView(google, didReceiveAppEvent: "Prebid", with: nil)
        XCTAssertEqual(reportedHeights(), [], "the previous creative must not be cut")
        size(CGSize(width: 300, height: 600))
        ad.bannerViewDidReceiveAd(google)
        XCTAssertEqual(reportedHeights(), [250])
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
