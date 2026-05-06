import 'dart:async';
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

  static const int _maxRetries = 5;
  static const Duration _retryInterval = Duration(seconds: 30);

  Timer? _retryTimer;
  int _retryCount = 0;

  RemotePublisherConfiguration? get publisherConfig => _publisherConfig;

  List<RemoteAdConfiguration>? get adUnitConfigs => _adUnitConfigs;

  void configureRemote({
    required String remoteUrl,
    required String publisherId,
  }) {
    _cancelRetryTimer();
    _remoteUrl = remoteUrl;
    _publisherId = publisherId;
  }

  Future<void> fetchPublisherConfig({bool enablePolling = true}) async {
    if (_remoteUrl == null) {
      log('Audienzz Remote Config missing remote url');
      throw Exception('AudienzzRemoteConfigError.missingRemoteUrl');
    }

    if (_publisherId == null) {
      log('Audienzz Remote Config missing publisher id');
      throw Exception('AudienzzRemoteConfigError.missingRemotePublisherId');
    }

    _cancelRetryTimer();
    log('Audienzz Remote Config started fetching new config');

    try {
      await _fetchAndPopulate();
      log('Audienzz Remote Config finished fetching new config, using it');
    } catch (e) {
      log('Audienzz Remote Config fetch failed: $e');

      if (await _remoteConfigCache.isCacheValid()) {
        _adUnitConfigs = await _remoteConfigCache.loadAdUnitConfigs();
        _publisherConfig = await _remoteConfigCache.loadPublisherConfig();

        log('Audienzz Remote Config using valid cached config');
        return;
      }

      final staleAdUnitConfigs = await _remoteConfigCache.loadAdUnitConfigs();
      if (staleAdUnitConfigs == null) {
        if (enablePolling) _startBackgroundPolling();
        rethrow;
      }
      _adUnitConfigs = staleAdUnitConfigs;
      _publisherConfig = await _remoteConfigCache.loadPublisherConfig();

      log('Audienzz Remote Config using stale cached config');
    }
  }

  RemoteAdConfiguration? remoteConfigFor(String adConfigId) {
    return _adUnitConfigs?.firstWhereOrNull((e) => e.id == adConfigId);
  }

  Future<void> _fetchAndPopulate() async {
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
  }

  void _startBackgroundPolling() {
    _retryTimer = Timer(_retryInterval, () async {
      if (_retryCount >= _maxRetries) {
        log('Audienzz Remote Config: max retries reached, giving up');
        _cancelRetryTimer();
        return;
      }
      _retryCount++;
      log('Audienzz Remote Config: background retry $_retryCount/$_maxRetries');
      try {
        await _fetchAndPopulate();
        log('Audienzz Remote Config: background retry succeeded');
        _cancelRetryTimer();
      } catch (e) {
        log('Audienzz Remote Config: background retry failed: $e');
        _startBackgroundPolling();
      }
    });
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryCount = 0;
  }
}
