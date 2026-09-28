import 'dart:convert';
import 'package:audienzz_sdk_flutter/src/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<Map<dynamic, dynamic>> initializations;
  setUp(() {
    initializations = [];
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') {
        initializations.add(call.arguments as Map<dynamic, dynamic>);
        return InitializationStatus.success;
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('remote publisher identity reaches native initialization', () async {
    await http.runWithClient(
      () async {
        await AudienzzSdkFlutter.instance.initializeRemote(
          publisherId: '35',
          remoteUrl: 'https://example.test/config',
          environment: 'test',
          enablePolling: false,
        );
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('ad-configs')
                ? []
                : {
                    'id': 35,
                    'prebidServer': {
                      'url': 'https://example.test/pbs',
                      'accountId': 1,
                      'statusUrl': 'https://example.test/status',
                    },
                    'ortb': {
                      'schain': {
                        'sellerId': 'seller-1',
                        'advertisingSystemDomain': 'example.test',
                      },
                    },
                  },
          ),
          200,
        ),
      ),
    );
    expect(initializations, hasLength(1));
    expect(initializations.single['publisherId'], '35');
    expect(initializations.single['companyId'], 'seller-1');
    expect(initializations.single['environment'], 'test');
  });

  test('direct init defaults to production without a publisher', () async {
    await AudienzzSdkFlutter.instance.initialize(companyId: 'seller-1');
    expect(initializations, hasLength(1));
    expect(initializations.single['publisherId'], isNull);
    expect(initializations.single['environment'], 'production');
  });
}
