import 'dart:convert';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/remote_config_fetcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ws-sdk-config moved to `sdks/{sdkId}`; `publishers/` stays only for
/// released SDKs. Flutter fetches the config in Dart, so it also has to hand
/// native the config's own `sdkId` — native reports that as `sdk_id`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remoteUrl = 'https://config.test/public/v1';
  final fetcher = RemoteConfigFetcher.instance;

  Map<String, dynamic> publisher({Object? sdkId}) => {
        'id': 35,
        if (sdkId != null) 'sdkId': sdkId,
        'prebidServer': {
          'url': 'https://pbs.test',
          'accountId': 1,
          'statusUrl': 'https://pbs.test/status',
        },
        'ortb': <String, dynamic>{},
      };

  late List<String> requested;

  void serve(int Function(String path) status, {Object? sdkId = '35'}) {
    fetcher.clientForTesting = MockClient((request) async {
      final path = request.url.path;
      requested.add(path);
      final body = path.endsWith('ad-configs')
          ? '[]'
          : jsonEncode(publisher(sdkId: sdkId));
      return http.Response(body, status(path));
    });
  }

  setUp(() {
    requested = [];
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => fetcher.clientForTesting = null);

  group('routes', () {
    test('reads the sdks route', () async {
      serve((_) => 200);
      final config = await fetcher.fetchPublisherConfig(
        remoteUrl: remoteUrl,
        publisherId: '35',
      );
      await fetcher.fetchAdUnitConfigs(remoteUrl: remoteUrl, publisherId: '35');
      expect(
        requested,
        ['/public/v1/sdks/35', '/public/v1/sdks/35/ad-configs'],
      );
      expect(config.sdkId, '35');
    });

    test('a server without the sdks route falls back to publishers', () async {
      serve((path) => path.contains('/sdks/') ? 404 : 200);
      await fetcher.fetchPublisherConfig(
        remoteUrl: remoteUrl,
        publisherId: '35',
      );
      await fetcher.fetchAdUnitConfigs(remoteUrl: remoteUrl, publisherId: '35');
      expect(requested, [
        '/public/v1/sdks/35',
        '/public/v1/publishers/35',
        '/public/v1/sdks/35/ad-configs',
        '/public/v1/publishers/35/ad-configs',
      ]);
    });

    test('any other failure is not retried on the old route', () async {
      serve((_) => 500);
      await expectLater(
        fetcher.fetchPublisherConfig(remoteUrl: remoteUrl, publisherId: '35'),
        throwsA(isA<Exception>()),
      );
      expect(requested, ['/public/v1/sdks/35']);
    });
  });

  group('sdkId', () {
    test('parses a string or a number; blank or absent is null', () {
      expect(
        RemotePublisherConfiguration.fromJson(publisher(sdkId: 'sdk-7')).sdkId,
        'sdk-7',
      );
      expect(
        RemotePublisherConfiguration.fromJson(publisher(sdkId: 35)).sdkId,
        '35',
      );
      expect(
        RemotePublisherConfiguration.fromJson(publisher(sdkId: ' ')).sdkId,
        isNull,
      );
      expect(RemotePublisherConfiguration.fromJson(publisher()).sdkId, isNull);
    });

    test('survives the on-device cache', () {
      final parsed =
          RemotePublisherConfiguration.fromJson(publisher(sdkId: 'sdk-7'));
      expect(
        RemotePublisherConfiguration.fromJson(parsed.toJson()).sdkId,
        'sdk-7',
      );
      expect(
        RemotePublisherConfiguration.fromJson(publisher())
            .toJson()
            .containsKey('sdkId'),
        isFalse,
      );
    });
  });

  group('remote initialization hands native the analytics id', () {
    final codec = StandardMethodCodec(AdMessageCodec());
    final channel = MethodChannel(Constants.methodChannelName, codec);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'initialize'
            ? InitializationStatus.success
            : null;
      });
    });

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<Object?> initializeWith({Object? sdkId}) async {
      serve((_) => 200, sdkId: sdkId);
      await AudienzzSdkFlutter.instance.initializeRemote(
        publisherId: 'init-id',
        remoteUrl: remoteUrl,
        enablePolling: false,
      );
      final initialize = calls.singleWhere((c) => c.method == 'initialize');
      return (initialize.arguments as Map<Object?, Object?>)['publisherId'];
    }

    test("the config's sdkId", () async {
      expect(await initializeWith(sdkId: 'sdk-7'), 'sdk-7');
      expect(requested.first, '/public/v1/sdks/init-id');
    });

    test('a config without sdkId keeps the id the app passed', () async {
      expect(await initializeWith(), 'init-id');
    });
  });
}
