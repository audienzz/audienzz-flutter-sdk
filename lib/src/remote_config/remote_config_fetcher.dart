import 'dart:convert';
import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP 404: the server does not serve this route.
class RemoteConfigNotFound implements Exception {
  const RemoteConfigNotFound(this.url);

  final Uri url;

  @override
  String toString() => 'Remote config route not found: $url';
}

/// ws-sdk-config. The SDK id the app initializes with addresses
/// `sdks/{sdkId}`; the `publishers/` routes are what released SDKs call and
/// are kept as a fallback when `sdks/` is not served.
class RemoteConfigFetcher {
  RemoteConfigFetcher._();

  static final RemoteConfigFetcher instance = RemoteConfigFetcher._();

  /// Replaces the HTTP client. Tests only — they must never reach the real
  /// config service.
  @visibleForTesting
  http.Client? clientForTesting;

  Future<RemotePublisherConfiguration> fetchPublisherConfig({
    required String remoteUrl,
    required String publisherId,
  }) async {
    return _fetchRoute(remoteUrl, publisherId, '', (json) {
      return RemotePublisherConfiguration.fromJson(
        json as Map<String, dynamic>,
      );
    });
  }

  Future<List<RemoteAdConfiguration>> fetchAdUnitConfigs({
    required String remoteUrl,
    required String publisherId,
  }) async {
    return _fetchRoute(remoteUrl, publisherId, '/ad-configs', (json) {
      return (json as List)
          .map((e) => RemoteAdConfiguration.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// `sdks/{sdkId}…` first. Only a 404 — a server that does not serve that
  /// route yet — falls back to `publishers/{id}…`; any other failure is
  /// reported as it is.
  Future<T> _fetchRoute<T>(
    String remoteUrl,
    String sdkId,
    String route,
    T Function(dynamic json) fromJson,
  ) async {
    try {
      return await _fetch(Uri.parse('$remoteUrl/sdks/$sdkId$route'), fromJson);
    } on RemoteConfigNotFound {
      log('Remote config: sdks/ route not found; falling back to publishers/');
      return _fetch(Uri.parse('$remoteUrl/publishers/$sdkId$route'), fromJson);
    }
  }

  Future<T> _fetch<T>(
    Uri url,
    T Function(dynamic json) fromJson,
  ) async {
    try {
      final client = clientForTesting;
      final response = await (client != null ? client.get(url) : http.get(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body);
        return fromJson(json);
      } else if (response.statusCode == 404) {
        throw RemoteConfigNotFound(url);
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
