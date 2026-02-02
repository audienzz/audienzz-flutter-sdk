import 'dart:developer';
import 'dart:io';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/audienzz_targeting.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
import 'package:flutter/services.dart';

final class AudienzzSdkFlutter {
  const AudienzzSdkFlutter._();

  static final _instance = const AudienzzSdkFlutter._().._init();

  static AudienzzSdkFlutter get instance => _instance;

  /// Required to initialize the SDK.
  Future<InitializationStatus> initialize({
    required String companyId,
    bool isAutomaticPpidEnabled = false,
  }) {
    return adInstanceManager.initialize(
      companyId: companyId,
      isAutomaticPpidEnabled: isAutomaticPpidEnabled,
    );
  }

  /// Required to initialize the SDK with remote configuration.
  Future<InitializationStatus> initializeRemote({
    required String publisherId,
    required String remoteUrl,
    bool isAutomaticPpidEnabled = false,
  }) async {
    final audienzzRemoteConfig = AudienzzRemoteConfig.instance
      ..configureRemote(
        remoteUrl: remoteUrl,
        publisherId: publisherId,
      );
    await audienzzRemoteConfig.fetchPublisherConfig();

    final config = audienzzRemoteConfig.publisherConfig;
    if (config != null) {
      final ortb = config.ortb;
      await AudienzzTargeting.setPublisherName(ortb.publisherName);

      if (ortb.domain != null) {
        await AudienzzTargeting.setDomain(ortb.domain!);
      }
      
      final advertisingSystemDomain = ortb.schain?.advertisingSystemDomain;
      final sellerId = ortb.schain?.sellerId;

      if (advertisingSystemDomain != null && sellerId != null) {
        await setSchainObject('''
                        { "source": 
                            { "schain": {
                                "ver": "1.0",
                                "complete": 1,
                                "nodes": [
                                    {
                                        "asi": $advertisingSystemDomain,
                                        "sid": $sellerId,
                                        "hp": 1
                                    }
                                  ]
                                }
                            } 
                        }
                    ''');
      }

      if (Platform.isAndroid && config.android != null) {
        await AudienzzTargeting.setBundleName(config.android!.ortb.bundleName);

        if (config.android?.ortb.storeUrl != null) {
          await AudienzzTargeting.setStoreUrl(config.android!.ortb.storeUrl!);
        }
      } else if (Platform.isIOS && config.ios != null) {
        await AudienzzTargeting.setItunesID(config.ios!.ortb.bundleId);
        await AudienzzTargeting.setBundleName(config.ios!.ortb.sourceApp);

        if (config.ios?.ortb.storeUrl != null) {
          await AudienzzTargeting.setStoreUrl(config.ios!.ortb.storeUrl!);
        }
      }
    }

    return adInstanceManager.initialize(
      companyId: config?.ortb.schain?.sellerId ?? '1',
      isAutomaticPpidEnabled: isAutomaticPpidEnabled,
      prebidServerUrl: audienzzRemoteConfig.publisherConfig?.prebidServer.url,
    );
  }

  Future<void> _init() async {
    try {
      await adInstanceManager.methodChannel.invokeMethod('_init');
    } on PlatformException catch (e) {
      log('Exception while initialization of AudienzzSdkFlutter'
          ' instance: ${e.message} ${e.details}');
    }
  }

  Future<void> setSchainObject(String schain) {
    return adInstanceManager.methodChannel.invokeMethod(
      'setSchainObject',
      {'schain': schain},
    );
  }
}
