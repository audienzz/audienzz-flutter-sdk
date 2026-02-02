import 'dart:convert';

import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedConfig {
  CachedConfig({
    required this.adUnitConfigs,
    required this.publisherConfig,
    required this.timestamp,
  });

  factory CachedConfig.fromJson(Map<String, dynamic> json) {
    return CachedConfig(
      adUnitConfigs: (json['adUnitConfigs'] as List)
          .map((e) => RemoteAdConfiguration.fromJson(e as Map<String, dynamic>))
          .toList(),
      publisherConfig: RemotePublisherConfiguration.fromJson(
        json['publisherConfig'] as Map<String, dynamic>,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final List<RemoteAdConfiguration> adUnitConfigs;
  final RemotePublisherConfiguration publisherConfig;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'adUnitConfigs': adUnitConfigs.map((e) => e.toJson()).toList(),
        'publisherConfig': publisherConfig.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };
}

class RemoteConfigCache {
  static const String _remotePublisherConfigKey =
      'remote_publisher_configuration';
  static const Duration _cacheTTL = Duration(hours: 24);

  Future<void> save({
    required RemotePublisherConfiguration publisherConfig,
    required List<RemoteAdConfiguration> adUnitConfigs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedConfig = CachedConfig(
      adUnitConfigs: adUnitConfigs,
      publisherConfig: publisherConfig,
      timestamp: DateTime.now(),
    );
    await prefs.setString(
      _remotePublisherConfigKey,
      jsonEncode(cachedConfig.toJson()),
    );
  }

  Future<List<RemoteAdConfiguration>?> loadAdUnitConfigs() async {
    final cachedConfig = await _loadFromCache();
    return cachedConfig?.adUnitConfigs;
  }

  Future<RemotePublisherConfiguration?> loadPublisherConfig() async {
    final cachedConfig = await _loadFromCache();
    return cachedConfig?.publisherConfig;
  }

  Future<bool> isCacheValid() async {
    final cachedConfig = await _loadFromCache();
    if (cachedConfig == null) {
      return false;
    }
    return DateTime.now().difference(cachedConfig.timestamp) < _cacheTTL;
  }

  Future<CachedConfig?> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_remotePublisherConfigKey);
    if (jsonString == null) {
      return null;
    }
    try {
      return CachedConfig.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } on Object catch (_) {
      return null;
    }
  }
}
