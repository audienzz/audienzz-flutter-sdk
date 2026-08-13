import 'package:audienzz_sdk_flutter/src/entities/remote_config/schain.dart';

class Ortb {
  const Ortb({
    required this.schain,
    required this.publisherName,
    required this.domain,
  });

  factory Ortb.fromJson(Map<String, dynamic> json) {
    return Ortb(
      schain: json['schain'] == null
          ? null
          : Schain.fromJson(json['schain'] as Map<String, dynamic>),
      publisherName: json['publisherName'] as String?,
      domain: json['domain'] as String?,
    );
  }

  final Schain? schain;
  final String? publisherName;
  final String? domain;

  Map<String, dynamic> toJson() => {
        'schain': schain?.toJson(),
        'publisherName': publisherName,
        'domain': domain,
      };
}
