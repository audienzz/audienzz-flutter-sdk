import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> config() => {
        'id': 35,
        'prebidServer': {
          'url': 'https://example.test',
          'accountId': 1,
          'statusUrl': 'https://example.test/status',
        },
        'ortb': <String, dynamic>{},
      };
  test('optional batch field tolerates absent and malformed values', () {
    expect(
      RemotePublisherConfiguration.fromJson(config()).analyticsBatchSize,
      isNull,
    );
    for (final value in <Object?>[
      null,
      '',
      '  ',
      0,
      -2,
      false,
      <String, Object?>{},
      <Object?>[],
      3.5,
    ]) {
      final parsed = RemotePublisherConfiguration.fromJson(
        {...config(), 'analyticsBatchSize': value},
      );
      expect(
        parsed.analyticsBatchSize,
        isNull,
        reason: '$value should use native default 10',
      );
      expect(parsed.id, 35);
    }
  });
  test('batch size is cached and capped at fifteen', () {
    for (final entry in {1: 1, 8: 8, 999: 15, ' 7 ': 7}.entries) {
      final parsed = RemotePublisherConfiguration.fromJson(
        {...config(), 'analyticsBatchSize': entry.key},
      );
      expect(parsed.analyticsBatchSize, entry.value);
      final cached = RemotePublisherConfiguration.fromJson(parsed.toJson());
      expect(cached.analyticsBatchSize, entry.value);
    }
  });
}
