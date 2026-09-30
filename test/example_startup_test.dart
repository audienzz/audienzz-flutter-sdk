// Tests the shipped example composition across package boundaries.
// ignore_for_file: avoid_relative_lib_imports, require_trailing_commas
// ignore_for_file: cascade_invocations, always_put_control_body_on_new_line
import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../example/lib/pages/remote_banner_ad_example.dart';
import '../example/lib/widgets/sdk_initialization_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
      Constants.methodChannelName, StandardMethodCodec(AdMessageCodec()));
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    AudienzzPageRegistry.instance.resetForTesting();
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
        'id': '46',
        'config': {'adType': 'banner'},
        'gamConfig': {
          'adUnitPath': '/fixture/banner',
          'adSizes': ['320x50']
        },
        'prebidConfig': {
          'placementId': 'test',
          'adSizes': ['320x50']
        },
      }),
    ]);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    AudienzzRemoteConfig.instance.setAdUnitConfigsForTesting(null);
  });

  Widget ready(BuildContext context) => MaterialApp(
        navigatorObservers: [AudienzzNavigatorObserver()],
        home: const Scaffold(
            body: AudienzzPage(
                name: 'main', child: RemoteBannerAdExample(configId: '46'))),
      );
  List<MethodCall> pageAndLoadCalls() => calls
      .where((call) =>
          call.method == 'pageImpression' || call.method == 'loadBannerAd')
      .toList();

  for (final failure in [
    InitializationStatus.fail,
    InitializationStatus.fallbackPolling,
    null
  ]) {
    testWidgets('startup $failure keeps pages closed until a successful retry',
        (tester) async {
      var starts = 0;
      final first = Completer<InitializationStatus>();
      final retry = Completer<InitializationStatus>();
      await tester.pumpWidget(SdkInitializationGate(
        initialize: () => ++starts == 1 ? first.future : retry.future,
        readyBuilder: ready,
      ));
      await tester.pump();
      expect(starts, 1);
      expect(pageAndLoadCalls(), isEmpty);
      if (failure == null) {
        first.completeError(StateError('config unavailable'));
      } else {
        first.complete(failure);
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry initialization'), findsOneWidget);
      expect(pageAndLoadCalls(), isEmpty);
      await tester.tap(find.text('Retry initialization'));
      await tester.pump();
      expect(starts, 2);
      expect(find.text('Retry initialization'), findsNothing);
      expect(pageAndLoadCalls(), isEmpty);
      retry.complete(InitializationStatus.success);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      final events = pageAndLoadCalls();
      expect(events.map((call) => call.method),
          ['pageImpression', 'loadBannerAd']);
      final page = (events[0].arguments as Map)['pageId'];
      expect(page, isNotNull);
      expect((events[1].arguments as Map)['pageKey'], page);
      await tester.pump();
      expect(starts, 2, reason: 'rebuilding must not reinitialize');
      expect(pageAndLoadCalls(), hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
