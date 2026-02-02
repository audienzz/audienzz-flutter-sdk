class IosOrtb {
  const IosOrtb({
    required this.bundleId,
    required this.sourceApp,
    required this.storeUrl,
  });

  factory IosOrtb.fromJson(Map<String, dynamic> json) {
    return IosOrtb(
      bundleId: json['bundleId'] as String?,
      sourceApp: json['sourceApp'] as String?,
      storeUrl: json['storeUrl'] as String?,
    );
  }

  final String? bundleId;
  final String? sourceApp;
  final String? storeUrl;

  Map<String, dynamic> toJson() => {
        'bundleId': bundleId,
        'sourceApp': sourceApp,
        'storeUrl': storeUrl,
      };
}
