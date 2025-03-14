import 'dart:developer';

import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:flutter/services.dart';

final class AudienzzSdkFlutter {
  const AudienzzSdkFlutter._();

  static final _instance = const AudienzzSdkFlutter._().._init();

  static AudienzzSdkFlutter get instance => _instance;

  /// Required to initialize the SDK.
  Future<InitializationStatus> initialize({required String companyId}) {
    return adInstanceManager.initialize(companyId: companyId);
  }

  Future<void> _init() async {
    try {
      await adInstanceManager.methodChannel.invokeMethod('_init');
    } on PlatformException catch (e) {
      log('Exception while initialization of AudienzzSdkFlutter'
          ' instance: ${e.message} ${e.details}');
    }
  }
}
