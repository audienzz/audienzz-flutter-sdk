import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blueprint requires a managed banner to expose custom cover reporting and
/// a durable publisher pause. Geometry and hit testing cannot see a
/// pointer-transparent overlay, and a publisher stop must survive everything
/// that is not an explicit resume.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return {'width': 320.0, 'height': 50.0};
      return null;
    });
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting([
      RemoteAdConfiguration.fromJson({
        'id': 'managed',
        'config': {'adType': 'banner', 'refreshTimeSeconds': 30},
        'gamConfig': {
          'adUnitPath': '/1234/test',
          'adSizes': ['320x50'],
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['320x50'],
        },
      })
    ]);
  });

  tearDown(() {
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<AudienzzBannerController> pumpBanner(WidgetTester tester) async {
    final controller = AudienzzBannerController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AudienzzPage(
          name: 'article',
          child: AudienzzBanner(
            adConfigId: 'managed',
            slotKey: 'one',
            controller: controller,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a reported cover reaches the ad and can be cleared',
      (tester) async {
    final controller = await pumpBanner(tester);
    final adId = adInstanceManager.obscuredAdIds;
    expect(adId, isEmpty, reason: 'control: nothing is covered yet');

    await controller.reportCover(covered: true);
    expect(adInstanceManager.obscuredAdIds, isNotEmpty);

    await controller.reportCover(covered: false);
    expect(adInstanceManager.obscuredAdIds, isEmpty,
        reason: 'a cover is current state, not a one-way event');
  });

  testWidgets('disposal clears a reported cover', (tester) async {
    final controller = await pumpBanner(tester);
    await controller.reportCover(covered: true);
    expect(adInstanceManager.obscuredAdIds, isNotEmpty);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(adInstanceManager.obscuredAdIds, isEmpty);
  });

  testWidgets('the publisher pause reaches native and is durable',
      (tester) async {
    final controller = await pumpBanner(tester);
    await controller.stopAutoRefresh();
    expect(calls.where((c) => c.method == 'pauseBannerAutoRefresh'),
        hasLength(1));

    await controller.resumeAutoRefresh();
    expect(calls.where((c) => c.method == 'resumeBannerAutoRefresh'),
        hasLength(1));
  });

  testWidgets('controls are optional', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AudienzzPage(
          name: 'article',
          child: AudienzzBanner(adConfigId: 'managed', slotKey: 'one'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
