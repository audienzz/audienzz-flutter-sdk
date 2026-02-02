class RemotePrebidConfig {
  const RemotePrebidConfig({
    required this.placementId,
    required this.adSizes,
  });

  factory RemotePrebidConfig.fromJson(Map<String, dynamic> json) {
    return RemotePrebidConfig(
      placementId: json['placementId'] as String,
      adSizes: (json['adSizes'] as List).cast<String>(),
    );
  }

  final String placementId;
  final List<String> adSizes;

  Map<String, dynamic> toJson() => {
        'placementId': placementId,
        'adSizes': adSizes,
      };
}
