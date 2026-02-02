import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_ad_configuration.dart';
import 'package:audienzz_sdk_flutter/src/entities/remote_config/remote_publisher_configuration.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/remote_config_cache.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/remote_config_fetcher.dart';
import 'package:collection/collection.dart';

class AudienzzRemoteConfig {
  AudienzzRemoteConfig._();

  static final AudienzzRemoteConfig instance = AudienzzRemoteConfig._();

  final _remoteConfigCache = RemoteConfigCache();
  final _remoteConfigFetcher = RemoteConfigFetcher.instance;

  String? _publisherId;
  String? _remoteUrl;

  RemotePublisherConfiguration? _publisherConfig;
  List<RemoteAdConfiguration>? _adUnitConfigs;

  RemotePublisherConfiguration? get publisherConfig => _publisherConfig;

  List<RemoteAdConfiguration>? get adUnitConfigs => _adUnitConfigs;

  void configureRemote({
    required String remoteUrl,
    required String publisherId,
  }) {
    _remoteUrl = remoteUrl;
    _publisherId = publisherId;
  }

  Future<void> fetchPublisherConfig() async {
    if (_remoteUrl == null) {
      log('Audienzz Remote Config missing remote url');
      throw Exception('AudienzzRemoteConfigError.missingRemoteUrl');
    }

    if (_publisherId == null) {
      log('Audienzz Remote Config missing publisher id');
      throw Exception('AudienzzRemoteConfigError.missingRemotePublisherId');
    }

    log('Audienzz Remote Config started fetching new config');

    try {
      final publisherConfig = await _remoteConfigFetcher.fetchPublisherConfig(
        remoteUrl: _remoteUrl!,
        publisherId: _publisherId!,
      );
      final adUnitConfigs = await _remoteConfigFetcher.fetchAdUnitConfigs(
        remoteUrl: _remoteUrl!,
        publisherId: _publisherId!,
      );

      await _remoteConfigCache.save(
        publisherConfig: publisherConfig,
        adUnitConfigs: adUnitConfigs,
      );

      _publisherConfig = publisherConfig;
      _adUnitConfigs = adUnitConfigs;

      log('Audienzz Remote Config finished fetching new config, using it');
    } catch (e) {
      log('Audienzz Remote Config fetch failed: $e');

      if (await _remoteConfigCache.isCacheValid()) {
        _adUnitConfigs = await _remoteConfigCache.loadAdUnitConfigs();
        _publisherConfig = await _remoteConfigCache.loadPublisherConfig();

        log('Audienzz Remote Config using valid cached config');
        return;
      }

      if (_adUnitConfigs == null) {
        rethrow;
      }

      log('Audienzz Remote Config using stale cached config');
    }
  }

  RemoteAdConfiguration? remoteConfigFor(String adConfigId) {
    return _adUnitConfigs?.firstWhereOrNull((e) => e.id == adConfigId);
  }
}
