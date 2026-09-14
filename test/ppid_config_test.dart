import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

/// PPID is backend-controlled, and Flutter fetches the publisher config in Dart — so the native
/// SDK never sees it and cannot read these switches itself. They have to survive parsing and be
/// forwarded at initialize, or the feature silently does nothing on this platform.
void main() {
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

  test('absent switches parse as null so native applies its default', () {
    // Absent must not become `false`: that is the shape of the bug that silently dropped every
    // PPID before this was backend-controlled at all.
    final parsed = RemotePublisherConfiguration.fromJson(config());

    expect(parsed.ppidEnabled, isNull);
    expect(parsed.automaticPpidEnabled, isNull);
  });

  test('a disabled master switch parses as false', () {
    final parsed =
        RemotePublisherConfiguration.fromJson(config(ppidEnabled: false));

    expect(parsed.ppidEnabled, isFalse);
    expect(parsed.automaticPpidEnabled, isNull);
  });

  test('the two switches parse independently', () {
    final parsed = RemotePublisherConfiguration.fromJson(
      config(ppidEnabled: true, automaticPpidEnabled: false),
    );

    expect(parsed.ppidEnabled, isTrue);
    expect(parsed.automaticPpidEnabled, isFalse);
  });

  test('the switches survive a round trip', () {
    final parsed = RemotePublisherConfiguration.fromJson(
      config(ppidEnabled: false, automaticPpidEnabled: true),
    );

    final round = RemotePublisherConfiguration.fromJson(parsed.toJson());

    expect(round.ppidEnabled, isFalse);
    expect(round.automaticPpidEnabled, isTrue);
  });
}
