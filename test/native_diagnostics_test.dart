import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = StandardMethodCodec(AdMessageCodec());

  test('native diagnostics use the Dart sink without causing page or ad calls',
      () async {
    final originalSink = AudienzzDiagnostics.sink;
    final wasEnabled = AudienzzDiagnostics.isEnabled;
    final lines = <String>[];
    final outgoing = <MethodCall>[];
    // Initialize the actual singleton's channel handler, as the SDK does.
    final beforeEpoch = adInstanceManager.pageEpoch.value;
    final beforePage = adInstanceManager.currentPage;
    messenger.setMockMethodCallHandler(
      MethodChannel(Constants.methodChannelName, codec),
      (call) async => outgoing.add(call),
    );
    addTearDown(() {
      AudienzzDiagnostics.sink = originalSink;
      AudienzzDiagnostics.isEnabled = wasEnabled;
      messenger.setMockMethodCallHandler(
        MethodChannel(Constants.methodChannelName, codec),
        null,
      );
    });
    AudienzzDiagnostics.sink = lines.add;
    Future<void> deliver(Object? line) => messenger.handlePlatformMessage(
          Constants.methodChannelName,
          codec.encodeMethodCall(MethodCall('onDiagnosticLog', line)),
          (_) {},
        );

    await AudienzzSdkFlutter.instance.setDiagnosticsEnabled(true);
    const nativeLines = [
      'AUDZ page recovered name=Article epoch=1',
      'AUDZ slot blank config=46',
      'AUDZ auction start slot=46 reason=pageImpression gen=2',
      'AUDZ slot reveal config=46',
    ];
    for (final line in nativeLines) {
      await deliver(line);
    }
    // Exact, non-empty: missing/duplicate output fails.
    expect(lines, nativeLines);
    await deliver(null);
    await deliver({'line': 'malformed'});
    await AudienzzSdkFlutter.instance.setDiagnosticsEnabled(false);
    await deliver('AUDZ slot blank config=disabled');
    expect(lines, nativeLines);
    expect(adInstanceManager.pageEpoch.value, beforeEpoch);
    expect(adInstanceManager.currentPage, beforePage);
    expect(
      outgoing.map((c) => c.method),
      ['_init', 'setDiagnosticsEnabled', 'setDiagnosticsEnabled'],
    );
  });
}
