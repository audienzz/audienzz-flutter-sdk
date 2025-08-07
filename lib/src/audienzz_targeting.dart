import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:audienzz_sdk_flutter/src/entities/external_user_id.dart';

final class AudienzzTargeting {
  const AudienzzTargeting._();

  static Future<void> setUserLatLng(double? latitude, double? longitude) async {
    return adInstanceManager.methodChannel.invokeMethod('setUserLatLng', {
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  static Future<({double latitude, double longitude})?> getUserLatLng() async {
    final result = await adInstanceManager.methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getUserLatLng');
    if (result != null) {
      return (
        latitude: result['latitude'] as double,
        longitude: result['longitude'] as double,
      );
    }
    return null;
  }

  // Basic properties
  static Future<String?> getUserKeywords() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getUserKeywords',
    );
  }

  static Future<List<String>> getKeywordSet() async {
    final result = await adInstanceManager.methodChannel
        .invokeMethod<List<dynamic>>('getKeywordSet');
    return result?.cast<String>() ?? [];
  }

  static Future<void> setPublisherName(String? name) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setPublisherName',
      {'value': name},
    );
  }

  static Future<String?> getPublisherName() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getPublisherName',
    );
  }

  static Future<void> setDomain(String domain) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setDomain',
      {'value': domain},
    );
  }

  static Future<String> getDomain() async {
    return await adInstanceManager.methodChannel.invokeMethod<String>(
          'getDomain',
        ) ??
        '';
  }

  static Future<void> setStoreUrl(String storeUrl) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setStoreUrl',
      {'value': storeUrl},
    );
  }

  static Future<String> getStoreUrl() async {
    return await adInstanceManager.methodChannel.invokeMethod<String>(
          'getStoreUrl',
        ) ??
        '';
  }

  static Future<List<String>> getAccessControlList() async {
    final result = await adInstanceManager.methodChannel
        .invokeMethod<List<dynamic>>('getAccessControlList');
    return result?.cast<String>() ?? [];
  }

  static Future<void> setOmidPartnerName(String? name) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setOmidPartnerName',
      {'value': name},
    );
  }

  static Future<String?> getOmidPartnerName() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getOmidPartnerName',
    );
  }

  static Future<void> setOmidPartnerVersion(String? version) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setOmidPartnerVersion',
      {'value': version},
    );
  }

  static Future<String?> getOmidPartnerVersion() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getOmidPartnerVersion',
    );
  }

  // COPPA and GDPR methods
  static Future<void> setSubjectToCOPPA({required bool isSubject}) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setSubjectToCOPPA',
      {'value': isSubject},
    );
  }

  static Future<bool?> isSubjectToCOPPA() async {
    return adInstanceManager.methodChannel.invokeMethod<bool>(
      'isSubjectToCOPPA',
    );
  }

  static Future<void> setSubjectToGDPR({required bool isSubject}) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setSubjectToGDPR',
      {'value': isSubject},
    );
  }

  static Future<bool?> isSubjectToGDPR() async {
    return adInstanceManager.methodChannel.invokeMethod<bool>(
      'isSubjectToGDPR',
    );
  }

  static Future<void> setGdprConsentString(String? consentString) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setGdprConsentString',
      {'value': consentString},
    );
  }

  static Future<String?> getGdprConsentString() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getGdprConsentString',
    );
  }

  static Future<void> setPurposeConsents(String? consents) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setPurposeConsents',
      {'value': consents},
    );
  }

  static Future<String?> getPurposeConsents() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getPurposeConsents',
    );
  }

  static Future<void> setBundleName(String? bundleName) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setBundleName',
      {'value': bundleName},
    );
  }

  static Future<String?> getBundleName() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getBundleName',
    );
  }

  static Future<Map<String, List<String>>> getExtDataDictionary() async {
    final result = await adInstanceManager.methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('getExtDataDictionary');
    if (result != null) {
      return result.map(
        (key, value) => MapEntry(
          key as String,
          (value as List<dynamic>).cast<String>(),
        ),
      );
    }
    return {};
  }

  static Future<bool?> isDeviceAccessConsent() async {
    return adInstanceManager.methodChannel.invokeMethod<bool>(
      'isDeviceAccessConsent',
    );
  }

  static Future<void> setUserExt(Map<String, dynamic>? ext) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setUserExt',
      {'ext': ext},
    );
  }

  static Future<Map<String, dynamic>?> getUserExt() async {
    return adInstanceManager.methodChannel
        .invokeMethod<Map<String, dynamic>>('getUserExt');
  }

  static Future<void> addUserKeyword(String keyword) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addUserKeyword',
      {'keyword': keyword},
    );
  }

  static Future<void> addUserKeywords(List<String> keywords) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addUserKeywords',
      {'keywords': keywords},
    );
  }

  static Future<void> removeUserKeyword(String keyword) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'removeUserKeyword',
      {'keyword': keyword},
    );
  }

  static Future<void> clearUserKeywords() async {
    return adInstanceManager.methodChannel.invokeMethod('clearUserKeywords');
  }

  // External User ID methods
  static Future<void> setExternalUserIds(
    List<ExternalUserId>? externalUserIds,
  ) async {
    final serialized = externalUserIds?.map((e) => e.toMap()).toList();
    await adInstanceManager.methodChannel.invokeMethod(
      'setExternalUserIds',
      {'externalUserIds': serialized},
    );
  }

  static Future<List<ExternalUserId>?> getExternalUserIds() async {
    final result = await adInstanceManager.methodChannel
        .invokeMethod<List<dynamic>>('getExternalUserIds');
    return result
        ?.map(
          (e) => ExternalUserId.fromMap(e as Map<dynamic, dynamic>),
        )
        .toList();
  }

  // Ext Data methods
  static Future<void> addExtData(String key, String value) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addExtData',
      {'key': key, 'value': value},
    );
  }

  static Future<void> updateExtData(String key, List<String> values) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'updateExtData',
      {'key': key, 'values': values},
    );
  }

  static Future<void> removeExtData(String key) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'removeExtData',
      {'key': key},
    );
  }

  static Future<void> clearExtData() async {
    return adInstanceManager.methodChannel.invokeMethod('clearExtData');
  }

  static Future<void> addBidderToAccessControlList(String bidderName) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addBidderToAccessControlList',
      {'bidderName': bidderName},
    );
  }

  static Future<void> removeBidderFromAccessControlList(
    String bidderName,
  ) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'removeBidderFromAccessControlList',
      {'bidderName': bidderName},
    );
  }

  static Future<void> clearAccessControlList() async {
    return adInstanceManager.methodChannel.invokeMethod(
      'clearAccessControlList',
    );
  }

  // Purpose consent methods
  static Future<bool?> getPurposeConsent(int index) async {
    return adInstanceManager.methodChannel.invokeMethod<bool>(
      'getPurposeConsent',
      {'index': index},
    );
  }

  // Global ORTB config methods
  static Future<String?> getGlobalOrtbConfig() async {
    return adInstanceManager.methodChannel.invokeMethod<String>(
      'getGlobalOrtbConfig',
    );
  }

  static Future<void> setGlobalOrtbConfig(Map<String, dynamic> config) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'setGlobalOrtbConfig',
      {'config': config},
    );
  }

  // Global targeting methods
  static Future<void> addSingleGlobalTargeting(String key, String value) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addGlobalTargeting',
      {'key': key, 'value': value},
    );
  }

  static Future<void> addGlobalTargeting(String key, Set<String> values) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'addGlobalTargeting',
      {'key': key, 'values': values.toList()},
    );
  }

  static Future<void> removeGlobalTargeting(String key) async {
    return adInstanceManager.methodChannel.invokeMethod(
      'removeGlobalTargeting',
      {'key': key},
    );
  }

  static Future<void> clearGlobalTargeting() async {
    return adInstanceManager.methodChannel.invokeMethod('clearGlobalTargeting');
  }
}
