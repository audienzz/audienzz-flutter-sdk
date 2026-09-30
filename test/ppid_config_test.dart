import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// PPID is backend-controlled, and Flutter fetches the publisher config in Dart — so the native
/// SDK never sees it and cannot read the switch itself. It has to survive parsing and be forwarded
/// at initialize, or the feature silently does nothing on this platform.
///
/// There is exactly one switch: `ppidEnabled`. `automaticPpidEnabled` used to ride alongside it and
/// gate the SDK-generated UUID, but no endpoint the SDK calls ever sent it, so it was a second gate
/// that could only ever be wrong. It is gone from the model and from the initialize payload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> config({
    bool? ppidEnabled,
    bool? automaticPpidEnabled,
  }) =>
      {
        'id': 1,
        'prebidServer': {
          'url': 'https://example.test',
          'accountId': 1,
          'statusUrl': 'https://example.test/status',
        },
        'ortb': <String, dynamic>{},
        if (ppidEnabled != null) 'ppidEnabled': ppidEnabled,
        if (automaticPpidEnabled != null)
          'automaticPpidEnabled': automaticPpidEnabled,
      };

  test('an absent switch parses as null so native applies its default', () {
    // Absent must not become `false`: that is the shape of the bug that silently dropped every
    // PPID before this was backend-controlled at all.
    final parsed = RemotePublisherConfiguration.fromJson(config());

    expect(parsed.ppidEnabled, isNull);
  });

  test('a disabled switch parses as false', () {
    final parsed =
        RemotePublisherConfiguration.fromJson(config(ppidEnabled: false));

    expect(parsed.ppidEnabled, isFalse);
  });

  test('the switch survives a round trip', () {
    final parsed =
        RemotePublisherConfiguration.fromJson(config(ppidEnabled: false));

    final round = RemotePublisherConfiguration.fromJson(parsed.toJson());

    expect(round.ppidEnabled, isFalse);
  });

  test('a payload carrying automaticPpidEnabled parses and drops it', () {
    // The backend never sent it, but a payload carrying it must still parse — and it must not
    // reappear on the way back out, where a plugin could start honouring it again.
    final parsed = RemotePublisherConfiguration.fromJson(
      config(ppidEnabled: true, automaticPpidEnabled: false),
    );

    expect(parsed.ppidEnabled, isTrue);
    expect(parsed.toJson().containsKey('automaticPpidEnabled'), isFalse);
  });

  group('the initialize payload', () {
    final codec = StandardMethodCodec(AdMessageCodec());
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(
        MethodChannel(Constants.methodChannelName, codec),
        (call) async {
          calls.add(call);
          return InitializationStatus.success;
        },
      );
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(
        MethodChannel(Constants.methodChannelName, codec),
        null,
      );
    });

    test('forwards ppidEnabled and nothing else about PPID', () async {
      await adInstanceManager.initialize(companyId: '1', ppidEnabled: false);

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['ppidEnabled'], isFalse);
      expect(args.containsKey('automaticPpidEnabled'), isFalse);
    });

    test('omits the switch entirely when the backend said nothing', () async {
      // Omitted, not `false`: native has to be free to apply its own default of enabled.
      await adInstanceManager.initialize(companyId: '1');

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args.containsKey('ppidEnabled'), isFalse);
    });
  });
}
