import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page ownership on Flutter is split deliberately: `currentPage` is the stamp new ads are created
/// with and must be set synchronously, while the page epoch — which drives platform-view remounting
/// — advances only when native echoes an impression back.
///
/// Getting that split wrong shipped three separate ways: the epoch advancing twice per impression,
/// a late echo resetting the stamp to an older page, and (in the RN twin of this code) the stamp
/// not being set synchronously at all so ads captured the previous page permanently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final codec = StandardMethodCodec(AdMessageCodec());
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Deliver a native -> Dart call, as the plugin does after every page impression.
  Future<void> nativeSays(String method, Object? arguments) async {
    await messenger.handlePlatformMessage(
      Constants.methodChannelName,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  setUp(() {
    adInstanceManager.currentPage = null;
    adInstanceManager.lastReportedPage = null;
    adInstanceManager.lastPageImpressionAt = null;
    adInstanceManager.pageEpoch.value = 0;
    messenger.setMockMethodCallHandler(
      MethodChannel(Constants.methodChannelName, codec),
      (call) async => null,
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      MethodChannel(Constants.methodChannelName, codec),
      null,
    );
  });

  group('pageImpression', () {
    test('stamps the creation page synchronously', () async {
      // The documented ordering is "report the page, then create its ads". Waiting for native's
      // asynchronous echo would stamp those ads with the previous page — permanently, since an
      // ad's page is fixed at creation.
      final future = AudienzzSdkFlutter.instance.pageImpression(name: 'A');
      // The stamp is the page id, which for a name-only report IS the name.
      // Reporting the same screen again therefore matches the banners already
      // on it and refreshes them, which is the long-standing contract.
      final reportedId = adInstanceManager.currentPage;
      expect(reportedId, 'A');

      expect(adInstanceManager.currentPage, reportedId);
      await future;
    });

    test('does not advance the epoch itself', () async {
      // The epoch must advance once per real impression. Advancing here as well as on the echo
      // produced two notifications, and with a frame between them, two platform-view remounts.
      await AudienzzSdkFlutter.instance.pageImpression(name: 'A');

      expect(adInstanceManager.pageEpoch.value, 0);
    });
  });

  group('native echo', () {
    test('advances the epoch exactly once', () async {
      await AudienzzSdkFlutter.instance.pageImpression(name: 'A');
      // Native echoes the ROUTING key — the page instance id — because that is
      // what a banner matches its own page impression against.
      final idA = adInstanceManager.currentPage!;

      await nativeSays('onPageImpression', {'name': idA});

      expect(adInstanceManager.pageEpoch.value, 1);
      expect(adInstanceManager.lastReportedPage, idA);
    });

    test('advances the epoch for an impression Dart never made', () async {
      // The automatic foreground impression is fired natively and never passes through the Dart
      // API. Before native owned foreground reporting, this case remounted nothing at all.
      await nativeSays('onPageImpression', {'name': 'Home'});

      expect(adInstanceManager.pageEpoch.value, 1);
      expect(adInstanceManager.lastReportedPage, 'Home');
    });

    test('drops an echo for a page that has already been superseded', () async {
      // Report B then C before either echo lands. B's confirmation arriving last must not reset
      // the creation stamp, or ads built in that window take permanent ownership of B.
      await AudienzzSdkFlutter.instance.pageImpression(name: 'B');
      await AudienzzSdkFlutter.instance.pageImpression(name: 'C');
      final idC = adInstanceManager.currentPage!;

      await nativeSays('onPageImpression', {'name': 'B'});

      expect(adInstanceManager.currentPage, idC);
      expect(adInstanceManager.lastReportedPage, isNot('B'));
      expect(adInstanceManager.pageEpoch.value, 0);
    });

    test('accepts the echo for the current page after a superseded one', () async {
      await AudienzzSdkFlutter.instance.pageImpression(name: 'B');
      await AudienzzSdkFlutter.instance.pageImpression(name: 'C');
      final idC = adInstanceManager.currentPage!;

      await nativeSays('onPageImpression', {'name': 'B'});
      await nativeSays('onPageImpression', {'name': idC});

      expect(adInstanceManager.currentPage, idC);
      expect(adInstanceManager.lastReportedPage, idC);
      expect(adInstanceManager.pageEpoch.value, 1);
    });

    test('ignores a malformed echo', () async {
      await nativeSays('onPageImpression', {'name': null});

      expect(adInstanceManager.pageEpoch.value, 0);
    });
  });
}
