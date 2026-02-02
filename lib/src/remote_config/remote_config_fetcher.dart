import 'dart:convert';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:http/http.dart' as http;

class RemoteConfigFetcher {
  RemoteConfigFetcher._();

  static final RemoteConfigFetcher instance = RemoteConfigFetcher._();

  Future<RemotePublisherConfiguration> fetchPublisherConfig({
    required String remoteUrl,
    required String publisherId,
  }) async {
    final url = Uri.parse('$remoteUrl/publishers/$publisherId');
    return _fetch(url, (json) {
      return RemotePublisherConfiguration.fromJson(
        json as Map<String, dynamic>,
      );
    });
  }

  Future<List<RemoteAdConfiguration>> fetchAdUnitConfigs({
    required String remoteUrl,
    required String publisherId,
  }) async {
    final url = Uri.parse('$remoteUrl/publishers/$publisherId/ad-configs');
    return _fetch(url, (json) {
      return (json as List)
          .map((e) => RemoteAdConfiguration.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<T> _fetch<T>(
    Uri url,
    T Function(dynamic json) fromJson,
  ) async {
    try {
      final response = await http.get(url);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body);
        return fromJson(json);
      } else {
        throw Exception(
          'Failed to load remote config: ${response.statusCode}',
        );
      }
    } catch (e) {
      log('Remote config fetch error: $e');
      rethrow;
    }
  }
}
